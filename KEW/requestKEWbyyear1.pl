#!C:/Perl/bin Perl
#use 5.010;
#------
# This script processes query by year from Kew.
# Generates new and changed species and synonyms into a file.
#
# 1)  Fetch advance search results for Orchidaceae by year.
#       Currently manually copy source page to files and put in data/input
#
# 2)  Run RequestKEWbyyear1.pl (this script)
#       request content of "http://apps.kew.org/wcsp/namedetail.do?name_id=$pid"
#       output: data/pid1, /data/pid2, (intermedate results.
#               data/results/changes.dat and data/results/new.dat
#               data/results/newspecies.dat (final)
#       1. Extract and output
#           1. TODO: genus
#           2. DONE: Extract and output species with status accepted/not accepted (PID1)
#       3. DONE: compare PID1 with actual and output new.txt and changes.txt
#           1. output data/results/changed.txt if statuys changed
#           2. output data/results/new.txt if new PID
#       4. Logon to kew to get detail for new and changes
#           1. For new. extract remaining fields
#               if status = accepted or unplaced and type = species, output to /results/newspecies.dat (confirm if infra specific is captured)
#               if status = accepted or unplaced and type = hybrid, output to /results/newhybrid.dat TODO
#           2. For status changed. Extract remaining fields
#               if status changed to synonym, extract acc_id of accepted species
#                   1. update status in species
#                   2. add (pid, acc_id) to synonym
#                   3. if image exists, update pid to acc_id, and set source_file_name to genus+species
#               if status changed from synonym, extract all synonym spid's
#                   1. update status in species
#                   1. add pid to accepted
#                   2. if synonyms exist,
#                       1. if spid already exists, update acc_id to NEW.pid
#                       2. if new spid, check the current status of spid.
#                           1. If it is 'synonym' (normal), insert (spid, NEW.pid)
#                           2. If not 'synonym' (error) manually update status and follow #1
#           2. TODO: hybrid, output results/hybrid.dat
#           3. TODO: synonym
#
# 3)  Load newspecies.dat to orchid_species, orchid_grex (pid) and orchid_accepted (pid)
#
# 4)  For changed species, update database manually using getpid query.
#       For each pid in changed.dat
#       Delete from orchid_synonym where spid = new pid or acc_id = pid.
#       if current.status = synonym
#           From synonym.dat file, get all new spid where acc_id = pid.
#           Update orchid_species set (status distribution, physicology) to new values
#           insert into orchid_accepted (pid)
#           insert into orchid_synonym (pid, all new spid)
#       else if old status != synonym (new status = accepted or unplaced)
#           From synonym.dat file, get new acc_id where spid = pid.
#           Update orchid_species set (status) to synonym
#           update orchid_spchybrids (pid) to (acc_id)
#           update orchid_ancestordescendant set acc_id = new acc_pid where acc_id = pid
#           delete (pid) from orchid_accepted
#           insert into orchid_synonym (pid, acc_id)
#
# 5)  TODO: For Synonyms, Load data/results/newsynonym.dat to orchid_synonym(acc_id,spid)
#
# 6)  TODO: Natural hybrid
#           Manual load
#------
##############################
use open qw(:locale);
use strict;
use Encode qw(encode decode);
use utf8;
use warnings qw(all);
use LWP::Simple;
use WWW::Mechanize;
my $ctime = time();
#use Time::Duration;
my $url  = "http://apps.kew.org/wcsp/namedetail.do?name_id=";
my $synurl  = "http://wcsp.science.kew.org/synonomy.do?name_id=";
require "common.pl";
our ($sth);
my (%pid, %oldpid, %newpid, %name, %oldname, %oldauth);
#my ($status, $lifeform, $distribution, $family, $count);

# Directorues
my $inputdir = "data/input/";
my $pid1dir = "data/pid1/";
my $pid2dir = "data/pid2/";
my $resdir = "data/results/";

my $new = "new.txt";
my $changed = "changed.txt";
my $type = 'species';

# File names
#my $infile = "kew_$year.html";
#my $pid1 = "pid1_$year.txt";
#my $pid2 = "pid2_$year.txt";
#my $results = "results_$year.html";


print "\nGetting pid and status from search result... ";
#getPID();

print "\nCompareing pid with existing pid...\n";
my (%new, %seen);
comparePid();

