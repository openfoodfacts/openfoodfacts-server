#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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
use utf8;

use ProductOpener::Config qw/%options $query_url/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::Products qw/split_code/;
use LWP::UserAgent;
use Path::Tiny;
use File::Slurp;

# This script recursively visits all scans.json files from the root of the products directory
# and sends the data to off-query

my ($checkpoint_file, $last_processed_path) = open_checkpoint('export_scans_to_query_checkpoint.tmp');
my $can_process = $last_processed_path ? 0 : 1;

my $scans = "{";
my $scan_count = 0;

$query_url =~ s/^\s+|\s+$//g;
my $query_post_url = URI->new("$query_url/scans");
my $ua = LWP::UserAgent->new();
# Add a timeout to the HTTP query
$ua->timeout(15);

sub process_file($path, $code) {
	my $scans_file = $path . "/scans.json";
	return if not -e $scans_file;
	my $scans_ref = read_file($scans_file);

	$scans .= '"' . $code . '":' . $scans_ref . ',';
	$scan_count++;

	if ($scan_count % 60 == 0) {
		send_scans();
		update_checkpoint($checkpoint_file, $path);
	}

	return 1;
}

sub send_scans() {
	# Remove last comma
	chop($scans);
	$scans .= '}';
	my $resp = $ua->post(
		$query_post_url,
		Content => $scans,
		'Content-Type' => 'application/json; charset=utf-8'
	);
	if (!$resp->is_success) {
		print '['
			. localtime()
			. "] query response not ok calling "
			. $query_post_url
			. " error: "
			. $resp->status_line . "\n";
		die;
	}

	print '[' . localtime() . "] $scan_count products processed.\n";
	$scans = '{';

	return 1;
}

# because getting products from mongodb won't give 'deleted' ones
# found that path->visit was slow with full product volume
sub find_products($dir, $code) {
	my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

	# Collection that will be used to iterate products
	my $products_collection = get_products_collection({timeout => $socket_timeout_ms});

	# only retrieve important fields
	my $cursor = $products_collection->query({})->sort({code => 1})->fields({code => 1});
	$cursor->immortal(1);

	while (my $product_ref = $cursor->next) {
		my $code = $product_ref->{code};
		my $product_path = split_code($code);
		my $file_path = "$dir/$product_path";

		if (not $can_process and $file_path eq $last_processed_path) {
			$can_process = 1;
			print "Resuming from '$last_processed_path'\n";
			next;    # we don't want to process the product again
		}
		next if not $can_process;
		process_file($file_path, $code);
	}

	return;
}

sub open_checkpoint($filename) {
	if (!-e $filename) {
		`touch $filename`;
	}
	open(my $checkpoint_file, '+<', $filename) or die "Could not open file '$filename' $!";
	seek($checkpoint_file, 0, 0);
	my $checkpoint = <$checkpoint_file>;
	chomp $checkpoint if $checkpoint;
	my $last_processed_path;
	if ($checkpoint) {
		$last_processed_path = $checkpoint;
	}
	return ($checkpoint_file, $last_processed_path);
}

sub update_checkpoint($checkpoint_file, $dir) {
	seek($checkpoint_file, 0, 0);
	print $checkpoint_file $dir;
	truncate($checkpoint_file, tell($checkpoint_file));
	return 1;
}

find_products($BASE_DIRS{PRODUCTS}, '');

if (length($scans) > 1) {
	send_scans();
}

close $checkpoint_file;
