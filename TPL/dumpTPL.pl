#!C:/Perl/bin Perl
#use 5.010;
#------
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
my $url  = "http://www.theplantlist.org/1.1/browse/A/Orchidaceae/";
my $mech = WWW::Mechanize->new;
$mech->get($url);

require "common.pl";
our ($sth);
#my ($status, $lifeform, $distribution, $family, $count);

# Directorues
# my $inputdir = "data/input/";
my $resdir = "data/results/";

my %genus = {};
getExistingGenus();

submitForm();

sub submitForm {
    my $debug = 0;
    my $count = 0;
    my ($genus, $genstatus, $gentype) = ('', '', '');
    my $Con = $mech->content;
    my (@lines) = split(/\n/, $Con);
    open GEN, ">:utf8", $resdir . "genus.dat" or die "Cant open genus.dat: $!\n";
    print GEN "genus\tstatus\ttype\n";
    open SPC, ">:utf8", $resdir . "species.dat" or die "Cant open species.dat: $!\n";
    print SPC "pid\torg\tgenus\tspecies\tinfraspr\tinfraspe\tauthor\tstatus\ttype\n";
    open SYN, ">:utf8", $resdir . "synonym.dat" or die "Cant open synonym.dat: $!\n";
    print SYN "spid\taccid\n";
    print "1) Looping over genus list\n";
    for (my $i = 0; $i < scalar @lines; $i++) {
        if ($lines[$i] =~ /browse\/A\/Orchidaceae\/\b([A-Za-z]+)\b\/.*\b([A-za-z ]+)\b genus.*\1/) {
            $genus = $1;
            next if $genus{$genus};
            next if $genus ne "Orchis" and $debug;
            $genstatus = $2;
            $gentype = "species";
            if ($lines[$i] =~ /×/) {
                # print "$i\tHYBRID\t$genus\t$status\n";
                $gentype = "hybrid";
            }
            print GEN "$genus\t$genstatus\t$gentype\n" if !$debug;

            # Now go to individual genus page
            # $genus = "Ophrys";
            my $genusurl = $url . "$genus\/";
            sleep int(rand(5));
            $mech->get($genusurl);
            $Con = $mech->content;
            my (@species) = split(/\n/, $Con);
            print "Total #lines for genus $genus = " . scalar(@species) . "\n" if $debug;
            my $j = 0;
            my ($species, $org, $pid, $author, $status, $type) = ('', '', '', '', '');
            while (1) {
                # print "$j\t$species[$j]\n";
                if ($species[$j] =~ /class=\"name \b([A-Za-z-]+)\b/) {
                    print "\n";
                    $status = $1;
                    print "status = $status\n" if $debug;
                    "a" =~ /a/;
                    $j++;
                    $species[$j] =~ /.*record\/\b([a-z]+)\b\-(\d+)\"/;
                    $org = $1;
                    $pid = $2;
                    print "Org = $org\n" if $debug;
                    print "pid = $pid\n" if $debug;
                    $j++;
                    "a" =~ /a/;
                    if ($species[$j] =~ /.*class=\"species\">\b([\w]+)\b/) {
                        $species = $1;
                    }
                    $type = "species";
                    if ($species[$j] =~ /×/) {
                        $type = "hybrid";
                    }
                    print "species = $species\n" if $debug;;
                    "a" =~ /a/;
                    $species[$j] =~ /.*class=\"authorship\">([^<]+)</;
                    $author = $1;
                    print "author = $author\n" if $debug;

                    $j++;
                    "a" =~ /a/;

                    # print "$pid\t$org\t$genus $species\t$author\t$status\t$type\n";
                    print "$pid\t$genus\t$species\n";
                    print SPC "$pid\t$org\t$genus\t$species\t\t\t$author\t$status\t$type\n" if !$debug;

                    # Now, go look for synonym
                    getSynonym($org,$pid,0);
                }
                last if $j++ == scalar(@species) - 1;
                # sleep 5;
            }
        }
    }
}

sub getSynonym {
    my ($org,$pid,$debug) = @_;
    my $synurl = "http://www.theplantlist.org/tpl1.1/record/$org-$pid";
    $mech->get($synurl);
    my $Con = $mech->content;
    my (@sspecies) = split(/\n/, $Con);
    my ($sspecies, $sgenus, $sorg, $spid, $sauthor, $sstatus, $stype, $sinfraspr, $sinfraspe) = ('', '', '', '', '', '', '', '', '');
    for (my $k = 0; $k < scalar(@sspecies)-1; $k++) {
        "a" =~ /a/;
        if ($sspecies[$k] =~ /record\/([a-z]+)\-(\d+)\'/) {
            $sorg = $1;
            $spid = $2;
            $sstatus = 'synonym';
            print "\t$k\t$sspecies[$k]" if $debug;
            "a" =~ /a/;
            if ($sspecies[$k] =~ /class=\"genus\">\b([\w-]+)\b</) {
                $sgenus = $1;
            }
            "a" =~ /a/;
            if ($sspecies[$k] =~ /class=\"species\">\b([a-z-]+)\b</) {
                $sspecies = $1;
            }
            "a" =~ /a/;
            if ($sspecies[$k] =~ /class=\"authorship\">([^<]+)</) {
                $sauthor = $1;
            }
            "a" =~ /a/;
            if ($sspecies[$k] =~ /class=\"infraspr\">([\w]+\.)<.+ class=\"infraspe\">([^<]+)</) {
                $sinfraspr = $1;
                $sinfraspe = $2;
            }
            "a" =~ /a/;
            if ($sspecies[$k] =~ /class=\"genushybrid\"/ or $sspecies[$k] =~ /class=\"specieshybrid\"/) {
                $stype = "hybrid";
            }
            else {
                $stype = "species";
            }
            print "\t$spid\t$pid\t$sorg\t$sgenus\t$sspecies\t$sinfraspr\t$sinfraspe\t$sauthor\t$sstatus\t$stype\n";
            print SPC "$spid\t$sorg\t$sgenus\t$sspecies\t$sinfraspr\t$sinfraspe\t$sauthor\t$sstatus\t$stype\n" if !$debug;
            print SYN "$spid\t$pid\n" if !$debug;
        }
    }
}


sub getExistingGenus {
    my $stmt = "select genus from source_TPL_genus";
    getASPM($stmt);
    while (my @row = $sth->fetchrow_array()) {
        $genus{$row[0]}++;
    }
}