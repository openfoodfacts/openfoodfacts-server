#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

use Storable qw(lock_store lock_nstore lock_retrieve);
use Encode;
use MongoDB;

my $timeout = 60000;
my $database = "off";
my $collection = "products_revs";

my $products_collection = MongoDB::MongoClient->new->get_database($database)->get_collection($collection);

my $start_dir = $ARGV[0];

if (not defined $start_dir) {
	print STDERR "Pass the root of the product directory as the first argument.\n";
	exit();
}

sub retrieve {
	my $file = shift @_;
	# If the file does not exist, return undef.
	if (!-e $file) {
		return;
	}
	my $return = undef;
	eval {$return = lock_retrieve($file);};

	return $return;
}

my @products = ();

sub get_path_from_code($) {

	my $code = shift;
	# Require at least 4 digits (some stores use very short internal barcodes, they are likely to be conflicting)
	if ($code !~ /^\d{4,24}$/) {

		return "invalid";
	}

	my $path = $code;
	if ($code =~ /^(...)(...)(...)(.*)$/) {
		$path = "$1/$2/$3/$4";
	}
	return $path;
}

my $d = 0;

sub find_products($$) {

	my $dir = shift;
	my $code = shift;

	my $dh;

	opendir $dh, "$dir" or die "could not open $dir directory: $!\n";
	foreach my $file (sort readdir($dh)) {
		chomp($file);
		#print "file: $file\n";
		if ($file =~ /^(([0-9]+))\.sto/) {
			push @products, [$code, $1];
			$d++;
			(($d % 1000) == 1) and print "$d products revisions - $code\n";
			#print "code: $code\n";
		}
		else {
			$file =~ /\./ and next;
			if (-d "$dir/$file") {
				find_products("$dir/$file", "$code$file");
			}
		}
		#last if $d > 100;
	}
	closedir $dh or print "could not close $dir dir: $!\n";

	return;
}

if (scalar $#products < 0) {
	find_products($start_dir, '');
}

my $count = $#products;
my $i = 0;

my %codes = ();

print STDERR "$count products revs to update\n";

foreach my $code_rev_ref (@products) {

	my ($code, $rev) = @$code_rev_ref;

	my $path = get_path_from_code($code);

	my $product_ref = retrieve("$start_dir/$path/$rev.sto") or print "not defined $start_dir/$path/$rev.sto\n";

	if ((defined $product_ref)) {

		next if ((defined $product_ref->{deleted}) and ($product_ref->{deleted} eq 'on'));
		print STDERR "updating product code $code -- rev $rev -- " . $product_ref->{code} . " \n";

		$product_ref->{_id} = $code . "." . $rev;

		my $return = $products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
		print STDERR "return $return\n";
		$i++;
		$codes{$code} = 1;
	}
}

print STDERR "$count products revs to update - $i products revs not empty or deleted\n";
print STDERR "scalar keys codes : " . (scalar keys %codes) . "\n";

exit(0);

