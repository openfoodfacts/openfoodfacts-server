#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

my $dir = "$data_root/cgi/tests/extract_ingredients_from_text";

use File::Path qw(remove_tree);

(-e "$dir/current") and remove_tree("$dir/current");
mkdir("$dir/current", 0755);

opendir(DH, "$dir/tests") or print STDERR "cannot open directory $dir/tests : $!\n";

my @files = ();
if (defined $ARGV[0]) {
	@files = @ARGV;
}
else {
	foreach my $f (sort readdir(DH)) {
		next if ($f =~  /\./);
		push @files, $f;
	}
}

foreach my $f (@files) {
		next if ($f =~  /\./);
		print STDERR "$f\t";
		
		open (IN, "<$dir/tests/$f") ;
		my $text = join("", (<IN>));
		close IN;
		
		my $product_ref = { code => 0, ingredients_text => $text };
		print $product_ref->{ingredients_text} . "\t";
		extract_ingredients_from_text($product_ref);
		
		print STDERR "saving\n";
		
		open (OUT, ">$dir/current/$f.out") or die("cannot write $dir/current/$f.out: $!\n");
		
		print OUT "ingredients_text:\n$product_ref->{ingredients_text}\n\n";
		
		if (not defined $product_ref->{ingredients}) {
			print OUT "no ingredients field\n";
			next;
		}
	
		foreach my $i (@{$product_ref->{ingredients}}) {
	
			print OUT $i->{rank} . "\t" . $i->{id} . "\t" . '"' . $i->{text} . '"' . "\t" . $i->{percent} . "\n";
	
		}		
		close OUT;
		
		if (-e "$dir/golden/$f") {
		}
		else {
			print STDERR "no golden file";
		}
		
		print STDERR "\n";
}

closedir(DH);

exit(0);

