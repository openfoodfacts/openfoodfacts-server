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

# Use a PostgreSQL connection string for configuration
my $pg = Mojo::Pg->new('postgresql://productopener:productopener@query_postgres/query');
my $db = $pg->db;

# Get a list of all products
my $count = 0;
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
		if (-d "$dir/$file") {
			find_products("$dir/$file","$code$file");
			next;
		} 
		if ($file =~ /.*\.sto$/) {
			my $data = encode_json(retrieve("$dir/$file"));
			if ($file eq 'product.sto') {
				#print "code: $code\n";
				$db->insert('product.product', {code => $code, data => $data});
				$count++;
				if (!($count % 100)) {
					print DateTime->now->hms . ' ' . $count . "\n";
				}
			} 
			elsif ($file eq 'changes.sto') {
				$db->insert('product.change', {code => $code, data => $data});
			} 
			elsif ($file eq 'images.sto') {
				$db->insert('product.image', {code => $code, data => $data});
			} 
			else {
				my @parts = split(/\./,$file);
				#print $file . ' ' . $parts[0] . "\n";
				$db->insert('product.revision', {code => $code, revision => $parts[0], data => $data});
			}
		}
		elsif ($file =~ /.*\.json$/) {
			my $data = read_file("$dir/$file");
			$db->insert('product.scan', {code => $code, data => $data});
		}
	}

	return;
}


find_products($BASE_DIRS{PRODUCTS},'');
print DateTime->now->hms . ' ' . $count . "\n";
exit(0);

