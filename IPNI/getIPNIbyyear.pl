#!C:/Perl/bin Perl
#use 5.010;
# 1) Run this script with argument YYYY-MM-DD
# IPNI output all matches created or modified from YYYY_01_01 to current in % limited format
# Script fetched results and stored in orchid_species table. Also output to data/input/ipni_YYYY-MM-DD.txt.
# 2) Add all hybrid type records to orchid_hybrid table.  Manually create seed pollen parents using hybrid formula in Description field
#-------
# WARNING!!!:  Load to table ipni using import wizard seems to miss a number of records (~10%)
# To get all records, Copy and paste into table directly.
#------
##############################
use open qw(:locale);
use utf8;
use strict;
use Encode qw(encode decode);
use utf8;
use warnings qw(all);
use LWP::UserAgent;
use LWP::Protocol::https;
use LWP::Simple;
use WWW::Mechanize;
$ENV{HTTPS_DEBUG} = 0;

require "common.pl";
our ($sth);
#my ($status, $lifeform, $distribution, $family, $count);

# Directorues
my $inputdir = "data/input/";

my $date = '';
$date = $ARGV[0] if $ARGV[0];
my $family = "orchidaceae";

if ($date !~ /^[\d]{4}\-[\d]{2}\-[\d]{2}$/ ) {
    print "\nUsage: getIPNI.pl YYYY-MM-DD\n\n";
    exit;
}

#----- 1)  Submit Query by Year
print "1) Fetch query results for $date\n";

my %oldname;
getPID();
getPIDfromfile($date);
exit;

sub getPIDfromfile {
    my $date = shift;
    my $i = 0;
    # Submit form and write to input dir.
    my $url = "http://www.ipni.org/ipni/advPlantNameSearch.do?find_includePublicationAuthors=on&find_includePublicationAuthors=off&find_includeBasionymAuthors=on&find_includeBasionymAuthors=off&show_extras=on&find_isAPNIRecord=on&find_isAPNIRecord=false&find_isGCIRecord=on&find_isGCIRecord=false&find_isIKRecord=on&find_isIKRecord=false&find_rankToReturn=all&output_format=delimited&find_sortByFamily=off&query_type=by_query&back_page=plantsearch";
    $url .= "&find_family=" . $family . "&find_modifiedSince=" . $date . "&find_addedSince=" . $date;
    print "$url\n";
    my $mech = WWW::Mechanize->new;
    $mech->get($url);
    # my $results = $mech->content;
    my $file = $mech->content;
    $file =~ s/\%/\t/g;
    $inputdir .= "ipni_$date.txt";
    open INPUT, ">:utf8", $inputdir or die "Cant open $inputdir: $!\n";
    print INPUT $file;
    close INPUT;
    my(@lines) = split(/\n/,$file);
    open OUT, ">:utf8","data/new.txt";
    foreach my $line (@lines) {
        $line =~ s/\'/\'\'/g;
        my($pid,$source,$genus,$species,$infraspr,$infraspe,$author,$citation,$status,$type,$year,$distribution,$description,$is_hybrid)
            = ('','','','','','','','','','','','','','');
        my (@recs) = split(/\t/,$line);
        next if $recs[11] ne 'spec.';
        $pid = $recs[0];
        $pid =~ s/\-\d+$//;
        $pid = int($pid) + 400000000;
        $source = 'IPNI';
        $is_hybrid = '×' if $recs[4] eq 'Y' or $recs[7] eq 'Y';
        $genus = $recs[5];
        $species = $recs[8];
        $infraspr = $recs[11] if $recs[11] ne 'spec.';
        $infraspe = $recs[10];
        $author = $recs[12];
        $citation = $recs[19];
        $status = 'published';
        if ($is_hybrid eq '×') {
            $type = 'hybrid';
            $description = $recs[23]; # Hybrid parents
        }
        else {
            $type = 'species';
        }
        $citation =~ /[^\d]{1}([\d]{4})[^\d]{1}/;
        next if $citation =~ /inval\.$/;
        $year = $1;
        $distribution = $recs[26];
        my $name = $genus.$species;
        $name   .= $infraspr if $infraspr;
        $name   .= $infraspe if $infraspe;

        next if exists $oldname{$name};
        print "$pid\t>$name<\n";
        #print "$pid\t$genus $is_hybrid $species $author\t$citation\t$type\t$year\t$distribution\t$description\n";
        print OUT "$pid\t\t$source\t$genus\t$species\t$infraspr\t$infraspe\t$author\t$citation\t$status\t$type\t$year\t\t$distribution\t\t$description\n";
        my $stmt = "insert ignore into orchid_species_ipni_xfer (pid,source,genus,species,infraspr,infraspe,author,citation,status,type,year,distribution,description,is_hybrid)
                    values ('$pid','$source','$genus','$species','$infraspr','$infraspe','$author','$citation','$status','$type','$year','$distribution','$description','$is_hybrid')";
        getASPM($stmt);
    }
}

sub getPID {
    my $stmt = "select pid,genus,species,infraspr,infraspe from orchid_species";
    getASPM($stmt);
	while (my @row = $sth->fetchrow_array()) {
        my $name = $row[1].$row[2];
        $name .= $row[3] if $row[3];
        $name .= $row[4] if $row[4];
        $oldname{$name} = $row[0];
	}
    $stmt = "select pid,genus,species,infraspr,infraspe from orchid_species_ipni_xfer";
    getASPM($stmt);
	while (my @row = $sth->fetchrow_array()) {
        my $name = $row[1].$row[2];
        $name .= $row[3] if $row[3];
        $name .= $row[4] if $row[4];
        $oldname{$name} = $row[0];
	}


}

