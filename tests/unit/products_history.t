#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;
use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/%writable_tags_fields @writable_tags_fields_list/;

# Test 1: compute_changes_diff_text formatting
{
	my $change_add = {
		diffs => {
			fields => {
				add => ['categories'],
			},
		},
	};
	my $text_add = compute_changes_diff_text($change_add);
	like($text_add, qr/Added:\s*categories/, 'compute_changes_diff_text reports added categories');

	my $change_change = {
		diffs => {
			fields => {
				change => ['categories'],
			},
		},
	};
	my $text_change = compute_changes_diff_text($change_change);
	like($text_change, qr/Changed:\s*categories/, 'compute_changes_diff_text reports changed categories');

	my $change_packaging = {
		diffs => {
			packagings => {
				add => ['data'],
			},
		},
	};
	my $text_packaging = compute_changes_diff_text($change_packaging);
	like(
		$text_packaging,
		qr/Packaging\s*\(Added:\s*data\)/,
		'compute_changes_diff_text handles packagings group with translated name'
	);
}

# Test 2: compute_product_history_and_completeness detects tag additions via tags_sources
{
	my $changes_ref = [
		{
			rev => 1,
			t => 1000,
			userid => 'user1',
		},
		{
			rev => 2,
			t => 2000,
			userid => 'user2',
		},
	];

	my $rev1_product = {
		code => '1234567890',
		rev => 1,
		last_modified_t => 1000,
		tags_sources => {},
	};
	my $rev2_product = {
		code => '1234567890',
		rev => 2,
		last_modified_t => 2000,
		tags_sources => {
			categories => {
				packaging => {
					tags => ['en:walnut-cakes'],
				},
			},
		},
	};

	my $mock = mock 'ProductOpener::Products' => (
		override => [
			retrieve_product => sub ($product_id, $include_deleted = 0, $rev = undef) {
				return $rev == 1 ? $rev1_product : $rev2_product;
			},
			compute_completeness_and_missing_tags => sub {return;},
		],
	);

	my $blame_ref = {};
	compute_product_history_and_completeness($rev2_product, $changes_ref, $blame_ref);

	# Check that rev 2 recorded categories addition
	my $rev2_diffs = $changes_ref->[1]{diffs};
	ok(defined $rev2_diffs, 'rev 2 has diffs defined');
	ok(defined $rev2_diffs->{fields}, 'rev 2 has fields diffs defined');
	ok(defined $rev2_diffs->{fields}{add}, 'rev 2 has fields add diffs');
	is($rev2_diffs->{fields}{add}, ['categories'], 'rev 2 diffs correctly recorded categories addition');

	my $diff_text = compute_changes_diff_text($changes_ref->[1]);
	like($diff_text, qr/Added:\s*categories/, 'diff text shows added categories for revision 2');
}

# Test 3: compute_product_history_and_completeness ignores ingredients-derived allergens
{
	my $changes_ref = [
		{
			rev => 1,
			t => 1000,
			userid => 'user1',
		},
		{
			rev => 2,
			t => 2000,
			userid => 'user2',
		},
	];

	my $rev1_product = {
		code => '1234567890',
		rev => 1,
		last_modified_t => 1000,
		tags_sources => {},
	};
	my $rev2_product = {
		code => '1234567890',
		rev => 2,
		last_modified_t => 2000,
		tags_sources => {
			allergens => {
				ingredients => {
					tags => ['en:soybeans'],
				},
			},
		},
	};

	my $mock = mock 'ProductOpener::Products' => (
		override => [
			retrieve_product => sub ($product_id, $include_deleted = 0, $rev = undef) {
				return $rev == 1 ? $rev1_product : $rev2_product;
			},
			compute_completeness_and_missing_tags => sub {return;},
		],
	);

	my $blame_ref = {};
	compute_product_history_and_completeness($rev2_product, $changes_ref, $blame_ref);

	my $rev2_diffs = $changes_ref->[1]{diffs};
	ok(!defined $rev2_diffs->{fields}{add} || !grep {$_ eq 'allergens'} @{$rev2_diffs->{fields}{add}},
		'allergens from ingredients source are not marked as user additions');
}

# Test 4: compute_product_history_and_completeness tracks packaging-derived allergens
{
	my $changes_ref = [
		{
			rev => 1,
			t => 1000,
			userid => 'user1',
		},
		{
			rev => 2,
			t => 2000,
			userid => 'user2',
		},
	];

	my $rev1_product = {
		code => '1234567890',
		rev => 1,
		last_modified_t => 1000,
		tags_sources => {},
	};
	my $rev2_product = {
		code => '1234567890',
		rev => 2,
		last_modified_t => 2000,
		tags_sources => {
			allergens => {
				packaging => {
					tags => ['en:gluten'],
				},
			},
		},
	};

	my $mock = mock 'ProductOpener::Products' => (
		override => [
			retrieve_product => sub ($product_id, $include_deleted = 0, $rev = undef) {
				return $rev == 1 ? $rev1_product : $rev2_product;
			},
			compute_completeness_and_missing_tags => sub {return;},
		],
	);

	my $blame_ref = {};
	compute_product_history_and_completeness($rev2_product, $changes_ref, $blame_ref);

	my $rev2_diffs = $changes_ref->[1]{diffs};
	ok(defined $rev2_diffs->{fields}{add}, 'rev 2 has fields add diffs for user allergens');
	is($rev2_diffs->{fields}{add}, ['allergens'], 'rev 2 diffs correctly recorded packaging allergens addition');
}

# Test 5: brands scalar is preserved in blame
{
	my $changes_ref = [
		{
			rev => 1,
			t => 1000,
			userid => 'user1',
		},
	];

	my $rev1_product = {
		code => '1234567890',
		rev => 1,
		last_modified_t => 1000,
		brands => 'Brand A',
		tags_sources => {
			brands => {
				packaging => {
					tags => ['en:brand-a'],
				},
			},
		},
	};

	my $mock = mock 'ProductOpener::Products' => (
		override => [
			retrieve_product => sub ($product_id, $include_deleted = 0, $rev = undef) {
				return $rev1_product;
			},
			compute_completeness_and_missing_tags => sub {return;},
		],
	);

	my $blame_ref = {};
	compute_product_history_and_completeness($rev1_product, $changes_ref, $blame_ref);

	is($blame_ref->{fields}{brands}{value}, 'Brand A', 'brands preserves scalar string in blame value');
}

done_testing();
