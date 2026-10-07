#!/usr/bin/perl -w

# The column mapping of an import is supplied by the caller (columns_fields_json):
# check that only the fields the mapping interface can offer are accepted, and
# that the control fields (local image paths, owner, source fields of another
# organization) are always refused.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use File::Path qw/make_path remove_tree/;

use ProductOpener::Config qw/%options/;
use ProductOpener::Food qw/%cc_nutrient_table/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Producers
	qw/create_off_columns_to_input_columns_match generate_import_export_columns_groups_for_select2 get_selectable_import_fields is_import_field_allowed/;
use ProductOpener::Import qw/get_local_image_path/;

load_data();

# init_request() sets the nutrient table for each web request
$ProductOpener::Display::nutrient_table = $cc_nutrient_table{off_default};

subtest 'fields the mapping interface offers' => sub {

	my $allowed_fields_ref = get_selectable_import_fields();

	# Identification, origins, ingredients, other and packaging groups
	foreach my $field (
		'code', 'lc', 'producer_product_id', 'producer_version_id',
		'product_name', 'abbreviated_product_name', 'generic_name',
		'quantity_value_unit', 'net_weight_value_unit', 'drained_weight_value_unit',
		'volume_value_unit', 'serving_size_value_unit', 'packaging',
		'brands', 'brand_owner', 'categories', 'categories_specific', 'labels', 'labels_specific',
		'countries', 'stores', 'obsolete', 'obsolete_since_date', 'periods_after_opening',
		'origins', 'origin', 'manufacturing_places', 'producer', 'emb_codes',
		'ingredients_text', 'allergens', 'traces',
		'conservation_conditions', 'warning', 'preparation', 'nutriscore_score_producer',
		'nutriscore_grade_producer', 'nova_group_producer', 'recipe_idea', 'customer_service',
		'link', 'packaging_text', 'recycling_instructions_to_recycle', 'recycling_instructions_to_discard',
		# Field that our own converters emit (GS1 partyName)
		'org_name'
		)
	{
		ok($allowed_fields_ref->{$field}, "selectable: $field")
			or diag Dumper([sort keys %$allowed_fields_ref]);
		ok(is_import_field_allowed($field, undef), "allowed: $field");
	}

	# Nutrition fields: nutrients of the table, and of the taxonomy (as proposed
	# by the automatic column matching)
	foreach my $field (
		'energy_100g_value_unit', 'energy-kcal_100g_value_unit',
		'energy-kj_100g_value_unit', 'carbohydrates_100g_value_unit',
		'saturated-fat_100g_value_unit', 'sugars_serving_value_unit',
		'proteins_prepared_100g_value_unit', 'fruits-vegetables-nuts_100g_value_unit',
		'iron_serving_value_unit'
		)
	{
		ok($allowed_fields_ref->{$field}, "selectable: $field")
			or diag Dumper([sort keys %$allowed_fields_ref]);
		ok(is_import_field_allowed($field, undef), "allowed: $field");
	}

	# Packaging components
	foreach my $field (
		'packaging_1_shape', 'packaging_1_material',
		'packaging_1_recycling', 'packaging_1_number_of_units',
		'packaging_1_quantity_per_unit', 'packaging_1_weight_specified',
		'packaging_4_recycling', 'packaging_6_shape'
		)
	{
		ok($allowed_fields_ref->{$field}, "selectable: $field");
		ok(is_import_field_allowed($field, undef), "allowed: $field");
	}

	# Image columns: the language of the image column can be any language
	foreach my $field (
		'image_front_url_fr', 'image_front_url_en', 'image_ingredients_url_de', 'image_nutrition_url_pt',
		'image_packaging_url_zh'
		)
	{
		ok(is_import_field_allowed($field, undef), "allowed: $field");
	}

	foreach my $field ('image_other_url', 'image_other_type') {
		ok($allowed_fields_ref->{$field}, "selectable: $field");
		ok(is_import_field_allowed($field, undef), "allowed: $field");
	}

	return;
};

subtest 'fields that must never be accepted' => sub {

	my $allowed_fields_ref = get_selectable_import_fields();

	foreach my $field (
		# Ownership
		'owner',
		# Import bookkeeping
		'imports',
		# Not offered by the mapping interface
		'no_nutrition_data',
		# Local image paths: would let an import read an arbitrary file of the server
		'image_front_en_file', 'image_front_fr_file', 'image_ingredients_file',
		'image_nutrition_file', 'image_other_file', 'image_front_file',
		# Bare image fields are also local paths for import_csv_file
		'image_front', 'image_ingredients', 'image_nutrition', 'image_packaging', 'image_other',
		# Source fields of any organization
		'sources_fields:org-other:gln', 'sources_fields:org-other:fdc_id',
		'sources_fields:all:nutrient',
		# Anything else that is not offered by the mapping interface
		'images_dir', 'data_sources', 'text', 'product_name_invalid', 'image_front_url'
		)
	{
		ok(!$allowed_fields_ref->{$field}, "not selectable: $field");
		ok(!is_import_field_allowed($field, undef), "refused: $field");
	}

	ok(!is_import_field_allowed(undef, undef), "refused: undef");
	ok(!is_import_field_allowed('', undef), "refused: empty string");

	return;
};

