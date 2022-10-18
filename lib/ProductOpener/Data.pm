# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

ProductOpener::Data - methods to create or get the mongoDB client and fetch "data collections" from the MongoDB database;

=head1 DESCRIPTION

The module implements the methods required to fetch certain collections from the MongoDB database.
The functions used in this module are responsible for executing queries, to get connection to database and also to select the collection required.

The module exposes 2 distinct kinds of collections, products and products_tags, returned by the Data::get_products_collections
and the Data::get_products_tags_collections methods respectively.

The products collection contains a complete document for each product in the OpenFoodFacts database which exposes all
available information about the product.

The products_tags collection contains a stripped down version of the data in the products collection, where each
product entry has a select few fields, including fields used in tags. The main purpose of having this copy is to
improve performance of aggregate queries for an improved user experience and more efficient resource usage. This
collection was initially proposed in L<issue#1610|https://github.com/openfoodfacts/openfoodfacts-server/issues/1610> on
GitHub, where some additional context is available.

=cut

package ProductOpener::Data;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&execute_query
		&get_database
		&get_collection
		&get_products_collection
		&get_products_tags_collection
		&get_emb_codes_collection
		&get_recent_changes_collection

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use experimental 'smartmatch';

use ProductOpener::Config qw/:all/;

use MongoDB;
use Tie::IxHash;
use Log::Any qw($log);

use Action::CircuitBreaker;
use Action::Retry;

my $client;
my $action = Action::CircuitBreaker->new();

=head1 FUNCTIONS

=head2 execute_query( $subroutine )

C<execute_query()> executes a query on the database.

=head3 Arguments

=head4 subroutine $sub

A query subroutine that performs a query against the database.

=head3 Return value

The function returns the return value of the query subroutine $sub passed as a parameter to it.

=head3 Synopsis

eval {
	$result = execute_query(sub {
		return get_products_collection()->query({})->sort({code => 1});
	});
}

=cut

sub execute_query ($sub) {

	return Action::Retry->new(
		attempt_code => sub {$action->run($sub)},
		on_failure_code => sub {my ($error, $h) = @_; die $error;},    # by default Action::Retry would return undef
			# If we didn't get results from MongoDB, the server is probably overloaded
			# Do not retry the query, as it will make things worse
		strategy => {Fibonacci => {max_retries_number => 0,}},
	)->run();
}

=head2 get_products_collection()

C<get_products_collection()> establishes a connection to MongoDB and uses timeout as an argument. This then selects a collection
from within the database.

=head3 Arguments

This method takes in arguments of integer type (user defined timeout in milliseconds).
It is optional for this subroutine to have an argument.

=head3 Return values

Returns a mongoDB collection object.

=cut

sub get_products_collection ($timeout = undef) {
	return get_collection($mongodb, 'products', $timeout);
}

=head2 get_products_tags_collection()

C<get_products_collection()> This selects the product tag collection from within the database.

=head3 Arguments

This method takes in arguments of integer type (user defined timeout in milliseconds).
It is optional for this subroutine to have an argument.

=head3 Return values

Returns a mongoDB collection.

=cut

sub get_products_tags_collection ($timeout = undef) {
	return get_collection($mongodb, 'products_tags', $timeout);
}

sub get_emb_codes_collection ($timeout = undef) {
	return get_collection($mongodb, 'emb_codes', $timeout);
}

sub get_recent_changes_collection ($timeout = undef) {
	return get_collection($mongodb, 'recent_changes', $timeout);
}

sub get_collection ($database, $collection, $timeout = undef) {
	return get_mongodb_client($timeout)->get_database($database)->get_collection($collection);
}

sub get_database {
	my $database = $_[0] // $mongodb;
	return get_mongodb_client()->get_database($database);
}

=head2 get_mongodb_client()

C<get_mongodb_client()> gets the MongoDB client. It first checks if the client already exists and if not,
it creates and configures a new MongoDB::MongoClient.

=head3 Arguments

This method takes in arguments of integer type (user defined timeout in milliseconds). It is optional for this subroutine to have an argument.

=head3 Return values

Returns $client of type MongoDB::MongoClient object.

=cut

sub get_mongodb_client ($timeout = undef) {
	# Note that for web pages, $client will be cached in mod_perl,
	# so passing in different options for different queries won't do anything after the first call.

	my $max_time_ms = $timeout // $mongodb_timeout_ms;

	my %client_options = (
		host => $mongodb_host,

		# https://metacpan.org/pod/MongoDB::MongoClient#max_time_ms
		# default is 0, meaning failures cause socket timeouts instead.
		max_time_ms => $max_time_ms,

		# https://metacpan.org/pod/MongoDB::MongoClient#socket_timeout_ms
		# default is 30000 ms
		socket_timeout_ms => $max_time_ms + 5000,
	);

	if (!defined($client)) {
		$log->info("Creating new DB connection", {socket_timeout_ms => $client_options{socket_timeout_ms}});
		$client = MongoDB::MongoClient->new(%client_options);
	}
	else {
		$log->info("DB connection already exists");
	}

	return $client;
}

1;
