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
my $ctime = time();
#use Time::Duration;
my $url  = "http://apps.kew.org/wcsp/namedetail.do?name_id=";
my $synurl  = "http://wcsp.science.kew.org/synonomy.do?name_id=";
require "common.pl";
our ($sth);
my (%pid, %oldpid, %newpid, %name, %oldname, %oldgenus, %oldspecies, %oldinfraspr, %oldinfraspe, %oldauth);
#my ($status, $lifeform, $distribution, $family, $count);

# Directorues
my $inputdir = "data/input/";
my $pid1dir = "data/pid1/";
my $pid2dir = "data/pid2/";
my $resdir = "data/results/";

my $new = "new.txt";
my $changed  = "changed_status.txt";
my $changed2 = "changed_name.txt";
my $type = 'species';

# my $year = $ARGV[0];
my $start = $ARGV[0];
my $end = $start;
$end = $ARGV[1] if $ARGV[1];
my (%new, %seen);


#----- 1)  Submit Query by Year
for (my $year = $start; $year < $end; $year++) {
	print "1) Fetch query results for $year\n";
    submitForm($year, 0);
	print "\n";
    getPIDfromfile($year, 0);
}
#----- 2)  Extract query results
#getPID($year, 1);

#----- 3) Compare query results with current
my ($change_count, $new_count) = (0,0);
open OUT, ">:utf8","data/results/newspecies.dat" or die "Cant open file: $!\n";
print OUT "pid\tgen\tsource\tgenus\tspecies\tinfraspe\tinfraspr\tauthor\tcitation\tstatus\ttype\tyear\t\tdistribution\tlifeform\n";
for (my $year = $start; $year < $end; $year++) {
	print "2) Compare $year pid with existing pid...";
	($change_count, $new_count) = (0,0);
	comparePid($year, 0);
	print "Found $new_count new pid and $change_count changed pid\n\n";
	# next if $count;
	#----- 4)  From new and chanbged files, request detail page from Kew and extract new content.
	print "3) Extract $year content from Kew\n";
	my $ct = 1;
	foreach my $pid (sort keys %new) {
		next if $seen{$pid}++;
		print "Working on $pid\n\n" if $debug;
		my $ret = getContent($pid,0);
		next if !$ret;
		my $wait =  int(rand(5));
		print "3.1) Processing #".$ct++." $pid. Wait $wait seconds.\n";
		sleep $wait;
	}
}

print "\n4) Extract synonym from new PID\n";
#open OUT, ">data/results/newsynonym.dat" or die "Cant open file: $!\n";
#print OUT "pid\tacc_id\n";
my %seensyn = ();
# foreach my $pid (sort keys %new) {
##while (<IN>) {
##    my @items = split(/\t/,$_);
##    my $pid = $items[0];
#    next if $seensyn{$pid}++;
#    getSynonym($pid);
#    my $wait =  int(rand(30));
#    print "\nProcessing synonym #".$ct++.". Wait $wait seconds.\n";
#    sleep $wait;
# }
#
# sub getSynonym {
#     my $pid = shift;
#     #next if $pid <= 521265;
#     my $m = WWW::Mechanize->new();
#     $m->get( $synurl.$pid ) or die "unable to get $url$pid";
#     my $Con = $m->content;
#     my (@lines) = split(/\n/,$Con);
#     for my $i (0 .. $#lines ) {
#         next if $lines[$i] !~ /name_id=(\d+)(.)*onwardnav/;
#         print "$pid\t$1\n";
#         print OUT "$pid\t$1\n";
#     }
# }
#


