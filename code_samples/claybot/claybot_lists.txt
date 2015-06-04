#!/usr/bin/perl -w 
#
# 	claybot lists
#
# 		This collection of script will update the database from the textfiles 
# 		generated from the spreadsheets that clay and kevin use. 
# 		(spreadsheet -> database).
#	
#		This script updates the lists
#
#		Originally this script was written to make clay and kevin's job
#		easier. But it is a good robot. And like all good robots, it will turn 
#		on its masters and replace them, seeing them as inefficient meat bags.
#
#		jsk 2006

use strict;
use DBI;
use Data::Dumper;

# CONFIG
my $PUB_ID = $ARGV[0] || die "You must specify a pub id!\n";
my $DATADIR = "data/$PUB_ID";
# END CONFIG

# GLOBALS 
my @COLS; #A
my %DATA; #H 
my $TABLE; 
# END GLOBALS

# Read in the data
open(LISTS, "<$DATADIR/LISTS.txt")
	or die "Can't open LISTS.txt: $!";

# first the column names
my $line = <LISTS>;
@COLS = split(/\s+/, $line);

print "COLS = " . Dumper(\@COLS);

# Grab a connection the database
my $dbh = DBI->connect('dbi:mysql:XXX', 'XXX', 'XXX', 
	{ RaiseError => 1, AutoCommit => 1 })
		  or die "Can't connect to Mysql server: $!";

# TODO: get pub_id
# delete what we have in here.
$dbh->do("DELETE FROM LISTS WHERE PUB_ID=$PUB_ID");

# Okay now for the data!
while (<LISTS>) { 
	chomp;
	next if /^$/;

	my @TMP_DATA = split(/\t/);	
	
	for (0..$#TMP_DATA) { 
		$DATA{$COLS[$_]} = $TMP_DATA[$_];
	}

	# build the insert string
	# TODO: This could be taken outside the loop for SPEED
	my $placeholders =  "?, " x (keys %DATA);
	$placeholders =~ s/, $//;

	my $st = "INSERT INTO LISTS ( " . join(", ", keys %DATA) .
			  "	) VALUES (" . $placeholders . ")";

	print "st = $st\n";
	print "DATA = " . Dumper(\%DATA);
	print "\n";

	# insert the row!
	my $sth = $dbh->prepare($st);
	$sth->execute(values %DATA);
}

