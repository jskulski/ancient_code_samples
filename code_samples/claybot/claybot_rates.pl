#!/usr/bin/perl -w
#
# 	claybot rates
#
# 		This collection of script will update the database from the textfiles 
# 		generated from the spreadsheets that clay and kevin use. 
# 		(spreadsheet -> database).
#	
#		This script updates the Package and Upsell tables in the DB.
#
#		Originally this script was written to make clay and kevin's job
#		easier. But it is a good robot. And like all good robots, it will turn 
#		on its masters and replace them, seeing them as inefficient meat bags.
#
#		jsk 2006

use strict; # Eventually...
use DBI;
use Data::Dumper;

# CONFIG
my $PUB_ID = $ARGV[0] || die "You must specify a pub id!\n";
my $DATADIR = "data/$PUB_ID";
## 

# GLOBALS
my @UPSELL_DATA = ();
my @COLS; #A
my @PKG_DATA; #AoH
my @UPELL_DATA; #AoH
my @JPKG_DATA; #AoH
my @JUPELL_DATA; #AoH
my %CLASSES; #HoHoA

my %JPKGS;
my %JUPSELLS;
my @JUPSELL_DATA = ();

#	%*_UPSELLS{RATE_CODE}->[INTERNET,ESC,ESOL,ETC]
my %UPSELLS_INCLUDED = (); # HoA
my %UPSELLS_SELECTED = (); # HoA
my %UPSELLS_REQUIRED = (); # HoA
my %UPSELLS_DISALLOW = (); # HoA

my %UPSELL_CLASSES = (); # HoA
##

## !!! RATES !!! ## 
# Open the rates file.
open(RATES, "<$DATADIR/RATES.txt")
	or die "Can't open RATES.txt: $!";

# Read in the column names (the first line)
my $line = <RATES>;
$line =~ s/\r\n//g;
$line =~ s/\r//g;
$line =~ s/\n//g;
#@COLS = split(/\s+/, $line);
@COLS = split(/\t/, $line);
my $numcols = $#COLS;

# Read in the data into a Array of Hash
while (<RATES>) { 
	next if /^\s+$/;
	#s/\r\n$//;
	#s/\r$//;
	#s/\n$//;
	s/\cM$//;
	chomp;

	my %hash = ();

	my @data = split(/\t/);
	#if ($#data != $numcols) {
		#die "Col mismatch. Started with $numcols, got $#data";
	#}

	for my $i (0..$#data) { 
		$hash{$COLS[$i]} = $data[$i];
		#print "\t$COLS[$i] $data[$i]\n";
	}


	# Remove DAYS_TO_RUN until its worked out.
	#delete $hash{DAYS_TO_RUN};

	# Replace \0 with | to make this easier
	$hash{UPSELLS_INCLUDED} =~ s/\\0/\|/g;
	$hash{UPSELLS_SELECTED} =~ s/\\0/\|/g;
	$hash{UPSELLS_REQUIRED} =~ s/\\0/\|/g;
	$hash{UPSELLS_DISALLOW} =~ s/\\0/\|/g;

	# Build %REQUIRED/UPSELLS_INCLUDED to populate CHECKED in
	# UPSELL_RATES later.
	$UPSELLS_INCLUDED{$hash{RATE_CODE}} = [];
	$UPSELLS_SELECTED{$hash{RATE_CODE}} = [];
	$UPSELLS_REQUIRED{$hash{RATE_CODE}} = [];
	$UPSELLS_DISALLOW{$hash{RATE_CODE}} = [];
	#print "wtf: $hash{UPSELLS_INCLUDED}\n";
	if ($hash{UPSELLS_INCLUDED}) {
		#print "got some: $hash{UPSELLS_INCLUDED}\n";
		my @tmp = split(/\|/,$hash{UPSELLS_INCLUDED});
		$UPSELLS_INCLUDED{$hash{RATE_CODE}} = \@tmp;
	}
	if ($hash{UPSELLS_SELECTED}) {
		my @tmp = split(/\|/,$hash{UPSELLS_SELECTED});
		$UPSELLS_SELECTED{$hash{RATE_CODE}} = \@tmp;
	}
	if ($hash{UPSELLS_REQUIRED}) {
		my @tmp = split(/\|/,$hash{UPSELLS_REQUIRED});
		$UPSELLS_REQUIRED{$hash{RATE_CODE}} = \@tmp;
	}
	if ($hash{UPSELLS_DISALLOW}) {
		my @tmp = split(/\|/,$hash{UPSELLS_DISALLOW});
		$UPSELLS_DISALLOW{$hash{RATE_CODE}} = \@tmp;
	}

	# Now remove the *_UPSELLS because they don't go in the DB
	delete $hash{UPSELLS_INCLUDED};
	delete $hash{UPSELLS_SELECTED};
	delete $hash{UPSELLS_REQUIRED};
	delete $hash{UPSELLS_DISALLOW};

	# Get it in the correct hash
	if ($hash{'TYPE'} eq 'upsell' || $hash{'TYPE'} eq 'cpupsell' || $hash{TYPE} eq 'xsell' || $hash{TYPE} eq 'blindbox' || $hash{TYPE} eq 'logo') {
		push @UPSELL_DATA, \%hash;
		$JUPSELLS{$hash{RATE_CODE}} = \%hash;
		my @tmp_classifications =
			split(/\|/,$hash{CLASSIFICATION});

		# Sanity. Remove duplicate entries from this array.
		my %undup = ();
		foreach (@tmp_classifications) {
			$undup{$_} = 1;
		}
		@tmp_classifications = (keys %undup);

		$UPSELL_CLASSES{$hash{RATE_CODE}} = \@tmp_classifications;
	} else { 
		delete $hash{XSELL_CLASS};
		delete $hash{DAYS_TO_RUN};
		push @PKG_DATA, \%hash;
		$JPKGS{$hash{RATE_CODE}} = \%hash;
	}

}

