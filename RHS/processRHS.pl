#!C:/Perl/bin Perl
#use 5.010;
#---------------
#  This script read from the updated RHS_start-end.txt and add seed and pollen id, status. Replace synonyms with accepted, etc.
#  Output:  RHS1.txt.
#  After runningin this script, perform the following
#  1.  Load RHS into natural_hybrid_tmp table (clear all data from the table first.
#  2.  Run the foloiwng quesries:
#  2.1  update natural_hybrid_tmp a join natural_hybrid b on a.seed_genus = b.genus and a.seed_species = b.species
#          set a.seed_id = b.id, a.seed_status = b.status where a.seed_type='hybrid';
#  2.1  update natural_hybrid_tmp a join natural_hybrid b on a.pollen_genus = b.genus and a.pollen_species = b.species
#          set a.pollen_id = b.id, a.pollen_status = b.status where a.pollen_type='hybrid';
#  3.   insert into natural_hybrid (genus,species,seed_genus,seed_species,seed_id,seed_type,seed_status,pollen_genus,pollen_species,
#          pollen_id,pollen_type,pollen_status,author,originator,status,synonym,date,source_id,source,gen_id)
#          select genus,species,seed_genus,seed_species,seed_id,seed_type,seed_status,pollen_genus,pollen_species,pollen_id,pollen_type,pollen_status,
#          author,originator,status,synonym,date,source_id,source,gen_id from natural_hybrid_tmp;
#-TODO:  Move some or all of these last steps to script.

use open qw(:locale);
use strict;
use Encode qw(encode decode);
use utf8;
use warnings qw(all);

require "common.pl";
our ($sth);
my $dir = "C:/Projects/Orchids/Perl/RHS/data/";
my $out = "RHS.dat";
my $out1 = "RHS_1.dat";

my $i = 1;
my %genus;
my (%accepted, %synonym, %synacc, %hybrid);


#-- Add gen_id
getGenus();
#foreach my $gen (sort keys %genus) { print "$gen\t$genus{$gen}\n";}

#-- Add Hybrid ID
open OUT, ">".$out or die "Can't open output $out: $!\n";
print OUT "id|genus|species|seed_genus|seed_species|pollen_genus|pollen_species|author|originator|status|synonym|date|source_id|source|gen_id|seed_id|seed_type|seed_status|seed_gensyn|seed_spcsyn|pollen_id|pollen_type|pollen_status|pollen_gensyn|pollen_spcsyn|description\n";
addId($dir."RHS-accepted-988559-988800.txt");

#open OUT, ">>".$out or die "Can't open output $out: $!\n";
#addId($dir."RHS-100000-200000.txt");

#open OUT, ">>".$out or die "Can't open output $out: $!\n";
#addId($dir."RHS-200000-1000000.txt");

%genus = ();
close OUT;
#foreach my $hyb (sort keys %hybrid) { print "$hyb\t$hybrid{$hyb}\n";}


#-- Initialize accepted, synonym
getAccepted();
#foreach my $acc (sort keys %accepted) { print "$acc\t$accepted{$acc}\n";}

getSynonym();
#foreach my $syn (sort keys %synonym) { print "$syn\t$synonym{$syn}\n";}

open IN, $out or die "Can't open output $out: $!\n";
open OUT, ">".$out1 or die "Can't open output $out: $!\n";
#-- Actual processing starts here
procHybrid();



