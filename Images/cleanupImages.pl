#use 5.010;
#----------------
#  This script go through image tables (species or hybrid) and performs the following
#   1. Load genus
#	2. Load image tables and check if genus is valid
#	3. Fetch each image from source and put in assigned folder
#	4. Update table set genus id, width, height of each image
use strict;
use warnings qw(all);
# use autodie;
use File::Copy;   #Gives you access to the "move" command
use DBI;
# use DBD::ODBC;

# require "common.pl";
my ($sth);
my $stmt;
my $mediaroot = 'C:/projects/orchids/orchidproject/static/utils/images/';
   $mediaroot = '/home/chariya/webapps/static_media/utils/images/';
my $discard_file = $mediaroot."discard_file/";

system( 'mkdir '.$discard_file ) if ( ! -d $discard_file );

# Database connection
my $dbh = DBI->connect( "DBI:mysql:orchidroots","chariya","imh3r3r3") or die( "Could not connect to: $DBI::errstr" );
my $DB = "orchidroots";
&getASPM("use $DB");

my @type = ("species","hybrid");
my %type = (species=>"spc", hybrid=>"hyb");
my %tab  = (species=>"orchiddb_spcimages", hybrid=>"orchiddb_hybimages");
my %files = ();

foreach my $type (@type) {
	print "Initialize images\n";
	%files = ();
	getImages($tab{$type});

	# Process files
	print "Process image objects\n";
	processFiles($type);

}

sub processFiles {
	my $type = shift;
	my $image_dir = $mediaroot . $type . '/';

    opendir(my $dh, $image_dir) or die "cant open $image_dir : $!\n";
	print "image dir = $image_dir\n";
    my $i = 0;
    my @filelist = readdir $dh;
	foreach (@filelist) {
	    next if exists $files{$_};
	    next if $_ !~ /^$type{$type}/;
		print $i++."\t$_\n";
		my $from = $image_dir .  $_;
		move $from, $discard_file;
	}
	print "\n\tMoved $i $type image files to discard folder\n";
}

sub getImages {
#-- Get genus
    my $tab = shift;

    &getASPM("use orchidroots");
	$stmt = "select image_file from $tab;";
	&getASPM($stmt);
   
	while (my @row = $sth->fetchrow_array()) {
    	if ($row[0]) {
		    $files{$row[0]}++;
		}
	}
}

sub getASPM {
	my $stmt = shift;
	$sth = $dbh->prepare( $stmt ) or die( "\n$stmt\nCannot prepare: ", $dbh->errstr(), "\n" );
	my $rc = $sth->execute() or die("\nDead! \n$stmt\nCannot execute: ", $sth->errstr(),"\n" );
}
