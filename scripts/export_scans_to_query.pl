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
use ProductOpener::Products qw/product_id_from_path/;
use ProductOpener::Store qw/object_iter retrieve_object_json/;
use LWP::UserAgent;
use Path::Tiny;
use File::Slurp;

# This script recursively visits all scans.json files from the root of the products directory
# and sends the data to off-query

my $batch_size = $ARGV[0] // 100;
my ($checkpoint_file, $last_processed_path) = open_checkpoint('export_scans_to_query_checkpoint.tmp');
my $can_process = $last_processed_path ? 0 : 1;

my $scans = "{";
my $scan_count = 0;

$query_url =~ s/^\s+|\s+$//g;
my $query_post_url = URI->new("$query_url/scans");
my $ua = LWP::UserAgent->new();
# Add a timeout to the HTTP query
$ua->timeout(15);

sub send_scans($fully_loaded = 0) {
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
		print '['
			. localtime()
			. "] query response not ok calling "
			. $query_post_url
			. " resp: "
			. $resp->status_line . "\n" . $scans . "\n";
		die;
	}

	print '[' . localtime() . "] Sent to off-query.\n";
	$scans = '{';

	return 1;
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

#11872 TODO Use object_iter
my $next = object_iter($BASE_DIRS{PRODUCTS}, qr/scans/);
while (my $path = $next->()) {
	if (not $can_process) {
		if ($path eq $last_processed_path) {
			$can_process = 1;
			print "Resuming from '$last_processed_path'\n";
		}
		next;    # we don't want to process the product again
	}

	my $scans_ref = retrieve_object_json($path);
	my $code = product_id_from_path($path);

	$scans .= '"' . $code . '":' . $scans_ref . ',';
	$scan_count++;

	if ($scan_count % $batch_size == 0) {
		send_scans();
		update_checkpoint($checkpoint_file, $path);
	}
}

# Always send last batch even if no scans to indicate all loaded
send_scans(1);

close $checkpoint_file;
