#!/usr/bin/perl -w
#
# aimgraph.pl
#
# 1/27/2005
#
# This script counts the number of lines conversed with your aimbuddies
# and then using Imager::Plot constructs a graph and writes a
# webpage using these statistics, assigning ranks to each buddy. 
#
# Silly? Yes. Useful? No. Fun? Absolutely
#
use strict;

use lib qw(blib/lib blib/arch);

use Imager;
use Imager::Plot;
# -- MAIN

sub logread();
sub blistread();
sub by_number();
sub buildgraph(@);
sub output(@);
	       
my $LOGDIR = "/home/jskulski/.gaim/logs";
my $BLIST = "/home/jskulski/.gaim/ENCHANTOBOT.0.blist";
my $HTML = "/home/jskulski/public_html/aimgraph.html";
my $PNG = "/home/jskulski/public_html/aimgraph.png";

my (@sortedkeys,@out);
my (%files);

Imager::Font->priorities(qw(w32 ft2 tt t1));


%files = blistread();
@sortedkeys = sort by_number keys(%files);

buildgraph(@sortedkeys);
output(@sortedkeys);


# logread constructs the list of buddies from the files in the log directory. 
#sub logread () {
#    my (%files,$size,$name);
#
#    print "from the logs\n";
#    
#    chdir($LOGDIR);
#
#    foreach (<*.log>) { 
#		$size = `grep -cv "New Conversation" $_`;
#		chomp $size;
#		$name = `head -1 $_`;
#		$name =~ s/^.*with //;
#		chomp $name;
#		$files{$name} = $size - 1;
#    }
#    return %files;
#}


# blistread constructs the list of buddies to rank from the buddylist file
# TODO # this will only count those on your buddy list, not everyone 
# you have talked to. logread is still in progress
sub blistread () {

    my (%files,$formed,$size);

    open(BLIST, "<$BLIST") or die "Buddy List Error: $!\n";

    chdir($LOGDIR);

    # For each Buddy Logged, count how many lines 
    # *NOT INCLUDING* New: Conversation lines
    while (<BLIST>)
    {
		next if !/^b/;
		s/b //;
		chomp;
		$formed = $_;
		tr/A-Z/a-z/;
		s/ //;
		if ( -e "$_.log") { 
			 $size = `grep -cv "New Conversation" $_.log`;
			 chomp $size;
			 $files{$formed} = $size - 1; 
		}	
    }
	 close BLIST or die "Buddy List Error: $!\n";
    return %files;
}

# helper function to sort by lines instead of name
sub by_number () {
    if ( $files{$a} < $files{$b} ) { return 1; }
    elsif ( $files{$a} == $files{$b} ) { return 0; }
    else { return -1; }
}

# use Imager::Plot to build a graph of lines per buddy 

sub buildgraph(@) {

	my (@X, @Y, @TEMP, $max, $img);
	
	# X is lines
	# Y is going to be each name
	@X = 1..@_;
	@Y = ($files{$_},@Y) foreach @_;
	@TEMP = reverse @_;
	$max = $Y[-1];

	chdir("/home/jskulski/src/perl");

	# define look of graph
	my %opts = (size=>10, color=>Imager::Color->new('black'));
	my $font = Imager::Font->new(file=>"font.ttf", %opts);
	my $plot = Imager::Plot->new(Width => 500, Height => 300, GlobalFont => $font);
	my $axis = $plot->GetAxis(); 

	# define X and Y
	$axis->AddDataSet(X => \@Y, Y => \@X, 
		style => {code=>{ref=>\&bar_style,opts=>undef}});
	
	$axis->{Border} = "blrt";
	$axis->{YgridNum} = 16;
	$axis->{XgridNum} = 8;
	$axis->{BackGround} = "#cccccc";

	$plot->{'Xlabel'} = 'Lines';
	$axis->{make_yrange} = sub {
		my	$self = shift;
		$self->{YRANGE} = [0,17];
	};

	$axis->{make_xrange} = sub { 
		my $self = shift;
		$self->{XRANGE} = [0,$max*1.2];
	};
	
	$axis->{Yformat} = sub {
		my $n = shift;
		return $TEMP[$n-1];
	};

	
	# create the Image PNG in memory
	$img = Imager->new(xsize=>650, ysize => 350);
	$img->box(filled=>1, color=>"white");

	$axis->Render(Xoff=>125, Yoff=>300, Image=>$img);

	# write the image
	$img->write(file=>$PNG) or die $img->errstr;
}


# Defines the look of the bars in the graph (red long bars)
# see CPAN for info
sub bar_style {
  my ($DataSet, $xr, $yr, $Xmapper, $Ymapper, $img, $opts) = @_;

  my @x = @$xr;
  my @y = @$yr;
  for (0..$#x) {
    $img->box(color=>'red', ymin=>$y[$_]-6, ymax=>$y[$_]+5, xmin=>125, xmax=>$x[$_], filled=>1);
    $img->box(color=>'black', ymin=>$y[$_]-6, ymax=>$y[$_]+5, xmin=>125, xmax=>$x[$_], filled=>0);
  }

}

# Prints out the HTML output file to $HTML (defined above)
sub output(@) {
	
	open(BLIST, ">$BLIST") or die "Can't open buddylist file: $!\n";
	open(HTML,">$HTML") or die "Can't open HTML file: $!\n";

	# weird log magic number thinger (in progress)
	print BLIST "m 4\ng >\n";
	print HTML <<EOF;

<html>
<head>
<link rel="stylesheet" type="text/css" href="styles.css" />	
<title>conversation statistics</title>
</head>	
<body>

<!--#include virtual="header.html"-->

<div class="contentbox">		
<div class="box">&nbsp;</div>
<div class="heading">Aim Olympics</div>
<center>
<img class="aimgraph" src="aimgraph.png">

<div class="heading">Standings</div></center>
<ol class="aimrank">

EOF
	
	foreach (@_) {
		print HTML "<li class=\"aimli1\">$_ -> $files{$_} lines </li>\n";
		print BLIST "b $_\n";
	}	

	print BLIST "b enchantobot\n";
	print HTML <<EOF;

</ol>
Last Updated: <!--#flastmod file="\$DOCUMENT_NAME"-->
</div>

<!--#include virtual="footer.html"-->
</body>
</html>	
EOF

	close BLIST or die "Can't close HTML file: $!\n";
	close HTML or die "Can't close HTML file: $!\n";
}
