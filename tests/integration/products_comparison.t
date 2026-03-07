#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use HTTP::Request::Common qw(PATCH);
use JSON::MaybeXS ();
use boolean qw/:all/;

use ProductOpener::APITest qw/construct_test_url create_user edit_product new_client wait_application_ready/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products qw/init_product product_path_from_id retrieve_product store_product/;
use ProductOpener::Store qw/object_exists retrieve_object/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;

no warnings qw(experimental::signatures);

my $json = JSON::MaybeXS->new->convert_blessed->canonical->utf8(1);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'products-comparison@example.com'));
create_user($ua, \%create_user_args);

# Serialize persisted product state so no-op checks can compare exact storage output.
sub serialize_product_state ($product_ref) {
	return if not defined $product_ref;
	return if ref($product_ref) ne 'HASH';
	return $json->encode($product_ref);
}

# Read the stored product snapshot so before/after assertions stay compact.
sub read_persisted_state ($product_id) {
	my $path = product_path_from_id($product_id);
	my $latest_product_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/product");
	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes") // [];
	my $last_modified_t;
	my $latest_product_state_json;
	my $product_name;
	my $product_name_en;
	my $rev = 0;

	if (defined $latest_product_ref) {
		$last_modified_t = $latest_product_ref->{last_modified_t};
		$latest_product_state_json = serialize_product_state($latest_product_ref);
		$product_name = $latest_product_ref->{product_name};
		$product_name_en = $latest_product_ref->{product_name_en};
		$rev = int($latest_product_ref->{rev}) if defined $latest_product_ref->{rev};
	}

	return {
		changes_count => scalar @{$changes_ref},
		last_modified_t => $last_modified_t,
		latest_product_state_json => $latest_product_state_json,
		path => $path,
		product_name => $product_name,
		product_name_en => $product_name_en,
		rev => $rev,
	};
}

# Assert saved writes create both a new revision and a new change entry.
sub assert_saved_revision ($before_ref, $after_ref, $label) {
	is($after_ref->{rev}, $before_ref->{rev} + 1, "$label increments rev");
	is($after_ref->{changes_count}, $before_ref->{changes_count} + 1, "$label appends one change entry");
	ok(object_exists("$BASE_DIRS{PRODUCTS}/$after_ref->{path}/$after_ref->{rev}"),
		"$label stores the new revision object");
	return;
}

# Assert skipped writes leave revision history and persisted state untouched.
sub assert_skipped_revision ($before_ref, $after_ref, $label) {
	is($after_ref->{rev}, $before_ref->{rev}, "$label keeps rev unchanged");
	is($after_ref->{changes_count}, $before_ref->{changes_count}, "$label keeps changes history unchanged");
	is(
		$after_ref->{latest_product_state_json},
		$before_ref->{latest_product_state_json},
		"$label keeps latest product state unchanged"
	);
	return;
}

# Send JSON PATCH requests through the test client so API assertions stay focused.
sub patch_json ($ua, $path, $body_ref) {
	my $response = $ua->request(
		PATCH(
			construct_test_url($path),
			Content => $json->encode($body_ref),
			Accept => "application/json",
			"Content-Type" => "application/json; charset=utf-8",
		)
	);

	ok($response->is_success, "PATCH $path succeeds");
	return $response;
}

