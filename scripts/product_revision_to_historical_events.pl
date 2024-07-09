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
my $filename = 'historical_events.jsonl';
open(my $file, '>:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";

my $total = 0;

sub process_file {
	my ($path) = @_;
	$total++;

	if ($total % 1000 == 0) {
		print STDERR "$total processed\n";
	}

	my $product = retrieve($path);
	my $changes = retrieve($path->parent . "/changes.sto");

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

		print $file encode_json(
			{
				ts => $change->{t},
				barcode => $product->{code},
				userid => $change->{userid},
				comment => $change->{comment},
				flavor => $options{current_server},
				action => $action,
				diffs => $change->{diffs}
			}
		) . "\n";
	}

	# push_to_redis_stream(
	# 	$change->{userid},
	# 	$product,
	# 	$action,
	# 	$change->{comment}
	# 	$change->{diffs},
	# 	$change->{t}
	# );

	return 1;
}

# because getting products from mongodb won't give 'deleted' ones
path($BASE_DIRS{PRODUCTS})->visit(
	sub {
		my ($path, $state) = @_;
		if ($path->is_file && $path->basename eq 'product.sto') {
			process_file($path);
		}
	},
	{recurse => 1}
);

close $file;
