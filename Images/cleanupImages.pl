#use 5.010;
#----------------
#  This script go through image tables (species or hybrid) and performs the following
#   1. Load genus
#	2. Load image tables and check if genus is valid
#	3. Fetch each image from source and put in assigned folder
#	4. Update table set genus id, width, height of each image
use strict;
use warnings qw(all);
use autodie;
use File::Copy;   #Gives you access to the "move" command


require "common.pl";
our ($sth);
my (%img,%src,%nam,%fnm,%genus,%gen);
my $type = $ARGV[0];
my $imgtype;
my $stmt;
my $tab;
my $mediaroot = 'C:/projects/orchids/git/static/utils/images/';
my $mediaroot = '/home/chariya/webapps/static_media/utils/images/';
my $discard_file = $mediaroot."discard_file/";
my $discard_thmb = $mediaroot."discard_thmb/";
my ($image_dir, $thumb_dir);

system( 'mkdir '.$discard_file ) if ( ! -d $discard_file );
system( 'mkdir '.$discard_thmb ) if ( ! -d $discard_thmb );

if ($ARGV[0] eq 'species') {
    $tab = "orchid_spcimages";
    $image_dir = $mediaroot . 'species/';
    $thumb_dir = $mediaroot . 'species_thumb/';
    $type = "spc";

}
elsif ($ARGV[0] eq 'hybrid') {
    $tab = "orchid_hybimages";
    $image_dir = $mediaroot . 'hybrid/';
    $thumb_dir = $mediaroot . 'hybrid_thumb/';
    $type = "hyb";
}

print "Initialize images\n";
my %files = ();
getImages($tab);

# Process files
print "Process image objects\n";
processFiles();

sub processFiles {
    opendir(my $dh, $image_dir) or die "cant open $image_dir : $!\n";
    my $i = 0;
    my @filelist = readdir $dh;
	foreach (@filelist) {
	    next if exists $files{$_};
	    next if $_ !~ /^$type/;
		print $i++."\t$_\n";
		my $from = $image_dir .  $_;
		move $from, $discard_file;
		my $from_tmb = $thumb_dir  . $_;
		move $from_tmb, $discard_thmb;
#        print "move $from_tmb\tto\t$discard_thmb\n"; sleep 1;
	}
	print "Moved $i $ARGV[0] image files to discard folder\n";
}

sub getImages {
#-- Get genus
    my $tab = shift;

    &getASPM("use orchidroots");
	$stmt = "select image_file from $tab;";
	&getASPM($stmt);
   
	while (my @row = $sth->fetchrow_array()) {
    	if ($row[0]) {
#	    	print "$row[0]\n"; sleep 1;
		    $files{$row[0]}++;
		}
	}
}

