#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use Modern::Perl '2012';
use utf8;

my $usage = <<TXT
add_missing_photos.pl is a script that adds images to the product that exist
in the image directory, but are not indexed by the product.

Usage:

add_missing_photos.pl

--pretend	do not actually update products
TXT
;

use File::Copy qw/ move /;
use File::Temp qw/ tempdir /;
use Getopt::Long;
use Try::Tiny;

use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Users qw/:all/;

my $pretend = '';
my $query_ref = {};	# filters for mongodb query

GetOptions ("pretend" => \$pretend,
			"user_id=s" => \$User_id,
			)
  or die("Error in command line arguments:\n\n$usage");

my $cursor = get_products_collection()->query($query_ref)->fields({ code => 1 });;
$cursor->immortal(1);
my $count = $cursor->count();

my $n = 0;	# number of products updated

print STDERR "$count products to update\n";

while (my $product_ref = $cursor->next) {

	my $code = $product_ref->{code};
	my $path = product_path($code);
	my $imgdir = "$www_root/images/products/$path";
	next if (not (-e $imgdir));

	print STDERR "updating product $code\n";

	$product_ref = retrieve_product($code);
	next if not ((defined $product_ref) and ($code ne ''));
	$lc = $product_ref->{lc};
	defined $product_ref->{images} or $product_ref->{images} = {};

	my $DIR;
	opendir($DIR, $imgdir) or die $!;

	while (my $file = readdir($DIR)) {
		my $imgpath = "$imgdir/$file";
		next unless (-f $imgpath);
		next unless ($file =~ m/^(\d+)\.jpe?g$/);
		my $imgid = $1;
		next if (defined $product_ref->{images}{$imgid});

		if ($pretend) {
			print STDERR "would add $imgid ($imgpath) to $code\n";
			next;
		}			
		
		print STDERR "adding add $imgid ($imgpath) to $code\n";

		# Backup original image and existing resized versions to a temporary directory		
		my $tmpdir = tempdir( CLEANUP => 1 );
		my $tmpfile = "$tmpdir/$file";
		move($imgpath, $tmpfile) if (-f $imgpath);
		move("$imgpath.$thumb_size.jpg", "$tmpdir/$file.$thumb_size.jpg") if (-f "$imgpath.$thumb_size.jpg");
		move("$imgpath.$crop_size.jpg", "$tmpdir/$file.$crop_size.jpg") if (-f "$imgpath.$crop_size.jpg");
		move("$imgpath.$small_size.jpg", "$tmpdir/$file.$small_size.jpg") if (-f "$imgpath.$small_size.jpg");
		move("$imgpath.$display_size.jpg", "$tmpdir/$file.$display_size.jpg") if (-f "$imgpath.$display_size.jpg");
		move("$imgpath.$zoom_size.jpg", "$tmpdir/$file.$zoom_size.jpg") if (-f "$imgpath.$zoom_size.jpg");

		my $ok = -9000;
		try {
			$ok = process_image_upload(
				$code,
				$tmpfile,
				$User_id,
				(stat ($tmpfile))[9],
				"add_missing_photos.pl - adding missing pictures original id $imgid", undef);
		} finally {
			# Restore backup files
			if (@_ or $ok < 0) {
				print STDERR "Unable to add img $imgid: @_ OK: $ok\n";
				move($tmpfile, $imgpath) if (-f $tmpfile);
				move("$tmpdir/$file.$thumb_size.jpg", "$imgpath.$thumb_size.jpg") if (-f "$tmpdir/$file.$thumb_size.jpg");
				move("$tmpdir/$file.$crop_size.jpg", "$imgpath.$crop_size.jpg") if (-f "$tmpdir/$file.$crop_size.jpg");
				move("$tmpdir/$file.$small_size.jpg", "$imgpath.$small_size.jpg") if (-f "$tmpdir/$file.$small_size.jpg");
				move("$tmpdir/$file.$display_size.jpg", "$imgpath.$display_size.jpg") if (-f "$tmpdir/$file.$display_size.jpg");
				move("$tmpdir/$file.$zoom_size.jpg", "$imgpath.$zoom_size.jpg") if (-f "$tmpdir/$file.$zoom_size.jpg");
			}
		}
	}

	$n++;
	closedir($DIR);
}

print STDERR "$n products updated (pretend: $pretend)\n";

exit(0);

