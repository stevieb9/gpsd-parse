package GPSD::Parse;

use strict;
use warnings;

use Carp qw(croak);
use IO::Socket::INET;

our $VERSION = '1.04';

BEGIN {

    # look for JSON::XS, and if not available, fall
    # back to JSON::PP to avoid requiring non-core modules

    my $json_ok = eval {
        require JSON::XS;
        JSON::XS->import;
        1;
    };
    if (! $json_ok){
        require JSON::PP;
        JSON::PP->import;
    }
}

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;

    $self->_file($args{file});
    $self->_is_metric($args{metric});
    $self->_is_signed($args{signed});

    if (! $self->_file) {
        $self->_port($args{port});
        $self->_host($args{host});
        $self->_socket;
        $self->_is_socket(1);
        $self->on;
    }

    return $self;
}
sub on {
    $_[0]->_socket->send('?WATCH={"enable": true}' . "\n");
}
sub off {
    $_[0]->_socket->send('?WATCH={"enable": false}' . "\n");
}
sub poll {
    my ($self, %args) = @_;
 
    $self->_file($args{file});

    my $gps_json_data;

    if ($self->_file){
        my $fname = $self->_file;

        open my $fh, '<', $fname or croak "can't open file '$fname': $!";

        {
            local $/;
            $gps_json_data = <$fh>;
            close $fh or croak "can't close file '$fname': $!";
        }
    }
    else {
        $self->_socket->send("?POLL;\n");
        local $/ = "\r\n";
        while (my $line = $self->_socket->getline){
            chomp $line;
            my $data = decode_json $line;
            if ($data->{class} eq 'POLL'){
                $gps_json_data = $line;
                last;
            }
        }
    }

    die "no JSON data returned from the GPS" if ! defined $gps_json_data;

    my $gps_perl_data = decode_json $gps_json_data;

    my $tpv = $gps_perl_data->{tpv}[0];

    if (! defined $tpv || ! defined $tpv->{lat}){
        warn "Waiting for valid GPS signal...\n";
        return;
    }

    $self->_parse($gps_perl_data);

    return $gps_json_data if defined $args{return} && $args{return} eq 'json';
    return $gps_perl_data;
}

# tpv methods

sub tpv {
    my ($self, $stat) = @_;

    if (defined $stat){
        return '' if ! defined $self->{tpv}{$stat};
        return $self->{tpv}{$stat};
    }
    return $self->{tpv};
}
sub lon {
    return $_[0]->tpv('lon');
}
sub lat {
    return $_[0]->tpv('lat');
}
sub alt {
    return $_[0]->tpv('alt');
}
sub climb {
    return $_[0]->tpv('climb');
}
sub speed {
    return $_[0]->tpv('speed');
}
sub track {
    return $_[0]->tpv('track');
}

# sky methods

sub sky {
    return shift->{sky};
}
sub satellites {
    my ($self, $sat_num, $stat) = @_;

    if (defined $sat_num){
        return undef if ! defined $self->{satellites}{$sat_num};
    }

    if (defined $sat_num && defined $stat){
        return undef if ! defined $self->{satellites}{$sat_num}{$stat};
        return $self->{satellites}{$sat_num}{$stat};
    }
    return $self->{satellites};
}

# device methods

sub device {
    return shift->{device};
}
sub time {
    return shift->{time};
}

# helper/convenience methods

