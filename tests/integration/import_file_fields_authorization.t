#!/usr/bin/perl -w

# The mapping of a producers-platform import arrives as the columns_fields_json request
# parameter of cgi/import_file_process.pl, and every field name it contains becomes a header
# of the converted CSV that the import_csv_file job reads afterwards. A hand written mapping
# can therefore name fields that the mapping interface never offers, and turn a cell into a
# control value for the importer:
#
#   - image_front_en_file / image_front: a local file path, read as the product photo
#   - owner: the owner namespace of another organization
#   - sources_fields:<other organization>:...: the source fields of another organization
#
# This test checks the two layers of the fix: the processing step refuses such a mapping and
# queues no import, and import_csv_file itself refuses those control columns while an
# operator import (local image paths of our own exporter, sources fields of a dataset dump,
# import_owner) keeps working.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP', filter => "info";

use Cwd qw/abs_path/;
use File::Basename "dirname";
use File::Copy "copy";
use File::Path qw/make_path remove_tree/;

use JSON::MaybeXS qw/encode_json/;

use ProductOpener::APITest qw/:all/;
use ProductOpener::Import qw/import_csv_file/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Minion qw/get_minion/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products qw/retrieve_product/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/%default_user_form/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();
remove_all_orgs();
load_data();

my $test_dir = abs_path(dirname(__FILE__));
my $outputs_dir = "$test_dir/outputs/import_file_fields_authorization";
remove_tree($outputs_dir, {safe => 1});
make_path($outputs_dir);

sub write_csv ($file, @rows) {
	open(my $out, '>', $file) or die "cannot write $file: $!";
	binmode($out, ":encoding(UTF-8)");
	foreach my $row_ref (@rows) {
		print $out join("\t", map {defined $_ ? $_ : ''} @{$row_ref}) . "\n";
	}
	close($out);
	return $file;
}

sub import_jobs_created_after ($created_after) {
	my $jobs = get_minion()->jobs({tasks => ["import_csv_file"]});
	my @found = ();
	while (my $job = $jobs->next) {
		push @found, $job if $job->{created} >= $created_after;
	}
	return @found;
}

sub import_products ($csv_file, %extra_args) {
	return import_csv_file(
		{
			user_id => "test-user",
			org_id => "test-org",
			owner_id => "org-test-org",
			csv_file => $csv_file,
			no_source => 1,
			%extra_args,
		}
	);
}

# Number of image files that were actually uploaded to the product (the product also has
# an "images" hashref for the selected images, which is created whether or not an image
# was read, so we count the uploaded ones)

sub uploaded_image_count ($product_ref) {
	return ((defined $product_ref->{images}) and (defined $product_ref->{images}{uploaded}))
		? scalar keys %{$product_ref->{images}{uploaded}}
		: 0;
}

# ---- The processing step refuses a mapping with fields the interface does not offer

my $ua = new_client();
create_user($ua, {%default_user_form, email => 'import.mapping@example.com'});
my $anon_ua = new_client();

my $process_url = construct_test_url('/cgi/import_file_process.pl');

sub post_mapping ($client, $mapping_ref) {
	# Post the parameter ourselves: post_form() dies on non 2xx responses, and a refused
	# request is exactly what we test here
	return $client->post($process_url, Content => {columns_fields_json => encode_json($mapping_ref)});
}

my $queued_from = time();

my @refused_mappings = (
	["a local image path", {barcode => {field => "code"}, photo => {field => "image_front_en_file"}}],
	["a bare local image path", {barcode => {field => "code"}, photo => {field => "image_front"}}],
	["the owner of another organization", {barcode => {field => "code"}, org => {field => "owner"}}],
	[
		"the source fields of another organization",
		{barcode => {field => "code"}, gln => {field => "sources_fields:org-other:gln"}}
	],
	[
		"a moderator only field, sent by a non moderator",
		{barcode => {field => "code"}, s => {field => "sources_fields_specific"}}
	],
	[
		"a field the mapping interface does not offer",
		{barcode => {field => "code"}, n => {field => "no_nutrition_data"}}
	],
);

foreach my $test_case (@refused_mappings) {
	my ($name, $mapping_ref) = @$test_case;
	my $response = post_mapping($ua, $mapping_ref);
	is($response->code, 400, "$name - the request is refused");
	like($response->decoded_content, qr/cannot be imported/, "$name - the error page names the refused fields");
}

# The same refusal applies to a client that is not logged in
my $anon_response = post_mapping($anon_ua, {barcode => {field => "code"}, photo => {field => "image_front_en_file"}});
is($anon_response->code, 400, "a local image path - an anonymous client is refused too");

# A malformed mapping is refused as well
my $invalid_response = $ua->post($process_url, Content => {columns_fields_json => "{not json"});
is($invalid_response->code, 400, "an invalid columns_fields_json parameter is refused");

# A column that does not map to an object is refused too
my $bad_column_response = $ua->post($process_url, Content => {columns_fields_json => encode_json({barcode => "code"})});
is($bad_column_response->code, 400, "a column whose mapping is not an object is refused");

