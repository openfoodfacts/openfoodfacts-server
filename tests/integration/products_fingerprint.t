#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Digest::SHA qw(sha256_hex);
use JSON::MaybeXS ();

use ProductOpener::APITest qw/wait_application_ready/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products
	qw/get_server_for_product init_product product_path_from_id retrieve_product store_product/;
use ProductOpener::Store qw/object_exists remove_object retrieve_object/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;

no warnings qw(experimental::signatures);

my $json = JSON::MaybeXS->new->canonical->utf8(1);

# Run application setup for integration tests.
wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

sub digest_product_ref ($product_ref) {
	return undef if not defined $product_ref;
	return undef if ref($product_ref) ne 'HASH';
	return sha256_hex($json->encode($product_ref));
}

# Read persisted revision state for assertions.
sub read_persisted_state ($product_id) {
	my $path = product_path_from_id($product_id);
	my $latest_product_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/product");
	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes") // [];
	my $rev
		= ((defined $latest_product_ref) and (ref($latest_product_ref) eq 'HASH') and defined $latest_product_ref->{rev})
		? int($latest_product_ref->{rev})
		: 0;
	return {
		path => $path,
		rev => $rev,
		changes_count => scalar @{$changes_ref},
		latest_product_digest => digest_product_ref($latest_product_ref),
	};
}

# Assert that a save created a new revision.
sub assert_saved_revision ($before_ref, $after_ref, $label) {
	is($after_ref->{rev}, $before_ref->{rev} + 1, "$label increments rev");
	is($after_ref->{changes_count}, $before_ref->{changes_count} + 1, "$label appends one change entry");
	ok(
		object_exists("$BASE_DIRS{PRODUCTS}/$after_ref->{path}/$after_ref->{rev}"),
		"$label stores the new revision object"
	);
	return;
}

# Assert that a no-op save was skipped.
sub assert_skipped_revision ($before_ref, $after_ref, $label) {
	is($after_ref->{rev}, $before_ref->{rev}, "$label keeps rev unchanged");
	is($after_ref->{changes_count}, $before_ref->{changes_count}, "$label keeps changes history unchanged");
	is(
		$after_ref->{latest_product_digest},
		$before_ref->{latest_product_digest},
		"$label keeps latest product state unchanged"
	);
	return;
}

subtest 'Store product fingerprint gate.' => sub {
	my $code = '2999999999101';
	my $user_id = $default_user_form{userid};

	my $create_product_ref = init_product($user_id, undef, $code, undef);
	$create_product_ref->{product_name} = 'Fingerprint Store Product';
	my $before_create = read_persisted_state($code);
	my $create_result = store_product($user_id, $create_product_ref, 'integration create');
	is($create_result, 1, 'Store create returns saved');
	my $after_create = read_persisted_state($code);
	assert_saved_revision($before_create, $after_create, 'store create');

	my $noop_product_ref = retrieve_product($code);
	my $before_noop = read_persisted_state($code);
	my $noop_result = store_product($user_id, $noop_product_ref, 'integration noop');
	is($noop_result, 0, 'Store no-op returns skipped');
	my $after_noop = read_persisted_state($code);
	assert_skipped_revision($before_noop, $after_noop, 'store no-op');

	my $real_change_ref = retrieve_product($code);
	$real_change_ref->{product_name} = 'Fingerprint Store Product Updated';
	my $before_real_change = read_persisted_state($code);
	my $real_change_result = store_product($user_id, $real_change_ref, 'integration real change');
	is($real_change_result, 1, 'Store real change returns saved');
	my $after_real_change = read_persisted_state($code);
	assert_saved_revision($before_real_change, $after_real_change, 'store real change');

	my $whitespace_ref = retrieve_product($code);
	$whitespace_ref->{product_name} = '   Fingerprint Store Product Updated   ';
	my $before_whitespace = read_persisted_state($code);
	my $whitespace_result = store_product($user_id, $whitespace_ref, 'integration whitespace change');
	is($whitespace_result, 0, 'Store whitespace-only change returns skipped');
	my $after_whitespace = read_persisted_state($code);
	assert_skipped_revision($before_whitespace, $after_whitespace, 'store whitespace-only change');

	my $number_as_number_ref = retrieve_product($code);
	$number_as_number_ref->{fingerprint_numeric_test} = 19;
	my $before_number_as_number = read_persisted_state($code);
	my $number_as_number_result = store_product($user_id, $number_as_number_ref, 'integration number as number');
	is($number_as_number_result, 1, 'Store numeric field create returns saved');
	my $after_number_as_number = read_persisted_state($code);
	assert_saved_revision($before_number_as_number, $after_number_as_number, 'store number as number');

	my $number_as_string_ref = retrieve_product($code);
	$number_as_string_ref->{fingerprint_numeric_test} = '19';
	my $before_number_as_string = read_persisted_state($code);
	my $number_as_string_result = store_product($user_id, $number_as_string_ref, 'integration number as string');
	is($number_as_string_result, 0, 'Store numeric-string equivalent returns skipped');
	my $after_number_as_string = read_persisted_state($code);
	assert_skipped_revision($before_number_as_string, $after_number_as_string, 'store number as string equivalent');

	my $number_lexical_diff_ref = retrieve_product($code);
	$number_lexical_diff_ref->{fingerprint_numeric_test} = '019';
	my $before_number_lexical_diff = read_persisted_state($code);
	my $number_lexical_diff_result = store_product($user_id, $number_lexical_diff_ref, 'integration number lexical diff');
	is($number_lexical_diff_result, 1, 'Store numeric lexical difference returns saved');
	my $after_number_lexical_diff = read_persisted_state($code);
	assert_saved_revision($before_number_lexical_diff, $after_number_lexical_diff, 'store number lexical difference');

	my $structural_ref = retrieve_product($code);
	my $server = get_server_for_product($structural_ref);
	ok(defined $server, 'Structural server value is available');
	my $before_structural = read_persisted_state($code);
	$structural_ref->{server} = $server;
	my $structural_result = store_product($user_id, $structural_ref, 'integration structural bypass');
	is($structural_result, 1, 'Store structural flow returns saved');
	my $after_structural = read_persisted_state($code);
	assert_saved_revision($before_structural, $after_structural, 'store structural bypass');

	my $fail_open_ref = retrieve_product($code);
	my $before_fail_open = read_persisted_state($code);
	remove_object("$BASE_DIRS{PRODUCTS}/$before_fail_open->{path}/product");
	my $fail_open_result = store_product($user_id, $fail_open_ref, 'integration fail-open');
	is($fail_open_result, 1, 'Store fail-open path returns saved');
	my $after_fail_open = read_persisted_state($code);
	assert_saved_revision($before_fail_open, $after_fail_open, 'store fail-open');
};

done_testing();
