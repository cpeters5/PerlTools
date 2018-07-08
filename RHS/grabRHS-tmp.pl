#!C:/Perl/bin Perl
#use 5.010;

#---
# Get data from RHS for selected pid list.

use open qw(:locale);
use strict;
use Encode qw(encode decode);
use utf8;
use warnings qw(all);
use LWP::Simple;
use WWW::Mechanize;

require "common.pl";
our ($sth);

my %pid = ();
my ($start, $end) = (1, 1);
# ($start, $end) = (1007000,1007500); #900001);
my $ctime       = time();
my $url   = "http://apps.rhs.org.uk/horticulturaldatabase/orchidregister/orchiddetails.asp?ID=";
my $dir = "RHSQuerries";
system( 'mkdir RHSQuerries' ) if ( ! -d $dir);
 open OUT, '>:encoding(UTF-8)',"data/RHS-accepted-$start-$end.txt" or die "\tCan't open RSH-Search\n $!\n";
#open OUT, ">RHS-accepted-$start-$end.txt" or die "\tCan't open RSH-Search\n $!\n";
# open SYN, ">>RHS-synonym-976648.txt" or die "\tCan't open RSH-Search\n $!\n";
#for (my $pid=976648; $pid < 987400; $pid++) {
print OUT "genus|species|seed_genus|seed_species|pollen_genus|pollen_species|author|originator|status|synonym|date|year|pid|source\n";
my $c = 0;

&getPID();

foreach my $pid (keys %pid) {
	print $pid."\n"; # if $c%10==0;
	$pid = $pid - 100000000;
	my $m = WWW::Mechanize->new();
	$m->get( $url.$pid ) or die "unable to get $url";
	my $Con = $m->content;
	my ($line0,$line) = split(/<table/i,$Con,2);
	next if !defined $line;
	my @line = split(/\n/,$line);
	for (my $i=0; $i< scalar @line; $i++) {
		$line[$i] =~ s/^ +| +$//;
	}
		
	for (my $i =0; $i< scalar @line; $i++) {
		my %info = ();
		my $lno = 0;	#Count lines with orchid information (in <td> tag)
		my $j = 0;
		my $prev = "";
		for ($j = $i; $j < $#line; $j++) {
			last if $line[$j] =~ /<\/table>/igs;
			next if $line[$j]!~ /<td/igs;
			$line[$j] =~ s/<\/em>//igs;
			$line[$j] =~ s/<\/h4>//igs;
			$line[$j] =~ />([^<>\/].+)</;
			$info{status} = $1 if $lno++ == 5;
			$info{$prev} = $1 if defined $prev;
			#print "1)\t$i $j $lno\t$pid\t$prev\t$line[$j]\n"; sleep 1;
			$prev = $1;
		}
		#exit;
		#last if !defined $info{Genus} || $info{Genus} =~ /^na$/i;
		#last if !defined $info{Epithet} || $info{Epithet} =~ /^na$/i;
		#last if $info{Epithet} =~ /^[a-z]/;	# ignore species
		my $k = 0;
		#print "Begin parent table --- $i\n";
		my $l = 0;
		for ($l = $j; $l < $#line; $l++) { 	#-- Get parentage
			last if $line[$l] =~ /<\/table>/igs;
			next if $line[$l]!~ /<td/igs;
			$line[$l] =~ s/<\/em>//igs;
			$line[$l] =~ s/<\/h4>//igs;
			$line[$l] =~ />([^<>\/].+)</;
			#print "2)\t\t$i $j $l $k\t$pid\t$line[$l]\n";
			$info{seedGenus} = $1 if $k == 0;
			$info{seedGrex} = $1 if $k == 2;
			$info{pollenGenus} = $1 if $k == 1;
			$info{pollenGrex} = $1 if $k == 3;
			$k++;
		}
		
		my ($author,$originator,$synonym,$status) = ("","","","","");
		$author = $info{"Registrant Name"} if (defined $info{"Registrant Name"});
		$originator = $info{"Originator Name"} if (defined $info{"Originator Name"});
		if (defined $info{"Synonym Flag"}) {
			$status = $info{"Synonym Flag"};
			$status = "accepted" if $status eq "This is not a synonym";
			$status = "synonym" if $status eq "This is  a synonym";
#next if $status ne "synonym";
			#print "3)\t\t$pid\tstatus = $status\n";
		}
		
		$synonym = $info{"Synonym Genus Name"} if (defined $info{"Synonym Genus Name"});
		#print "4)\t\t$pid\tsynonym = $synonym\n";
		#sleep 1;
		next if !$info{seedGenus} and !$info{pollenGenus};
		$info{seedGenus} = "" if !defined $info{seedGenus};
		$info{pollenGenus} = "" if !defined $info{pollenGenus};
		$info{seedGrex} = "" if !defined $info{seedGrex};
		$info{pollenGrex} = "" if !defined $info{pollenGrex};
		#my ($dy,$mn,$yr) = ("","","");
		#next if ! $info{'Date of registration'};
		my ($dy,$mn,$yr) = ('00','00','0000');
		if ($info{'Date of registration'}) {
			($dy,$mn,$yr) = split(/\//,$info{'Date of registration'});
			#print "$info{'Date of registration'}\t$dy,$mn,$yr\n"; sleep 5;
		}
		
		$info{Epithet} = encode('UTF-8',$info{Epithet});
		$info{seedGrex} = encode('UTF-8',$info{seedGrex});
		$info{pollenGrex} = encode('UTF-8',$info{pollenGrex});
		$author = encode('UTF-8',$author);
		$originator = encode('UTF-8',$originator);
		next if !defined $info{Epithet};
		# utf8::encode($author);
		# utf8::encode($originator);
		# utf8::encode($info{Epithet});
		# utf8::encode($info{seedGrex});
		# utf8::encode($info{pollenGrex});
		# if ($info{status} eq "This is not a synonym") {
		my $pidout = $pid + 100000000;
		
		print OUT "$info{Genus}|$info{Epithet}|$info{seedGenus}|$info{seedGrex}|$info{pollenGenus}|$info{pollenGrex}|$author|$originator|$status|$synonym|$yr-$mn-$dy|$yr|$pidout|RHS\n";
		# }
		# else {print SYN "$info{Genus}\t$info{Epithet}\t$info{seedGenus}\t$info{seedGrex}\t$info{pollenGenus}\t$info{pollenGrex}\t$author\t$yr$mn$dy\t$pidout\tRHS\t$info{'Synonym Flag'}\n";}
		print "5)\t$info{Genus}	$info{Epithet}	$info{seedGenus}	$info{seedGrex}	$info{pollenGenus}	$info{pollenGrex}	$author	$originator	$synonym	$yr-$mn-$dy	$pidout	RHS	$synonym\n";
		last;
	}
}


sub xgetPID {
#-- Get genus
  my $stmt = "select pid-100000000, pid from natural_species where source = 'RHS'";
  &getASPM($stmt);
   
  while (my @row = $sth->fetchrow_array()) { 
	$pid{$row[0]}++;
	#print "$pid{$row[0]}\t$row[0]\t$row[1]\n"; sleep 1;
  }
}


sub getPID {
#-- Get genus
  my $stmt = "select * from natural_species where originator is null and source = 'RHS' and status <> 'synonym' and type <> 'species';";
  &getASPM($stmt);
  my $c = 0;
  while (my @row = $sth->fetchrow_array()) { 
	$pid{$row[0]}++;
	$c++;
	print "$c\t$row[0]\n"; 
  }
}