sub comparePid {
	my $year = shift;
	my $debug = shift;

    getOldPid();
    #print "2.1>>>$oldpid{25329}\n";
    open (CHG, ">:utf8",$resdir."$changed") or die "Cannot open input file $changed: $!\n";
    open (CHG2, ">:utf8",$resdir."$changed2") or die "Cannot open input file $changed: $!\n";
    open (NEW, ">:utf8",$resdir."$new") or die "Cannot open input file $new: $!\n";
    open (GEN, ">:utf8",$resdir."changed_genus.dat") or die "Cannot open input file changed_genus.dat: $!\n";
    open (SPC, ">:utf8",$resdir."changed_species.dat") or die "Cannot open input file changed_species.dat: $!\n";
    open (INE, ">:utf8",$resdir."changed_infraspe.dat") or die "Cannot open input file changed_infraspe.dat: $!\n";
    open (INR, ">:utf8",$resdir."changed_infraspr.dat") or die "Cannot open input file changed_infraspr.dat: $!\n";
	opendir (my $dir, $pid1dir) or die "Cant open directory $pid1dir: $!\n";
    my @files = readdir($dir);
    close $dir;
	my $count = 0;
    my %seenpid;
    # foreach my $pid1 (@files) {
	for (my $year = $start; $year < $end; $year++) {	
    	my $newname = '';
        # next if $pid1 !~ /^pid1_(\d{4})/;
        # my $year = $1;
		my $pid1 = $pid1dir . "pid1_" . $year . ".txt";
        #my $results = "results_$year.txt";
        #print "$results\n" if $debug;
		open (PID1, $pid1) or die "Cannot open input file $pid1: $!\n";
        #open (RES, ">".$resdir.$results) or die "Cannot open input file $results: $!\n";
        while (<PID1>) {
            chomp;
            my @data = split(/\t/,$_);
            my $newname = "$data[1] $data[2]";
            $newname .= " " . $data[3] if $data[3];
            $newname .= " " . $data[4] if $data[4];
            # next if $seenpid{$data[0]}++;
            print "2.2) @data\n" if $debug;
            # Skip illegal citation
            next if $data[6] =~ /Nom\.* illeg/i;
            print "2.3) $data[0]\told = $oldname{$data[0]}\tnew = $newname\n" if $debug;
    #        $pid{$data[0]} = $data[1];
            if (exists($oldpid{$data[0]})) {
                if ($oldpid{$data[0]} ne $data[8] or $oldname{$data[0]} ne $newname) {
                    #print "$data[0]\t$oldpid{$data[0]}\t$data[1]\n";
                    #print RES "$data[0]\t$oldpid{$data[0]}\t$data[5]\t$_\n" ;
                    
					if (($oldpid{$data[0]} eq "accepted" and $data[8] ne "accepted") or
                        ($oldpid{$data[0]} eq "unplaced" and $data[8] eq "accepted") or
                        ($oldpid{$data[0]} eq "synonym" and $data[8] eq "accepted")){
    					print "\t$oldpid{$data[0]} ne $data[8]\n"; # if $debug;
						$change_count++;
						print CHG "$data[0]\told = >$oldname{$data[0]}<\tnew = >$newname<\toldstatus = >$oldpid{$data[0]}<\tnewstatus = >$data[8]<\n"; #\t($_)\n"
					}
					else {
                        if ($oldname{$data[0]} ne $newname) {
                            print "\t$oldname{$data[0]} ne $newname\n"; # if $debug;
                            $change_count++;
                            print CHG2 "$data[0]\told = >$oldname{$data[0]}<\tnew = >$newname<\toldstatus = >$oldpid{$data[0]}<\tnewstatus = >$data[8]<\n"; #\t($_)\n"
                        }
					}
				}
                if ($oldgenus{$data[0]} ne $data[1]){
                    print "\tGenus changed $oldgenus{$data[0]} ne $data[1]\n"; # if $debug;
                    $change_count++;
                    print GEN "$data[0]\tnew genus = >$data[1]<\told genus = >$oldgenus{$data[0]}<\n";
                }
                if ($oldspecies{$data[0]} ne $data[2]){
                    print "\tSpecies changed $oldspecies{$data[0]} ne $data[2]\n"; # if $debug;
                    $change_count++;
                    print SPC "$data[0]\tnew species = >$data[2]<\told species = >$oldspecies{$data[0]}<\n";
                }
                if ($oldinfraspr{$data[0]} and $oldinfraspr{$data[0]} ne $data[3]){
                    print "\tInfraspr changed $oldspecies{$data[0]} ne $data[3]\n"; # if $debug;
                    $change_count++;
                    print INR "$data[0]\tnew infraspr = >$data[3]<\told infraspr = >$oldinfraspr{$data[0]}<\n";
                }
                if ($oldinfraspe{$data[0]} and $oldinfraspe{$data[0]} ne $data[4]){
                    print "\tInfraspe changed $oldinfraspe{$data[0]} ne $data[4]\n"; # if $debug;
                    $change_count++;
                    print INE "$data[0]\tnew infraspe = >$data[4]<\told infraspe = >$oldinfraspe{$data[0]}<\n";
                }
            }
            else {
               #print "$data[0] $_\n";
                #print RES "not exist\t$data[0] $_\n";
                print NEW "$_\n";
                $new{$data[0]} = $_;
				print "\n\t$data[0]\t$new{$data[0]}\n";
				$new_count++;;
            }
        }
    }
}

