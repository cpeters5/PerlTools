#!c:\perl\bin\perl.exe
# Program to query a database and display the contents in a table

use warnings;
#use strict;
use DBI;
use DBD::ODBC;
#use DB_File;
use Carp;

	#my $dbh = DBI->connect( "DBI:ODBC:MySQL") or die( "Could not connect to: $DBI::errstr" );		#BlueNanta
	my $dbh = DBI->connect( "DBI:ODBC:Bluenanta") or die( "Could not connect to: $DBI::errstr" );		#local
our ($stf,$sth, $rc, $sth1, $sth2, %cent);
	$DB = "orchidroots";
	&getASPM("use $DB");
	print ("Database: $DB\n");

sub getASPM {
	my $stmt = shift;
	$sth = $dbh->prepare( $stmt ) or die( "\n$stmt\nCannot prepare: ", $dbh->errstr(), "\n" );
	$rc = $sth->execute() or die("\nDead! \n$stmt\nCannot execute: ", $sth->errstr(),"\n" );
}
sub getASPM1 {
	my $stmt = shift;
	$sth1 = $dbh->prepare( $stmt ) or die( "\n$stmt\nCannot prepare: ", $dbh->errstr(), "\n" );
	$rc = $sth1->execute() or die("\nDead! \n$stmt\nCannot execute: ", $sth1->errstr(),"\n" );
}
sub getASPM2 {
	my $stmt = shift;
	print "$stmt\n";
	$sth2 = $dbh->prepare( $stmt ) or die( "\n$stmt\nCannot prepare: ", $dbh->errstr(), "\n" );
	$rc = $sth2->execute() or die("\nDead! \n$stmt\nCannot execute: ", $sth2->errstr(),"\n" );
}

1
