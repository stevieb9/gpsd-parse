use strict;
use warnings;

use GPSD::Parse;
use Test::More;

my $mod = 'GPSD::Parse';

my $fname = 't/data/gps.json';

my $gps;

my $sock = eval {
    $gps = $mod->new;
    1;
};

$gps = GPSD::Parse->new(file => $fname) if ! $sock;
$ENV{GPSD_LIVE_TESTING} = 1 if $sock;

my @stats = qw(
    satellites
    xdop
    ydop
    pdop
    tdop
    vdop
    gdop
    hdop
    class
    tag
    device
);
$gps->poll;

{
    my $s = $gps->sky;

    is ref $s, 'HASH', "sky() returns a hash ref ok";

    if ($ENV{GPSD_LIVE_TESTING}){
        note "GPSD_LIVE_TESTING env var not set\n";
        is keys %$s, @stats -1, "keys match SKY entry count";
    }
    else {
        is keys %$s, @stats, "keys match SKY entry count";
    }

    for (@stats){
        next if $_ eq 'tag' && $ENV{GPSD_LIVE_TESTING};
        is exists $s->{$_}, 1, "SKY stat $_ exists";
    }

    is ref $s->{satellites}, 'ARRAY', "SKY->satellites is an aref";
    is ref $s->{satellites}[0], 'HASH', "SKY satellite entries are hrefs";
    is exists $s->{satellites}[0]{ss}, 1, "each SKY sat entry has stats";
}

done_testing;
