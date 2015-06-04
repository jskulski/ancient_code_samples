#!/usr/bin/perl -w
#
# claybot_ad_props.pl
#
# Breakup the AD_PROPERTY_TABLES Spreadsheet and put it into the
# table of the same name. This one will pretty much be able to go straight in.
# It just has to break on the |'s in CLASSES and then put them into a
# column called CLASS_ID.

use strict;
use DBI;

my $PUB_ID = $ARGV[0] || '9999';
my $DATADIR = "data/$PUB_ID";

# Start DB connection
my $dbh = DBI->connect('dbi:mysql:XXX', 'XX', 'XXX', 
	{ RaiseError => 1, AutoCommit => 1 })
		  or die "Can't connect to Mysql server: $!";
my $sth;

# open AD_PROPERTY_TABLES.txt (APT)
open(APT,"$DATADIR/AD_PROPERTY_TABLES.txt")
	or die "Couldn't open $DATADIR/AD_PROPERTY_TABLES.txt: $!";

# Put the DB column names in @COLS
my $tmp_cols = <APT>;
chomp($tmp_cols);
my @COLS = split(/\t/,$tmp_cols);


# Before we can INSERT, we must DELETE the old stuff for this pub.
$sth = $dbh->prepare("DELETE FROM AD_PROPERTY_SETS WHERE PUB_ID=?");
$sth->execute($PUB_ID) or die "Delete failed: $!";

# Loop through and get the data
while (<APT>) {
	chomp;
	my @DATA = split(/\t/);

	# Build hash: $PROPS{COL_NAME} = value
	my %PROPS = ();
	for my $i (0 .. $#DATA) {
		#chomp($DATA[$i]);
		$DATA[$i] =~ s/\r\n//g;
		$DATA[$i] =~ s/\n//g;
		$DATA[$i] =~ s/\r//g;

		$DATA[$i] =~ s/^"//;
		$DATA[$i] =~ s/"$//;
		$DATA[$i] =~ s/""/"/g;

		$PROPS{$COLS[$i]} = $DATA[$i];
	}

	my @classes = split(/\|/,$PROPS{CLASSES});
	delete $PROPS{CLASSES};

	foreach my $class (@classes) {
		$PROPS{CLASS_ID} = $class;
		my $ph = ""; # Place Holders (?,?)
		my $cols = "";
		my @vals = ();
		foreach my $col (keys %PROPS) {
			$ph .= "?,";
			$cols .= "$col,";
			push(@vals,$PROPS{$col});
		}
		$ph =~ s/,$//;
		$cols =~ s/,$//;
		
		# INSERT
		print $ph . "\n";
		foreach my $i (@vals) {
			print "$i,";
		}
		eval {
			$sth = $dbh->prepare("INSERT INTO AD_PROPERTY_SETS
				($cols) VALUES ($ph)");
			$sth->execute(@vals);
			$sth->finish();
		};
		if ($@) {
			print "\n\n\n=========================\n";
			print "INSERT FAILED: $@\n\n\n".
				"==========================\n".
				"Insert values dump\n";
				my @inscols = split(/,/,$cols);

				for (my $i = 0; $i<=$#inscols; $i++) {
					print "\t$inscols[$i]\t$vals[$i]\n";
				}
			exit;
		}
	}
}

close(APT) or die "Couldn't close $DATADIR/AD_PROPERTY_TABLES.txt: $!";

$dbh->disconnect();
