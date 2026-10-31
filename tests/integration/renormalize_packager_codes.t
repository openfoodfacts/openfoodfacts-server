#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products qw/product_path_from_id/;
use ProductOpener::Store qw/retrieve_object store_object link_object/;
use ProductOpener::Test qw/remove_all_products/;

# This migration uses the product files and MongoDB directly; it does not call HTTP APIs.
remove_all_products();

my $timestamp = 1700000000;
my @be_tags = ("be-1-11-ec", "be-11-1-ec");
my @products = (
	{
		code => "2000000000001",
		schema_version => 1003,
		emb_codes => "  DE BY-30410 EC  ",
		emb_codes_tags => ["de-by-30410-ec"],
	},
	{
		code => "2000000000002",
		schema_version => 1004,
		tags_sources => {emb_codes => {packaging => {tags => ["de-by30410-ec"], last_updated_t => $timestamp}}},
		emb_codes_tags => ["de-by-30410-ec"],
		cities_tags => [],
	},
	{
		code => "2000000000003",
		schema_version => 1004,
		tags_sources => {emb_codes => {packaging => {tags => [@be_tags], last_updated_t => $timestamp}}},
		emb_codes_tags => [@be_tags],
		cities_tags => [],
	},
	{
		code => "2000000000004",
		schema_version => 1004,
		tags_sources => {emb_codes => {packaging => {tags => ["de-by-30410-ec"], last_updated_t => $timestamp}}},
		emb_codes_tags => ["de-by-30410-ec"],
		deleted => "on",
	},
	{code => "2000000000005", schema_version => 1004, tags_sources => {}},
);

my $products_collection = get_products_collection();
my %original_products;
foreach my $product_ref (@products) {
	my $code = $product_ref->{code};
	$product_ref->{_id} = "$code";
	$product_ref->{rev} = 1;
	$product_ref->{created_t} = $timestamp;
	$product_ref->{last_modified_t} = $timestamp;
	$product_ref->{last_updated_t} = $timestamp;
	$product_ref->{lc} = "en";
	$product_ref->{lang} = "en";
	$product_ref->{product_type} = "food";
	$product_ref->{product_name} = "Packager migration test";
	my $path = "$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code);
	# Store raw fixtures so retrieval must perform the real schema upgrade.
	store_object("$path/1", $product_ref);
	store_object("$path/changes",
		[{userid => "test", t => $timestamp, rev => 1, comment => "Create migration fixture"}]);
	link_object(1, "$path/product");
	$products_collection->insert_one($product_ref) unless $product_ref->{deleted};
	$original_products{$code} = retrieve_object("$path/product");
}

sub run_migration (@args) {
	open(my $output, "-|", $^X, "scripts/migrations/2026_10_renormalize_packager_codes.pl", @args)
		or die "Cannot run packager-code migration: $!";
	my $text = do {local $/; <$output>};
	close($output);
	return ($?, $text);
}

my ($status, $output) = run_migration("--dry-run");
is($status, 0, "dry-run completes successfully");
like($output, qr/Would renormalize 2000000000001: de-by30410-ec/, "dry-run reports a legacy product");
like($output, qr/Would renormalize 2000000000002: de-by30410-ec/, "dry-run reports a derived-tags-only repair");
like($output, qr/Processed 5 products, 2 products would be updated/, "dry-run reports changes without claiming saves");

foreach my $product_ref (@products) {
	my $code = $product_ref->{code};
	my $path = "$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code);
	is(retrieve_object("$path/product"), $original_products{$code}, "$code: dry-run does not change product files");
	if (not $product_ref->{deleted}) {
		is($products_collection->find_id($code), $original_products{$code}, "$code: dry-run does not change MongoDB");
	}
}

($status, $output) = run_migration();
is($status, 0, "migration completes successfully");
like($output, qr/Processed 5 products, 2 products updated/, "only the two changed products are saved");

my %migrated_products;
foreach my $product_ref (@products) {
	my $code = $product_ref->{code};
	my $path = "$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code);
	my $stored_ref = retrieve_object("$path/product");
	$migrated_products{$code} = $stored_ref;
	if (($code eq "2000000000001") or ($code eq "2000000000002")) {
		is(
			$stored_ref->{tags_sources}{emb_codes}{packaging},
			{tags => ["de-by30410-ec"], last_updated_t => $timestamp},
			"$code: normalized sources are persisted"
		);
		is($stored_ref->{emb_codes_tags}, ["de-by30410-ec"], "$code: final tags are persisted");
		is($products_collection->find_id($code)->{emb_codes_tags}, ["de-by30410-ec"], "$code: MongoDB is updated");
		ok(!exists $stored_ref->{emb_codes}, "$code: the current schema is retained");
	}
	else {
		is($stored_ref, $original_products{$code}, "$code: unchanged, deleted, or code-free products are preserved");
	}
}

($status, $output) = run_migration();
is($status, 0, "a second migration completes successfully");
like($output, qr/Processed 5 products, 0 products updated/, "a second migration is a no-op");
foreach my $product_ref (@products) {
	my $code = $product_ref->{code};
	my $path = "$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code);
	is(retrieve_object("$path/product"), $migrated_products{$code}, "$code: a second run creates no revision");
}

done_testing();
