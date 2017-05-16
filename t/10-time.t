use strict;
use warnings;

use GPSD::Parse;
use Test::More;

my $mod = 'GPSD::Parse';

my $gps = $mod->new;
my $fname = 't/data/gps.json';

{ # default return

    $gps->poll(fname => $fname);

    my $t = $gps->time;

    is ref \$t, 'SCALAR', "time is returned as a string";
    like $t, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/, "...and is ok"; 
}

done_testing;
