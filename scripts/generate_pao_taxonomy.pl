#!/usr/bin/perl -w

use Modern::Perl '2015';

open (IN, "<periods_after_opening_logo.svg") or die ;
my $svg = join ("",(<IN>));
close(IN);

my $entry_format = <<TXT
en:<i> months, <i>months, <i> M, <i>M, <i>
fr:<i> mois, <i>mois
numeric_number_of_months_after_opening:en:<i>
TXT
;

my $image_path = "/home/obf/html/images/lang/en/periods_after_opening";

for (my $i = 1; $i <= 4 * 12; $i++) {

	my $entry = $entry_format;
	$entry =~ s/<i>/$i/g;
	print $entry . "\n";
	
	# generate SVG logo
	my $isvg = $svg;
	$isvg =~ s/49 M/$i M/;
	
	my $file = "$image_path/$i-months.90x90.svg";
	$file =~ s/^1-months/1-month/;
	
	open (OUT, "> $file") or die;
	print OUT $isvg;
	close OUT;
	
}