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

#11872 Use PO Storable
use ProductOpener::Store qw/retrieve_object/;
use ProductOpener::Products qw/product_id_from_path product_iter/;
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

my @products = ();

my $d = 0;

sub find_products($) {

	my $dir = shift;
	my $next = product_iter($dir, qr/^(([0-9]+))/);
	while (my $file = $next->()) {
		push @products, [$file, $1];
		$d++;
		(($d % 1000) == 1) and print "$d products revisions - $file\n";
	}

	return;
}

if (scalar $#products < 0) {
	find_products($start_dir);
}

my $count = $#products;
my $i = 0;

my %codes = ();

print STDERR "$count products revs to update\n";

foreach my $code_rev_ref (@products) {

	my ($path, $rev) = @$code_rev_ref;
	my $code = product_id_from_path($path);

	my $product_ref = retrieve_object("$start_dir/$path/$rev") or print "not defined $start_dir/$path/$rev\n";

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

