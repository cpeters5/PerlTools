#!C:/Perl/bin Perl
#use 5.010;
# Generates family trees and output to files.
# Call 

use open qw(:locale);
use strict;
use Encode qw(encode decode);
use DateTime;

#use encoding 'utf8', Filter => 1;
#use utf8;
use warnings qw(all);
use IO::File;
use List::MoreUtils qw(firstidx);
use File::Copy;

my $treedata = "treedata1/";
my $pctdata  = "pctdata1/";
require "common.pl";
our ($sth);
my (%hybcount,%genus, %parents, %pct, %type, %anc_num, %anc_spc, %arr);
my $rec = 0;
my $case = 0;
my $rowcase = 0;
my %outfiles = ("A.dat"=>"AC.dat","B.dat"=>"AC.dat","C.dat"=>"AC.dat","D.dat"=>"DO.dat",
				"E.dat"=>"DO.dat","F.dat"=>"DO.dat","G.dat"=>"DO.dat","H.dat"=>"DO.dat",
				"I.dat"=>"DO.dat","J.dat"=>"DO.dat","K.dat"=>"DO.dat","L.dat"=>"DO.dat",
				"M.dat"=>"DO.dat","N.dat"=>"DO.dat","O.dat"=>"DO.dat","P.dat"=>"PP.dat",
				"Q.dat"=>"QZ.dat","R.dat"=>"QZ.dat","S.dat"=>"QZ.dat","T.dat"=>"QZ.dat",
				"U.dat"=>"QZ.dat","V.dat"=>"QZ.dat","W.dat"=>"QZ.dat","X.dat"=>"QZ.dat",
				"Y.dat"=>"QZ.dat","Z.dat"=>"QZ.dat",);
open CT, ">AC.dat" || die "Can't open file AC.dat: $!\n";
print CT "did\taid\tpct\tanctype\tfile\n\n";
open CT, ">DO.dat" || die "Can't open file DO.dat: $!\n";
print CT "did\taid\tpct\tanctype\tfile\n";
open CT, ">QZ.dat" || die "Can't open file QZ.dat: $!\n";
print CT "did\taid\tpct\tanctype\tfile\n";
open CT, ">PP.dat" || die "Can't open file PP.dat: $!\n";
print CT "did\taid\tpct\tanctype\tfile\n";

my $sttime = DateTime->now();

print "initializing All species\n\n";
initParents();
print "Read data from files\n\n";
getDataFromFiles();  #-- stored in $hybridCount (anc-desc) and $desc (anc-#desc)
#print "Output results\n\n";
#outputAscDesc();

my $entime = DateTime->now;
my $elapse = $entime - $sttime;
print "Elapsed time : ".$elapse->in_units('minutes')."m\n";