print "UPSELL_CLASSES: ".Dumper(\%UPSELL_CLASSES);

close(RATES) or die "Couldn't close $DATADIR/RATES.txt $!";

foreach my $pkg_rate_code (keys %UPSELLS_INCLUDED) {
	foreach my $upsell_rate_code (@{$UPSELLS_INCLUDED{$pkg_rate_code}}) {
		my %tmp_pkg = ();
		eval {
			%tmp_pkg = %{$JUPSELLS{$upsell_rate_code}};
		};
		if ($@) {
			#print "wtf\n";
			#exit;
			die "Bad shit went down. RATE_CODE was ".
			"\"$upsell_rate_code\": $@\n".
			"This error is probably because there is no ".
			"RATE_CODE for $upsell_rate_code";
		}
		#print "$JPKGS{$upsell_rate_code}\n";
		#print $upsell_rate_code."\n";\
		$tmp_pkg{RATE_CODE} = $upsell_rate_code;
		$tmp_pkg{PARENT_ID} = $pkg_rate_code;
		$tmp_pkg{CHECKED} = 0;
		push(@JUPSELL_DATA,\%tmp_pkg);
	}
}
foreach my $pkg_rate_code (keys %UPSELLS_SELECTED) {
	foreach my $upsell_rate_code (@{$UPSELLS_SELECTED{$pkg_rate_code}}) {
		my %tmp_pkg = ();

		eval {
			%tmp_pkg = %{$JUPSELLS{$upsell_rate_code}};
		};
		
		if ($@) {
			die "Couldn't use '$upsell_rate_code' on JUPSELLS (\$pkg_rate_code: '$pkg_rate_code')";
		}


		$tmp_pkg{PARENT_ID} = $pkg_rate_code;
		$tmp_pkg{CHECKED} = 1;
		push(@JUPSELL_DATA,\%tmp_pkg);
	}
}
foreach my $pkg_rate_code (keys %UPSELLS_REQUIRED) {
	foreach my $upsell_rate_code (@{$UPSELLS_REQUIRED{$pkg_rate_code}}) {
		my %tmp_pkg = ();
		eval {
			%tmp_pkg = %{$JUPSELLS{$upsell_rate_code}};
		};
		if ($@) {
			die "Bad shit went down. RATE_CODE was ".
			"\"$upsell_rate_code\": $@\n".
			"This error is probably because there is no ".
			"RATE_CODE for $upsell_rate_code";
		}
		$tmp_pkg{PARENT_ID} = $pkg_rate_code;
		$tmp_pkg{CHECKED} = 2;
		push(@JUPSELL_DATA,\%tmp_pkg);
	}
}
foreach my $pkg_rate_code (keys %UPSELLS_DISALLOW) {
	foreach my $upsell_rate_code (@{$UPSELLS_DISALLOW{$pkg_rate_code}}) {
		my %tmp_pkg = ();
		eval {
			%tmp_pkg = %{$JUPSELLS{$upsell_rate_code}};
		};
		if ($@) {
			die "Bad shit went down. RATE_CODE was ".
			"\"$upsell_rate_code\": $@\n".
			"This error is probably because there is no ".
			"RATE_CODE for $upsell_rate_code";
		}
		$tmp_pkg{PARENT_ID} = $pkg_rate_code;
		$tmp_pkg{CHECKED} = 3;
		push(@JUPSELL_DATA,\%tmp_pkg);
	}
}