sub direction {
    shift if @_ > 1;

    my ($deg) = @_;

    my @directions = qw(
        N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW N
    );

    my $calc = (($deg % 360) / 22.5) + .5;

    return $directions[$calc];
}
sub feet {
    return $_[0]->_is_metric(0);
}
sub metres {
    return $_[0]->_is_metric(1);
}
sub signed {
    my $self = shift;

    if (! @_){
        # caller just wants to set is_signed
        return $self->_is_signed(1);
    }

    my ($lat, $lon) = @_;

    return ($lat, $lon) if $lat !~ /[NESW]$/;
    return ($lat, $lon) if $lon !~ /[NESW]$/;

    my %directions = (
        W => '-',
        E => '',
        N => '',
        S => '-',
    );

    for ($lat, $lon){
        my ($dir) = $_ =~ /([NESW])$/;
        s/([NESW])$//;
        $_ = $directions{$dir} . $_;
    }

    return ($lat, $lon);
}
sub unsigned {
    my $self = shift;

    if (! @_){
        # caller just wants to set unsigned
        return $self->_is_signed(0);
    }
    my ($lat, $lon) = @_;

    return ($lat, $lon) if $lat =~ /[NESW]$/;
    return ($lat, $lon) if $lon =~ /[NESW]$/;

    if ($lat =~ /^-/) {
        $lat =~ s/-(.*)/${1}S/;
    }
    else {
        $lat .= 'N';
    }

    if ($lon =~ /^-/) {
        $lon =~ s/-(.*)/${1}W/;
    }
    else {
        $lon .= 'E';
    }

    return ($lat, $lon);
}

# private methods

sub _convert {
    my $self = shift;

    my @convertable_stats = qw(alt climb speed);

    if (! $self->_is_metric){
        for (@convertable_stats) {
            my $num = $self->{tpv}{$_};
            $num = $num * 3.28084;
            $self->{tpv}{$_} = substr($num, 0, index($num, '.') + 1 + 3);
        }
    }
}
sub _file {
    my ($self, $file) = @_;
    $self->{file} = $file if defined $file;
    return $self->{file};
}
sub _host {
    my ($self, $host) = @_;
    $self->{host} = $host if defined $host;
    $self->{host} = '127.0.0.1' if ! defined $self->{host};
    return $self->{host};
}
sub _is_metric {
    # whether we're in feet or metres mode
    my ($self, $metric) = @_;
    $self->{metric} = $metric if defined $metric;
    $self->{metric} = 1 if ! defined $self->{metric};
    return $self->{metric};
}
sub _is_signed {
    # set whether we're in signed or unsigned mode
    my ($self, $signed) = @_;
    $self->{signed} = $signed if defined $signed;
    $self->{signed} = 1 if ! defined $self->{signed};
    return $self->{signed};
}
sub _port {
    my ($self, $port) = @_;
    $self->{port} = $port if defined $port;
    $self->{port} = 2947 if ! defined $self->{port};
    return $self->{port};
}
sub _parse {
    # parse the GPS data and populate the object
    my ($self, $data) = @_;

    $self->{tpv}  = $data->{tpv}[0];
    $self->{time} = $self->{tpv}{time};
    $self->{device} = $self->{tpv}{device};
    $self->{sky} = $data->{sky}[0];

    # perform conversions on metric/standard if necessary

    $self->_convert;

    # perform conversions on the lat/long if necessary

    my ($lat, $lon) = ($self->{tpv}{lat}, $self->{tpv}{lon});

    ($self->{tpv}{lat}, $self->{tpv}{lon}) = $self->_is_signed
        ? $self->signed($lat, $lon)
        : $self->unsigned($lat, $lon);

    my %sats;

    for my $sat (@{ $self->{sky}{satellites} }){
        my $prn = $sat->{PRN};
        delete $sat->{PRN};
        $sat->{used} = $sat->{used} ? 1 : 0;
        $sats{$prn} = $sat;
    }
    $self->{satellites} = \%sats;
}
sub _is_socket {
    # check if we're in socket mode
    my ($self, $status) = @_;
    $self->{is_socket} = $status if defined $status;
    return $self->{is_socket};
}
sub _socket {
    my ($self) = @_;

    return undef if $self->_file;

    if (! defined $self->{socket}){
        $self->{"socket"}=IO::Socket::INET->new(
                        PeerAddr => $self->_host,
                        PeerPort => $self->_port,
        );
    }

    my ($h, $p) = ($self->_host, $self->_port);

    croak "can't connect to gpsd://$h:$p" if ! defined $self->{socket};
  
    return $self->{'socket'};
}
sub DESTROY {
    my $self = shift;
    $self->off if $self->_is_socket;
}
sub _vim {} # fold placeholder

1;

=head1 NAME

