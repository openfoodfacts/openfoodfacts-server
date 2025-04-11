#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Config qw/:all/;
# Specifically import :all to test the base_paths_loading_script function used in shell scripts
use ProductOpener::Paths qw/:all/;
use File::Path qw/remove_tree/;

# hardcode docker path for now
my $src_root = "/opt/product-opener";

my $EXPECTED_BASE_PATHS = {
	CACHE_BUILD => "$data_root/build-cache",
	CACHE_DEBUG => "$data_root/debug",
	CACHE_NEW_IMAGES => "$data_root/new_images",
	CACHE_TMP => "$data_root/tmp",
	CONF => "$src_root/conf",
	DELETED_IMAGES => "$data_root/deleted.images",
	DELETED_PRIVATE_PRODUCTS => "$data_root/deleted_private_products",
	DELETED_PRODUCTS => "$data_root/deleted_products",
	DELETED_PRODUCTS_IMAGES => "$data_root/deleted_products_images",
	EXPORT_FILES => "$data_root/export_files",
	FILES_DEBUG => "$www_root/files/debug",
	IMPORT_FILES => "$data_root/import_files",
	LANG => "$data_root/lang",
	LOGS => "$data_root/logs",
	ORGS => "$data_root/orgs",
	PRIVATE_DATA => "$data_root/data",
	PRODUCTS => "$data_root/products",
	PRODUCTS_IMAGES => "$www_root/images/products",
	PUBLIC_DATA => "$www_root/data",
	PUBLIC_DUMP => "$www_root/dump",
	PUBLIC_EXPORTS => "$www_root/exports",
	PUBLIC_FILES => "$www_root/files",
	RELEASE_VERSION => "$src_root/version.txt",
	REVERTED_PRODUCTS => "$data_root/reverted_products",
	SCRIPTS => "$src_root/scripts",
	TAXONOMIES_SRC => "$src_root/taxonomies",
	USERS => "$data_root/users",
	USERS_TRANSLATIONS => "$data_root/translate",
};

my %EXPECTED_OFF_PATHS = (%{$EXPECTED_BASE_PATHS});
is(base_paths(), \%EXPECTED_OFF_PATHS, "base_paths content for off");

ok(ensure_dir_created("$BASE_DIRS{CACHE_TMP}"), "cache tmp directory exists");
remove_tree("$BASE_DIRS{CACHE_TMP}/test-unit-xxx");
ok(ensure_dir_created("$BASE_DIRS{CACHE_TMP}/test-unit-xxx/some/path"), "we can create a path in cache tmp directory");
remove_tree("$BASE_DIRS{CACHE_TMP}/test-unit-xxx");
ok(
	ensure_dir_created_or_die("$BASE_DIRS{CACHE_TMP}/test-unit-xxx/some/path"),
	"we can create a path in cache tmp directory without dying"
);

ok(!ensure_dir_created("$data_root/doesnotexists"), "We do not create a path that's not under a know folder");

# pro instances
my %EXPECTED_OFF_PRO_PATHS = (%{$EXPECTED_BASE_PATHS}, "SFTP_HOME" => "/mnt/podata/sftp");
my $producers_platform_previous = $server_options{producers_platform};
{
	$server_options{producers_platform} = 1;
	is(base_paths(), \%EXPECTED_OFF_PRO_PATHS, "base_paths content for off pro");
}
$server_options{producers_platform} = $producers_platform_previous;

my $export_commands = base_paths_loading_script();

like($export_commands, qr/export OFF_CACHE_BUILD_DIR=$data_root\/build-cache/, "export OFF_CACHE_BUILD_DIR");

done_testing()
