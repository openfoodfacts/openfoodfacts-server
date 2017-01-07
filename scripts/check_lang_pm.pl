#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

my $file = $ARGV[0];

print "Checking $file\n";

open(my $IN, "<:encoding(UTF-8)", $file) or die "Could not open $file: $!\n";

my %langs = ();

app_take_a_picture => {
	fr => "Prendre une photo",
	en => "Take a picture",
	es => "Saca una foto",
	pt => "Tira uma foto",
	ro => "Faceți o fotografie",
	ar => "التقاط صورة",
	de => "Machen Sie ein Foto",
	it => "Scattare una foto",  
	he => "צילום תמונה",
},

my $key = "";

while (<$IN>) {

	chomp;
	my $l = $_;
	if ($l =~ /=>\s*\{/) {
		$key = $`;
		$key =~ s/\s//g;
		%langs = ();
	}
	elsif ($l =~ /=>\s*/) {
		my $lang = $`;
		my $value = $';
		$lang =~ s/\s//g;
		if (exists $langs{$lang}) {
			print STDERR "key $key has 2 values for lang $lang\n\t$langs{$lang}\n\t$value\n";
		}
		else {
			$langs{$lang} = $value;
		}
	}

}

