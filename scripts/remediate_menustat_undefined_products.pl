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

=head1 NAME

remediate_menustat_undefined_products.pl - Remediate invalid MenuStat bulk-imported products

=head1 SYNOPSIS

remediate_menustat_undefined_products.pl [OPTIONS]

Options:
    --dry-run             Report matching candidates without modifying data (default)
    --execute             Apply soft deletion via store_product()
    --limit N             Stop after processing N matching candidates
    --batch-size N        Sleep after every N writes during --execute (default: 100)
    --batch-sleep SEC     Seconds to sleep per batch during --execute (default: 0)
    --min-created-t EPOCH Minimum creation timestamp (default: 1740009600 / 2025-02-20T00:00:00Z)
    --max-created-t EPOCH Maximum creation timestamp (default: 1740182399 / 2025-02-21T23:59:59Z)
    --creator USER        Expected creator username (default: openfoodfacts-contributors)
    --verbose             Print per-product match/exclusion decisions
    --help                Display usage information

=head1 DESCRIPTION

Identifies and safely soft-deletes products created during the February 20-21, 2025
MenuStat restaurant bulk import containing literal "undefined" ingredients (Issue #14863).

Uses strict compound validation (creator, creation timestamp window, literal
"undefined" ingredients, absence of images, absence of human revisions, and exclusion
of valid GTIN barcodes) to protect unrelated records.

=cut

package ProductOpener::Scripts::RemediateMenuStat;

use ProductOpener::PerlStandards;

use Algorithm::CheckDigits qw(CheckDigits);
use Getopt::Long qw(GetOptions);
use Log::Any qw($log);

use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::Products qw/retrieve_product store_product/;

our $DEFAULT_CREATOR = 'openfoodfacts-contributors';
our $DEFAULT_MIN_CREATED_T = 1740009600;    # 2025-02-20 00:00:00 UTC
our $DEFAULT_MAX_CREATED_T = 1740182399;    # 2025-02-21 23:59:59 UTC
our $REMEDIATION_USER_ID = 'remediate-menustat-bot';
our $REMEDIATION_COMMENT = '[remediate_menustat_undefined_products.pl] '
	. 'soft-delete invalid MenuStat import with undefined ingredients (issue #14863)';

my $EAN_CHECK = CheckDigits('ean');
my @USER_FIELDS = qw(editors_tags informers_tags correctors_tags checkers_tags weighers_tags);

sub is_valid_gtin ($code) {
	return 0 unless defined $code && $code =~ /^\d+$/;
	return 0 if $code =~ /^0+$/;

	my $len = length($code);
	if ($len == 12) {
		return ProductOpener::Products::is_valid_upc12($code) ? 1 : 0;
	}
	if ($len == 8 || $len == 13 || $len == 14) {
		return $EAN_CHECK->is_valid($code) ? 1 : 0;
	}

	return 0;
}

sub has_product_images ($product_ref) {
	return 0 unless ref($product_ref) eq 'HASH';

	if (defined $product_ref->{last_image_t} && $product_ref->{last_image_t} ne '' && $product_ref->{last_image_t} > 0)
	{
		return 1;
	}

	if (   defined $product_ref->{photographers_tags}
		&& ref($product_ref->{photographers_tags}) eq 'ARRAY'
		&& scalar(@{$product_ref->{photographers_tags}}) > 0)
	{
		return 1;
	}

	my $images_ref = $product_ref->{images};
	if (defined $images_ref && ref($images_ref) eq 'HASH') {
		for my $group (qw(uploaded selected)) {
			if (   defined $images_ref->{$group}
				&& ref($images_ref->{$group}) eq 'HASH'
				&& scalar(keys %{$images_ref->{$group}}) > 0)
			{
				return 1;
			}
		}

		for my $key (keys %{$images_ref}) {
			next if $key eq 'uploaded' || $key eq 'selected';
			return 1;
		}
	}

	return 0;
}

sub has_human_modifications ($product_ref, $expected_creator = $DEFAULT_CREATOR) {
	return 1 unless ref($product_ref) eq 'HASH';

	if (defined $product_ref->{rev} && $product_ref->{rev} =~ /^\d+$/ && $product_ref->{rev} > 1) {
		return 1;
	}

	if (   defined $product_ref->{last_modified_by}
		&& $product_ref->{last_modified_by} ne ''
		&& $product_ref->{last_modified_by} ne $expected_creator)
	{
		return 1;
	}

	for my $field (@USER_FIELDS) {
		next unless defined $product_ref->{$field} && ref($product_ref->{$field}) eq 'ARRAY';
		for my $user (@{$product_ref->{$field}}) {
			next unless defined $user && $user ne '';
			return 1 if $user ne $expected_creator;
		}
	}

	return 0;
}

sub _normalized_ingredients_text ($product_ref) {
	my $text = $product_ref->{ingredients_text};
	if (!defined $text || $text eq '') {
		$text = $product_ref->{ingredients_text_en};
	}
	return '' unless defined $text;
	$text =~ s/^\s+|\s+$//g;
	return lc($text);
}

sub evaluate_menustat_product ($product_ref, $opts = {}) {
	return (0, 'invalid_product_ref') unless ref($product_ref) eq 'HASH';
	return (0, 'missing_code') unless defined $product_ref->{code} && $product_ref->{code} ne '';

	if ($product_ref->{deleted}) {
		return (0, 'already_deleted');
	}

	if (defined $product_ref->{owner} && $product_ref->{owner} ne '') {
		return (0, 'has_owner');
	}

	my $expected_creator = $opts->{creator} // $DEFAULT_CREATOR;
	my $min_created_t = $opts->{min_created_t} // $DEFAULT_MIN_CREATED_T;
	my $max_created_t = $opts->{max_created_t} // $DEFAULT_MAX_CREATED_T;

	my $ingredients = _normalized_ingredients_text($product_ref);
	if ($ingredients ne 'undefined') {
		return (0, 'ingredients_not_undefined');
	}

	my $creator = $product_ref->{creator} // '';
	if ($creator ne $expected_creator) {
		return (0, 'creator_mismatch');
	}

	my $created_t = $product_ref->{created_t};
	if (!defined $created_t || $created_t !~ /^\d+$/ || $created_t < $min_created_t || $created_t > $max_created_t) {
		return (0, 'timestamp_out_of_window');
	}

	if (has_product_images($product_ref)) {
		return (0, 'has_images');
	}

	if (has_human_modifications($product_ref, $expected_creator)) {
		return (0, 'user_edited');
	}

	if (is_valid_gtin($product_ref->{code})) {
		return (0, 'valid_gtin');
	}

	return (1, 'matched_menustat_undefined_import');
}

sub build_mongo_query ($opts = {}) {
	my $expected_creator = $opts->{creator} // $DEFAULT_CREATOR;
	my $min_created_t = $opts->{min_created_t} // $DEFAULT_MIN_CREATED_T;
	my $max_created_t = $opts->{max_created_t} // $DEFAULT_MAX_CREATED_T;

	return {
		created_t => {
			'$gte' => $min_created_t + 0,
			'$lte' => $max_created_t + 0,
		},
		creator => $expected_creator,
	};
}

sub init_stats () {
	return {
		scanned => 0,
		matched => 0,
		excluded => 0,
		not_found_or_del => 0,
		remediated => 0,
		dry_run_candidates => 0,
		errors => 0,
		exclusion_reasons => {},
	};
}

sub process_product ($product_ref, $opts = {}, $stats = init_stats(), $store_fn = \&store_product) {
	my ($is_match, $reason) = evaluate_menustat_product($product_ref, $opts);

	if (!$is_match) {
		$stats->{excluded}++;
		$stats->{exclusion_reasons}{$reason}++;
		return (0, $reason);
	}

	$stats->{matched}++;

	if ($opts->{execute}) {
		$product_ref->{deleted} = 'on';
		my $ok = eval {$store_fn->($REMEDIATION_USER_ID, $product_ref, $REMEDIATION_COMMENT)};
		if ($@ || !$ok) {
			$stats->{errors}++;
			$log->error('Failed to soft-delete MenuStat product',
				{code => $product_ref->{code}, error => $@ || 'store_product returned false'});
			return (0, 'store_failed');
		}
		$stats->{remediated}++;
		return (1, 'remediated');
	}

	$stats->{dry_run_candidates}++;
	return (1, 'dry_run_candidate');
}

sub run_remediation ($opts = {}, $deps = {}) {
	my $stats = init_stats();
	my $limit = $opts->{limit};

	my $retrieve_fn = $deps->{retrieve_fn} // \&retrieve_product;
	my $store_fn = $deps->{store_fn} // \&store_product;
	my $sleep_fn = $deps->{sleep_fn} // sub ($s) {sleep($s) if $s > 0};
	my $cursor = $deps->{cursor};

	if (!defined $cursor) {
		my $socket_timeout_ms = 2 * 60000;
		my $products_collection = get_products_collection({timeout => $socket_timeout_ms});
		my $query_ref = build_mongo_query($opts);
		$cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1});
		$cursor->immortal(1);
	}

	my $batch_size = $opts->{batch_size} // 100;
	my $batch_sleep = $opts->{batch_sleep} // 0;
	my $out_fh = $opts->{out_fh} // \*STDOUT;

	while ((!defined $limit || $stats->{matched} < $limit) && (my $doc_ref = $cursor->next)) {
		$stats->{scanned}++;

		my $product_id = $doc_ref->{_id} // $doc_ref->{code} // '';
		if ($product_id eq '') {
			$stats->{not_found_or_del}++;
			next;
		}

		my $product_ref = $retrieve_fn->($product_id);
		if (!defined $product_ref) {
			$stats->{not_found_or_del}++;
			next;
		}

		my $code = $product_ref->{code} // $doc_ref->{code} // '';
		my ($did_match, $status) = process_product($product_ref, $opts, $stats, $store_fn);

		if ($opts->{verbose}) {
			my $brand = $product_ref->{brands} // '';
			my $name = $product_ref->{product_name} // '';
			print {$out_fh} sprintf("[%s] code=%s brand=%s name=%s\n", $status, $code, $brand, $name);
		}

		if ($opts->{execute} && $did_match && $batch_size > 0 && ($stats->{remediated} % $batch_size == 0)) {
			$sleep_fn->($batch_sleep);
		}
	}

	return $stats;
}

