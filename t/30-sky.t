use strict;
use warnings;

use GPSD::Parse;
use Test::More;

my $mod = 'GPSD::Parse';

my $gps = $mod->new;
my $fname = 't/data/gps.json';

my @stats = qw(
    hdop time class device satellites
);

$gps->poll(fname => $fname);

{

    my $s = $gps->sky;

    is ref $s, 'HASH', "sky() returns a hash ref ok";

    is keys %$s, @stats, "keys match SKY entry count";

    for (@stats){
        is exists $s->{$_}, 1, "SKY stat $_ exists";
    }

    is ref $s->{satellites}, 'ARRAY', "SKY->satellites is an aref";
    is ref $s->{satellites}[0], 'HASH', "SKY satellite entries are hrefs";
    is exists $s->{satellites}[0]{ss}, 1, "each SKY sat entry has individual stats";
}

done_testing;
