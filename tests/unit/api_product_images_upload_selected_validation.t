#!/usr/bin/perl -w

# Validate the `selected` parameter of API v3 product image upload requests
# so malformed structures return HTTP 400 validation errors instead of HTTP 500 crashes.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::API qw/get_initialized_response/;
use ProductOpener::APIProductImagesUpload qw/is_valid_selected_images_param upload_product_image_api/;

subtest 'valid selected inputs are accepted' => sub {
	my @valid_cases = (
		{
			name => 'undef (omitted or null)',
			selected => undef,
		},
		{
			name => 'empty hash',
			selected => {},
		},
		{
			name => 'valid image type and language with empty hash',
			selected => {front => {en => {}}},
		},
		{
			name => 'valid generation hash',
			selected => {
				ingredients => {
					fr => {
						generation => {
							angle => 90,
							x1 => 10,
							y1 => 20,
							x2 => 100,
							y2 => 200,
						},
					},
				},
			},
		},
		{
			name => 'valid entry with undef generation',
			selected => {front => {en => {generation => undef}}},
		},
	);

	foreach my $case (@valid_cases) {
		my $response_ref = get_initialized_response();
		is(is_valid_selected_images_param($case->{selected}, $response_ref), 1, "$case->{name}: returns 1");
		is($response_ref->{errors}, [], "$case->{name}: adds no errors");
		is($response_ref->{status_code}, undef, "$case->{name}: does not set error status_code");
	}
};

subtest 'invalid selected inputs return 400 validation errors' => sub {
	my @invalid_cases = (
		{
			name => 'selected is a string',
			selected => 'front',
			expected_fields => ['selected'],
		},
		{
			name => 'selected is an array',
			selected => ['front'],
			expected_fields => ['selected'],
		},
		{
			name => 'image type value is a string (issue #12420)',
			selected => {front => 'en'},
			expected_fields => ['selected.front'],
		},
		{
			name => 'image type value is an array',
			selected => {front => ['en']},
			expected_fields => ['selected.front'],
		},
		{
			name => 'image type value is undef',
			selected => {front => undef},
			expected_fields => ['selected.front'],
		},
		{
			name => 'language value is a string',
			selected => {front => {en => '1'}},
			expected_fields => ['selected.front.en'],
		},
		{
			name => 'language value is undef',
			selected => {front => {en => undef}},
			expected_fields => ['selected.front.en'],
		},
		{
			name => 'language value is an array',
			selected => {front => {en => []}},
			expected_fields => ['selected.front.en'],
		},
		{
			name => 'generation value is not an object',
			selected => {front => {en => {generation => 'rotate90'}}},
			expected_fields => ['selected.front.en.generation'],
		},
		{
			name => 'mixed valid and invalid entries',
			selected => {front => {en => {}}, nutrition => 'fr'},
			expected_fields => ['selected.nutrition'],
		},
		{
			name => 'multiple invalid entries are reported in sorted order',
			selected => {nutrition => 'fr', front => 'en'},
			expected_fields => ['selected.front', 'selected.nutrition'],
		},
	);

	foreach my $case (@invalid_cases) {
		my $response_ref = get_initialized_response();
		is(is_valid_selected_images_param($case->{selected}, $response_ref), 0, "$case->{name}: returns 0");
		is($response_ref->{status_code}, 400, "$case->{name}: sets HTTP 400 status_code");

		my @expected_errors = ();
		foreach my $field_id (@{$case->{expected_fields}}) {
			my $expected_error_ref = {
				message => {id => 'invalid_type_must_be_object'},
				field => {id => $field_id},
				impact => {id => 'failure'},
			};
			push @expected_errors, $expected_error_ref;
		}

		is($response_ref->{errors}, \@expected_errors, "$case->{name}: adds expected errors");
	}
};

subtest 'upload_product_image_api rejects malformed selected before uploading' => sub {
	my $response_ref = get_initialized_response();
	my $request_ref = {
		code => '1234567890012',
		api_response => $response_ref,
		body_json => {
			image_data_base64 => 'not-even-decoded-because-selected-fails-first',
			selected => {front => 'en'},
		},
	};

	upload_product_image_api($request_ref);

	my $expected_errors_ref = [
		{
			message => {id => 'invalid_type_must_be_object'},
			field => {id => 'selected.front'},
			impact => {id => 'failure'},
		},
	];

	is($response_ref->{status_code}, 400, 'returns HTTP 400 instead of dying');
	is($response_ref->{result}, undef, 'does not attempt image upload');
	is($response_ref->{errors}, $expected_errors_ref, 'returns invalid_type_must_be_object error on selected.front');
};

done_testing();