sub getContent {
    my $pid = shift;
	my $debug = shift;
	
    my ($lifeform, $distribution, $family, $acc) = ('','','','');

    my $mech = WWW::Mechanize->new(quiet=>1);
    my $ua = LWP::UserAgent->new;
    $ua->protocols_allowed(['https']);
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
    for my $i (2 .. $#lines ) {
        next if $lines[$i] =~ /^ *$/;
        if ($status eq 'synonym') {
           if ($lines[$i] =~ /namedetail\.do(.*)name_id=(\d+)/) {
                $acc = $2;
                print "3.7) >>$pid - $acc\t$lines[$i]\n" if $debug;
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

    print "\n>>>Pid = $pid\tContent = $pid{$pid}\n\n" if $debug;
	my $date = "Null";
    my ($genus,$species,$infraspr,$infraspe,$year,$author,$citation) = split(/\t/,$pid{$pid});
    print "$pid-$acc\t$genus,\t$species,\t$status,\t$distribution,\t$lifeform,\t$family,\t$acc\t$pid{$pid},\t$year\n";
    # print OUT "$pid\t\tKew\t$genus\t$species\t$infraspr\t$infraspe\t$author\t$citation\t$status\t$type\t$year\t$date\t$distribution\t$lifeform\t\t\t\t$acc\n";
    print OUT "$pid\t\tKew\t$genus\t$species\t$infraspr\t$infraspe\t$author\t$citation\t$status\t$type\t$year\t$date\t$distribution\t$lifeform\n";
    #exit if $debug;
	return 1;
}

# TODO: Retrieve the input file from Kew advanced search.

sub submitForm {
    my $year = shift;
    my $debug = shift;
    my $count = 0;
    my $pid1dir = "data/pid1/";
    my $pid1 = "pid1_$year.txt";
    my $mech = WWW::Mechanize->new;
    $mech->get('http://wcsp.science.kew.org/advanced.do');
    $mech->submit_form(
        form_name => 'searchForm',
        fields    => {
            'family'        => 'Orchidaceae',
            'yearPublished' => $year,
        },
    );
    # my $results = $mech->content;
    my $file = $mech->content;
    # open INPUT, ">:utf8", "data/input/kew_$year.html";
    # print INPUT $file;
    close INPUT;
}

sub getPIDfromfile {
        my $year = shift;
		my $debug = shift;
		
        my $pid1 = "pid1_$year.txt";
        my $count = 0;
        open PID1, ">:utf8",$pid1dir.$pid1 or die "Can't open $pid1 - $1\n";
        open INPUT, "data/input/kew_$year.html" or die "Can't open file.html\n";
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
            print "$count\t$pid\t$pid{$pid}\n"  if $debug;
        }
        close INPUT;
        close PID1;
        #print "Found $count records for $file\n";

}



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
        open PID1, ">:utf8",$pid1dir.$pid1 or die "Can't open $pid1 - $1\n";
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
            print "$count\t$pid\t$pid{$pid}\n"  if $debug;
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
        $oldgenus{$row[0]} = $row[2];
        $oldspecies{$row[0]}  = $row[3];
        $oldinfraspr{$row[0]} = $row[4] if $row[4];
        $oldinfraspe{$row[0]} = $row[5] if $row[5];
    }
}