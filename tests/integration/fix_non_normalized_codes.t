#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Store qw/:all/;

remove_all_products();
wait_application_ready();

sub test_product_path ($code) {
	my $path = product_path_from_id("$code");
	$path = $code if $path eq "invalid";
	return "$data_root/products/$path";
}

sub retrieve_test_product ($code) {
	# bare retrieve for test product with strange data
	my $path = test_product_path($code);
	return retrieve("$path/product.sto");
}

# create product in a very minimal way, should be enough for our tests
sub make_product ($product_ref, $products_collection) {
	$product_ref->{_id} = $product_ref->{code};
	my $code = $product_ref->{code};    # copy code to avoid perl to stringify code
	my $product_path = test_product_path($code);
	my $rev = $product_ref->{rev};
	my $only_mongo = delete $product_ref->{only_mongo};
	if (!$only_mongo) {
		# use store instead of store_product to avoid normalizations
		`mkdir -p $product_path`;
		store("$product_path/$rev.sto", $product_ref);
		symlink("$rev.sto", "$product_path/product.sto");
	}
	# and index in mongo
	$products_collection->insert_one($product_ref);
	return;
}

sub remove_non_relevant_fields ($product_ref, $original_ref) {
	# only keep fields from original_ref (because lot of fields are added by store_product)
	foreach my $field (keys(%$product_ref)) {
		if (!(defined $original_ref->{$field})) {
			delete($product_ref->{$field});
		}
	}
	return;
}

my %default_product = (%default_product_form, rev => "0", created_t => 1290832);
delete($default_product{'.submit'});
delete($default_product{'type'});

# our sample data
# testimony ok product
my %product_ok = (%default_product, code => "2000000000001");
# int code
my %product_int_code = (%default_product, code => 2000000000002);
my %product_int_code_deleted = (%default_product, code => 2000000000003, deleted => "on");
my %product_int_code_mongo_only = (%default_product, code => 2000000000004, only_mongo => 1);
# non normalized
# simple case will be moved
my %product_non_normalized_code = (%default_product, code => "0000012345678");
# case when already deleted (nothing should happen, but mongodb removal)
my %product_non_normalized_code_deleted = (%default_product, code => "0000012345679", deleted => "on");
# case when an existing normalized product exists
my %product_normalized_existing = (%default_product, code => "12345670");
my %product_non_normalized_code_existing = (%default_product, code => "0000012345670");
# case when non normalized exists only in mongo, (mongodb removal)
my %product_non_normalized_only_mongo = (%default_product, code => "0000012345671", only_mongo => 1);
# highly broken id, impossible to compute previous path
my %product_broken_code = (%default_product, code => "broken-123");

# create
my $products_collection = get_products_collection();
my @products = (
	\%product_ok, \%product_int_code,
	\%product_int_code_deleted, \%product_int_code_mongo_only,
	\%product_non_normalized_code, \%product_non_normalized_code_deleted,
	\%product_normalized_existing, \%product_non_normalized_code_existing,
	\%product_non_normalized_only_mongo, \%product_broken_code
);
foreach my $product_ref (@products) {
	make_product($product_ref, $products_collection);
}

# launch script
my $script_out = `perl scripts/fix_non_normalized_codes.pl`;
# print($script_out."\n\n");
# check output precisely
$script_out =~ s/\n\s*\n/\n/sg;    # trim empty lines
$script_out =~ s/(^\s*\n*|\s*\n*$)//sg;
my @outputs = split("\n", $script_out);
is_deeply(
	\@outputs,
	[
		# removed product_broken_code
		"Removed broken-123",
		# removed product with existing id
		"Removed 0000012345670 as duplicate of 12345670",
		# product_non_normalized_code moved
		"Moved 0000012345678 to 12345678",
		# product_int_code
		"Int codes: refresh 1, removed 2",
		# product_broken_code and product_non_normalized_code* removed from mongo directly
		"5 items with non normalized code will be removed from mongo.",
	]
);

my $product_ref;
my %fixed_product;
# product_ok is there
$product_ref = retrieve_product("2000000000001");
is_deeply($product_ref, \%product_ok);
$product_ref = $products_collection->find_id("2000000000001");
is_deeply($product_ref, \%product_ok);

# product has no more int code
$product_ref = retrieve_product("2000000000002");
%fixed_product = (%product_int_code, code => "2000000000002", _id => "2000000000002");
is_deeply($product_ref, \%fixed_product);
$product_ref = $products_collection->find_id("2000000000002");
is_deeply($product_ref, \%fixed_product);
$product_ref = $products_collection->find_id(2000000000002);
is($product_ref, undef);
# product has no more int code even deleted
$product_ref = retrieve_product_or_deleted_product("2000000000003");
%fixed_product = (%product_int_code_deleted, code => "2000000000003", _id => "2000000000003");
is_deeply($product_ref, \%fixed_product);
# but not indexed
is($products_collection->find_id("2000000000003"), undef);
is($products_collection->find_id(2000000000003), undef);
# product_int_code_mongo_only
# but no more in mongo, neither a normalized version, neither exists on disk
is($products_collection->find_id("2000000000004"), undef);
is($products_collection->find_id(2000000000004), undef);
is(retrieve_product("2000000000004"), undef);

# product normalized
$product_ref = retrieve_product("12345678");
%fixed_product = (%product_non_normalized_code, code => "12345678", _id => "12345678", rev => "1");
# pop some inconvenient field
remove_non_relevant_fields($product_ref, \%fixed_product);
is_deeply($product_ref, \%fixed_product);
$product_ref = $products_collection->find_id("12345678");
# pop some inconvenient field
remove_non_relevant_fields($product_ref, \%fixed_product);
is_deeply($product_ref, \%fixed_product);
is($products_collection->find_id("0000012345678"), undef);

# product normalized deleted
$product_ref = retrieve_test_product("0000012345679");
# untouched
is_deeply($product_ref, \%product_non_normalized_code_deleted);
# but no more in mongo, neither a normalized version
is($products_collection->find_id("0000012345679"), undef);
is($products_collection->find_id("12345679"), undef);

# product_existing is there, unchanged
$product_ref = retrieve_product("12345670");
is_deeply($product_ref, \%product_normalized_existing);
$product_ref = $products_collection->find_id("12345670");
is_deeply($product_ref, \%product_normalized_existing);

# while non normalize version is deleted and no more in mondo
$product_ref = retrieve_product("0000012345670");
is($product_ref, undef);
$product_ref = retrieve_product_or_deleted_product("0000012345670");
is($product_ref->{deleted}, "on");
$product_ref = $products_collection->find_id("0000012345670");
is($product_ref, undef);

# product_non_normalized_only_mongo
# but no more in mongo, neither a normalized version
is($products_collection->find_id("0000012345671"), undef);
is($products_collection->find_id("12345671"), undef);

# product with broken code
$product_ref = retrieve_test_product("broken-123");
# removed
%fixed_product = (%product_broken_code, deleted => "on");
is_deeply($product_ref, \%fixed_product);
# no more in mongo
is($products_collection->find_id("broken-123"), undef);

done_testing();
