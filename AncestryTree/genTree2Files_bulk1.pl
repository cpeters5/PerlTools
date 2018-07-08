#!C:/Perl/bin Perl
#use 5.010;
# Generates family trees and output to files.
# Call genAndDescpairs.pl next to load database

use open qw(:locale);
use strict;
use Encode qw(encode decode);
use DateTime;

#use encoding 'utf8', Filter => 1;
#use utf8;
use warnings qw(all);
use IO::File;
use List::MoreUtils qw(firstidx);
#use File::Copy;
use Try::Tiny;

require "common.pl";
our ($sth);
my $debug = 0;

my @num = ('A.dat','B.dat','C.dat','D.dat','E.dat','F.dat','G.dat','H.dat','I.dat',
'J.dat','K.dat','L.dat','M.dat','N.dat','O.dat','P.dat','Q.dat',
'R.dat','S.dat','T.dat','U.dat','V.dat','W.dat','X.dat','Y.dat','Z.dat');

my @numhandles = map { IO::File->new($_, 'w') } @num;
my (%hybrid, %cross,  %accepted, %name,%genus);
my $treedata = "treedata1/";

my $sttime = DateTime->now();

# print "\nInitializing Parents\n";
# initParents();

print "\nInitializing Hybrid\n";
initHybrid();

print "\nInitializing Accepted\n";
initAccepted();

print "\nInitializing Parents\n";
# initParents();
#%parents = (%hybrid, %accepted);

print "Processing Hybrids\n";
getTree();			# populate pid crosses

my $entime = DateTime->now;
my $elapse = $entime - $sttime;
print "Elapsed time : ".$elapse->in_units('minutes')."m\n";


sub getTree {
	print "Start getCross\n"; 
	my $c = 0;
	my $loop = 0;
	my %seen;
	my %found;
	my $i = 0;
	my $rep = 0;
	my $prevc = -1;
	my $case = 100001635;
	my $lineno = 0;
	CONT: foreach my $id (sort keys %hybrid) {
		next if !$id;
		$case = $id if $debug;
		#next if $hybrid{$id} !~ /\-/;
		#my $shortstr = substr($hybrid{$id},11,100);
		print "\n2) $c $id   $hybrid{$id}\n" if ($id == $case and $hybrid{$id} =~ /\-/) or $debug;
		# $hybrid{$id} =~ /\-(\d+)/;
		if ($hybrid{$id} =~ /\-(\d+)/) {
			my $curid = $1;
			print "curid = $curid\t$hybrid{$id}\n" if $debug;
			try {
				$hybrid{$id} =~ s/\-$curid/$hybrid{$curid}/g;
				if (!$hybrid{$curid}) {
					print ">>>$curid | $hybrid{$id}<<<\n";
					# Usually when a parent is synonym
					exit;
				}
			}
			catch {
				print "$hybrid{$id}\n";
				exit;
			}
		}
		#else {
			#print "\t>>>>>>$id\t$hybrid{$id}\n";
			#exit;
		#}
		print "3) $c $id   $hybrid{$id}\n" if ($id == $case and $hybrid{$id} =~ /\-/) or $debug;
		$c++ if $hybrid{$id} =~ /\-/;
		print "4) $c-$i\n" if $debug;
		if ($hybrid{$id} !~ /\-/) {
			if (!$found{$id}++) { 
				my $file = uc(substr($genus{$id},0,1)).".dat";
				print "4) $c $id $genus{$id} $hybrid{$id}\n" if ($id == $case and $hybrid{$id} =~ /\-/) or $debug;
				my $depth = getDepth($id,$hybrid{$id});
				# Print output in files, named alphabetically
				my $idx = firstidx { $_ eq $file } @num;
				$numhandles[$idx]->print("$id\t$depth\t$hybrid{$id}\n");
				print "5) $file\t$idx\t$hybrid{$id}\n"  if $id == ($id == $case and $hybrid{$id} =~ /\-/) or $debug;
				if ($file =~ /^P\.dat/) {
					print "$lineno\t$file\t$id\t$idx\t$hybrid{$id}\n" if $lineno < 1200;
					$lineno++;
				}
				#print "5) $file\t$idx\t$hybrid{$id}\n" 
				#sleep 1 if $id == $case; 
				#exit if $id == $case;
				# sleep 1 if $debug;
			}
		}
		$hybrid{$id} =~ s/\-//g if $rep > 0;
	}
	
	if ($c > 0 and $rep ==0) {
		if ($prevc == $c) {
			$rep++;
		}
		else {
			$rep =0;
		}
		print "\n\n$c Repeating? $rep\n\n";
		if ($rep>0) {
			#$debug = 1;
			foreach my $x (sort keys %hybrid) {
				if ($hybrid{$x} =~/\-/) {
					sleep 1;
					print "\n\n$x\n";
				}

			}
			#exit;
		}
		sleep 1 if $debug;
		#exit if $loop++ == 1 and $debug;

		#return if ($prevc == $c);
		$prevc = $c;
		$c = 0;
		$i = 0;
		goto CONT;
	}
	#exit;
}

