#!C:/Perl/bin Perl
#use 5.010;
#------
# This script processes query by year from Kew.
# Generates new and changed species and synonyms into a file.
#
# 1)  submitForm(year) Request advance search form from Kew and fill in the family and year fields.  
#	  Results are stored in data/inmput/kew_yyyy.html files
#     TODO: store results in an array.
#
# 2)  getPIDfromfile(year) Read the input results (or @results array in memory) 
#	  Extract record of eqach pid and stor in %pid 
#	  Also output to data/pid1/pid1_YYYY.txt.
#
# 3)  comparePid(year)
#	  - Compare current status from database with the status in the results.
#	  - create an assoc array %pid to store record by pid
#	  - Output new pid records not currently in the dataase in data/results/new.txt.
#	  - Output all pid found in data/pid1/pid1_year.txt.
#
# 3)  Loop through %new generated from step 2.  
#       For each new pid, execure getContent() to dump detail page from Kew
#	    -  extract the record and output to data/results/newspecies.dat
#          if status = accepted or unplaced and type = species, output to /results/newspecies.dat 
#          if status = accepted or unplaced and type = hybrid, output to /results/newhybrid.dat TODO
#		-  TODO: if status = synonym, extract accepted pid from detail dump
#          Then compare the count with current count in the database (+1).  
#	       If different output pid into a file for further investigation 
#
#       TODO: For each record in change.dat extract remaining fields
#          if status changed to synonym, extract acc_id of accepted species
#                   1. update status in species
#                   2. add (pid, acc_id) to synonym
#                   3. if image exists, update pid to acc_id, and set source_file_name to genus+species
#          if status changed from synonym, extract all synonym spid's
#                   1. update status in species
#                   1. add pid to accepted
#                   2. if synonyms exist,
#                       1. if spid already exists, update acc_id to NEW.pid
#                       2. if new spid, check the current status of spid.
#                           1. If it is 'synonym' (normal), insert (spid, NEW.pid)
#                           2. If not 'synonym' (error) manually update status and follow #1
#       - hybrid, output results/hybrid.dat
#       - Extract synonym count of each accepted record
#
# 3)  Load newspecies.dat to orchid_species,
#	  - if status = accepted or unplaced, load pid to Accepted
#	  - If status = synonym, load (pid, acc_id) to Synonyms
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
use LWP::UserAgent;
use LWP::Protocol::https;
use LWP::Simple;
use WWW::Mechanize;
$ENV{HTTPS_DEBUG} = 0;
my $debug = 1;

#use Time::Duration;
my $url  = "http://apps.kew.org/wcsp/namedetail.do?name_id=";
my $synurl  = "http://wcsp.science.kew.org/synonomy.do?name_id=";
require "common.pl";
our ($sth);

my $start = $ARGV[0];
my $end = $start;
$end = $ARGV[1] if $ARGV[1];
open OUT, ">data/results/distcode.dat" or die "Cant open discode.dat: $!\n";

#----- 1)  Submit Query by Year

my $ct = 0;
my %seen;
for (my $year = $start; $year < $end; $year++) {
    %seen = ();
    getPid($year);
    foreach my $pid (sort keys %seen) {
        print "Working on $pid\n\n" if $debug;
        my $ret = getContent($year, $pid, 0);
        next if !$ret;
        my $wait = int(rand(10));
        print "3.1) Processing #" . $ct++ . " $pid. Wait $wait seconds.\n";
        last if $ct > 10 and $debug;
        sleep $wait;
    }
}

sub getContent {
    my $year = shift;
    my $pid = shift;
	my $debug = shift;
	
    my ($lifeform, $distribution, $family, $acc) = ('','','','');

    my $mech = WWW::Mechanize->new();
    # my $ua = LWP::UserAgent->new;
    # $ua->protocols_allowed(['https']);
    $mech->add_handler("request_send", sub { shift->dump; return });
    $mech->add_handler("response_done", sub { shift->dump; return });

    print "3.1) Start here\n" if $debug;
    # my $url ="https://www.cpan.org";
    my $url  = "http://wcsp.science.kew.org/namedetail.do?name_id=$pid";
    $mech->get( $url );
    print "3.2) Initialize mech\n" if $debug;

    # my @links = $mech->links();
    # for my $link ( @links ) {
    #     printf "%s, %s\n", $link->text, $link->url;
    # }
    my $Con = $mech->content;
    print "3.3) Got content\n" if $debug;
    my ($part0,$part) = split(/plantname/,$Con,2);
    return 0 if !defined $part;

    print "3.4) Split into lines\n" if $debug;
    my @lines = split(/\n/,$part);
    $lines[1] =~ /This name is[ a]* ([a-z-]+)/;
    my $status = $1;

    print "3.5) Line[1] = $lines[1]\n" if $debug;
    print "3.6) Status = $status\n" if $debug;
    my $prev_dist_num = 0;
    for my $i (2 .. $#lines ) {
        next if $lines[$i] =~ /^ *$/;
        if ($lines[$i] =~ /Distribution/) {
            $i = $i + 4;
            $lines[$i] =~ /^\s*(.+)<br>\s*$/;
            $distribution = $1;
            $i = $i + 4;
            for my $j ($i .. $#lines) {
                next if $lines[$j] =~ /^ *$/;
                my ($dist_num, $dist_code) = ('', '');
                $lines[$j] =~ /^(.*) *$/;
                $dist_code = $1;
                $dist_code =~ s/^ *//;
                if ($dist_code =~ /(\d+) (.+)/) {
                    $dist_num = $1;
                    $dist_code = $2;
                    $prev_dist_num = $dist_num;
                }
                else {
                    $dist_num = $prev_dist_num;
                }
                last if $lines[$j] =~ /<\/td>/;
                my $stmt = "insert ignore into orchid_distributioncode (pid,source,dist_num, dist_code) values ($pid, 'Kew',$dist_num, '$dist_code')";
                &getASPM($stmt);
                print OUT "$pid\t$dist_num\t$dist_code\n";
                print "$year\t$pid\t$dist_num\t$dist_code\t$distribution\n";
            }
        }
    }

	return 1;
}


sub getPid {
    my $year = shift;
    my $stmt = "select pid from orchid_species where source = 'kew' and year = $year and (status = 'accepted' or status = 'unplaced');";
    &getASPM($stmt);
    %seen = {};
    while (my @row = $sth->fetchrow_array()) {
        $seen{$row[0]}++;
    }
}