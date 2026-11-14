#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Storable qw/dclone/;

use ProductOpener::ProductSchemaChanges qw/convert_product_schema/;
use ProductOpener::ProductsTags qw/renormalize_packager_codes_field set_field_input_tags_for_source/;
use ProductOpener::Tags qw/init_emb_codes %emb_codes_cities/;

init_emb_codes();

subtest 'renormalize all sources and preserve their metadata' => sub {
	my $product_ref = {
		schema_version => 1004,
		tags_sources => {
			emb_codes => {
				packaging => {
					tags => ["de-by-777-23-ec", "de-by77723-ec", "uk-lk-002-ec"],
					last_updated_t => 1700000000,
				},
				manufacturer => {
					tags => ["de-by-77723-ec", "nl-z-0160-ec"],
					last_updated_t => 1700000001,
				},
				other => {last_updated_t => 1700000002},
			},
			labels => {packaging => {tags => ["en:organic"], last_updated_t => 1700000003}},
		},
		emb_codes_tags => ["de-by-777-23-ec", "de-by77723-ec", "nl-z-0160-ec", "uk-lk-002-ec"],
		cities_tags => [],
	};
	my $original_ref = dclone($product_ref);

	is(renormalize_packager_codes_field($product_ref), 1, "source changes are reported");
	is(
		$product_ref->{tags_sources}{emb_codes},
		{
			packaging => {tags => ["de-by77723-ec", "uk-lk002-ec"], last_updated_t => 1700000000},
			manufacturer => {tags => ["de-by77723-ec", "nl-z0160-ec"], last_updated_t => 1700000001},
			other => {last_updated_t => 1700000002},
		},
		"equivalent spellings are deduplicated within each source, with timestamps preserved"
	);
	is(
		$product_ref->{emb_codes_tags},
		["de-by77723-ec", "nl-z0160-ec", "uk-lk002-ec"],
		"final tags include the normalized codes from every source"
	);
	is($product_ref->{tags_sources}{labels}, $original_ref->{tags_sources}{labels}, "other sources are preserved");
	ok(!exists $product_ref->{emb_codes}, "the obsolete emb_codes field is not recreated");

	my $normalized_ref = dclone($product_ref);
	is(renormalize_packager_codes_field($product_ref), 0, "a second migration is a no-op");
	is($product_ref, $normalized_ref, "a second migration leaves the product unchanged");
};

subtest 'legacy products upgraded by the retrieval schema conversion' => sub {
	my $product_ref = {
		schema_version => 1003,
		emb_codes => "  DE BY-30410 EC  ",
		emb_codes_tags => ["de-by-30410-ec"],
		last_modified_t => 1700000000,
	};
	convert_product_schema($product_ref, 1004);
	ok(!exists $product_ref->{emb_codes}, "schema conversion removes the old field");
	is(renormalize_packager_codes_field($product_ref), 1, "the upgraded product is migrated");
	is(
		$product_ref->{tags_sources}{emb_codes}{packaging},
		{tags => ["de-by30410-ec"], last_updated_t => 1700000000},
		"the upgraded source is renormalized"
	);
	is($product_ref->{emb_codes_tags}, ["de-by30410-ec"], "the final tags are regenerated");
	is(renormalize_packager_codes_field($product_ref), 0, "legacy whitespace is handled in a single migration");
};

subtest 'Belgian and Italian establishments remain distinct' => sub {
	my $product_ref = {schema_version => 1004};
	set_field_input_tags_for_source($product_ref, "en", "emb_codes", "packaging",
		"BE 1/11 EC, BE 11/1 EC, BE 13/1 EC, BE 131 EC, BE 1/31 EC, IT 180-1 EC, IT 1801 EC",
		0, 1700000000);
	my $original_ref = dclone($product_ref);
	is(renormalize_packager_codes_field($product_ref), 0, "significant separators are preserved during migration");
	is(
		$product_ref->{emb_codes_tags},
		["be-1-11-ec", "be-1-31-ec", "be-11-1-ec", "be-13-1-ec", "be-131-ec", "it-180-1-ec", "it-1801-ec"],
		"all seven establishments retain different tags"
	);
	is($product_ref, $original_ref, "already canonical codes do not need saving");
};

subtest 'repairs to derived tags are reported even when sources are canonical' => sub {
	foreach my $tags_ref (undef, ["de-by-30410-ec"]) {
		my $product_ref = {
			tags_sources => {
				emb_codes => {packaging => {tags => ["de-by30410-ec"], last_updated_t => 1700000000}},
			},
			cities_tags => [],
		};
		$product_ref->{emb_codes_tags} = $tags_ref if defined $tags_ref;
		my $sources_ref = dclone($product_ref->{tags_sources});
		is(renormalize_packager_codes_field($product_ref), 1, "missing or stale derived tags require saving");
		is($product_ref->{emb_codes_tags}, ["de-by30410-ec"], "derived tags are repaired");
		is($product_ref->{tags_sources}, $sources_ref, "canonical sources and metadata are preserved");
		is(renormalize_packager_codes_field($product_ref), 0, "the repair is idempotent");
	}
};

subtest 'source-only repairs are saved' => sub {
	my $product_ref = {
		tags_sources => {emb_codes => {packaging => {tags => ["de-by-30410-ec"], last_updated_t => 1700000000}}},
		emb_codes_tags => ["de-by30410-ec"],
		cities_tags => [],
	};
	is(renormalize_packager_codes_field($product_ref), 1, "a source-only change requires saving");
	is($product_ref->{tags_sources}{emb_codes}{packaging}{tags}, ["de-by30410-ec"], "the source is repaired");
	is($product_ref->{emb_codes_tags}, ["de-by30410-ec"], "the derived tags remain canonical");
	is(renormalize_packager_codes_field($product_ref), 0, "the source repair is idempotent");
};

subtest 'city-only repairs are saved' => sub {
	local $emb_codes_cities{FREMB69238} = "Test City";
	my $product_ref = {
		tags_sources => {emb_codes => {packaging => {tags => ["fr-69-238-010-ec"], last_updated_t => 1700000000}}},
		emb_codes_tags => ["fr-69-238-010-ec"],
		cities_tags => ["stale-city"],
	};
	is(renormalize_packager_codes_field($product_ref), 1, "a city-only change requires saving");
	is($product_ref->{cities_tags}, ["test-city"], "the city is regenerated from the packager code");
	is(renormalize_packager_codes_field($product_ref), 0, "the city repair is idempotent");
};

subtest 'products with no codes and empty sources' => sub {
	my $product_ref = {};
	is(renormalize_packager_codes_field($product_ref), 0, "a product without packager sources is skipped");
	is($product_ref, {}, "skipping a product does not add empty fields");

	$product_ref = {
		tags_sources => {emb_codes => {packaging => {tags => [], last_updated_t => 1700000000}}},
		emb_codes_tags => ["de-by-30410-ec"],
		cities_tags => ["stale-city"],
	};
	is(renormalize_packager_codes_field($product_ref), 1, "empty sources clear stale derived fields");
	is($product_ref->{emb_codes_tags}, [], "stale packager tags are cleared");
	is($product_ref->{cities_tags}, [], "stale cities are cleared");
	is(renormalize_packager_codes_field($product_ref), 0, "empty sources are subsequently a no-op");
};

done_testing();
