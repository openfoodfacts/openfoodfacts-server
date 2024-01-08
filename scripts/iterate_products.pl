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

use ProductOpener::Paths qw/:all/;

use Storable;
use JSON::PP;
use Mojo::Pg;
use File::Slurp;
use DateTime;
use List::Util qw(max);

# Use a PostgreSQL connection string for configuration

# DROP TABLE product."change";
# DROP TABLE product.image;
# DROP TABLE product.product;
# DROP TABLE product.revision;
# DROP TABLE product.scan;

# CREATE TABLE product."change" (
# 	code varchar NOT NULL,
# 	"data" json NULL,
# 	file_last_modified timestamp,
# 	primary key (code)
# );

# CREATE TABLE product.image (
# 	code varchar NOT NULL,
# 	"data" json NULL,
# 	file_last_modified timestamp,
# 	primary key (code)
# );

# CREATE TABLE product.product (
# 	code varchar NOT NULL,
# 	"data" json NULL,
# 	file_last_modified timestamp,
# 	primary key (code)
# );

# CREATE TABLE product.revision (
# 	code varchar NOT NULL,
# 	revision int4 NOT NULL,
# 	"data" json NULL,
# 	file_last_modified timestamp,
# 	primary key (code)
# );

# CREATE TABLE product.scan (
# 	code varchar NOT NULL,
# 	"data" json NULL,
# 	file_last_modified timestamp,
# 	primary key (code)
# );

# DELETE FROM product."change";
# DELETE FROM product.image;
# DELETE FROM product.product;
# DELETE FROM product.revision;
# DELETE FROM product.scan;

my $start_from = $ARGV[0] // 0;
my $pg = Mojo::Pg->new('postgresql://productopener:productopener@postgres_products/products');
my $db = $pg->db;

# Get a list of all products
my $count = 0;
my $max_time = 0;
print DateTime->now->hms . "\n";

sub find_products {
	my $dir = shift;
	my $code = shift;
	
	#print "$dir\n";
	opendir DH, "$dir" or die "could not open $dir directory: $!\n";
	my @files = readdir(DH);
	closedir DH;
	foreach my $file (@files) {
		next if $file =~ /^\.\.?$/;
		my $file_path = "$dir/$file";
		if (-d $file_path) {
			find_products($file_path,"$code$file");
			next;
		}
		my $file_time = (stat($file_path))[9];
		next if ($file_time <= $start_from);

		$max_time = max($max_time,$file_time);
		my $mtime = DateTime->from_epoch(epoch => $file_time)->iso8601();
		if ($file =~ /.*\.sto$/) {
			my $data = encode_json(retrieve($file_path));
			if ($file eq 'product.sto') {
				#print "code: $code\n";
				$db->insert('product.product', {code => $code, data => $data, file_last_modified => $mtime}, {on_conflict => \'(code) do update set data=EXCLUDED.data, file_last_modified=EXCLUDED.file_last_modified'});
				$count++;
				if (!($count % 100)) {
					print DateTime->now->hms . ' ' . $count . "\n";
				}
			} 
			elsif ($file eq 'changes.sto') {
				$db->insert('product.change', {code => $code, data => $data, file_last_modified => $mtime}, {on_conflict => \'(code) do update set data=EXCLUDED.data, file_last_modified=EXCLUDED.file_last_modified'});
			} 
			elsif ($file eq 'images.sto') {
				$db->insert('product.image', {code => $code, data => $data, file_last_modified => $mtime}, {on_conflict => \'(code) do update set data=EXCLUDED.data, file_last_modified=EXCLUDED.file_last_modified'});
			} 
			elsif ($file =~ /[0-9]*\.sto$/) {
				my @parts = split(/\./,$file);
				#print $file . ' ' . $parts[0] . "\n";
				$db->insert('product.revision', {code => $code, revision => $parts[0], data => $data, file_last_modified => $mtime}, {on_conflict => undef});
			}
			else {
				print "Skipping $file_path\n";
			}
		}
		elsif ($file eq 'scans.json') {
			my $data = read_file($file_path);
			$db->insert('product.scan', {code => $code, data => $data, file_last_modified => $mtime}, {on_conflict => \'(code) do update set data=EXCLUDED.data, file_last_modified=EXCLUDED.file_last_modified'});
		}
		else {
			print "Skipping $file_path\n";
		}
	}

	return;
}


#find_products($BASE_DIRS{PRODUCTS},'');

find_products('/mnt/podata/debug/test','');

print DateTime->now->hms . ' ' . $count . "\n";
print "Most recent file timestamp: $max_time\n";
exit(0);