# get connection to the database 
my $dbh = DBI->connect('dbi:mysql:XXX', 'XXX', 'XXX', 
	{ RaiseError => 1, AutoCommit => 1 })
		  or die "Can't connect to Mysql server: $!";

my $sth; # Declare now. We'll be using it a lot

# DELETE everything for this pub first.
$dbh->do("DELETE FROM PKG_RATES WHERE PUB_ID=$PUB_ID");
$dbh->do("DELETE FROM PKG_CLASSES WHERE PUB_ID=$PUB_ID");
#$dbh->do("DELETE FROM PKG_EXCLUDED_CLASSES WHERE PUB_ID=$PUB_ID");

#print "PKG_DATA: ".Dumper(\@PKG_DATA);

foreach (@PKG_DATA) { 
	my %rate = %$_;
	#print Dumper(\%rate);
	

	$rate{PUB_ID} = $rate{PUBLICATION_ID};
	delete($rate{PUBLICATION_ID});

	my $code = $rate{'RATE_CODE'};
	my $pub_id = $rate{'PUB_ID'};

	# CLASSIFICATION,DAY_CALCULATIONS no longer exists
	# in PKG_RATES. JPJ 20060807
	#
	# Shoot, we need this one for later, but still have to get ride of
	# it if the record is to be built correctly.
	#delete $rate{CLASSIFICATION};
	my $pkg_classifications = $rate{CLASSIFICATION};
	delete $rate{CLASSIFICATION};
	#delete $rate{DAY_CALCULATIONS};

	my $placeholders = "?, " x (keys %rate);
	$placeholders =~ s/, $//;

	# Insert the Rate data into pkg_rates
	my $st = "INSERT INTO PKG_RATES (" . join(", ", keys %rate) . 
		   ") VALUES (" . $placeholders . ")";

	#print "SQL: $st\n";

	$sth = $dbh->prepare($st);
			   
	my $counter = 0;

	#print Dumper(\%rate);

	foreach my $val (values %rate) { 
		$counter++;
		$sth->bind_param($counter, $val);
	}


	print "$st\n";

	$sth->execute();

	# insert a row in PKG_CLASSES to relate classes and upsells
	my @yes_classes;
	my @no_classes;
	#@classes = split(/\\0/, $rate{CLASSIFICATION});
	my @classes = split(/\\0/, $pkg_classifications);

	# if the CLASSIFICATION was blank, then use 0 so that it applies to ALL classifications
	if (!@classes) { @yes_classes = ( '0' ) };

	# clay has this thing where he lists categories, classes and subclasses in SPECIFIC ways
	foreach my $class (@classes) { 
		if ($class =~ /^!(\d+)/) { 
			# !57 means exclude 57
			push @no_classes, $1;
		} elsif ($class =~ /(\d+):(\d+)/) {  
			# 204:206 means 204, 205, 206
			(push @yes_classes, $_) foreach ($1 .. $2); 
		} else { 
			push @yes_classes, $class; 
		} #else just pop it in the inclusive list.
	}

	#print "$code {\n"; 
	#print "Inc: " . Dumper(\@yes_classes) . "\n";
	#print "Exc: " . Dumper(\@no_classes) . "\n";
	#print "} \n";

	 #add a row for each inclusive upsell
	foreach my $class (@yes_classes) { 
		my @tmp_classes = split(/\|/,$class);
		foreach (@tmp_classes) {
			$sth = $dbh->prepare("INSERT INTO PKG_CLASSES (PUB_ID, IDENTIFIER, CLASS_CODE) VALUES (?,?,?)");
			#$sth->execute($pub_id,$code,$class);
			$sth->execute($pub_id,$code,$_);
			$sth->finish();
		}
	}

	# add a row for each exclusive upsell
	#foreach my $class (@no_classes) { 
	#	$sth = $dbh->prepare("INSERT INTO PKG_EXCLUDED_CLASSES (PUB, ID, CLASS) VALUES (?,?,?)");
	#	$sth->execute($pub_id,$code,$class);
	#	$sth->finish();
	#}
}

