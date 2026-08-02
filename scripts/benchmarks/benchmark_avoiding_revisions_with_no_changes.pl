#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;
use Time::HiRes qw/gettimeofday/;

use ProductOpener::PerlStandards;
use ProductOpener::Store qw/retrieve_object store_object/;
use ProductOpener::Products ();
use ProductOpener::Paths qw/%BASE_DIRS/;

# Performance test.
# Directory scanning version
sub update_products($dir, $code, $mode) {
	my $count = 0;
	opendir DH, "$dir" or die "could not open $dir directory: $!\n";
	my @files = readdir(DH);
	closedir DH;
	foreach my $entry (sort @files) {
		next if $entry =~ /^\.\.?$/;
		my $file_path = "$dir/$entry";

		if (-d $file_path) {
			$count += update_products($file_path, "$code$entry", $mode);
			next;
		}

		# Only do change files as the product files are just links
		# Note that we run the test on all files just so we have a decent volume
		# In practice it would only run on the current product
		if ($entry =~ /\d+\.json/) {
			my $stripped_path = substr($file_path, 0, -5);
			my $product_ref = retrieve_object($stripped_path);
			if ($mode eq 'NO_CHECK') {
				# Just save it back again
				store_object($stripped_path, $product_ref);
			}
			elsif ($mode eq 'NO_CHANGE') {
				# This is the equivalent code path for no when there is no significant change
				my $latest_product_ref = retrieve_object($stripped_path);
				my $has_latest_stored_product = (ref($latest_product_ref) eq 'HASH');
				my $matches_latest_stored_product = 0;
				my $should_skip_save = 0;

				if ($has_latest_stored_product) {
					# Compare against the persisted product before deciding to skip.
					$matches_latest_stored_product
						= ProductOpener::Products::_products_are_equivalent_for_revision($product_ref,
						$latest_product_ref);
				}

				if ($matches_latest_stored_product) {
					# Put the persisted state back before returning from a skipped save.
					$should_skip_save
						= ProductOpener::Products::_restore_product_state_from_latest_product($product_ref,
						$latest_product_ref);
				}
				# No save
			}
			elsif ($mode eq 'WITH_CHANGE') {
				# This is the equivalent code path for no when there is no significant change
				my $latest_product_ref = retrieve_object($stripped_path);
				my $has_latest_stored_product = (ref($latest_product_ref) eq 'HASH');
				my $matches_latest_stored_product = 0;
				my $should_skip_save = 0;

				if ($has_latest_stored_product) {
					# Compare against the persisted product before deciding to skip.
					$matches_latest_stored_product
						= ProductOpener::Products::_products_are_equivalent_for_revision($product_ref,
						$latest_product_ref);
				}
				# Pretend that $matches_latest_stored_product is false so we do a save
				store_object($stripped_path, $product_ref);
			}
			# NOOP doesn't do anything
			$count += 1;
		}
	}

	return $count;
}

sub run_for_mode($mode) {
	my $started_t = gettimeofday();
	my $count = update_products($BASE_DIRS{PRODUCTS}, '', $mode);
	print STDERR "$mode: $count files in " . (gettimeofday() - $started_t) . " s\n";

	return;
}

# Run NOOP first to get any caching done
run_for_mode('NOOP');
run_for_mode('NO_CHECK');
run_for_mode('NO_CHANGE');
run_for_mode('WITH_CHANGE');
