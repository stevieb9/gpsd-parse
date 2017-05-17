use strict;
use warnings;

use GPSD::Parse;
use Test::More;

my $m = 'GPSD::Parse';

{ # signed (default)

    my ($lat, $lon);

    ($lat, $lon) = $m->_signed_convert(1.234, 3.456);
    is $lat, '1.234N', "unsigned positive lat ok";
    is $lon, '3.456E', "unsigned positive lon ok";

    ($lat, $lon) = $m->_signed_convert(-1.234, -3.456);
    is $lat, '1.234S', "unsigned negative lat ok";
    is $lon, '3.456W', "unsigned negative lon ok";

    ($lat, $lon) = $m->_signed_convert(1.234, -3.456);
    is $lat, '1.234N', "unsigned positive lat ok";
    is $lon, '3.456W', "unsigned negative lon ok";

    ($lat, $lon) = $m->_signed_convert(-1.234, 3.456);
    is $lat, '1.234S', "unsigned negative lat ok";
    is $lon, '3.456E', "unsigned positive lon ok";
}
done_testing;
