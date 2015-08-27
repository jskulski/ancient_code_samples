#!/usr/bin/perl -w 
#
# 	claybot rules
#
# 		This collection of script will update the database from the textfiles 
# 		generated from the spreadsheets that clay and kevin use. 
# 		(spreadsheet -> database).
#	
#		This script updates the rules
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
my $PUB_ID = $ARGV[0] || die "no pub id specified!\n";
my $DATADIR = "data/$PUB_ID";
# END CONFIG

# GLOBALS 
my @COLS; #A
my %DATA; #H 
my $TABLE; 
# END GLOBALS

# Read in the data
open(RULES, "<$DATADIR/RULES.txt")
	or die "Can't open RULES.txt: $!";

# first the column names
my $line = <RULES>;
$line =~ s/RULE_//g;
@COLS = split(/\s+/, $line);

print "COLS = " . Dumper(\@COLS);

# Grab a connection the database
my $dbh = DBI->connect('dbi:mysql:XXX', 'XXX', 'XXX', 
	{ RaiseError => 1, AutoCommit => 1 })
		  or die "Can't connect to Mysql server: $!";

# delete what we have in here.
$dbh->do("DELETE FROM RULES WHERE PUB_ID=$PUB_ID");

# Okay now for the data!
while (<RULES>) { 
	chomp;
	next if /^$/;

	$_ =~ s/\r\n//g;
	$_ =~ s/\r//g;
	$_ =~ s/\n//g;

	my @TMP_DATA = split(/\t/);	
	
	for (0..$#TMP_DATA) { 
		$DATA{$COLS[$_]} = $TMP_DATA[$_];
	}

	# Modify the data
	$DATA{CLASSIFICATION} =~ s/\\0/\|/g; #change \0 to pipes
	if ($DATA{CLASSIFICATION} ne 'Standard') { 
		$DATA{CLASSIFICATION} =~ s/^(.*)$/|$1|/; # cap the pipes!
	}

	$DATA{FALSE} ||= "0";
	$DATA{RULE_ORDER} ||= "1";

	# Why are these freaking slashes getting doubled up?
	$DATA{DESCRIPTION} =~ s/""/"/g;

	$DATA{PUB_ID} = $DATA{PUBLICATION_ID};
	delete($DATA{PUBLICATION_ID});
	$DATA{RULE_ORDER} = $DATA{ORDER};
	delete($DATA{ORDER});

	$DATA{RULE_FALSE} = $DATA{FALSE};
	delete($DATA{FALSE});

	# build the insert string
	# TODO: This could be taken outside the loop for SPEED
	my $placeholders =  "?, " x (keys %DATA);
	$placeholders =~ s/, $//;

	my $st = "INSERT INTO RULES ( " . join(", ", keys %DATA) .
			  "	) VALUES (" . $placeholders . ")";

	print "st = $st\n";
	print "DATA = " . Dumper(\%DATA);
	print "\n";

	# insert the row!
	my $sth = $dbh->prepare($st);
	$sth->execute(values %DATA);
}

