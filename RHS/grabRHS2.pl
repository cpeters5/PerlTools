#!C:/Perl/bin Perl
#use 5.010;

#---
# Update natural_hybrid table.
#-- 1. Get max(source_id) from current table
#-- 2. set $start, $end pid
#-- 3. Run until reach record with current date
#-- 4. Edit output file to correct unicode using ./data/unicode.txt
#------Check in this order *'s, &times; unicode character, words contining unicode, {}
#-- 5. truncate natural_hybrid_xfer table
#-- 7. import output file to the transfer table
#-- 8. Run load hybrids.sql one command at a time
#	   update gen_id, afterward, check for new genus. If exists add it to natural_genus table
#-- 9. Manually check for missing fields. In particular seed and pollen may be a synonym
#-- 10 insert into natural_hybrid table after the trasfer table is clean





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
my ($start, $end) = (1000000, 1000500);
# ($start, $end) = (1,100000);
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

for (my $pid=$start; $pid < $end; $pid++) {
	next if $pid{$pid};
	print $pid."\n"; # if $c%10==0;
	#print "$pid\n" ;#if $pid%100==0;
	#sleep 1;
	
	
	
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
		$info{seedGenus} = "" if !defined $info{seedGenus};
		$info{seedGrex} = "" if !defined $info{seedGrex};
		$info{pollenGenus} = "" if !defined $info{pollenGenus};
		$info{pollenGrex} = "" if !defined $info{pollenGrex};
		my ($dy,$mn,$yr) = ("","","");
		if (defined $info{'Date of registration'}) {
			($dy,$mn,$yr) = split(/\//,$info{'Date of registration'});
		}
		else {
			($dy,$mn,$yr) = ('0000','00','00');
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


sub getPID {
#-- Get genus
  my $stmt = "select pid-100000000, pid from natural_species where source = 'RHS'";
  &getASPM($stmt);
   
  while (my @row = $sth->fetchrow_array()) { 
	$pid{$row[0]}++;
	#print "$pid{$row[0]}\t$row[0]\t$row[1]\n"; sleep 1;
  }
}