GPSD::Parse - Parse, extract use the JSON output from GPS units

=for html
<a href="http://travis-ci.org/stevieb9/gpsd-parse"><img src="https://secure.travis-ci.org/stevieb9/gpsd-parse.png"/>
<a href='https://coveralls.io/github/stevieb9/gpsd-parse?branch=master'><img src='https://coveralls.io/repos/stevieb9/gpsd-parse/badge.svg?branch=master&service=github' alt='Coverage Status' /></a>

=head1 SYNOPSIS

    use GPSD::Parse;
    my $gps = GPSD::Parse->new;

    # poll for data

    $gps->poll;

    # get all TPV data in an href

    my $tpv_href = $gps->tpv;

    # get individual TPV stats

    print $gps->tpv('lat');
    print $gps->tpv('lon');

    # ...or

    print $gps->lat;
    print $gps->lon;

    # timestamp of the most recent poll

    print $gps->time;

    # get all satellites in an href of hrefs

    my $sats = $gps->satellites;

    # get an individual piece of info from a single sattelite

    print $gps->satellites(16, 'ss');

    # check which serial device the GPS is connected to

    print $gps->device;

    # toggle between metres and feet (metres by default)

    $gps->feet;
    $gps->metres;

=head1 DESCRIPTION

Simple, lightweight (core only) distribution that polls C<gpsd> for data
received from a UART (serial/USB) connected GPS receiver over a TCP connection.

The data is fetched in JSON, and returned as Perl data.

=head1 NOTES

=head2 Requirements

A version of L<gpsd|http://catb.org/gpsd/gpsd.html> that returns results in
JSON format is required to have been previously installed. It should be started
at system startup, with the following flags with system-specific serial port.
See the above link for information on changing the listen IP and port.

    sudo gpsd /dev/ttyS0 -n -F /var/log/gpsd.sock

NOTE: The C<-n> flag *must* be present when running C<gpsd>. If not, this
software will stay in an endless loop of "Waiting for a valid GPS signal", even
if the GPS device has been triangulated. See your Operating Systems startup
system to add this flag to the startup if necessary (on Ubuntu, add "-n" to the
C<GPSD_OPTIONS> section in C</etc/defaults/gpsd>).

=head2 Available Data

Each of the methods that return data have a table in their respective
documentation within the L</METHODS> section. Specifically, look at the
L<tpv()|/tpv($stat)>, L<satellites()|/satellites($num, $stat)> and the more
broad L<sky()|/sky> method sections to understand what available data attributes
you can extract.

=head2 Conversions

All output where applicable defaults to metric (metres). See the C<metric>
parameter in the L<new()|/new(%args)> method to change this to use imperial/standard
measurements. You can also toggle this at runtime with the L<feet()|/feet> and
L<metres()|/metres> methods.

For latitude and longitude, we default to using the signed notation. You can
disable this with the C<signed> parameter in L<new()|/new(%args)>, along with the
L<signed()|/signed> and L<unsigned()|/unsigned> methods to toggle this
conversion at runtime.

=head1 METHODS

=head2 new(%args)

Instantiates and returns a new L<GPSD::Parse> object instance.

Parameters:

    host => 127.0.0.1

Optional, String: An IP address or fully qualified domain name of the C<gpsd>
server. Defaults to the localhost (C<127.0.0.1>) if not supplied.

    port => 2947

Optional, Integer: The TCP port number that the C<gpsd> daemon is running on.
Defaults to C<2947> if not sent in.

    metric => Bool

Optional, Integer: By default, we return measurements in metric (metres). Send
in a false value (C<0>) to use imperial/standard measurement conversions
(ie. feet). Note that if returning the raw *JSON* data from the
L<poll()|/poll(%args)> method, the conversions will not be done. The default raw
Perl return will have been converted however.

    signed => Bool

Optional, Integer: By default, we use the signed notation for latitude and
longitude. Send in a false value (C<0>) to disable this. Here's an example:

    enabled (default)   disabled
    -----------------   --------

    lat: 51.12345678    51.12345678N
    lon: -114.123456    114.123456W

