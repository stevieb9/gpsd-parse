use warnings;
use strict;
use feature 'say';

use GPSD::Parse;
my $gps = GPSD::Parse->new;
 
while (1){
    sleep 1;
    next if ! defined $gps->poll;

    say $gps->time . "\n";

    my $sats = $gps->satellites;

    my $sat_count = keys %{ $sats };

    my $sats_locked;

    for (keys %$sats){
        $sats_locked++ if $sats->{$_}{used};
    }

    say "\tsat: " . $sat_count;    
    say "\tlck: " . $sats_locked;
    say "\tlat: " . $gps->lat;
    say "\tlon: " . $gps->lon;
    say "\tdeg: " . $gps->track;
    say "\tdir: " . $gps->direction($gps->track);    
    say "\tspd: " . $gps->speed;
    say "\talt: " . $gps->alt;
    say "\n";

}
