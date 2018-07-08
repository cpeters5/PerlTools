#!C:/Perl/bin Perl
#use 5.010;

#---
# REead from old RHS download
# For each record, match pid with pid in orchid_species
# Run update sql to update originator firel in Species table
# Originator in Hybrid table is updated by a trigger

use open qw(:locale);
use strict;
use Encode qw(encode decode);
use utf8;
use warnings qw(all);

require "common.pl";
our ($sth);
my %pid = ();

getPID();
my %subpid = (1=>11,2=>12,4=>12);				#position of pid
my %baseorig = (1=>7,2=>8,4=>7);				#position of originator
my %basedate = (1=>10,2=>11,4=>10);				#position of date
my %basepid = (1=>100000000,2=>100000000,4=>0);	#base pid for hybrid

my $sub = 4;
my $path = "data/old/$sub/";
opendir (my $dir,$path ) or die "Can't open directory\n$!\n";

while (my $file = readdir $dir) {
	next if $file !~ /\.txt$/;
	open IN, $path.$file or die "Can't open file $file\n:$!\n";
	my $lineno = 0;
	print "$path$file\n";
	<IN>;
	while (<IN>) {
		$lineno++;
		# (my @recs) = split(/\t/,$_);
		(my @recs) = split(/\|/,$_);
		my $originator = $recs[7];
		$originator =~ s/\'/\'\'/g;
		my $date = $recs[$basedate{$sub}];
		#next if $date =~ /^00/;
		my $pid = int($recs[$subpid{$sub}]) + $basepid{$sub};
		$pid = "$pid";
		next if !$pid{$pid};
		print "\t$pid\t$pid{$pid}\n";
		#sleep 1;
		print "$lineno\t$pid\t$date\t$originator\n";
		my $stmt = "update natural_species set originator = '$originator', date='$date' where pid = '$pid' ;";
		&getASPM($stmt);
		#print "$stmt\n";
	}
	close IN;
	#exit;
}


sub getPID {
#-- Get genus
  my $stmt = "select pid from natural_species where source = 'RHS' and originator is null";
  &getASPM($stmt);
  my $c = 0;
  while (my @row = $sth->fetchrow_array()) { 
	$pid{$row[0]}++;
	$c++;
	#print "$c\t$row[0]\n"; 
  }
}