sub procHybrid {
	my $top = <IN>;
	print OUT $top;	#header
	while (<IN>) {
		#print $_; sleep 1;
		chomp;
		next if $_=~ /^ *$/;
		my (@vals) = split(/ *\| */,$_); 
	
		#-- Ignore the following lines
		next if $vals[2] =~ /^[a-z]/ & 
				$vals[4] =~ /^ *$/ &
				$vals[6] =~ /^ *$/;
		#last if $vals[0] > 1000;
		#-- Add seed info
		my $seed = "$vals[3] $vals[4]";
		# if ($vals[4] =~ /^[[:upper:]]/ or $vals[4] =~ /^\d/ or $vals[4] =~ /^\d/) {
		if ($vals[4] !~ /^[a-z]/) {
			if ($hybrid{$seed}) {
				$_ .= "|$hybrid{$seed}||";
			}
			else {
				print ">>$vals[0]\t$seed <<\n";
				$_ .= "||hybrid|||";
			}
		}
		else {
			if ($accepted{$seed}) {
				$_ .= "|$accepted{$seed}||";
			}
			elsif ($synonym{$seed}){
				$_ .= "|$synonym{$seed}|$synacc{$seed}";
				#$_ =~ m/$vals[3]\|$vals[4]/$synacc{$seed}/;
				print "syn seed = $synonym{$seed} - accpt = $synacc{$seed}\t$_\n";
			}
			else {
				$_ .= "|||||";
			}
		}
		
		#-- Add pollen info
		my $pollen = "$vals[5] $vals[6]";
		# if ($vals[6] =~ /^[[:upper:]]/ or $vals[6] =~ /^\d/) {
		if ($vals[6] !~ /^[a-z]/) {
			if ($hybrid{$pollen}) {
				$_ .= "|$hybrid{$pollen}||";
			}
			else {
				#print ">>$vals[0]\t$pollen <<\n";
				$_ .= "||hybrid|||";
			}
		}
		else {
			if ($accepted{$pollen}) {
				$_ .= "|$accepted{$pollen}||";
			}
			elsif ($synonym{$pollen}){
				$_ .= "|$synonym{$pollen}|$synacc{$pollen}";
			}
			else {
				$_ .= "|||||";
			}
		}
		
		
		
		
		$_ .= "|seed: $synacc{$seed}" if $synonym{$seed};
		$_ .= "|pollen: $synacc{$pollen}" if $synonym{$pollen};
		print "$vals[0]\t$vals[1] $vals[2]\t$seed\t$pollen\n" if $i++%100==0;
		print OUT "$_\n";
		#sleep 1;
		
	}
	close OUT;
	close IN;
}


sub getGenus {
#-- Get genus
  my $stmt = "select id, genus from natural_genus";
  &getASPM($stmt);
   
  while (my @row = $sth->fetchrow_array()) { 
	$genus{$row[1]} = $row[0];
	#print "$genus{$row[0]}\t$row[0]\n";
  }
}


sub addId {
#-- Add id to each line
#-- Add Genus id to the end of each line
#-- Obtain hash of hybrid=>hybrid id

  my $file = shift; 
  my $out = shift;
  
  open IN, $file or die "Can't open $file: $!\n";
  my $line = <IN>;
  chomp $line;
  while (<IN>) {
	next if $_ =~ /^ *$/;
	chomp;
	$_ =~ s/ *\| */|/g; #- Strips off leading and trailing blanks
    my (@vals) = split(/\|/,$_);
    my $hybrid = "$vals[0] $vals[1]";
	$hybrid{$hybrid} = "$i|hybrid|$vals[8]";	
#27845|Miltoniopsis|Firefly|Miltoniopsis|Glow|Miltoniopsis|William Pitt|Sanders[St Albans]|Sanders[St Albans]|accepted|Miltonia|1936-01-01|29132|RHS|225


	#-- Add gen id
	if ($genus{$vals[0]}) {
		$_ .= "|$genus{$vals[0]}";
	}
	else {
		$_ .= "|";
	}
	print OUT $i++."|".$_."\n";
  }
  close IN;
}
	

sub getAccepted {
    my $stmt = "select id,genus,species,infraspr,infraspe,status from natural_accepted
            where is_hybrid = '' or is_hybrid is NULL";
    &getASPM($stmt);
    while (my @row = $sth->fetchrow_array()) {
	    my $species = "$row[1] $row[2]";
	    if ($row[3]) {
		    $species .= " $row[3] $row[4]";
	    }
	    $accepted{ $species} = "$row[0]|species|$row[5]";
	    #print "$species\n";
	}
}


sub getSynonym {
    my $stmt = "select acc_id,sgenus,sspecies,sinfraspr,sinfraspe,status, genus,species,
            infraspr, infraspe from natural_synonym
            where sis_hybrid = '' or sis_hybrid is NULL";
    &getASPM($stmt);
	while (my @row = $sth->fetchrow_array()) {
		my $species = "$row[1] $row[2]";
		if ($row[3]) {
			$species .= " $row[3] $row[4]";
		}
		$synonym{ $species} = "$row[0]|species|$row[5]";
		
		my $syn = "$row[6]|$row[7]";
		if ($row[8]) {
			$syn .= " $row[8] $row[9]";
		}
		$synacc{ $species} = "$syn";
		#print "$species\n";
	}
}



#open OUT, '>:encoding(UTF-8)',"RHS-accepted-$start-$end.txt" or die "\tCan't open RSH-Search\n $!\n";
