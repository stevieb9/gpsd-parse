use strict;
use warnings;

use GPSD::Parse;
use Test::More;

my $mod = 'GPSD::Parse';

my $gps = $mod->new;
my $fname = 't/data/gps.json';

my @sats = qw(
    6 31 19 7 20 23 3 16 13
);

my @stats = qw(
    ss el az used
);

$gps->poll(fname => $fname);

{ # default, no param 

    my $s = $gps->satellites;

    is ref $s, 'HASH', "satellites() returns a hash ref ok";

    is keys %$s, @sats, "keys match satellite count";

    for my $sat (@sats){
        is ref $s->{$sat}, 'HASH', "satellite $sat is a hash ref";
        for (@stats){
            is exists $s->{$sat}{$_}, 1, "sat $sat, stat $_ exists";
        }
    }

}

{ # stat param

    for my $sat (@sats){
        for (@stats){
            my $ret = $gps->satellites($sat, $_);
            is defined $ret, 1, "sat $sat, stat $_ is defined";
            like $ret, qr/^\d+$/, "...and is an integer";
        }
        is $gps->satellites($sat, 'unknown'), undef, "sat $sat returns undef on unknown stat";
    }
}

{ # unknown sat
    is $gps->satellites(9999), undef, "satellites() returns undef with unknown sat param";
}

done_testing;
