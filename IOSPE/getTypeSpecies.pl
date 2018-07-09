#-- Initial implementation 20171212
#-- Author: Chariya Punyanitya
#-----------------------------
#  Logon to IOSPE, get content, put in data dir for ref.
#  Extract SUBGENUS, SECTION, SUBSECTION, SERIES
#  Load output filt to table.
#  Get pid from Species class.
#  Finally, compare with 
use open qw(:locale);
use strict;
use Encode qw(encode decode);
use utf8;
use warnings qw(all);

require "common.pl";
our ($sth);
my $path = "./data/";
my %pid = ();
my $debug = 0;

print "Initialize Genus\n";
getGEN();


print "Initialize Species\n";
getPID();

opendir (my $dir,$path ) or die "Can't open directory\n$!\n";
open OUT, ">typeout.dat" or die "Cant open typeout.dat\n$!\n";
print OUT "line_no	gen	pid	file	genus	species	author	year	section	secinfo	subsection	subgenus	series\n";
while (my $file = readdir $dir) {
	next if $file !~ /\.htm$/;
	my $out = $file;
	$out =~ s/\.htm/\.dat/;
	open IN, $path.$file or die "Cant open $file\n$!\n";
	my $i = 0;
	print "$file\n";
	next if $file !~ /^dendro\./ and $debug;
	#sleep 5;
	while (<IN>) {
		$i++;
		next if $_ =~ /^ *$/;
		next if $_ =~ /^ *<P> *\~/i;
		$_ =~ s/× //;
		$_ =~ s/ x / /i;
		$_ =~ s/&amp;/&/;
		next if $_ !~ /<i> *SECTION/i and $_!~ /SUBSECTION/ and $_!~ /SUBGENUS/ and $_!~ /SERIES/;
		print "\n1) $_" if $debug;
		my $section = '';
		my $subsection = '';
		my $subgenus = '';
		my $series = '';
		
		"a" =~ /a/;
		$_ =~ /SECTION +([A-Za-z\-]+)/;
		$section = $1 if $1;
		print "2) Section = $section\n" if $debug;
		
		"a" =~ /a/;
		$_ =~ /SUBSECTION +([A-Za-z]+)/;
		$subsection = $1 if $1;
		print "3) subsection = $subsection\n" if $debug;
		
		"a" =~ /a/;
		$_ =~ /SUBGENUS +([A-Za-z\-]+)/;
		next if $_ =~ /^ *<P> *SUBGENUS/i;
		$subgenus = $1 if $1;
		print "4) subgenus = $subgenus\n" if $debug;
		
		"a" =~ /a/;
		$_ =~ /SERIES +([A-Za-z\-]+)/;
		$series = $1 if $1;
		print "5) series = $series\n" if $debug;
		
		my ($genus, $species, $rest, $secinfo) = ('','','','');
		if ($_ =~ /<I> *SECTION +/i) {	# Section is not given, only extrace genus/species
			$_ =~ /> *([^<]+)<\/[Aa]>.*SECTION/i;
			# next if $1 =~ /sp\.?/;
			my $name = $1;
			$name =~ s/^ +//;
			($genus,$species,$rest) = split(/ +/,$name,3);
			print "6) name = $name\n" if $debug;
		}
		if  ($_ =~ /SUBGENUS/) {
			$_ =~ /> *([^<]+)<\/[Aa]>.*SUBGENUS\.* +/;
			if ($1) {
				my $name = $1;
				$name =~ s/^ +//;
				($genus,$species, $rest) = split(/ +/,$1,3);
				print "7) name = $name\n" if $debug;
			}
		}
		if  ($_ =~ /SUBSECTION/) {
			$_ =~ /> *([^<]+)<\/[Aa]>.*SUBSECTION\.* +/;
			if ($1) {
				my $name = $1;
				$name =~ s/^ +//;
				($genus,$species, $rest) = split(/ +/,$1,3);
				print "8) name = $name\n" if $debug;
			}
		}
		if  ($_ =~ /SERIES/) {
			$_ =~ /> *([^<]+)<\/[Aa]>.*SERIES\.* +/;
			if ($1) {
				my $name = $1;
				$name =~ s/^ +//;
				($genus,$species, $rest) = split(/ +/,$1,3);
				print "9) name = $name\n" if $debug;
			}
		}
		"a" =~ /a/;
		$_ =~ /[Aa]>.*SECTION\.* +([^<]+)?/i;
		$secinfo = $1 if $1;
		
		next if $species =~ /sp\.?/;
		
		print "10) Genus   = $genus\n" if $debug;
		print "11) species = $species\n" if $debug;
		print "12) rest    = $rest\n" if $debug;
		print "13) secinfo = $secinfo\n" if $debug;
		$secinfo =~ s/\n$//;
		$secinfo =~ s/ *$section *//;
		$secinfo =~ s/ *$subsection *//;
		$secinfo =~ s/ *$subgenus *//;
		$secinfo =~ s/ *$series *//;
		$secinfo =~ s/ *SECTION *//i;
		$secinfo =~ s/ *SUBSECTION *//;
		$secinfo =~ s/ *SUBGENUS *//;
		$secinfo =~ s/ *SERIES *//;
		my $year = '';
		my $author = '';
		$rest =~ s/\t/ /g;
		if ($rest =~ /([0-9]{4})/) {
			$year = $1;
			$author = $rest;
			$author =~ s/$year//;
		}
		else {
			$author = $rest;
		}
		my $status = 'accepted';
		if ($genus =~ /^\~/) {
			$status = "synonym";
			$genus =~ s/^\~//;
		}
		my $type = '';
		if ($genus =~ /^\!/) {
			$type = "type";
			$genus =~ s/^\!//;
		}
		$_ =~ s/.{100}\K.*//s;   # truncate line to 100 char.
		#print "$i\t$genus, $species, $author, $year, $section, $secinfo, $subsection, $subgenus, $series\t$_\n";
		
		my $pid = '';
		my $id = $genus.'|'.$species;
		$pid = $pid{$id} if $pid{$id};
		
		print OUT "$i\t$pid\t$file\t$status\t$type\t$genus\t$species\t$author\t$year\t$section\t$secinfo\t$subsection\t$subgenus\t$series\n";
		#sleep 1;
		exit if $i == 3774 and $debug;
	}
	close IN;
}



sub getGEN {
#-- Get genus
  my $stmt = "select pid, genus from orchid_genus";
  &getASPM($stmt);
   
  while (my @row = $sth->fetchrow_array()) { 
	
	my $id = $row[1].'|'.$row[2];
	$id .= '|'.$row[3] if $row[3];
	$id .= '|'.$row[4] if $row[4];
	$pid{$id} = $row[0];
	#print "$pid{$id}\t$row[0]\t$row[1]\t$row[2]\n"; 
  }
}


sub getPID {
#-- Get genus
  my $stmt = "select pid, genus, species, gen from orchid_species";
  &getASPM($stmt);
   
  while (my @row = $sth->fetchrow_array()) { 
	
	my $id = $row[1].'|'.$row[2];
	$id .= '|'.$row[3] if $row[3];
	$id .= '|'.$row[4] if $row[4];
	$pid{$id} = $row[0];
	#print "$pid{$id}\t$row[0]\t$row[1]\t$row[2]\n"; 
  }
}

