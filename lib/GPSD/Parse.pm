package GPSD::Parse;

use strict;
use warnings;

use Carp qw(croak);
use JSON;

our $VERSION = '0.01';

sub new {
    return bless {}, shift;
}
sub on {
    #FIXME: configure ?WATCH={"enable": true}
}
sub off {
    #FIXME: configure ?WATCH={"enable": false}
}
sub poll {
    my ($self, %args) = @_;
  
    # fname => json file (testing)
    # return => json

    my $gps_json_data;

    if ($args{fname}){
        my $fname = $args{fname};

        open my $fh, '<', $fname or croak "can't open file '$fname': $!";

        {
            local $/;
            $gps_json_data = <$fh>;
            close $fh or croak "can't close file '$fname': $!";
        }
    }
    else {
        # socket read from UART here...
    }

    #FIXME: check what is returned to ensure the following
    # line is correct in its assumption

    return undef if ! $gps_json_data;

    my $gps_perl_data = decode_json $gps_json_data;

    $self->_parse($gps_perl_data);

    return $gps_json_data if defined $args{return} && $args{return} eq 'json';
    return $gps_perl_data;
}
sub tpv {
    my ($self, $stat) = @_;

    if (defined $stat){
        return undef if ! defined $self->{tpv}{$stat};
        return $self->{tpv}{$stat};
    }
    return $self->{tpv};
}
sub sky {
    return shift->{sky};
}
sub time {
    return shift->{time};
}
sub device {
    return shift->{device};
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
sub _parse {
    my ($self, $data) = @_;

    $self->{tpv}  = $data->{tpv}[0];

    $self->{time} = $self->{tpv}{time};
    $self->{device} = $self->{tpv}{device};

    $self->{sky} = $data->{sky}[0];

    my %sats;

    for my $sat (@{ $self->{sky}{satellites} }){
        my $prn = $sat->{PRN};
        delete $sat->{PRN};
        $sat->{used} = $sat->{used} ? 1 : 0;
        $sats{$prn} = $sat;
    }
    $self->{satellites} = \%sats;
}
sub _vim {} # fold placeholder

1;

=head1 NAME

GPSD::Parse - Parse, extract and manipulate JSON output from gpsd

=head1 SYNOPSIS

    use GPSD::Parse;

    my $gps = GPSD::Parse->new;

    # start the data flow, and poll for data

    $gps->on;
    $gps->poll;

    # get all TPV data in an href

    my $tpv_href = $gps->tpv;

    # get individual TPV stats

    print $gps->tpv('lat');
    print $gps->tpv('lon');

    # get all sattelites in an href of hrefs

    my $sats = $gps->satellites;

    # get an individual piece of info from a single sattelite

    print $gps->satellites(16, 'used');

    # timestamp of the most recent poll

    print $gps->time;

    # stop capturing data

    $gps->off;

=head1 METHODS

=head2 new

Instantiates and returns a new L<GPSD::Parse> object instance.

=head2 on

Puts C<gpsd> in listening mode, ready to poll data from.

=head2 off

Turns off C<gpsd> listening mode.

=head2 poll(%args)

Does a poll of C<gpsd> for data, and configures the object with that data.

Parameters:

All parameters are sent in as a hash.

    fname => $filename

Optional, String: Used for testing, you can send in the name of a JSON file
that contains C<gpsd> JSON data and we'll work with that instead of polling
the GPS device directly.

    return => 'json'

Optional, String: By default, after configuring the object, we will return the
polled raw data as a Perl hash reference. Send this param in with the value of
C<'json'> and we'll return the data exactly as we received it from C<gpsd>.

Returns:

The raw poll data as either a Perl hash reference structure or as the
original JSON string.

=head2 tpv($stat)

C<TPV> stands for "Time Position Velocity". This is the data that represents
your location and other vital statistics.

By default, we return a hash reference that is in the format C<stat => 'value'>.
#FIXME: add in available stats!

Parameters:

    $stat

Optional, String. You can extract individual statistics of the TPV data by
sending in the name of the stat you wish to fetch. This will then return the
string value if available. Returns C<undef> if the statistic doesn't exist.

=head2 satellites($num, $stat)

#FIXME: add sat stat info!

This method returns a hash reference of hash references, where the key is the
satellite number, and the value is a hashref that contains the various
information related to the specific numbered satellite.

Note that the data returned by this function has been manipuated and is not
exactly equivalent of that returned by C<gpsd>. To get the raw data, see 
C<sky()>.

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

=head2 sky

Returns a hash reference containing all of the data that was pulled from the
C<SKY> information returned by C<gpsd>. This information contains satellite
info and other related statistics.

=head2 device

Returns a string containing the actual device the GPS is connected to
(eg: C</dev/ttyS0>).

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2017 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.
