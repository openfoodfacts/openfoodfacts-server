#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
# 
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

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
		
		open (my $IN, q{<}, "$dir/tests/$f") ;
		my $text = join("", (<$IN>));
		close $IN;
		
		my $product_ref = { code => 0, ingredients_text => $text };
		print $product_ref->{ingredients_text} . "\t";
		extract_ingredients_from_text($product_ref);
		
		print STDERR "saving\n";
		
		open (my $OUT, q{>}, "$dir/current/$f.out") or die("cannot write $dir/current/$f.out: $!\n");
		
		print $OUT "ingredients_text:\n$product_ref->{ingredients_text}\n\n";
		
		if (not defined $product_ref->{ingredients}) {
			print $OUT "no ingredients field\n";
			next;
		}
	
		foreach my $i (@{$product_ref->{ingredients}}) {
	
			print $OUT $i->{rank} . "\t" . $i->{id} . "\t" . '"' . $i->{text} . '"' . "\t" . $i->{percent} . "\n";
	
		}		
		close $OUT;
		
		if (-e "$dir/golden/$f") {
		}
		else {
			print STDERR "no golden file";
		}
		
		print STDERR "\n";
}

closedir(DH);

exit(0);

