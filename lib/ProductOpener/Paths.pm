# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Paths - functions to get, check and initialize important directories

=head1 SYNOPSIS

…

=cut

package ProductOpener::Paths;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		%BASE_DIRS

		&base_paths
		&base_paths_loading_script
		&check_missing_dirs
		&ensure_dir_created
		&ensure_dir_created_or_die
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;

=head1 VARIABLES

=cut

=head2 %BASE_DIRS
A hashmap containing references to base directories
=cut

%BASE_DIRS = ();

=head3 $BASE_DIRS{LOGS}
Directory for logging
=cut

$BASE_DIRS{LOGS} = "$data_root/logs";

=head2 $BASE_DIRS{ORGS}
Directory containing sto of organizations
=cut

$BASE_DIRS{ORGS} = "$data_root/orgs";

=head2 $BASE_DIRS{USERS}
Directory containing sto of users
=cut

$BASE_DIRS{USERS} = "$data_root/users";

=head2 $BASE_DIRS{PRODUCTS}
Directory containing sto of products
=cut

$BASE_DIRS{PRODUCTS} = "$data_root/products";

=head2 $BASE_DIRS{PRIVATE_DATA}
Directory for private data
=cut

$BASE_DIRS{PRIVATE_DATA} = "$data_root/data";

=head2 $BASE_DIRS{LANG}
Directory with language files (.po). Normally linked to openfoodfacts-web
=cut

$BASE_DIRS{LANG} = "$data_root/lang";

=head2 $BASE_DIRS{IMPORT_FILES}
files to import in producer platform
=cut

$BASE_DIRS{IMPORT_FILES} = "$data_root/import_files";

=head2 $BASE_DIRS{EXPORT_FILES}
files to export from producer platform to public platform
=cut

$BASE_DIRS{EXPORT_FILES} = "$data_root/export_files";

=head2 $BASE_DIRS{PRODUCTS_IMAGES}
product images is a big directory, normally a volume of its own
=cut

$BASE_DIRS{PRODUCTS_IMAGES} = "$www_root/images/products";

=head2 $BASE_DIRS{CACHE_TMP}
temporary files we manage locally
=cut

$BASE_DIRS{CACHE_TMP} = "$data_root/tmp";

=head2 $BASE_DIRS{CACHE_NEW_IMAGES}
A directory to link newly updated images in order to apply processing (like OCR)
=cut

$BASE_DIRS{CACHE_NEW_IMAGES} = "$data_root/new_images";

=head2 $BASE_DIRS{CACHE_DEBUG}
Temporary files for debugging purposes
=cut

$BASE_DIRS{CACHE_DEBUG} = "$data_root/debug";

=head2 $BASE_DIRS{CACHE_BUILD}
Files needed for various build phases - eg taxonomy and cached
=cut

$BASE_DIRS{CACHE_BUILD} = "$data_root/build-cache";

=head2 $BASE_DIRS{DELETED_PRODUCTS}
Products deleted from the public platform
=cut

$BASE_DIRS{DELETED_PRODUCTS} = "$data_root/deleted_products";

=head2 $BASE_DIRS{DELETED_PRODUCTS_IMAGES}
Products deleted from the public platform
=cut

$BASE_DIRS{DELETED_PRODUCTS_IMAGES} = "$data_root/deleted_products_images";

=head2 $BASE_DIRS{DELETED_PRIVATE_PRODUCTS}
Products deleted from the producers platform
=cut

$BASE_DIRS{DELETED_PRIVATE_PRODUCTS} = "$data_root/deleted_private_products";

=head2 $BASE_DIRS{DELETED_IMAGES}
A directory to store deleted images (not accessible from web)
=cut

$BASE_DIRS{DELETED_IMAGES} = "$data_root/deleted.images";

=head2 $BASE_DIRS{REVERTED_PRODUCTS}
A directory where we store revisions we reverted for some products
=cut

$BASE_DIRS{REVERTED_PRODUCTS} = "$data_root/reverted_products";

=head2 $BASE_DIRS{FILES_DEBUG}
A directory used to debug knowledge panels
=cut

$BASE_DIRS{FILES_DEBUG} = "$www_root/files/debug";

=head2 $BASE_DIRS{PUBLIC_DATA}
The main public data directory where database dumps are published along with other assets
=cut

$BASE_DIRS{PUBLIC_DATA} = "$www_root/data";

# FIXME: can we move those in PUBLIC_DATA_DIR ?

=head2 $BASE_DIRS{PUBLIC_DUMP}
=cut

