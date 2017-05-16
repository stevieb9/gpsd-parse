use strict;
use warnings;

use GPSD::Parse;
use Test::More;

my $mod = 'GPSD::Parse';

my $gps = $mod->new;
my $fname = 't/data/gps.json';

my @stats = qw(
    ept class mode lat track lon time device speed
);

$gps->poll(fname => $fname);

{ # default, no param 

    my $t = $gps->tpv;

    is ref $t, 'HASH', "tpv() returns a hash ref ok";

    is keys %$t, @stats, "tpv() key count matches number of stats";

    for (@stats){
        is exists $t->{$_}, 1, "$_ stat exists in return";
    }

    for (qw(lat lon)){
        like $t->{$_}, qr/^-?\d+\.\d{8,9}$/, "$_ is in proper format";
    }
}

{ # stat param

    for (@stats){
        is ref \$gps->tpv($_), 'SCALAR', "$_ stat param ok";
    }

    is $gps->tpv('invalid'), undef, "unknown stat param returns undef";
}

done_testing;
