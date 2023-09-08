#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use File::Path qw/remove_tree/;

my $EXPECTED_BASE_PATHS = {
	CACHE_BUILD => "$data_root/build-cache",
	CACHE_DEBUG => "$data_root/debug",
	CACHE_NEW_IMAGES => "$data_root/new_images",
	CACHE_TMP => "$data_root/tmp",
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
	REVERTED_PRODUCTS => "$data_root/reverted_products",
	USERS => "$data_root/users",
	USERS_TRANSLATIONS => "$data_root/translate",
};
my $EXPECTED_FOREIGN_PATHS = {
	OBF_PRODUCTS_DIR => '/srv/obf/products',
	OBF_PRODUCTS_IMAGES_DIR => '/srv/obf/html/images/products',
	OPFF_PRODUCTS_DIR => '/srv/opff/products',
	OPFF_PRODUCTS_IMAGES_DIR => '/srv/opff/html/images/products',
	OPF_PRODUCTS_DIR => '/srv/opf/products',
	OPF_PRODUCTS_IMAGES_DIR => '/srv/opf/html/images/products',
};
my %EXPECTED_OFF_PATHS = (%{$EXPECTED_BASE_PATHS}, %{$EXPECTED_FOREIGN_PATHS},);
is_deeply(base_paths(), \%EXPECTED_OFF_PATHS, "base_paths content for off");

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
	is_deeply(base_paths(), \%EXPECTED_OFF_PRO_PATHS, "base_paths content for off pro");
}
$server_options{producers_platform} = $producers_platform_previous;

done_testing()