subtest 'sources_fields_specific is only selectable by moderators' => sub {

	is(is_import_field_allowed('sources_fields_specific', undef), 0, "not allowed for a regular user");

	local $ProductOpener::Users::User{pro_moderator_owner} = 'org-my-org';

	is(is_import_field_allowed('sources_fields_specific', undef), 1, "allowed for a moderator");

	# The moderator-only group must not leak into the configuration used for the next request
	generate_import_export_columns_groups_for_select2(['en']);
	generate_import_export_columns_groups_for_select2(['en']);

	return;
};

subtest 'the select2 options do not accumulate in the configuration' => sub {

	my $groups_before = [map {$_->[0]} @{$options{import_export_fields_groups}}];

	local $ProductOpener::Users::User{pro_moderator_owner} = 'org-my-org';

	generate_import_export_columns_groups_for_select2(['en']);
	generate_import_export_columns_groups_for_select2(['en']);

	my $groups_after = [map {$_->[0]} @{$options{import_export_fields_groups}}];

	is($groups_after, $groups_before, "the global list of field groups is not modified");

	return;
};

subtest 'columns mapped to a refused field are dropped' => sub {

	my $input_headers_ref = ["Nom du produit", "Code-barres", "Proprietaire", "Image avant", "Glucides"];
	my $columns_fields_ref = {
		"Nom du produit" => {field => "product_name", lc => "fr"},
		"Code-barres" => {field => "code"},
		"Proprietaire" => {field => "owner"},
		"Image avant" => {field => "image_front_en_file"},
		"Glucides" => {field => "carbohydrates_100g_value_unit", value_unit => "value"},
	};

	my @output_headers = ();
	my %output_to_input_columns = ();

	create_off_columns_to_input_columns_match({}, $input_headers_ref, $columns_fields_ref, \@output_headers,
		\%output_to_input_columns);

	is(
		\@output_headers,
		["product_name_fr", "code", "carbohydrates_100g_value"],
		"only the fields that can be imported are kept"
	) or diag Dumper(\@output_headers);

	is($output_to_input_columns{code}, 1, "the barcode column is mapped");
	ok(!exists $output_to_input_columns{owner}, "the owner column is dropped");
	ok(!exists $output_to_input_columns{image_front_en_file}, "the local image column is dropped");

	return;
};

subtest 'local image paths are only read for operator imports' => sub {

	my $tmp_dir = "/tmp/import_fields_allowlist_test";
	my $images_dir = "$tmp_dir/images";
	my $outside_dir = "$tmp_dir/outside";

	remove_tree($tmp_dir);
	make_path($images_dir, $outside_dir);

	open(my $in, ">", "$images_dir/product.jpg") or die $!;
	print $in "fake image";
	close($in);

	open(my $out, ">", "$outside_dir/secret.txt") or die $!;
	print $out "secret";
	close($out);

	# Without the explicit flag, no local file is read at all
	is(get_local_image_path({images_dir => $images_dir}, "$images_dir/product.jpg"),
		undef, "local paths are refused when the import does not allow them");

	my $args_ref = {allow_local_image_paths => 1, images_dir => $images_dir};

	is(get_local_image_path($args_ref, "$images_dir/product.jpg"),
		"$images_dir/product.jpg", "a file inside the images directory is accepted");

	is(get_local_image_path($args_ref, "$images_dir/../outside/secret.txt"),
		undef, "a file outside of the images directory is refused");

	is(get_local_image_path($args_ref, "$outside_dir/secret.txt"), undef, "another absolute path is refused");

	is(get_local_image_path($args_ref, "/etc/passwd"), undef, "/etc/passwd is refused");

	is(get_local_image_path($args_ref, "$images_dir/missing.jpg"),
		"$images_dir/missing.jpg",
		"a missing file inside the images directory keeps its path (the file is checked by the caller)");

	is(get_local_image_path($args_ref, "$images_dir/../outside/missing.txt"),
		undef, "a missing file outside of the images directory is refused");

	is(get_local_image_path($args_ref, undef), undef, "an undefined path is refused");
	is(get_local_image_path(undef, "$images_dir/product.jpg"), undef, "no import arguments is refused");

	remove_tree($tmp_dir);

	return;
};

done_testing();
