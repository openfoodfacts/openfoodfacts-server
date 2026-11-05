#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Clone qw(clone);

use ProductOpener::Ingredients qw/select_ingredients_lc/;

my $images_ref = {
	uploaded => {
		9 => {uploaded_t => 1617235200},
		4 => {uploaded_t => 1698796800},
		1 => {uploaded_t => 1759276800},
		10 => {uploaded_t => 1761955200},
		11 => {uploaded_t => 1762041600},
	},
	selected => {
		ingredients => {
			bg => {imgid => 9, rev => 30},
			de => {imgid => 4, rev => 20},
			it => {imgid => 1, rev => 10},
		},
		front => {bg => {imgid => 11, rev => 40}},
		nutrition => {bg => {imgid => 11, rev => 40}},
	},
};

my $base_product_ref = {
	lc => 'en',
	ingredients_text_en => '',
	ingredients_text_bg => 'захар, сол',
	ingredients_text_de => 'Zucker, Salz',
	ingredients_text_it => 'zucchero, sale',
	images => $images_ref,
};

my $missing_timestamp_images_ref = clone($images_ref);
delete $missing_timestamp_images_ref->{uploaded}{1}{uploaded_t};

my $tied_timestamp_images_ref = clone($images_ref);
$tied_timestamp_images_ref->{uploaded}{1}{uploaded_t} = 1617235200;
$tied_timestamp_images_ref->{uploaded}{4}{uploaded_t} = 1617235200;

my $invalid_timestamp_images_ref = clone($images_ref);
$invalid_timestamp_images_ref->{uploaded}{9}{uploaded_t} = 'invalid';
$invalid_timestamp_images_ref->{uploaded}{4}{uploaded_t} = -1;
$invalid_timestamp_images_ref->{uploaded}{1}{uploaded_t} = undef;

