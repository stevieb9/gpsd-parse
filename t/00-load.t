use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok( 'GPSD::Parse' ) || print "Bail out!\n";
}

diag( "Testing GPSD::Parse $GPSD::Parse::VERSION, Perl $], $^X" );

my $gps = GPSD::Parse->new;

isa_ok $gps, 'GPSD::Parse', "obj is of appropriate class";

done_testing;
