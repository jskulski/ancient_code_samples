#!/usr/bin/perl -w 
#
# 	claybot deadlines
#
# 		This collection of script will update the database from the textfiles 
# 		generated from the spreadsheets that clay and kevin use. 
# 		(spreadsheet -> database).
#	
#		This script updates the deadlines
#
#		Originally this script was written to make clay and kevin's job
#		easier. But it is a good robot. And like all good robots, it will turn 
#		on its masters and replace them, seeing them as inefficient meat bags.
#
#		jsk 2006

use strict;
use DBI;
use Data::Dumper;

my $PUBID = $ARGV[0] || die "You must specify a pub id!\n";

# CONFIG
my $DATADIR = "data/$PUBID";
# END CONFIG

# GLOBALS 
my @COLS; #A
my %DATA; #H 
my $TABLE; 
# END GLOBALS

# Read in the data
open(DEADLINES, "<$DATADIR/DEADLINES.txt")
	or die "Can't open DEADLINES.txt: $!";
my @DEADLINES = <DEADLINES>;
close(DEADLINES) or die "Can't close DEADLINES.txt: $!";

# first the column names
my $line = shift(@DEADLINES);
@COLS = split(/\s+/, $line);

#print "COLS = " . Dumper(\@COLS);

# Grab a connection the database
my $dbh = DBI->connect('dbi:mysql:XXX', 'XXX', 'XXX', 
	{ RaiseError => 1, AutoCommit => 1 })
		  or die "Can't connect to Mysql server: $!";
my $sth;

# delete what we have in here.
$dbh->do("DELETE FROM DEADLINE_PKGS WHERE PUB_ID=$PUBID");
$dbh->do("DELETE FROM DEADLINE_CLASSES WHERE PUB_ID=$PUBID");

# Okay now for the data!
my %used_pkg_codes = (); # PKG_CODES we've already used
foreach (@DEADLINES) { 
	chomp;
	next if /^$/;

	my @TMP_DATA = split(/\t/);	
	
	for (0..$#TMP_DATA) { 
		$DATA{$COLS[$_]} = $TMP_DATA[$_];
	}

	#print "CATS: $DATA{DEADLINE_CATEGORY}\n";
	#print "CLAS: $DATA{DEADLINE_CLASSIFICATION}\n\n";

	# Modify the data!
	$DATA{TIME} =~ s/(\d+):(\d+)/$1$2/; # 17:30 -> 1730
	$DATA{DEADLINE_CLASSIFICATION} =~ s/\\0/\|/g; # change \0 to pipes!
	$DATA{DEADLINE_CLASSIFICATION} =~ s/^|//; # remove beginning pipe.
	$DATA{DEADLINE_CLASSIFICATION} =~ s/|$//; # remove (possible) end pipe!
	$DATA{DEADLINE_CATEGORY} =~ s/\\0/\|/g; # change \0 to pipes!
	$DATA{DEADLINE_CATEGORY} =~ s/^|//; # remove beginning pipe.
	$DATA{DEADLINE_CATEGORY} =~ s/|$//; # remove (possible) end pipe!

	# Create a unique PKG_CODE
	my $pkg_code_id = 0;
	my $pkg_code_id_format;
	do {
		$pkg_code_id++;
		$pkg_code_id_format = sprintf("%03d",$pkg_code_id);
		$DATA{PKG_CODE} = $DATA{TAKE_DAY}."_".$DATA{PUB_START_DAY}.
			"_".$DATA{TIME}."_".$pkg_code_id_format;
	} until (!exists($used_pkg_codes{$DATA{PKG_CODE}}));
	$used_pkg_codes{$DATA{PKG_CODE}} = 1;


	# Find all the classes...
	my @classes = split(/\|/,$DATA{DEADLINE_CLASSIFICATION});
	# ...lookup DEADLINE_CATEGORY and add those classes to the list...
	my @categories = split(/\|/,$DATA{DEADLINE_CATEGORY});

	my $placeholders;


	if ($#categories != -1) {
		$placeholders = "?," x @categories;
		$placeholders =~ s/,$//;
		$sth = $dbh->prepare("SELECT IDENTIFIER FROM CLASSES
			WHERE PARENT_IDENTIFIER IN ($placeholders)");
		#foreach (@categories) {
		#	$sth = $dbh->prepare("SELECT IDENTIFIER FROM CLASSES
		#		WHERE PARENT_IDENTIFIER=?");
		#	$sth->execute($_) or die "Class lookup failed: $!";
		$sth->execute(@categories) or die "Execute failed: $!";

		while (my ($IDENTIFIER) = $sth->fetchrow_array()) {
			#print "GOT: $IDENTIFIER\n";
			push(@classes,$IDENTIFIER);
		}
		$sth->finish();

	} else {
		print "categories: $#categories\n"
	}
	#}
	#print "CLASSES = ".Dumper(\@classes);
	# ...now put all these in DEADLINE_CLASSES...
	foreach (@classes) {
		$sth = $dbh->prepare("INSERT INTO DEADLINE_CLASSES
			(PUB_ID,PARENT_PKG_CODE,CLASS) VALUES (?,?,?)");
		$sth->execute($DATA{PUB_ID},$DATA{PKG_CODE},$_)
			or die "Execute failed $!";
		$sth->finish();
	}
	# ...and get rid of DEADLINE_CLASSIFICATION and DEADLINE_CATEGORY
	#  because they don't go in the database anywhere:
	delete($DATA{DEADLINE_CLASSIFICATION});
	delete($DATA{DEADLINE_CATEGORY});

	# PUB_START_DAY is now just START_DAY:
	$DATA{START_DAY} = $DATA{PUB_START_DAY};
	delete($DATA{PUB_START_DAY});

	# build the insert string
	## "TODO: This could be taken outside the loop for SPEED"
	## Not anymore. Because of the DEADLINE tables being split up
	## this has to be rebuilt everytime. JPJ 20060804
	$placeholders =  "?, " x (keys %DATA);
	$placeholders =~ s/, $//;

	print "INSERT INTO DEADLINE_PKGS ( " . join(", ", keys %DATA) .
	                          "     ) VALUES (" . $placeholders . ")";

	my $st = "INSERT INTO DEADLINE_PKGS ( " . join(", ", keys %DATA) .
			  "	) VALUES (" . $placeholders . ")";

	print "st = $st\n";
	print "DATA = " . Dumper(\%DATA);
	print "\n";

	# insert the row!
	$sth = $dbh->prepare($st);
	$sth->execute(values %DATA);
}