We add the letter notation at the end of the result if C<signed> is disabled.

NOTE: You can toggle this at runtime by calling the L<signed()|/signed> and
L<unsigned()|/unsigned> methods. The data returned at the next poll will reflect
any change.

    file => 'filename.ext'

Optional, String: For testing purposes. Instead of reading from a socket, send
in a filename that contains legitimate JSON data saved from a previous C<gpsd>
output and we'll operate on that. Useful also for re-running previous output.

=head2 poll(%args)

Does a poll of C<gpsd> for data, and configures the object with that data.

Parameters:

All parameters are sent in as a hash.

    file => $filename

Optional, String: Used for testing, you can send in the name of a JSON file
that contains C<gpsd> JSON data and we'll work with that instead of polling
the GPS device directly. Note that you *must* instantiate the object with the
C<file> parameter in new for this to have any effect and to bypass the socket
creation.

    return => 'json'

Optional, String: By default, after configuring the object, we will return the
polled raw data as a Perl hash reference. Send this param in with the value of
C<'json'> and we'll return the data exactly as we received it from C<gpsd>.

Returns:

The raw poll data as either a Perl hash reference structure or as the
original JSON string. If the GPS receiver has not yet locked in, the return
will be C<undef>.

NOTE: If polling within a loop, you can check the return value of C<poll()> to
ensure there's valid data before proceeding. Eg:

    while (1){
        next if ! defined $gps->poll;
        ...
    }

=head2 lon

Returns the longitude. Alias for C<< $gps->tpv('lon') >>.

=head2 lat

Returns the latitude. Alias for C<< $gps->tpv('lat') >>.

=head2 alt

Returns the altitude. Alias for C<< $gps->tpv('alt') >>.

=head2 climb

Returns the rate of ascent/decent. Alias for C<< $gps->tpv('climb') >>.

=head2 speed

Returns the rate of movement. Alias for C<< $gps->tpv('speed') >>.

=head2 track

Returns the direction of movement, in degrees. Alias for
C<< $gps->tpv('track') >>.

=head2 tpv($stat)

C<TPV> stands for "Time Position Velocity". This is the data that represents
your location and other vital statistics.

By default, we return a hash reference. The format of the hash is depicted
below. Note also that the most frequently used stats also have their own
methods that can be called on the object as opposed to having to reach into
a hash reference.

Parameters:

    $stat

Optional, String. You can extract individual statistics of the TPV data by
sending in the name of the stat you wish to fetch. This will then return the
string value if available. Returns an empty string if the statistic doesn't
exist.

Available statistic/info name, example value, description. This is the default
raw result:

   time     => '2017-05-16T22:29:29.000Z'   # date/time in UTC
   lon      => '-114.000000000'             # longitude
   lat      => '51.000000'                  # latitude
   alt      => '1084.9'                     # altitude (metres)
   climb    => '0'                          # rate of ascent/decent (metres/sec)
   speed    => '0'                          # rate of movement (metres/sec)
   track    => '279.85'                     # heading (degrees from true north)
   device   => '/dev/ttyS0'                 # GPS serial interface            
   mode     => 3                            # NMEA mode
   epx      => '3.636'                      # longitude error estimate (metres)
   epy      => '4.676'                      # latitude error estimate (metres)
   epc      => '8.16'                       # ascent/decent error estimate (meters)
   ept      => '0.005'                      # timestamp error (sec) 
   epv      => '4.082'                      # altitude error estimate (meters)
   eps      => '9.35'                       # speed error estimate (metres/sec)
   class    => 'TPV'                        # data type (fixed as TPV)
   tag      => 'ZDA'                        # identifier

=head2 satellites($num, $stat)

This method returns a hash reference of hash references, where the key is the
satellite number, and the value is a hashref that contains the various
information related to the specific numbered satellite.

Note that the data returned by this function has been manipuated and is not
exactly equivalent of that returned by C<gpsd>. To get the raw data, see 
L<sky()|/sky>.

Parameters:

    $num

