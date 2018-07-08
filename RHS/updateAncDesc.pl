#----------
# Initial implementation.
# Run this script every time a new hybrid is created.
#----------

use strict;
use warnings FATAL => 'all';

require "common.pl";
our ($sth);
my $debug = 0;
my %pid  = ();
my %seed = ();
my %poll = ();

&initHybrid();

foreach my $pid (sort keys %pid) {
    &getASPM("insert ignore into orchid_ancestordescendant (pct,aid,did) select pct/2, aid, $pid from orchid_ancestordescendant where did = $seed{$pid};");
    &getASPM("insert ignore into orchid_ancestordescendant (pct,aid,did) select pct/2, aid, $pid from orchid_ancestordescendant where did = $poll{$pid};");
    &getASPM("insert ignore into orchid_ancestordescendant (pct,aid,did) values (50, $pid, $seed{$pid})");
    &getASPM("insert ignore into orchid_ancestordescendant (pct,aid,did) values (50, $pid, $poll{$pid})");
    # print("insert ignore into orchid_ancestordescendant (pct,aid,did) select pct/2, aid, $pid from orchid_ancestordescendant where did = $seed{$pid};\n");
    # print("insert ignore into orchid_ancestordescendant (pct,aid,did) select pct/2, aid, $pid from orchid_ancestordescendant where did = $poll{$pid};\n");
    # print("insert ignore into orchid_ancestordescendant (pct,aid,did) values (50, $pid, $seed{$pid})\n");
    # print("insert ignore into orchid_ancestordescendant (pct,aid,did) values (50, $pid, $poll{$pid})\n\n");
    # exit;
    print "$pid = ($seed{$pid} x $poll{$pid}) added\n";
}


sub initHybrid {
    my $stmt = "select pid, seed_id, pollen_id from orchid_hybrid where pid not in (select distinct did from orchid_ancestordescendant);";
    &getASPM($stmt);
    while (my @row = $sth->fetchrow_array()) {
        $pid{$row[0]}++;
        $row[1] = 0 if !$row[1];
        $row[2] = 0 if !$row[2];
	    $seed{$row[0]} = "$row[1]";
	    $poll{$row[0]} = "$row[2]";
	    # print "$row[0]\t$pid{$row[0]}\t$row[1]\t$row[2]\n";
	}
}