print "\nExtract info from Kew\n";
my $extracted = "extracted.dat";
open OUT, ">data/results/newspecies.dat" or die "Cant open file: $!\n";
print OUT "pid\tsource\tgenus\tspecies\tinfraspe\tinfraspr\tauthor\tcitation\ttype\tstatus\tyear\tdistribution\tlifeform\tfamily\tacc_id\n";
my $ct = 0;
foreach my $pid (sort keys %new) {
    next if $seen{$pid}++;
    getContent($pid);
    my $wait =  int(rand(30));
    print "\nProcessing ".$ct++.". Wait $wait seconds.\n";
    sleep $wait;
}

print "\nExtract synonym from new PID\n";
#open OUT, ">data/results/newsynonym.dat" or die "Cant open file: $!\n";
#print OUT "pid\tacc_id\n";
my %seensyn = ();
foreach my $pid (sort keys %new) {
##while (<IN>) {
##    my @items = split(/\t/,$_);
##    my $pid = $items[0];
#    next if $seensyn{$pid}++;
#    getSynonym($pid);
#    my $wait =  int(rand(30));
#    print "\nProcessing synonym #".$ct++.". Wait $wait seconds.\n";
#    sleep $wait;
}

sub getSynonym {
    my $pid = shift;
    #next if $pid <= 521265;
    my $m = WWW::Mechanize->new();
    $m->get( $synurl.$pid ) or die "unable to get $url$pid";
    my $Con = $m->content;
    my (@lines) = split(/\n/,$Con);
    for my $i (0 .. $#lines ) {
        next if $lines[$i] !~ /name_id=(\d+)(.)*onwardnav/;
        print "$pid\t$1\n";
        print OUT "$pid\t$1\n";
    }
}



sub comparePid {
    getOldPid();
    print ">>>$oldpid{25329}\n";
    open (CHG, ">".$resdir."$changed") or die "Cannot open input file $changed: $!\n";
    open (NEW, ">".$resdir."$new") or die "Cannot open input file $new: $!\n";
	opendir (my $dir, $pid1dir) or die "Cant open directory $pid1dir: $!\n";
    my @files = readdir($dir);
    close $dir;
	my $count = 0;
	my %seenpid;
    foreach my $pid1 (@files) {
        next if $pid1 !~ /^pid1_(\d{4})/;
        my $year = $1;
        my $results = "results_$year.txt";
        open (PID1, $pid1dir.$pid1) or die "Cannot open input file $pid1dir.$pid1: $!\n";
        open (OUT, ">".$resdir.$results) or die "Cannot open input file $results: $!\n";
        while (<PID1>) {
            chomp;
            my @data = split(/\t/,$_);
            print "@data\n" if $data[0] == 25329;
            next if $seenpid{$data[0]}++;
            # Skip illegal citation
            next if $data[6] =~ /Nom\.* illeg/i;
            print "$data[0]\t$oldpid{$data[0]}\n" if $data[0] == 25329;
    #        $pid{$data[0]} = $data[1];
            if (exists($oldpid{$data[0]})) {
                if ($oldpid{$data[0]} ne $data[8]) {
                    #print "$data[0]\t$oldpid{$data[0]}\t$data[1]\n";
                    print OUT "$data[0]\t$oldpid{$data[0]}\t$data[5]\t$_\n" ;
                    print CHG "$data[0]\t$oldpid{$data[0]}\t$data[5]\t$_\n"
                        if $oldpid{$data[0]} eq "accepted" or $data[8] eq "accepted";

                }
            }
            else {
               #print "$data[0] $_\n";
                print OUT "not exist\t$data[0] $_\n";
                print NEW "$_\n";
                $new{$data[0]} = $_;
            }
        }
    }
}