my @tests = (
	{
		desc => 'newest uploaded selected ingredients photo wins, not selection revision or image id',
		expected_lc => 'it',
	},
	{
		desc => 'main-language ingredients remain preferred',
		fields => {ingredients_text_en => 'sugar, salt'},
		expected_lc => 'en',
	},
	{
		desc => 'missing main-language ingredients use the newest photo',
		remove_fields => ['ingredients_text_en'],
		expected_lc => 'it',
	},
	{
		desc => 'undefined main-language ingredients use the newest photo',
		fields => {ingredients_text_en => undef},
		expected_lc => 'it',
	},
	{
		desc => 'empty ingredients for the newest photo are skipped',
		fields => {ingredients_text_it => ''},
		expected_lc => 'de',
	},
	{
		desc => 'undefined ingredients for the newest photo are skipped',
		fields => {ingredients_text_it => undef},
		expected_lc => 'de',
	},
	{
		desc => 'a selected photo without an ingredients text field is skipped',
		remove_fields => ['ingredients_text_it'],
		expected_lc => 'de',
	},
	{
		desc => 'multiple languages without ingredients are skipped',
		fields => {ingredients_text_it => '', ingredients_text_de => undef},
		expected_lc => 'bg',
	},
	{
		desc => 'text without a selected photo is used when photo languages have no ingredients',
		fields => {
			ingredients_text_bg => '',
			ingredients_text_de => '',
			ingredients_text_it => '',
			ingredients_text_es => 'azúcar, sal',
		},
		expected_lc => 'es',
	},
	{
		desc => 'a missing main language does not prevent selecting localized ingredients',
		remove_fields => ['lc'],
		expected_lc => 'it',
	},
	{
		desc => 'missing images preserve the alphabetical fallback without creating image metadata',
		remove_fields => ['images'],
		expected_lc => 'bg',
	},
	{
		desc => 'undefined images preserve the alphabetical fallback',
		fields => {images => undef},
		expected_lc => 'bg',
	},
	{
		desc => 'empty images preserve the alphabetical fallback',
		fields => {images => {}},
		expected_lc => 'bg',
	},
	{
		desc => 'front photos do not supply ingredients photo timestamps',
		fields => {
			images => {
				uploaded => $images_ref->{uploaded},
				selected => {front => {bg => {imgid => 11, rev => 40}}},
			},
		},
		expected_lc => 'bg',
	},
	{
		desc => 'selected images without uploaded source metadata preserve the alphabetical fallback',
		fields => {images => {selected => $images_ref->{selected}}},
		expected_lc => 'bg',
	},
	{
		desc => 'incomplete selected ingredients images preserve the alphabetical fallback',
		fields => {
			images => {
				uploaded => $images_ref->{uploaded},
				selected => {ingredients => {bg => undef, de => {}, it => {rev => 10}}},
			},
		},
		expected_lc => 'bg',
	},
	{
		desc => 'a missing upload timestamp falls back to the next dated ingredients photo',
		fields => {images => $missing_timestamp_images_ref},
		expected_lc => 'de',
	},
	{
		desc => 'equal upload timestamps use alphabetical order',
		fields => {images => $tied_timestamp_images_ref},
		expected_lc => 'bg',
	},
	{
		desc => 'upload timestamps are compared numerically, including numeric strings',
		fields => {
			images => {
				uploaded => {9 => {uploaded_t => 9}, 4 => {uploaded_t => 2}, 1 => {uploaded_t => '10'}},
				selected => $images_ref->{selected},
			},
		},
		expected_lc => 'it',
	},
	{
		desc => 'the same source photo selected in multiple languages uses alphabetical order',
		fields => {
			images => {
				uploaded => $images_ref->{uploaded},
				selected => {
					ingredients => {
						bg => {imgid => 1, rev => 30},
						de => {imgid => 1, rev => 20},
						it => {imgid => 1, rev => 10},
					},
				},
			},
		},
		expected_lc => 'bg',
	},
	{
		desc => 'invalid or missing upload timestamps preserve the alphabetical fallback',
		fields => {images => $invalid_timestamp_images_ref},
		expected_lc => 'bg',
	},
	{
		desc => 'legacy ingredients_text keeps the main-language fallback',
		fields => {ingredients_text => 'sugar, salt', ingredients_lc => 'fr'},
		remove_fields => [qw/ingredients_text_en ingredients_text_bg ingredients_text_de ingredients_text_it/],
		expected_lc => 'en',
	},
	{
		desc => 'no ingredients text removes a stale ingredients language',
		fields => {
			ingredients_text_bg => undef,
			ingredients_text_de => '',
			ingredients_text_it => '',
			ingredients_text => '',
			ingredients_lc => 'fr',
		},
		expected_lc => undef,
	},
	{
		desc => 'legacy text without a main language cannot select an ingredients language',
		fields => {ingredients_text => 'sugar, salt', ingredients_lc => 'fr'},
		remove_fields => [qw/lc ingredients_text_en ingredients_text_bg ingredients_text_de ingredients_text_it/],
		expected_lc => undef,
	},
);

foreach my $invalid_timestamp (undef, '', 'not-a-timestamp', '1759276800oops', -1) {
	my $invalid_images_ref = clone($images_ref);
	$invalid_images_ref->{uploaded}{1}{uploaded_t} = $invalid_timestamp;
	push @tests,
		{
		desc => 'skip an invalid newest photo timestamp: ' . ($invalid_timestamp // 'undef'),
		fields => {images => $invalid_images_ref},
		expected_lc => 'de',
		};
}

foreach my $test_ref (@tests) {
	subtest $test_ref->{desc} => sub {
		my $product_ref = clone({%{$base_product_ref}, %{$test_ref->{fields} // {}}});
		foreach my $field (@{$test_ref->{remove_fields} // []}) {
			delete $product_ref->{$field};
		}

		my $expected_product_ref = clone($product_ref);
		my $expected_lc = $test_ref->{expected_lc};
		if (defined $expected_lc) {
			$expected_product_ref->{ingredients_lc} = $expected_lc;
			my $localized_text = $product_ref->{'ingredients_text_' . $expected_lc};
			if (defined $localized_text) {
				$expected_product_ref->{ingredients_text} = $localized_text;
			}
		}
		else {
			delete $expected_product_ref->{ingredients_lc};
		}

		is(select_ingredients_lc($product_ref), $expected_lc, 'returns the expected ingredients language');
		is($product_ref, $expected_product_ref, 'only ingredients_text and ingredients_lc are updated');
		is(select_ingredients_lc($product_ref), $expected_lc, 'repeated selection returns the same language');
		is($product_ref, $expected_product_ref, 'repeated selection leaves the product unchanged');
	};
}

done_testing();