sub getDepth {
	my $id = shift;
	my $line = shift;
	$line =~ s/\d+//g;
	$line =~ s/\[|\]//g;
	#print "\t$line\n";
	my $depth = 0;
	while (1) {
		$line =~ s/\(,\)//g;
		$depth++;
		last if $line =~ /^ *$/;
	}
	#print "$id\t$depth\t$line\n";
	return($depth);
}

sub initHybrid {
  my $stmt = "select pid, genus, species, seed_id, seed_type,pollen_id,pollen_type from orchid_hybrid";
  # where pid not in (100900791,100900792)";
#				where genus = 'Aliceara'";
  &getASPM($stmt);
   
  while (my @row = $sth->fetchrow_array()) {
	next if !$row[1];
	$row[2] = 'na' if !$row[2];
	if (!$row[3] or ! $row[4]) {
		#next;	# ignore hybrids with incomplete parent id
		$row[3] = 0;
		$row[4] = 'species';
		#print "\tSEED:   $row[0], $row[1], $row[2], $row[3], $row[4]\n"; sleep 1;
	}
	if (!$row[5] or !$row[6]) {
		#next;
		$row[5] = 0;
		$row[6] = 'species';
		#print "\tPOLLEN: $row[0], $row[1], $row[2], $row[5], $row[6]\n"; sleep 1;
	}
	$row[3] = -$row[3] if $row[4] eq 'hybrid'; # and !exists $except{$row[3]};
	$row[5] = -$row[5] if $row[6] eq 'hybrid'; # and !exists $except{$row[5]};
	$cross{$row[0]} = "$row[1] $row[2]";
	$hybrid{$row[0]} = "[$row[0]]($row[3],$row[5])";
	$genus{$row[0]} = $row[1]; 
	#print ">>> $row[0]\t$row[1] $row[2]\t$row[3]\t$row[4]\t$row[5]\t$row[6] $genus{$row[0]}.\n" 
	#	if $row[0] == 100112817; 
  }
  $hybrid{0} = '0';
  $cross{0} = 'na';
  #exit;
}




sub initAccepted {
    my $stmt = "select pid,genus,species,infraspr,infraspe from orchid_species
            where status <> 'synonym' and (is_hybrid = '' or is_hybrid is NULL)";
    &getASPM($stmt);
	my $species;
	$accepted{0} = 'na';
    while (my @row = $sth->fetchrow_array()) {
		next if $row[0] == 999999999;
		$species = "$row[1] $row[2]";
		
	    if ($row[3]) {
		    $species .= " $row[3] $row[4]";
	    }
		$row[3] = "" if !$row[3];
		$row[4] = "" if !$row[4];
	    $accepted{$row[0]} = "$species";
		$genus{$row[0]} = $row[1]; 
	}
}

# sub initParents {
# #-- Get genus
  # my $stmt = "select pid, genus, species, infraspr, infraspe from natural_species
				# where status <> 'synonym' and status <> 'pending'";
  # &getASPM($stmt);
	# my $parent;
	# $parents{0} = 'na';
    # while (my @row = $sth->fetchrow_array()) {
		# next if $row[0] == 999999999;
		# $parent = "$row[1] $row[2]";
		
		# $parent .= " $row[3]" if $row[3];
		# $parent .= " $row[4]" if $row[4];
	    # $parents{$row[0]} = "$parent";
		# $genus{$row[0]} = $row[1];
		# print "XXX) $row[0] $row[1] $row[2] $genus{$row[0]}.\n" if $row[0] == 100075658;
	# }
# }