# Control: a mapping built by the mapping interface passes the validation (this deployment
# is not the producers platform, so it stops later, on the owner of the import)
my $valid_mapping_ref = {barcode => {field => "code"}, name => {field => "product_name", lc => "fr"}};
my $valid_response = post_mapping($ua, $valid_mapping_ref);
is($valid_response->code, 200, "a mapping with selectable fields passes the validation");
unlike($valid_response->decoded_content, qr/cannot be imported/, "...and is not refused on its fields");

# None of the refused requests may have queued an import
my @queued_jobs = import_jobs_created_after($queued_from);
is(scalar @queued_jobs, 0, "no import job was queued by the refused requests");

# ---- import_csv_file refuses the control columns of a CSV file

my $images_root = $BASE_DIRS{PRODUCTS_IMAGES};
my $operator_images_dir = "$images_root/import_fields_authorization_test";
make_path($operator_images_dir);
copy("$test_dir/inputs/upload_images/1.jpg", "$operator_images_dir/1.jpg")
	or die "cannot copy the test image: $!";

my $outside_image = abs_path("$test_dir/inputs/upload_images/1.jpg");
my $images_root_abs = abs_path($images_root) // '';
ok(not(($images_root_abs ne '') and (index($outside_image, $images_root_abs) == 0)),
	"the sample image is outside of the images roots");

my $image_columns_ref = [qw/lc code product_name_fr image_front_fr_file/];

# An absolute path outside of the images roots, without the operator flag
my $code_outside = "3000000000101";
import_products(
	write_csv(
		"$outputs_dir/outside_path.csv",
		$image_columns_ref, ["fr", $code_outside, "Outside path", $outside_image],
	)
);
my $product_ref = retrieve_product($code_outside);
ok(defined $product_ref, "the product of the outside path csv was imported");
is(uploaded_image_count($product_ref), 0, "an image path outside of the images roots creates no image")
	or diag(encode_json($product_ref->{images} // {}));

# The same path with the operator flag: still refused, because the file is not inside one
# of the directories an import may read images from (get_local_image_path() logs the
# rejection, which the unit test covers)
my $code_outside_flagged = "3000000000102";
import_products(
	write_csv(
		"$outputs_dir/outside_path_allowed.csv", $image_columns_ref,
		["fr", $code_outside_flagged, "Outside path allowed", $outside_image],
	),
	allow_local_image_paths => 1,
);
$product_ref = retrieve_product($code_outside_flagged);
is(uploaded_image_count($product_ref), 0, "the operator flag does not allow a path outside of the images roots")
	or diag(encode_json($product_ref->{images} // {}));

# Control: the same file inside the images root, imported with the operator flag, is read
# (this is what the exporters to our own public database do with image_*_file columns)
my $code_inside = "3000000000103";
import_products(
	write_csv(
		"$outputs_dir/inside_path.csv", $image_columns_ref,
		["fr", $code_inside, "Inside path", "$operator_images_dir/1.jpg"],
	),
	allow_local_image_paths => 1,
);
$product_ref = retrieve_product($code_inside);
ok(defined $product_ref->{images}{uploaded}{1}, "an image inside the images root is imported by an operator import")
	or diag(encode_json($product_ref->{images} // {}));

# An owner column cannot change the owner the import runs with
my $code_owner = "3000000000104";
import_products(
	write_csv(
		"$outputs_dir/owner.csv", [qw/lc code product_name_fr owner/],
		["fr", $code_owner, "Owner column", "org-victim"],
	)
);
$product_ref = retrieve_product($code_owner);
is($product_ref->{owner}, "org-test-org", "an owner column cannot change the owner of the import");

# Control: an operator import (import_owner) still applies an owner column
my $code_owner_operator = "3000000000105";
import_products(
	write_csv(
		"$outputs_dir/owner_operator.csv", [qw/lc code product_name_fr owner/],
		["fr", $code_owner_operator, "Owner column operator", "org-victim"],
	),
	import_owner => 1,
);
$product_ref = retrieve_product($code_owner_operator);
is($product_ref->{owner}, "org-victim", "the operator import_owner option still applies an owner column");

# The source fields of another source than the importer are refused
my $code_source = "3000000000106";
import_products(
	write_csv(
		"$outputs_dir/source_fields.csv", [qw(lc code product_name_fr sources_fields:org-other:gln)],
		["fr", $code_source, "Source fields", "1234567"],
	)
);
$product_ref = retrieve_product($code_source);
is(defined $product_ref->{sources_fields} ? 1 : 0, 0, "the source fields of another source are refused")
	or diag(encode_json($product_ref->{sources_fields} // {}));

# Control: an operator import (a dataset dump) keeps its source fields
my $code_source_operator = "3000000000107";
import_products(
	write_csv(
		"$outputs_dir/source_fields_operator.csv",
		[qw(lc code product_name_fr sources_fields:org-other:gln)],
		["fr", $code_source_operator, "Source fields operator", "1234567"],
	),
	allow_any_source_fields => 1,
);
$product_ref = retrieve_product($code_source_operator);
is($product_ref->{sources_fields}{"org-other"}{gln}, "1234567", "the operator import accepts source fields");

remove_tree($operator_images_dir, {safe => 1});

done_testing();
