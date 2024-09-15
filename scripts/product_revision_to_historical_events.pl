#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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
use ProductOpener::Store qw/store retrieve/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Redis qw/push_to_redis_stream/;
use ProductOpener::Products qw/product_id_from_path/;
use Path::Tiny;
use JSON::MaybeXS;

# This script recursively visits all product.sto files from the root of the products directory
# and process its changes to generate a JSONL file of historical events
my $start_from = $ARGV[0] // 0;
my $end_before = $ARGV[1] // 9999999999;
#perl scripts/product_revision_to_historical_events.pl 1704067200

my ($checkpoint_file, $last_processed_path, $last_processed_rev) = open_checkpoint('checkpoint.tmp');
my $can_process = $last_processed_path ? 0 : 1;

# JSONL
my $filename = 'historical_events.jsonl';
open(my $file, '>>:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";

my $product_count = 0;
my $event_count = 0;

my @events = ();

$query_url =~ s/^\s+|\s+$//g;
my $query_post_url = URI->new("$query_url/productupdates");
my $ua = LWP::UserAgent->new();
# Add a timeout to the HTTP query
$ua->timeout(15);

sub process_file($path, $code) {
	$product_count++;

	if ($product_count % 1000 == 0) {
		print '[' . localtime() . "] $product_count products processed. Sent $event_count events \n";
	}

	my $changes = retrieve($path . "/changes.sto");
	if (!defined $changes) {
		print '[' . localtime() . "] Unable to open $path/changes.sto\n";
		return;
	}

	# JSONL
	#my $code = product_id_from_path($path);
	my $change_count = @$changes;    # some $product don't have a 'rev'
	my $rev = 0;    # some $change don't have a 'rev'
	my $obsolete = 0;
	my $deleted = 0;
	foreach my $change (@{$changes}) {
		$rev++;
		my $product = retrieve($path . "/" . $rev . ".sto");
		if (!defined $product) {
			print '[' . localtime() . "] Unable to open $path/$rev.sto\n";
			next;
		}

		my $isDeleted = $product->{deleted};
		my $isObsolete = $product->{obsolete};

		my $action = 'updated';
		if ($rev eq 1) {
			$action = 'created';
		}
		elsif ($isDeleted && !$deleted) {
			$action = 'deleted';
		}
		# Note we treat undeleted as "updated" for consitency with current behaviour
		# elsif (!$isDeleted and $deleted) {
		# 	$action = 'undeleted';
		# }
		elsif ($isObsolete && !$obsolete) {
			$action = 'archived';
		}
		elsif (!$isObsolete && $obsolete) {
			$action = 'unarchived';
		}

		$deleted = $isDeleted;
		$obsolete = $isObsolete;

		# Need to figure out action before testing checkpoint as we need the version history
		# to know where we are
		if (not $can_process and $rev == $last_processed_rev) {
			$can_process = 1;
			print "Resuming from '$last_processed_path' revision $last_processed_rev\n";
			next;    # we don't want to process the revision again
		}

		next if not $can_process;

		my $timestamp = $change->{t} // 0;
		next if ($timestamp < $start_from or $timestamp >= $end_before);

		push(
			@events,
			{
				timestamp => $timestamp,
				code => $code,
				rev => $rev + 0,
				user_id => $change->{userid} // 'initial_import',
				comment => $change->{comment},
				product_type => $options{product_type},
				action => $action,
				diffs => $change->{diffs}
			}
		);

		$event_count++;

		if ($event_count % 1000 == 0) {
			send_events();
			update_checkpoint($checkpoint_file, $path, $rev);
		}
	}

	return 1;
}

sub send_events() {
	foreach my $event (@events) {
		print $file encode_json($event) . "\n";
	}

	my $resp = $ua->post(
		$query_post_url,
		Content => encode_json(\@events),
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

	# Note pushing to redis will cause product to be reloaded
	# push_to_redis_stream(
	# 	$change->{userid} // 'initial_import',
	# 	{code=>$code, rev=>$rev},
	# 	$action,
	# 	$change->{comment},
	# 	$change->{diffs},
	# 	$change->{t}
	# );

	@events = ();

	return 1;
}

# because getting products from mongodb won't give 'deleted' ones
# found that path->visit was slow with full product volume
sub find_products($dir, $code) {
	opendir DH, "$dir" or die "could not open $dir directory: $!\n";
	my @files = readdir(DH);
	closedir DH;
	foreach my $entry (sort @files) {
		next if $entry =~ /^\.\.?$/;
		my $file_path = "$dir/$entry";

		if (-d $file_path and ($can_process or ($last_processed_path =~ m/^\Q$file_path/))) {
			find_products($file_path, "$code$entry");
			next;
		}

		if ($entry eq 'product.sto') {
			if ($can_process or ($last_processed_path and $last_processed_path eq $dir)) {
				process_file($dir, $code);
			}
		}
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
	my ($last_processed_path, $rev);
	if ($checkpoint) {
		($last_processed_path, $rev) = split(',', $checkpoint);
	}
	return ($checkpoint_file, $last_processed_path, $rev);
}

sub update_checkpoint($checkpoint_file, $dir, $revision) {
	seek($checkpoint_file, 0, 0);
	print $checkpoint_file "$dir,$revision";
	truncate($checkpoint_file, tell($checkpoint_file));
	return 1;
}

find_products($BASE_DIRS{PRODUCTS}, '');

if (scalar(@events)) {
	send_events();
}

close $file;
close $checkpoint_file;
