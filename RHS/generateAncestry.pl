#!C:/Perl/bin Perl
#use 5.010;
#----------
# Updte gen_id, acc_id (or hyb_id) for images table.
#----------

use open qw(:locale);
use strict;
use Encode qw(encode decode);
use utf8;
use warnings qw(all);

require "common.pl";
our ($sth);
my (%genus, %parent,%synonym);
#-- Add gen_id
initGenus();
#foreach my $gen (sort keys %genus) { print "$gen\t$genus{$gen}\n";}

#### TODO
####  Strip blanks before search


#processImages('natural_spcimages','acc_id');
processImages('natural_hybimages','hyb_id');

sub processImages {
#-- Add gen_id and hyb_i
	my ($tab,$col) = @_;
	if ($tab eq 'natural_spcimages') {
		initAccepted();
	}
	else {
		initHybrid();
	}
	#foreach my $acc (sort keys %accepted) { print "$acc\t$accepted{$acc}\n";sleep 1;}
  
	my $stmt = "select id, genus, species from $tab";
	&getASPM($stmt);
	my %stmt = ();
	
	while (my @row = $sth->fetchrow_array()) { 
		my $species = "$row[1] $row[2]";
		my ($col_id, $gen_id)  = ('','');
		$col_id = $parent{$species} if exists $parent{$species};
		$gen_id = $genus{$row[1]} if exists $genus{$row[1]};
		#print "$row[0], $row[1], $row[2], $species, $spc_id, $gen_id.\n";
		$stmt{$row[0]} = "update $tab set gen_id = '$gen_id', $col = '$col_id' where id = $row[0]";
	}
	
	foreach my $id (sort keys %stmt) {
		&getASPM($stmt{$id});
		print "$id $stmt{$id}\n";
		#sleep 1;
	}
}


sub initGenus {
#-- Get genus
  my $stmt = "select id, genus from natural_genus";
  &getASPM($stmt);
   
  while (my @row = $sth->fetchrow_array()) { 
	$genus{$row[1]} = $row[0];
	#print "$genus{$row[0]}\t$row[0]\n";
  }
}

sub initAccepted {
    my $stmt = "select id,genus,species,infraspr,infraspe,status from natural_accepted
            where is_hybrid = '' or is_hybrid is NULL";
    &getASPM($stmt);
    while (my @row = $sth->fetchrow_array()) {
		next if $row[5] ne 'accepted';
	    my $species = "$row[1] $row[2]";
	    if ($row[3]) {
		    $species .= " $row[3] $row[4]";
	    }
	    $parent{ $species} = "$row[0]";
	    #print "\t$row[0], $row[1], $row[2], $row[3], $row[4], $species, $accepted{$species}.\n";
		#sleep 1;
	}
}

sub initHybrid {
    my $stmt = "select id,genus,species from natural_hybrid";
    &getASPM($stmt);
    while (my @row = $sth->fetchrow_array()) {
	    my $hybrid = "$row[1] $row[2]";
	    $parent{ $hybrid} = "$row[0]";
	    #print "$species\n";
	}
}



#open OUT, '>:encoding(UTF-8)',"RHS-accepted-$start-$end.txt" or die "\tCan't open RSH-Search\n $!\n";