# UPSELLS
$dbh->do("DELETE FROM UPSELL_RATES WHERE PUB_ID=$PUB_ID");
$dbh->do("DELETE FROM UPSELL_CLASSES WHERE PUB_ID=$PUB_ID");
#$dbh->do("DELETE FROM UPSELL_EXCLUDED_CLASSES WHERE PUB=$PUB_ID");

print "JUPSELL_DATA: ".Dumper(\@JUPSELL_DATA);

foreach (@JUPSELL_DATA) {
	next if /^\s+$/;
	chomp;
	s/\r\n//;
	s/\r//;
	my %tmp_rate = %$_;

	my @upsell_classes = split(/\|/,$tmp_rate{CLASSIFICATION});
	if (!@upsell_classes) {
		@upsell_classes = (0);
	}

	delete $tmp_rate{DAY_CALCULATIONS};
	delete $tmp_rate{LINE_CALCULATIONS};
	delete $tmp_rate{APPLIES_TO};
	delete $tmp_rate{AGATE};
	delete $tmp_rate{CLASSIFICATION};
	#delete $tmp_rate{PUB_NAME};
	delete $tmp_rate{UPSELL_LIST_CODE};

	$tmp_rate{ADDS_LINES} = $tmp_rate{UPSELL_ADDS_LINES};
	delete($tmp_rate{UPSELL_ADDS_LINES});

	$tmp_rate{PUB_ID} = $tmp_rate{PUBLICATION_ID};
	delete($tmp_rate{PUBLICATION_ID});

	#my $placeholders = "?, " x (keys %tmp_rate);
	my $placeholders = "";
	my $cols = "";
	my @bind_vals = ();
	foreach my $key (keys %tmp_rate) { 
		#print "\"$key\": \"$tmp_rate{$key}\"\n";
		$placeholders .= "?,";
		$cols .= "$key,";
		push(@bind_vals,$tmp_rate{$key});
	}
	$placeholders =~ s/,$//;
	$cols =~ s/,$//;

	my $sql = "INSERT INTO UPSELL_RATES ($cols) VALUES($placeholders)";

	print "$sql\n";
	print Dumper(\@bind_vals);

	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_vals);
	$sth->finish();
}

