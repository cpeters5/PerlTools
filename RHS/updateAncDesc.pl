#----------
# Initial implementation.
# Run this script every time a new hybrid is created.
# Run with new pid parameter if update a single pid.
# Run without parameter if update all pid not currently in the ancdesc table.
#----------

use strict;
use warnings FATAL => 'all';

require "common.pl";
our ($sth, $dbh);
my $debug = 0;
my %pid  = ();
my %seed = ();
my %poll = ();

# Refresh ancdesc for inpout pid

if ($ARGV[0]) {
	my $pid = $ARGV[0];
	my $stmt = "select seed_id, pollen_id from orchid_hybrid where pid = ?";
	my @row = $dbh->selectrow_array($stmt,undef,$pid);
	unless (@row) { die "Pid $pid not found in Hybrid"; }
	my ($seed,$poll) = @row; 
	print "$pid, $seed, $poll\n";
	updatedata($pid,$seed,$poll);
	exit;
}

&initHybrid();

foreach my $pid (sort keys %pid) {
	updatedata($pid, $seed{$pid},$poll{$pid});
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


sub updatedata {
	my ($pid, $seed, $poll) = @_;

	&getASPM("delete from orchid_ancestordescendant where did = $pid"); 
	my $stmt = "select sum(pct)/2, aid from orchid_ancestordescendant where did in ($seed,$poll) group by 2";
    &getASPM($stmt);
    while (my @row = $sth->fetchrow_array()) {
		my $stmt = "insert into orchid_ancestordescendant (pct,aid,did) values($row[0],$row[1],$pid)";
		&getASPM1($stmt);
	}
    &getASPM("insert into orchid_ancestordescendant (pct,aid,did) values (50, $seed, $pid)");
    &getASPM("insert into orchid_ancestordescendant (pct,aid,did) values (50, $poll, $pid)");
	
}