Optional, Integer: Send in the satellite number and we'll return the relevant
information in a hash reference for the specific satellite requested, as
opposed to returning data for all the satellites. Returns C<undef> if a
satellite by that number doesn't exist.

    $stat

Optional, String: Like C<tpv()>, you can request an individual piece of
information for a satellite. This parameter is only valid if you've sent in
the C<$num> param, and the specified satellite exists.

Available statistic/information items available for each satellite, including
the name, an example value and a description:

NOTE: The PRN attribute will not appear unless you're using raw data. The PRN
can be found as the satellite hash reference key after we've processed the
data.

    PRN     => 16   # PRN ID of the satellite 

                    # 1-63 are GNSS satellites
                    # 64-96 are GLONASS satellites
                    # 100-164 are SBAS satellites

    ss      => 20   # signal strength (dB)
    az      => 161  # azimuth (degrees from true north)
    used    => 1    # currently being used in calculations
    el      => 88   # elevation in degrees

=head2 sky

Returns a hash reference containing all of the data that was pulled from the
C<SKY> information returned by C<gpsd>. This information contains satellite
info and other related statistics.

Available information, with the attribute, example value and description:

    satellites  => []           # array of satellite hashrefs
    xdop        => '0.97'       # longitudinal dilution of precision
    ydop        => '1.25'       # latitudinal dilution of precision
    pdop        => '1.16'       # spherical dilution of precision
    tdop        => '2.2'        # time dilution of precision
    vdop        => '0.71'       # altitude dilution of precision
    gdop        => '3.87'       # hyperspherical dilution of precision
    hdop        => '0.92'       # horizontal dilution of precision
    class       => 'SKY'        # object class, hardcoded to SKY
    tag         => 'ZDA'        # object ID
    device      => '/dev/ttyS0' # serial port connected to the GPS

=head2 direction($degree)

Converts a degree from true north into a direction (eg: ESE, SW etc).

Parameters:

    $degree

Mandatory, Integer/Decimal: A decimal ranging from 0-360. Returns the direction
representing the degree from true north. A common example would be:

    my $heading = $gps->direction($gps->track);

Degree/direction map:

    N       348.75 - 11.25
    NNE     11.25  - 33.75
    NE      33.75  - 56.25
    ENE     56.25  - 78.75

    E       78.75  - 101.25
    ESE     101.25 - 123.75
    SE      123.75 - 146.25
    SSE     146.25 - 168.75

    S       168.75 - 191.25
    SSW     191.25 - 213.75
    SW      213.75 - 236.25
    WSW     236.25 - 258.75

    W       258.75 - 281.25
    WNW     281.25 - 303.75
    NW      303.75 - 326.25
    NNW     326.25 - 348.75

=head2 device

Returns a string containing the actual device the GPS is connected to
(eg: C</dev/ttyS0>).

=head2 time

Returns a string of the date and time of the most recent poll, in UTC.

=head2 signed

This method works on the latitude and longitude output view. By default, we use
signed notation, eg:

    -114.1111111111 # lon
    51.111111111111 # lat

If you've switched to L<unsigned()|/unsigned>, calling this method will toggle
it back, and the results will be visible after the next L<poll()|/poll(%args)>.

You can optionally use this method to convert values in a manual way. Simply
send in the latitude and longitude in that order as parameters, and we'll return
a list containing them both after modification, if it was necessary.

=head2 unsigned

This method works on the latitude and longitude output view. By default, we use
signed notation, eg:

    -114.1111111111 # lon
    51.111111111111 # lat

Calling this method will convert those to:

    114.1111111111W # lon
    51.11111111111N # lat

If you've switched to L<signed()|/signed> calling this method will toggle it
back, and the results will be visible after the next L<poll()|/poll(%args)>.

You can optionally use this method to convert values in a manual way. Simply
send in the latitude and longitude in that order as parameters, and we'll return
a list containing them both after modification, if it was necessary.

=head2 feet

By default, we use metres as the measurement for any attribute that is measured
in distance. Call this method to have all attributes converted into feet
commencing at the next call to L<poll()|/poll(%args)>. Use L<metres()|/metres>
to revert back.

=head2 metres