foreach my $upsell_rate_code (keys %UPSELL_CLASSES) {
	foreach my $class (@{$UPSELL_CLASSES{$upsell_rate_code}}) {
		$sth = $dbh->prepare("INSERT INTO UPSELL_CLASSES
			(PUB_ID,RATE_CODE,CLASS_CODE) VALUES (?,?,?)");
		$sth->execute($PUB_ID,$upsell_rate_code,$class);
		$sth->finish();
	}
}

print "Done\n";
exit;



#foreach (@UPSELL_DATA) { 
#
#	next if /^$/;
#
#	chomp;
#	s/\r//; # get rid of windows carriage return
#	
#	%rate = %$_;
#	#print Dumper(\%rate);
#
#	$TABLE='UPSELL_RATES';
#
#	$applies_to = $rate{'APPLIES_TO'};
#	$code = $rate{'RATE_CODE'};
#	$pub_id = $rate{'PUBLICATION_ID'};
#
#	#my $upsells_included = $rate{UPSELLS_INCLUDED};
#	my $upsells_required = $rate{UPSELLS_REQUIRED};
#	my $rate_classification = $rate{CLASSIFICATION};
#
#	delete $rate{DAY_CALCULATIONS};
#	delete $rate{LINE_CALCULATIONS};
#	delete $rate{APPLIES_TO};
#	delete $rate{AGATE};
#	delete $rate{CLASSIFICATION};
#	delete $rate{PUB_NAME};
#
#	# It's a mimic, we'll have to build the pipe delimited string to break apart.
#	# I forget what this is about (this is older code), ask clay.
#	if ($applies_to eq "mimic") { 
#		my @parent_arr = ();
#
##		my $sth_mimic = $dbh->prepare("	SELECT RATE_CODE FROM PKG_RATES
##										WHERE PUBLICATION_ID=? AND 
##										(UPSELLS_INCLUDED LIKE ? OR
##										 UPSELLS_INCLUDED LIKE ? OR 
##										 UPSELLS_INCLUDED LIKE ? OR
##										 UPSELLS_INCLUDED=?)");
##
##		$sth_mimic->bind_param(1, $rate{PUBLICATION_ID});
##		$sth_mimic->bind_param(2, "%|$code|%");
##		$sth_mimic->bind_param(3, "%|$code");
##		$sth_mimic->bind_param(4, "$code|%");
##		$sth_mimic->bind_param(5, "$code");
##
##		$sth_mimic->execute();
#
#		#while (my $parent = $sth_mimic->fetchrow_array()) { 
#		#	push @parent_arr, $parent;
#		#}
#
#		foreach my $key (keys %UPSELLS_INCLUDED) {
#			foreach my $ae (@{$UPSELLS_INCLUDED{$key}}) {
#				if ($ae eq $code) {
#					#push @parent_arr, $parent;
#					push @parent_arr, $key;
#				}
#			}
#		}
#
#		$applies_to = join '\0', @parent_arr;
#
#		#$sth_mimic->finish();
#
#		#print "Built mimic str: $applies_to";
#	}
#
#	@parents = split(/\\0/, $applies_to);
#
#	# if there aren't any parents, then we'll create an empty array 
#	# this will insert one row with an empty parent_id field 
#	if (! @parents) { 
#		@parents = ( '' ); 
#	}
#
#	#print "parents = " . Dumper(\@parents);
#		
#	# insert an upsell row for each $parent_id
#	foreach $parent (@parents) { 
#		$rate{'PARENT_ID'} = $parent;
#
#		#if ($#{$UPSELLS_REQUIRED{$rate{PARENT_ID}}} > -1) {
#		#	$rate{CHECKED} = 2;
#		#} elsif ($#{$UPSELLS_INCLUDED{$rate{PARENT_ID}}} > -1) {
#		#	$rate{CHECKED} = 1;
#		#} else {
#		#	$rate{CHECKED} = 0;
#		#}
#
#		#my @wtf = ();
#		#foreach (@{$UPSELLS_REQUIRED{$rate{RATE_CODE}}}) {
#			
#		#@{$UPSELLS_INCLUDED{$rate{PARENT_ID}}});
#	
#		$placeholders = "?, " x (keys %rate);
#		$placeholders =~ s/, $//;
#
#		$st = "INSERT INTO $TABLE (" . join(", ", keys %rate) . 
#		   ") VALUES (" . $placeholders . ")";
#
#		$sth = $dbh->prepare($st);
#				   
#		$counter = 0;
#
#		#print Dumper(\%rate);
#
#		foreach $val (values %rate) { 
#			$counter++;
#			$sth->bind_param($counter, $val);
#		}
#
#		$sth->execute();
#	}
#
#	# insert a row in UPSELL_CLASSES to relate classes and upsells
#	my @yes_classes;
#	my @no_classes;
#	#@classes = split(/\\0/, $rate{CLASSIFICATION});
#	@classes = split(/\\0/, $rate_classification);
#
#	# if the CLASSIFICATION was blank, then use 0 so that it applies to ALL classifications
#	if (!@classes) { @yes_classes = ( '0' ) };
#
#	# clay has this thing where he lists categories, classes and subclasses in SPECIFIC ways
#	foreach $class (@classes) { 
#		if ($class =~ /^!(\d+)/) { 
#			# !57 means exclude 57
#			push @no_classes, $1;
#		} elsif ($class =~ /(\d+):(\d+)/) {  
#			# 204:206 means 204, 205, 206
#			(push @yes_classes, $_) foreach ($1 .. $2); 
#		} else { 
#			push @yes_classes, $class; 
#		} #else just pop it in the inclusive list.
#	}
#
#	#print "$code {\n"; 
#	#print "Inc: " . Dumper(\@yes_classes) . "\n";
#	#print "Exc: " . Dumper(\@no_classes) . "\n";
#	#print "} \n";
#
#	# add a row for each inclusive upsell
#	foreach $class (@yes_classes) { 
#		$dbh->do("INSERT INTO UPSELL_CLASSES (PUB, ID, CLASS) VALUES ($pub_id, \'$code\', $class)");
#	}
#
#	# add a row for each exclusive upsell
#	foreach $class (@no_classes) { 
#		$dbh->do("INSERT INTO UPSELL_EXCLUDED_CLASSES (PUB, ID, CLASS) VALUES ($pub_id, \'$code\', $class)");
#	}
#}
#
