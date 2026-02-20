#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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
use ProductOpener::Products qw/product_id_from_path product_iter/;
use ProductOpener::Store qw/retrieve_object_json/;
use ProductOpener::Checkpoint;
use ProductOpener::HTTP qw/create_user_agent/;

use Path::Tiny;
use File::Slurp;

# This script recursively visits all scans.json files from the root of the products directory
# and sends the data to off-query
# Add a "resume" argument to resume from the last checkpoint
my $checkpoint = ProductOpener::Checkpoint->new;
my $last_processed_path = $checkpoint->{value};
$last_processed_path = "/srv/off/products/999/136/048/6034/scans";
my $can_process = $last_processed_path ? 0 : 1;

print "last_processed_path: $last_processed_path\n";
print "can_process: $can_process\n";

my $batch_size = $ARGV[0] // 100;
my $scans = "{";
my $scan_count = 0;

$query_url =~ s/^\s+|\s+$//g;
my $query_post_url = URI->new("$query_url/scans");
my $ua = create_user_agent();
# Add a timeout to the HTTP query
$ua->timeout(15);

sub send_scans($fully_loaded = 0) {
	# Skip if there are no scans
	return if $scans eq "{";
	print '[' . localtime() . "] $scan_count products processed...";
	# Remove last comma
	chop($scans);
	$scans .= '}';
	my $resp = $ua->post(
		$query_post_url . ($fully_loaded ? '?fullyloaded=1' : ''),
		Content => $scans,
		'Content-Type' => 'application/json; charset=utf-8'
	);
	if (!$resp->is_success) {
		print '[' . localtime() . $query_post_url . " resp: " . $resp->status_line . "\n" . $scans . "\n";
		die;
	}

	print '[' . localtime() . "] Sent to off-query.\n";
	$scans = '{';

	return 1;
}

my $next = product_iter(
	$BASE_DIRS{PRODUCTS},
	qr/scans/,
	qr/^((conflicting|invalid|other-flavors)-codes|deleted-off-products-codes-replaced-by-other-flavors|new_images|invalid)$/,
	$last_processed_path
);
while (my $path = $next->()) {
	if (not $can_process) {
		if ($path eq $last_processed_path) {
			$can_process = 1;
		}
		next;    # we don't want to process the product again
	}

	my $scans_ref = retrieve_object_json($path);
	my $code = product_id_from_path($path);

	$scans .= '"' . $code . '":' . $scans_ref . ',';
	$scan_count++;

	if ($scan_count % $batch_size == 0) {
		send_scans();
		$checkpoint->update($path);
	}
}

# Always send last batch even if no scans to indicate all loaded
send_scans(1);