We measure in metres by default. If you've switched to using feet as the
measurement unit, a call to this method will revert back to the default.

=head2 on

Puts C<gpsd> in listening mode, ready to poll data from.

We call this method internally when the object is instantiated with
L<new()|/new(%args)> if we're not in file mode. Likewise, when the object is
destroyed (end of program run), we call the subsequent L<off()|/off> method.

If you have long periods of a program run where you don't need the GPS, you can
manually run the L<off()|/off> and L<on()|/on> methods to disable and re-enable
the GPS.

=head2 off

Turns off C<gpsd> listening mode.

Not necessary to call, but it will help preserve battery life if running on a
portable device for long program runs where the GPS is used infrequently. Use in
conjunction with L<on()|/on>. We call L<off()|/off> automatically when the
object goes out of scope (program end for example).

=head1 EXAMPLES

=head2 Basic Features and Options

Here's a simple example using some of the basic features and options. Please
read through the documentation of the methods (particularly L<new()|/new(%args)>
and L<tpv()|/tpv($stat)> to get a good grasp on what can be fetched).

    use warnings;
    use strict;
    use feature 'say';

    use GPSD::Parse;

    my $gps = GPSD::Parse->new(signed => 0);

    $gps->poll;

    my $lat = $gps->lat;
    my $lon = $gps->lon;

    my $heading = $gps->track; # degrees
    my $direction = $gps->direction($heading); # ENE etc

    my $altitude = $gps->alt;

    my $speed = $gps->speed;

    say "latitude:  $lat";
    say "longitude: $lon\n";

    say "heading:   $heading degrees";
    say "direction: $direction\n";

    say "altitude:  $altitude metres\n";

    say "speed:     $speed metres/sec";

Output:

    latitude:  51.1111111N
    longitude: 114.11111111W

    heading:   31.23 degrees
    direction: NNE

    altitude:  1080.9 metres

    speed:     0.333 metres/sec

=head2 Displaying Satellite Information

Here's a rough example that displays the status of tracked satellites, along
with the information on the ones we're currently using.

    use warnings;
    use strict;

    use GPSD::Parse;

    my $gps = GPSD::Parse->new;

    while (1){
        $gps->poll;
        my $sats = $gps->satellites;

        for my $sat (keys %$sats){
            if (! $gps->satellites($sat, 'used')){
                print "$sat: unused\n";
            }
            else {
                print "$sat: used\n";
                for (keys %{ $sats->{$sat} }){
                    print "\t$_: $sats->{$sat}{$_}\n";
                }
            }
        }
        sleep 3;
    }

Output:

    7: used
        ss: 20
        used: 1
        az: 244
        el: 20
    29: unused
    31: used
        el: 12
        az: 64
        used: 1
        ss: 17
    6: unused
    138: unused
    16: used
        ss: 17
        el: 53
        used: 1
        az: 119
    26: used
        az: 71
        used: 1
        el: 46
        ss: 27
    22: used
        ss: 28
        el: 17
        used: 1
        az: 175
    3: used
        ss: 24
        az: 192
        used: 1
        el: 40
    9: unused
    23: unused
    2: unused

=head1 TESTING

Please note that we init and disable the GPS device on construction and
deconstruction of the object respectively. It takes a few seconds for the GPS
unit to initialize itself and then lock on the satellites before we can get
readings. For this reason, please understand that one test sweep may pass while
the next fails.

NOTE: Some GPS receivers can take up to 20 minutes before it acquires a peroper
lock.

I am considering adding specific checks, but considering that it's a timing
thing (seconds, not microseconds that everyone is in a hurry for nowadays) I am
going to wait until I get a chance to take the kit into the field before I do
anything drastic.

For now. I'll leave it as is; expect failure if you ram on things too quickly.

=head1 SEE ALSO

A very similar distribution is L<Net::GPSD3>. However, it has a long line of
prerequisite distributions that didn't always install easily on my primary
target platform, the Raspberry Pi.

This distribution isn't meant to replace that one, it's just a much simpler and
more lightweight piece of software that pretty much does the same thing.

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2019 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.