sub getDataFromFiles {
	opendir(D, ".")||die "Cant open $treedata dir: $!\n";
	#open ANC, ">hybrid_counts.dat" or die "Cant open count file: $!\n";
	#print ANC "rec\tdepth\tanc_species\tanc_total\name\n";
	while (my $f = readdir(D)) {
		next if $f !~ /^[A-Z]\.dat$/;
#		next if $f ~= /^P\./;
		print "\n\n$f\t start record # $rec\n";
		open IN, "$f"  || die "Can't open file $f: $!\n";
		open (CT, ">>",$outfiles{$f}) || die "Can't open file $outfiles{$f}: $!\n";
		my $row = 0;
		while (<IN>) {
			#$rec++;
			print "$row\n" if $row++%1000==0;
			print "$row\t$_" if $row == $rowcase;
			my %seen = ();
			%arr = ();
			chomp;
			my ($id,$depth,$line) = split(/\t/,$_);
			#/\[(\d+)\]\((.+)\)$/;
			#my $id = $1;
			#my $line = $2;
			print "\n0) $id\t$line\n"  if $id == $case;
			#sleep 1;
			$anc_spc{$id} = 0;
			$anc_num{$id} = 0;
			getPercentage($line,$row);
			if ($id == $case) {
				foreach my $x (sort keys %arr) {print "\t$x => $arr{$x}.\n"}; 
			}
			#exit;
			#my @arr = ($line =~ m/(\d+)/g);
			my $i = 0;
			foreach my $aid (keys %arr) {
				next if $id == $aid;
				my $key = $id."|".$aid;
				if (!$seen{$aid}++) {
					$anc_spc{$id}++ if $type{$aid} eq 'species'; # distinct species ancestors
					$anc_num{$id}++;	# Count distinct ancestors
					$hybcount{$key}++ ;
					#printf ("3) %10d\t%-19s\t %.4f\t %5d\t %5d\t %5d\t %-30s\t %-30s\n",$row, $key,$pct{$key},$depth,$anc_spc{$id},$anc_num{$id},$parents{$id},$parents{$aid});
					print "7) $id\t$type{$aid}\t$aid\t$key\t$pct{$key}\n" if $id == $case;
					#sleep 1;
					$type{$aid} = 'unk' if !$type{$aid};
					#my $stmt = "insert ignore into orchid_ancestordescendant (did,aid,anc_type,pct) values ($id,$aid,'$type{$aid}',$pct{$key})";
					#&getASPM($stmt);		
					#print "$stmt\n";
				}
				#print "4) $key\t $hybcount{$key}\t$line\n" if $key =~ /(100003268)/;
				print CT "$id\t$aid\t$pct{$key}\t$type{$aid}\t$f\n";
			}
			#print ANC "$row\t$id\t$depth\t$anc_spc{$id}\t$anc_num{$id}\t$parents{$id}\n" if $f !~ /^D\.dat$/;
			$i++;
			print "5) $i $row\t$id\t$depth\t$anc_spc{$id}\t$anc_num{$id}\t$parents{$id}\n"  if $id == $case;
			#exit if $id == $case;
		}
		close IN;
		close CT;
		my $entime = DateTime->now;
		my $elapse = $entime - $sttime;
		print "\nRows processed = $row\nElapsed time : ".$elapse->in_units('minutes')."m\n\n";

		#move($f,$treedata.$f);
		#exit;
	}
}

sub getPercentage {
	#-- Compute percentage
	my $line = shift;
	my $row = shift;
	my @id = ($line =~ m/(\d+)/g);
	my $id = $id[0];
	
	$line =~ s/\[|\]//g;
	#print "1) $id[0]\t$parents{$id}\t$line\n";
	my $n = 0;
	my ($x);
	my $i = 0;

	while ($line =~ /\d/) {
		$line =~ m/^(\(|\)|\,|\d+)(.*)$/;
		my $par = $1;
		my $key = $id.'|'.$par;
		$line=$2 if $2;
		print "4) $i\t.$key.\tpar=$par\tline=$2.\n" if $row == $rowcase;; #sleep 1;
		$i++ if $par eq "(";
		$i-- if $par eq ")";
		print "5) $i\t.$key.\tpar=$par\tline=$2.\n" if $row == $rowcase;; #sleep 1;
		next if $i eq ",";
		if ($par =~ /^\d+$/) { # and $i) {
			$pct{$key} += 100/2**$i;
			$pct{$key} = sprintf "%.2f", $pct{$key};
			$arr{$par}++;
			#print "6) $i>>> $id\t$key\t$pct{$key}\t$parents{$par}\n";  #sleep 1;
		}

	}
}

sub initParents {
#-- Get genus
  my $stmt = "select pid, genus, species, infraspr, infraspe, status, type 
				from orchid_species where status not in ('synonym','pending') and pid not in (100900791,100900792)";
  &getASPM($stmt);
	my $parent;
	$parents{0} = 'na';
    while (my @row = $sth->fetchrow_array()) {
		next if $row[0] == 999999999;
		$type{$row[0]}	 = $row[6];
		$parents{$row[0]} = "$row[1] $row[2]";
		$parents{$row[0]} .= " $row[3]" if $row[3];
		$parents{$row[0]} .= " $row[4]" if $row[4];
		#print "A) $row[0] $parents{$row[0]}\n" if $row[0] eq "100075658";
		$type{$row[0]}	 = 'species' if $row[0] == 0;   #These are unklnown.  Treat as a leaf node (species)
		
	}
	$parents{0}='unk';
	$type{0}='unk';
}

