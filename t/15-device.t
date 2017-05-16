use strict;
use warnings;

use GPSD::Parse;
use Test::More;

my $mod = 'GPSD::Parse';

my $gps = $mod->new;
my $fname = 't/data/gps.json';

{ # default return

    $gps->poll(fname => $fname);

    my $t = $gps->device;

    is ref \$t, 'SCALAR', "device is returned as a string";
    like $t, qr|^/dev/ttyUSB0$|, "...and is ok"; 
}

done_testing;
