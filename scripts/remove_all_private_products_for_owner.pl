#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

my $usage = <<TXT
update_all_products.pl is a script that updates the latest version of products in the file system and on MongoDB.
It is used in particular to re-run tags generation when taxonomies have been updated.

Usage:

remove_all_private_products_for_owner.pl --owner owner-id

owner-id is of the form org-orgid or user-userid


TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Data qw/:all/;

use Getopt::Long;

my $owner;

GetOptions("owner=s" => \$owner)
	or die("Error in command line arguments:\n\n$usage");

if ($owner !~ /^(user|org)-\S+$/) {
	die("owner must start with user- or org-:\n\n$usage");
}

print STDERR "Deleting products for owner $owner in database\n";

my $products_collection = get_products_collection();
$products_collection->delete_many({"owner" => $owner});

use File::Copy::Recursive qw(dirmove);

my $deleted_dir = $data_root . "/deleted_private_products/" . $owner . "." . time();
(-e $data_root . "/deleted_private_products") or mkdir($data_root . "/deleted_private_products", oct(755));

print STDERR "Moving data to $deleted_dir\n";

mkdir($deleted_dir, oct(755));

dirmove("$data_root/import_files/$owner", "$deleted_dir/import_files")
	or print STDERR "Could not move $data_root/import_files/$owner to $deleted_dir/import_files : $!\n";
dirmove("$data_root/export_files/$owner", "$deleted_dir/export_files")
	or print STDERR "Could not move $data_root/export_files/$owner to $deleted_dir/export_files : $!\n";
dirmove("$data_root/products/$owner", "$deleted_dir/products")
	or print STDERR "Could not move $data_root/products/$owner to $deleted_dir/products : $!\n";
dirmove("$www_root/images/products/$owner", "$deleted_dir/images")
	or print STDERR "Could not move $www_root/images/products/$owner to $deleted_dir/images : $!\n";

exit(0);

