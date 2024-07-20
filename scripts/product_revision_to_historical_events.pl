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

use ProductOpener::PerlStandards;
use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/%options/;
use ProductOpener::Store qw/store retrieve/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Redis qw/push_to_redis_stream/;
use Path::Tiny;
use JSON;

# This script recursively visits all product.sto files from the root of the products directory
# and process its changes to generate a JSONL file of historical events

# JSONL
# my $filename = 'historical_events.jsonl';
# open(my $file, '>:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";

my $total = 0;

sub process_file {
	my ($path) = @_;
	$total++;

	if ($total % 1000 == 0) {
		print STDERR "$total processed\n";
	}

	my $product = retrieve($path. "/product.sto");
	my $changes = retrieve($path . "/changes.sto");

	# JSONL
	my $rev = 0;    # some $change don't have a 'rev'
	foreach my $change (@{$changes}) {

		$rev++;

		my $action = 'updated';
		if ($rev eq 1) {
			$action = 'created';
		}
		elsif ( $rev == $product->{rev}
			and exists $product->{deleted}
			and $product->{deleted} eq 'on')
		{
			$action = 'deleted';
		}

		if (exists $change->{diffs}{fields}{add}
			and $change->{diffs}{fields}{add}[0] eq 'obsolete')
		{
			$action = 'archived';
		}
		if (exists $change->{diffs}{fields}{delete}
			and $change->{diffs}{fields}{delete}[0] eq 'obsolete')
		{
			$action = 'unarchived';
		}

		$change->{diffs}{initial_import} = 1;

		# print $file encode_json(
		# 	{
		# 		timestamp => $change->{t},
		# 		barcode => $product->{code},
		# 		userid => $change->{userid},
		# 		comment => $change->{comment},
		# 		product_type => $options{product_type},
		# 		action => $action,
		# 		diffs => $change->{diffs}
		# 	}
		# ) . "\n";

		push_to_redis_stream(
			$change->{userid} // 'initial_import',
			$product,
			$action,
			$change->{comment},
			$change->{diffs},
			$change->{t}
		);
	}

	return 1;
}

# because getting products from mongodb won't give 'deleted' ones
# found that path->visit was slow with full product volume
sub find_products {
	my $dir = shift;
	my $code = shift;

	opendir DH, "$dir" or die "could not open $dir directory: $!\n";
	my @files = readdir(DH);
	closedir DH;
	foreach my $entry (@files) {
		next if $entry =~ /^\.\.?$/;
		my $file_path = "$dir/$entry";
		if (-d $file_path) {
			find_products($file_path,"$code$entry");
			next;
		}
		if ($entry eq 'product.sto') {
			process_file($dir);
		} 
	}

	return;
}

find_products($BASE_DIRS{PRODUCTS},'');

#close $file;
