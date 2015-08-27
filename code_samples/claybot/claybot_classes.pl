#!/usr/bin/perl -w 
#
# 	claybot classes
#
# 		This collection of script will update the database from the textfiles 
# 		generated from the spreadsheets that clay and kevin use. 
# 		(spreadsheet -> database).
#	
#		This script updates the Category, Classes, Subclasses tables in the DB.
#		Also updates BILLTYPES
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
open(CLASSES, "<$DATADIR/CATEGORY INDEX.txt")
	or die "Can't open $DATADIR/CATEGORY INDEX.txt: $!";

# first the column names
my $line = <CLASSES>;
@COLS = split(/\s+/, $line);

print "COLS = " . Dumper(\@COLS);

# Grab a connection the database
my $dbh = DBI->connect('dbi:mysql:XXX', 'XXX', 'XXX', 
	{ RaiseError => 1, AutoCommit => 1 })
		  or die "Can't connect to Mysql server: $!";

# delete what we have in here.
$dbh->do("DELETE FROM CATEGORIES WHERE PUB_ID=$PUB_ID");
$dbh->do("DELETE FROM CLASSES WHERE PUB_ID=$PUB_ID");
$dbh->do("DELETE FROM SUB_CLASSES WHERE PUB_ID=$PUB_ID");
$dbh->do("DELETE FROM BILLTYPES WHERE PUB_ID=$PUB_ID");

# Okay now for the data!
while (<CLASSES>) { 

	next if /^$/;

	chomp;
	s/\r//; # get rid of windows carriage return


	my @TMP_DATA = split(/\t/);	
	print "TMPDATA = " . Dumper(\@TMP_DATA);
	
	for (0..$#TMP_DATA) { 
		$DATA{$COLS[$_]} = $TMP_DATA[$_];
	}

	print "DATA = " . Dumper(\%DATA);
	
	# determine which table based on type
	if ($DATA{TYPE} eq "category") { 
		$TABLE = "CATEGORIES";
	} elsif ($DATA{TYPE} eq "classification") { 
		$TABLE = "CLASSES";
	} elsif ($DATA{TYPE} eq "subclassification") { 
		$TABLE = "SUBCLASSES";
	} else { 
		die "Malformed data for $DATA{IDENTIFIER} for TYPE = $DATA{TYPE}.";
	}

	# remove some stuff from DATA that isn't in the table
	delete $DATA{TYPE};
	delete $DATA{PARENT_TYPE};
	#delete $DATA{CLASSIFICATION_CPINDEX}; # this may be something clay needs YEP IT WAS
	

	# Delete some "
	# for some reason the SAMPLE_AD is always enclosed by quotes.
	# Additionally, any actual quote (") always shows up double ("")
	$DATA{SAMPLE_AD} =~ s/^"(.*)"$/$1/;
	$DATA{SAMPLE_AD} =~ s/""/"/g;

	# build the insert string
	# TODO: This could be taken outside the loop for SPEED
	my $placeholders =  "?, " x (keys %DATA);
	$placeholders =~ s/, $//;

	my $st = "INSERT INTO $TABLE ( " . join(", ", keys %DATA) .
			  "	) VALUES (" . $placeholders . ")";

	print "st = $st\n";
	print "TABLE = $TABLE\n";
	print "DATA = " . Dumper(\%DATA);
	print "\n";

	# insert the row!
	my $sth = $dbh->prepare($st);
	$sth->execute(values %DATA);

	# Now if there is billingtype information we'll need to add that to BILLTYPES
	if ($DATA{BILLING_TYPES}) { 
		
		# initialize data as initial data. initial.
		my %bt_data = ( 
			PUB_ID => $DATA{PUB_ID},
			IDENTIFIER => $DATA{IDENTIFIER},
			BILLING_TYPES => $DATA{BILLING_TYPES},
			CC => 0,
			CHK => 0,
			CASH => 0,
			BILL => 0,
			CHK_BY_PHONE => 0,
			FREE => 0,
			AMEX => 0,
			MC => 0,
			VISA => 0,
			DISC => 0
		);

		# split up the billtypes field
		my @billtypes = split(/\\0/, $DATA{BILLING_TYPES});
		print "billtypes = @billtypes\n";

		# loop through and build the string
		foreach my $bt (@billtypes) { 
			$bt = uc $bt;

			# this is because in the spreadsheets it is Check By Phone
			# and in the database the column is CHK_BY_PHONE
			if ($bt eq 'CHECK BY PHONE') { $bt = 'CHK_BY_PHONE' }
			
			if (exists $bt_data{$bt}) { 
				$bt_data{$bt} = 1;
			}
		}

		$placeholders =  "?, " x (keys %bt_data);
		$placeholders =~ s/, $//;

		my $st = "INSERT INTO BILLTYPES ( " . join(", ", keys %bt_data) .
				  "	) VALUES (" . $placeholders . ")";

		$sth = $dbh->prepare($st);
		$sth->execute(values %bt_data);

		print "BT_DATA = " . Dumper(\%bt_data);
	}
}

