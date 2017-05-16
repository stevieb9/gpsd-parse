use strict;
use warnings;

use Data::Dumper;
use GPSD::Parse;
use Test::More;

my $mod = 'GPSD::Parse';

my $gps = $mod->new;
my $fname = 't/data/gps.json';

#FIXME: add check for env var if GPS is connected, and add tests for
# using the socket ($gps->on etc)

#
# with filename
#

{ # default return

    my $res = $gps->poll(fname => $fname);

    is ref $res, 'HASH', "default return is an href ok";

    is exists $res->{sky}, 1, "SKY exists";
    is exists $res->{tpv}, 1, "TPV exists";
    is exists $res->{active}, 1, "active exists";
    is exists $res->{time}, 1, "time exists";
    is $res->{class}, 'POLL', "proper poll class ok";
}

{ # json return

    my $res = $gps->poll(return => 'json', fname => $fname);

    is ref \$res, 'SCALAR', "json returns a string";
    like $res, qr/^{/, "...and appears to be JSON data";
    like $res, qr/TPV/, "...and it contains TPV ok";
}

{ # no filename (undef return)

    my $res = $gps->poll;
    is $res, undef, "undef returned if no GPS data acquired";
}

{ # invalid filename

    my $res;

    my $ok = eval {
        $res = $gps->poll(fname => 'invalid.file');
        1;
    };

    is $ok, undef, "croaks if file can't be opened with fname param";
    like $@, qr/invalid\.file/, "...and the error msg is sane";
    undef $@;
}

done_testing;