sub getContent {
    my $pid = shift;
    my ($lifeform, $distribution, $family, $acc) = ('','','','');

    my $count = 0;
    #next if $pid <= 521265;
    my $m = WWW::Mechanize->new();
    $m->get( $url.$pid ) or die "unable to get $url$pid";
    my $Con = $m->content;
    my ($part0,$part) = split(/plantname/,$Con,2);
    next if !defined $part;
    my @lines = split(/\n/,$part);
    $lines[1] =~ /This name is[ a]* ([a-z-]+)/;
    my $status = $1;

    for my $i (2 .. $#lines ) {
        next if $lines[$i] =~ /^ *$/;
        if ($status eq 'synonym') {
           if ($lines[$i] =~ /namedetail\.do(.*)name_id=(\d+)/) {
                $acc = $2;
#                print ">>$pid - $acc\t$lines[$i]\n";
                next;
            }
        }
        else {
            if ($lines[$i] =~ /Distribution/) {
                $i = $i+4;
                $lines[$i] =~ /^\s*(.+)<br>\s*$/;
                $distribution = $1;
                next;
            }
            if ($lines[$i] =~ /Lifeform/) {
                $i = $i+3;
                $lines[$i] =~ /^\s*(.+)\s*$/;
                $lifeform = $1;
                next;
            }
        }
        if ($lines[$i] =~ /Family/) {
            $i = $i+3;
            $lines[$i] =~ /^\s*(.+)\s*$/;
            $family = $1;
            next;
        }
    }
    my ($genus,$species,$infraspr,$infraspe,$year,$author,$citation) = split(/\t/,$pid{$pid});
    print "$pid-$acc\t$genus,\t$species,\t$status,\t$distribution,\t$lifeform,\t$family,\t$acc\t$pid{$pid},\t$year\n";
    print OUT "$pid\tKew\t$genus\t$species\t$infraspr\t$infraspe\t$author\t$citation\t$type\t$status\t$year\t$distribution\t$lifeform\t$family\t$acc\n";
}

# TODO: Retrieve the input file from Kew advanced search.

sub getPID {
	opendir (my $dir, $inputdir) or die "Cant open directory $inputdir: $!\n";
    my @files = readdir($dir);
    close $inputdir;
	my $count = 0;
    my $pid1dir   = "data/pid1/";
    foreach my $file (@files) {
        next if $file !~ /^kew_(\d{4})/;
        my $year = $1;
        my $pid1 = "pid1_$year.txt";
        open PID1, ">$pid1dir$pid1" or die "Can't open $pid1 - $1\n";
        open INPUT, $inputdir.$file or die "Can't open $pid1 - $1\n";
        while (<INPUT>) {
            next if $_ !~ /name_id=(\d+).*<i>([A-Za-z-]+)<\/i><i> ([a-z-]+)<\/i> (.+)<\/a>/;
            my ($pid,$genus,$species,$auth,$infraspe,$infraspr,$author,$citation) = ('','','','','','','','');
            ($pid,$genus,$species,$auth) = ($1,$2,$3,$4);
            if ($auth =~ /^([a-z\.]+)<i> (.+)<\/i>(.+)$/) {
                $infraspr = $1;
                $infraspe = $2;
                $auth = $3;
            }
            if ($auth =~ /\((\d{4})\)/) {
                $year = $1;
            }
            my $authtemp = $auth;
            if ($auth =~ /^(.+), nom / or $auth =~ /^(.+), nom\. /) {
                $authtemp = $1;
            }
            $authtemp =~ s/^(\([\d]{4}[A-Za-z]*\)),/$1/;
            $authtemp =~ s/, +suppl/ suppl/i;
            $authtemp =~ s/, ([A-Za-z ]*\.*)$/ $1/i;

            ($author,$citation) = split(/\,([^\,]+)$/,$authtemp);
            #$citation = $auth;
            # $citation =~ s/$author, //;
            $citation = $auth;
            #print "\t\t>>$author | $citation\n";

            if ($pid) {
                $pid{$pid} = "$genus\t$species\t$infraspr\t$infraspe\t$year\t$author\t$citation";
                <INPUT>;
                if (<INPUT> =~ /<\/b>/) {
                    $pid{$pid} .= "\taccepted";
                    $newpid{$pid} = "accepted";
                }
                else {
                    $pid{$pid} .= "\tnotaccepted";
                    $newpid{$pid} = "notaccepted";
                }
            }
            print PID1 "$pid\t$pid{$pid}\n";
            $count++;
            print "$count\t$pid\t$pid{$pid}\n" if $pid == 25329;
        }
        close INPUT;
        close PID1;
        #print "Found $count records for $file\n";
    }
}


sub getOldPid {
    my $stmt = "select pid, status, genus, species, infraspr, infraspe, author from orchid_species where source = 'kew';";
    &getASPM($stmt);
    while (my @row = $sth->fetchrow_array()) {
        $oldpid{$row[0]} = $row[1];
        $oldname{$row[0]} = "$row[2] $row[3]";
        $oldname{$row[0]} .= " $row[4]" if $row[4];
        $oldname{$row[0]} .= " $row[5]" if $row[5];
        $oldname{$row[0]} =~ s/ +$//;
        $oldauth{$row[0]} = $row[6];
        print "$oldpid{$row[0]}\t$oldname{$row[0]}\n" if $row[0] == 25329;
    }
}