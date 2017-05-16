use warnings;
use strict;
use feature 'say';

use Data::Dumper;
use GPSD::Parse;

my $gps = GPSD::Parse->new;

$gps->poll(fname => 't/data/gps.json');

print Dumper $gps->satellites;

my $sat = $gps->satellites(16);

say $gps->satellites(16, 'el');
say $gps->tpv('speed');
say $gps->time;
