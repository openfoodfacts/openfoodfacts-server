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

package ProductOpener::ProductsDatabase;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&store_product_in_database
		&retrieve_product_from_database
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;    # no 'my' keyword for these

use ProductOpener::Config qw/:all/;

use Log::Any qw($log);

use DBI;
use JSON::MaybeXS qw(decode_json encode_json);
use Encode qw(decode decode_utf8 encode_utf8);


sub retrieve_product_from_database ($product_id, $rev) {
	
my $connection = DBI->connect_cached(
	"DBI:Pg:dbname=$postgres_products_db;host=$postgres_products_host;port=5432",
	$postgres_products_user, $postgres_products_password,
	{ RaiseError => 1, PrintError => 0, AutoCommit => 1 }
) or die "Could not connect to database: $DBI::errstr";

	my $sth = $connection->prepare("SELECT data FROM off_prod WHERE id = ?");
	$sth->execute($product_id);
	
	my $pg_product = $sth->fetchrow_hashref();
	$sth->finish();

	$log->debug("fetched product", {product_id => $product_id, pg_product => $pg_product}) if $log->is_debug();

	if ((not defined $pg_product) or (not defined $pg_product->{data})) {
		$log->debug("Product not found in database", { product_id => $product_id }) if $log->is_debug();
		return undef;
	}
# Mark the data as UTF-8
my $utf8_data = Encode::decode('UTF-8', $pg_product->{data}, Encode::FB_CROAK);

	# Decode JSON
	my $product_ref = decode_json($utf8_data);
	
	return $product_ref;
}

sub store_product_in_database ($product_ref) {
	my $product_id = $product_ref->{id};
	
	# Convert product data to JSON
	my $json_data = encode_utf8(encode_json($product_ref));
	
	# Connect to the database
	my $connection = DBI->connect_cached(
		"DBI:Pg:dbname=$postgres_products_db;host=$postgres_products_host;port=5432",
		$postgres_products_user, $postgres_products_password,
		{ RaiseError => 1, PrintError => 0, AutoCommit => 1 }
	) or die "Could not connect to database: $DBI::errstr";

	# Prepare and execute the insert statement
	my $sth = $connection->prepare("INSERT INTO off_prod (id, data, rev) VALUES (?, ?, ?) ON CONFLICT (id) DO UPDATE SET data = ?, rev = ?");
	$sth->execute($product_id, $json_data, $product_ref->{rev}, $json_data, $product_ref->{rev}) or $log->error("Failed to store product in database", { product_id => $product_id, error => $DBI::errstr });
	
	$sth->finish();
	
	return 1;
}

1;