sub main (@argv) {
	local @ARGV = @argv if @argv;

	my %opts = (
		dry_run => undef,
		execute => 0,
		limit => undef,
		batch_size => 100,
		batch_sleep => 0,
		min_created_t => $DEFAULT_MIN_CREATED_T,
		max_created_t => $DEFAULT_MAX_CREATED_T,
		creator => $DEFAULT_CREATOR,
		verbose => 0,
		help => 0,
	);

	GetOptions(
		'dry-run!' => \$opts{dry_run},
		'execute' => \$opts{execute},
		'limit=i' => \$opts{limit},
		'batch-size=i' => \$opts{batch_size},
		'batch-sleep=i' => \$opts{batch_sleep},
		'min-created-t=i' => \$opts{min_created_t},
		'max-created-t=i' => \$opts{max_created_t},
		'creator=s' => \$opts{creator},
		'verbose' => \$opts{verbose},
		'help|h|?' => \$opts{help},
	) or die("Invalid command line arguments\n");

	if ($opts{help}) {
		print <<'USAGE';
Usage: remediate_menustat_undefined_products.pl [OPTIONS]
  --dry-run             Preview matching candidates without writing (default)
  --execute             Execute soft-deletion via store_product()
  --limit N             Maximum number of matched candidates to process
  --batch-size N        Batch size before throttling sleep (default: 100)
  --batch-sleep SEC     Seconds to sleep per batch during --execute (default: 0)
  --min-created-t EPOCH Minimum creation timestamp (default: 1740009600)
  --max-created-t EPOCH Maximum creation timestamp (default: 1740182399)
  --creator USER        Expected creator (default: openfoodfacts-contributors)
  --verbose             Print per-product evaluation decisions
  --help                Show this help
USAGE
		return 0;
	}

	if ($opts{execute} && defined $opts{dry_run} && $opts{dry_run}) {
		die("Conflicting options: cannot specify both --dry-run and --execute\n");
	}
	$opts{dry_run} = $opts{execute} ? 0 : 1;

	if (defined $opts{limit} && $opts{limit} < 0) {
		die("Invalid --limit: must be >= 0\n");
	}
	if ($opts{batch_size} < 1) {
		die("Invalid --batch-size: must be >= 1\n");
	}
	if ($opts{batch_sleep} < 0) {
		die("Invalid --batch-sleep: must be >= 0\n");
	}
	if ($opts{min_created_t} > $opts{max_created_t}) {
		die("Invalid timestamp window: --min-created-t must be <= --max-created-t\n");
	}

	my $mode = $opts{execute} ? 'EXECUTE' : 'DRY-RUN';
	my $stats = run_remediation(\%opts);

	print "MenuStat Undefined Products Remediation ($mode)\n";
	print "  Scanned:              $stats->{scanned}\n";
	print "  Matched candidates:   $stats->{matched}\n";
	print "  Dry-run candidates:   $stats->{dry_run_candidates}\n";
	print "  Remediated (deleted): $stats->{remediated}\n";
	print "  Excluded:             $stats->{excluded}\n";
	print "  Not found/deleted:    $stats->{not_found_or_del}\n";
	print "  Errors:               $stats->{errors}\n";

	if (scalar keys %{$stats->{exclusion_reasons}}) {
		print "  Exclusion breakdown:\n";
		for my $reason (sort keys %{$stats->{exclusion_reasons}}) {
			print "    - $reason: $stats->{exclusion_reasons}{$reason}\n";
		}
	}

	return $stats->{errors} > 0 ? 1 : 0;
}

unless (caller) {
	exit(main(@ARGV));
}

1;