subtest 'Store product skips no-ops and keeps caller-visible state aligned.' => sub {
	my $code = '2999999999101';
	my $user_id = $default_user_form{userid};

	my $create_product_ref = init_product($user_id, undef, $code, undef);
	$create_product_ref->{product_name} = 'Comparison Store Product';
	my $before_create = read_persisted_state($code);
	ok(store_product($user_id, $create_product_ref, 'integration create'), 'Store create succeeds');
	my $after_create = read_persisted_state($code);
	assert_saved_revision($before_create, $after_create, 'store create');

	my $noop_product_ref = retrieve_product($code);
	$noop_product_ref->{product_name} = '  Comparison Store Product  ';
	my $before_noop = read_persisted_state($code);
	ok(store_product($user_id, $noop_product_ref, 'integration noop'), 'Store no-op stays on the success path');
	my $after_noop = read_persisted_state($code);
	assert_skipped_revision($before_noop, $after_noop, 'store no-op');
	# Check caller-visible fields too so skipped saves do not leave a synthetic in-memory state behind.
	is($noop_product_ref->{rev}, $after_noop->{rev}, 'Store no-op restores the in-memory rev');
	is($noop_product_ref->{last_modified_t}, $after_noop->{last_modified_t}, 'Store no-op restores last_modified_t');
	is(
		serialize_product_state($noop_product_ref),
		$after_noop->{latest_product_state_json},
		'Store no-op restores the in-memory product state'
	);

	my $real_change_ref = retrieve_product($code);
	$real_change_ref->{product_name} = 'Comparison Store Product Updated';
	my $before_real_change = read_persisted_state($code);
	ok(store_product($user_id, $real_change_ref, 'integration real change'), 'Store real change succeeds');
	my $after_real_change = read_persisted_state($code);
	assert_saved_revision($before_real_change, $after_real_change, 'store real change');
};

subtest 'Store product handles blessed booleans without crashing.' => sub {
	my $code = '2999999999102';
	my $user_id = $default_user_form{userid};

	my $create_product_ref = init_product($user_id, undef, $code, undef);
	$create_product_ref->{product_name} = 'Comparison Boolean Product';
	$create_product_ref->{nutrition}{no_nutrition_data_on_packaging} = true;
	my $before_create = read_persisted_state($code);
	ok(store_product($user_id, $create_product_ref, 'integration boolean create'),
		'Store create with blessed booleans succeeds');
	my $after_create = read_persisted_state($code);
	assert_saved_revision($before_create, $after_create, 'store boolean create');

	my $noop_product_ref = retrieve_product($code);
	my $before_noop = read_persisted_state($code);
	ok(store_product($user_id, $noop_product_ref, 'integration boolean noop'), 'Store boolean no-op succeeds');
	my $after_noop = read_persisted_state($code);
	assert_skipped_revision($before_noop, $after_noop, 'store boolean no-op');
};

subtest 'Legacy API v2 keeps success semantics for no-op writes.' => sub {
	my $code = '2999999999103';
	my %edit_fields = (
		cc => 'fr',
		code => $code,
		lc => 'en',
		product_name => 'Legacy Comparison Product',
	);

	edit_product($ua, \%edit_fields);

	my $before_noop = read_persisted_state($code);
	my $response = edit_product($ua, \%edit_fields);
	my $after_noop = read_persisted_state($code);
	my $response_ref = JSON::MaybeXS::decode_json($response->decoded_content);

	assert_skipped_revision($before_noop, $after_noop, 'legacy API v2 no-op');
	is($response_ref->{status}, 1, 'Legacy API v2 no-op still returns success');
	is($response_ref->{status_verbose}, 'fields saved', 'Legacy API v2 no-op still reports fields saved');
};

subtest 'API v3 returns the persisted state after a skipped save.' => sub {
	my $code = '2999999999104';
	patch_json(
		$ua,
		"/api/v3/product/$code",
		{
			fields => 'rev,last_modified_t,product_name_en',
			product => {
				product_name_en => 'API v3 Comparison Product',
			},
			tags_lc => 'en',
		}
	);

	my $before_noop = read_persisted_state($code);
	my $response = patch_json(
		$ua,
		"/api/v3/product/$code",
		{
			fields => 'rev,last_modified_t,product_name_en',
			product => {
				product_name_en => '  API v3 Comparison Product  ',
			},
			tags_lc => 'en',
		}
	);
	my $after_noop = read_persisted_state($code);
	my $response_ref = JSON::MaybeXS::decode_json($response->decoded_content);

	assert_skipped_revision($before_noop, $after_noop, 'API v3 no-op');
	is($response_ref->{product}{rev}, $after_noop->{rev}, 'API v3 no-op returns the persisted rev');
	is(
		$response_ref->{product}{last_modified_t},
		$after_noop->{last_modified_t},
		'API v3 no-op returns the persisted last_modified_t'
	);
	is(
		$response_ref->{product}{product_name_en},
		$after_noop->{product_name_en},
		'API v3 no-op returns the persisted product_name_en'
	);
};

done_testing();