$BASE_DIRS{PUBLIC_DUMP} = "$www_root/dump";

=head2 $BASE_DIRS{PUBLIC_FILES}
=cut

$BASE_DIRS{PUBLIC_FILES} = "$www_root/files";

=head2 $BASE_DIRS{PUBLIC_EXPORTS}
=cut

$BASE_DIRS{PUBLIC_EXPORTS} = "$www_root/exports";

=head2 $BASE_DIRS{USERS_TRANSLATIONS}
Users contributed translations directory
=cut

$BASE_DIRS{USERS_TRANSLATIONS} = "$data_root/translate";

=head2 $BASE_DIRS{SFTP_HOME}
sftp home directory, only for producers platform
=cut

$BASE_DIRS{SFTP_HOME} = $sftp_root;

my @PRO_ONLY_PATHS = qw(SFTP_HOME);

=head1 FUNCTIONS

=head2 products_dir($server_name)
products directory for a foreign server
=head3 Arguments
=head4 $server_name - off/obf/opf/opff…
=head3 Return
String of path to base directory containing products sto
=cut

sub products_dir ($server_name) {
	my $server_data_root = $options{other_servers}{$server_name}{data_root};
	return "$server_data_root/products";
}

=head2 products_images_dir($server_name)
products images directory for a foreign server
=head3 Arguments
=head4 $server_name - off/obf/opf/opff…
=head3 Return
String of path to base directory containing products images
=cut

sub products_images_dir ($server_name) {
	my $server_www_root = $options{other_servers}{$server_name}{www_root};
	return "$server_www_root/images/products";
}

=head2 base_paths()
Return the list of base paths as a hashmap
=cut

sub base_paths() {
	my %paths = (%BASE_DIRS);
	if (!$server_options{producers_platform}) {
		# on non pro instances,
		# also add foreign projects dirs for products migrations
		my $servers_options = $options{other_servers};
		foreach my $server_name (keys %{$servers_options}) {
			if ($server_name eq $options{current_server}) {
				next;
			}
			$paths{uc($server_name) . "_PRODUCTS_DIR"} = products_dir($server_name);
			$paths{uc($server_name) . "_PRODUCTS_IMAGES_DIR"} = products_images_dir($server_name);
		}
		# remove some paths
		foreach my $path (@PRO_ONLY_PATHS) {
			delete $paths{$path};
		}
	}
	return \%paths;
}

=head2 check_missing_dirs()
Check main directories, needed for the project to run, exists
=head3 Return
A ref to a list of missing paths
=cut

sub check_missing_dirs() {
	my @to_check = (values %{base_paths()});
	$log->debug("check_missing_dirs - to check: " . (join ":", @to_check)) if $log->is_debug;

	my @missing = grep {!(-e $_)} @to_check;

	return \@missing;
}

=head2 ensure_dir_created($path, $mode=oct(755))
Ensure a multiple path is created but die if a fundamental path is missing
=cut

sub ensure_dir_created ($path, $mode = oct(755)) {
	# search base directory
	my $prefix;
	my $suffix;
	my @base_dirs = (values %{base_paths()});
	foreach my $prefix_candidate (@base_dirs) {
		if ($path =~ /^$prefix_candidate/) {
			$prefix = $prefix_candidate;
			$suffix = $';
			last;
		}
	}
	if (!defined $prefix) {
		$log->error("Could not create $path, no corresponding base directory found in " . join(":", @base_dirs));
		return;
	}
	# ensure the rest of the path
	foreach my $component (split(/\//, $suffix)) {
		$prefix .= "/$component";
		(-e $prefix) or mkdir($prefix);
	}
	return (-e $path);
}

=head2 ensure_dir_created_or_die($path, $mode=0755)
Ensure a multiple path is created but die if a fundamental path is missing
=cut

sub ensure_dir_created_or_die ($path, $mode = 0755) {
	my $result = ensure_dir_created($path, $mode);
	if (!$result) {
		die("Could not create target directory $path : $!\n");
	}
	return $result;
}

=head2 base_paths_loading_script()
Return a sh script to define environment variables

You can then use it in a script by running:

C<< . <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()') >>

=cut

sub base_paths_loading_script() {
	my %paths = %{base_paths()};
	my @outputs = ();
	foreach my $path_name (keys %paths) {
		my $value = $paths{$path_name};
		if (defined $value) {
			push @outputs, "export OFF_${path_name}_DIR=$value";
		}
	}
	return (join "\n", @outputs) . "\n";
}

1;
