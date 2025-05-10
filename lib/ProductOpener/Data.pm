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

ProductOpener::Data - methods to create or get the mongoDB client and fetch "data collections" from the MongoDB database;

=head1 DESCRIPTION

The module implements the methods required to fetch certain collections from the MongoDB database.
The functions used in this module are responsible for executing queries, to get connection to database and also to select the collection required.

The products collection contains a complete document for each product in the OpenFoodFacts database which exposes all
available information about the product.

Obsolete products that have been withdrawn from the market have separate collections: products_obsolete

=cut

package ProductOpener::Data;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&init_data_debug
		&can_use_off_query
		&can_use_cache_results
		&execute_query
		&execute_aggregate_tags_query
		&execute_count_tags_query
		&execute_product_query
		&get_database
		&get_collection
		&get_products_collection
		&get_emb_codes_collection
		&get_recent_changes_collection
		&remove_documents_by_ids
		&get_orgs_collection

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use experimental 'smartmatch';

use ProductOpener::Config qw/:all/;
use ProductOpener::Cursor;
use ProductOpener::HTTP qw/request_param single_param get_http_request_header/;

use Storable qw(freeze);
use MongoDB;
use JSON::MaybeXS;
use CGI ':cgi-lib';
use Log::Any qw($log);

use Action::CircuitBreaker;
use Action::Retry;

my $client;
my $action = Action::CircuitBreaker->new();

=head1 FUNCTIONS

=head2 init_data_debug ($request_ref)

Initializes the data_debug variable that will list parameters and info related to data queries

=cut

sub init_data_debug () {

	my $data_debug = "data_debug start\n";

	return $data_debug;
}

=head2 can_use_off_query ($data_debug_ref)

Determine if we can use off_query backend:
- off_query URL needs to be set
- no_off_query parameter is not set, or off_query parameter is set
- we are not on the producers platform

=cut

sub can_use_off_query ($data_debug_ref) {

	# TODO: pass parameters inside $request_ref instead, so that we don't have to call single_param() here
	my $param_no_off_query = single_param("no_off_query") || '';
	my $param_off_query = single_param("off_query") || '';
	my $platform = $server_options{producers_platform} ? "producers" : "public";

	$$data_debug_ref .= "no_off_query: $param_no_off_query\n";
	$$data_debug_ref .= "off_query: $param_off_query\n";
	$$data_debug_ref .= "platform: $platform\n";
	$$data_debug_ref .= "query_url: " . ($query_url || '') . "\n";

	# use !! operator to convert to boolean
	my $can_use_off_query
		= !!(((not $param_no_off_query) or ($param_off_query)) and (not $platform eq 'producers') and ($query_url));

	$$data_debug_ref .= "can_use_off_query: $can_use_off_query\n";
	return $can_use_off_query;
}

=head2 can_use_cache_results ($data_debug_ref)

Determine if we can use cached results:
- no_cache parameter is not set
- we are not on the producers platform
- Cache-Control header is not set to no-cache

=head3 parameters

=head4 $data_debug_ref - ref string

This parameter is modified to add debug information.

=cut

sub can_use_cache_results ($data_debug_ref) {

	my $param_no_cache = single_param("no_cache");
	my $cache_control = get_http_request_header("Cache-Control");
	my $platform = $server_options{producers_platform} ? "producers" : "public";

	$$data_debug_ref .= "Cache-Control: $cache_control\n" if defined $cache_control;
	$$data_debug_ref .= "no_cache: $param_no_cache\n" if defined $param_no_cache;
	$$data_debug_ref .= "platform: $platform\n";

	my $can_use_cache = not(($platform eq 'producers')
		or ($param_no_cache)
		or ((defined $cache_control) and ($cache_control =~ /no-cache/i)));

	$$data_debug_ref .= "can_use_cache: $can_use_cache\n";

	return $can_use_cache;
}

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

sub execute_aggregate_tags_query ($query) {
	return execute_tags_query('aggregate', $query);
}

sub execute_count_tags_query ($query) {
	return execute_tags_query('count', $query);
}

sub execute_product_query ($parameters_ref, $query_ref, $fields_ref, $sort_ref, $limit, $skip, $data_debug_ref) {

	defined $$data_debug_ref or $$data_debug_ref = "data_debug start\n";

	# Currently only send descending popularity_key sorts to off-query
	# Note that $sort_ref is a Tie::IxHash so can't use $sort_ref->{popularity_key}
	if ($parameters_ref->{off_query} && $sort_ref && $sort_ref->FETCH('popularity_key') == -1) {

		$$data_debug_ref .= "off_query parameter set, and sorting by popularity_key: using off_query\n";

		# Convert sort into an array so that the order of keys is not ambiguous
		my @sort_array = ();
		foreach my $k ($sort_ref->Keys) {
			push(@sort_array, [$k, $sort_ref->FETCH($k)]);
		}

		my $results = execute_tags_query(
			'find',
			{
				filter => $query_ref,
				projection => $fields_ref,
				sort => \@sort_array,
				limit => $limit,
				skip => $skip
			}
		);

		if (defined $results) {
			return ProductOpener::Cursor->new($results);
			$$data_debug_ref .= "got results from off_query\n";
		}
		else {
			$$data_debug_ref .= "no results from off_query\n";
		}
	}
	else {
		$$data_debug_ref .= "off_query parameter not set, or not sorting by popularity_key: not using off_query\n";
	}

	my $cursor = get_products_collection($parameters_ref)->query($query_ref)->fields($fields_ref);
	if ($sort_ref) {
		$cursor = $cursor->sort($sort_ref);
	}
	if ($limit) {
		$cursor = $cursor->limit($limit);
	}
	if ($skip) {
		$cursor = $cursor->skip($skip);
	}

	$$data_debug_ref .= "got results from MongoDB\n";

	return $cursor;
}

# $json_utf8 has utf8 enabled: it decodes UTF8 bytes
my $json_utf8 = JSON::MaybeXS->new->utf8(1)->allow_nonref->canonical;

sub execute_tags_query ($type, $query) {
	if ((defined $query_url) and (length($query_url) > 0)) {
		$query_url =~ s/^\s+|\s+$//g;
		my $params = Vars();
		my $url = URI->new("$query_url/$type");
		$url->query_form($params);
		$log->debug('Executing PostgreSQL ' . $type . ' query on ' . $url, {query => $query})
			if $log->is_debug();

		my $ua = LWP::UserAgent->new();
		# Add a timeout to the HTTP query
		$ua->timeout(15);
		my $resp = $ua->post(
			$url,
			Content => encode_json($query),
			'Content-Type' => 'application/json; charset=utf-8'
		);
		if ($resp->is_success) {
			return $json_utf8->decode($resp->decoded_content);
		}
		else {
			$log->warn(
				"query response not ok",
				{
					code => $resp->code,
					status_line => $resp->status_line,
					response => $resp
				}
			) if $log->is_warn();
			return;
		}
	}
	else {
		$log->debug('QUERY_URL not defined') if $log->is_debug();
		return;
	}
}

=head2 get_products_collection( $parameters_ref )

C<get_products_collection()> establishes a connection to MongoDB and uses timeout as an argument. This then selects a collection
from within the database.

=head3 Arguments

This method takes parameters in an optional hash reference with the following keys:

=head4 database MongoDB database name

Defaults to $ProductOpener::Config::mongodb

This is useful when moving products to another flavour
(e.g. from Open Food Facts (database: off) to Open Beauty Facts (database: obf))

=head4 timeout User defined timeout in milliseconds

=head4 obsolete

If set to a true value, the function returns a collection that contains only obsolete products,
otherwise it returns the collection with products that are not obsolete.

=head3 Return values

Returns a mongoDB collection object.

=cut

sub get_products_collection ($parameters_ref = {}) {
	my $database = $parameters_ref->{database} // $mongodb;
	my $collection = 'products';
	if ($parameters_ref->{obsolete}) {
		$collection .= '_obsolete';
	}
	return get_collection($database, $collection, $parameters_ref->{timeout});
}

sub get_emb_codes_collection ($timeout = undef) {
	return get_collection($mongodb, 'emb_codes', $timeout);
}

sub get_recent_changes_collection ($timeout = undef) {
	return get_collection($mongodb, 'recent_changes', $timeout);
}

sub get_orgs_collection ($timeout = undef) {
	return get_collection($mongodb, 'orgs', $timeout);
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

=head2 remove_documents_by_ids($ids_to_remove_ref, $coll, $bulk_write_size=100)

Efficiently removes a set of documents

=head3 Arguments

=head4 $ids_to_remove_ref - ref to list of ids to remove

correspond to the _id field

=head4 $coll - a document collection

=head4 $bulk_size - how many concurrent deletion in a bulk

=head3 Return values

Returns a hash with:

	<dl>
	  <dt>removed</dt>
	  <dd>int - number of effectively removed items</dd>
	  <dt>errors</dt>
	  <dd>ref to a list of errors</dd>
	</dl>

=cut

sub remove_documents_by_ids ($ids_to_remove_ref, $coll, $bulk_write_size = 100) {
	my @ids_to_remove = (@$ids_to_remove_ref);    # copy the list because we will use splice
	my @errors = ();

	if (!@ids_to_remove) {
		return {removed => 0, errors => \@errors};    # nothing to do
	}

	# remove found ids
	my $removed = 0;
	# prepare a bulk operation, with one operation per slice
	my $bulk = $coll->unordered_bulk;
	while (scalar @ids_to_remove) {
		my @batch_ids = splice(@ids_to_remove, 0, $bulk_write_size);
		$bulk->find({_id => {'$in' => \@batch_ids}})->delete_many();
	}
	# try to do our best
	eval {
		# execute
		my $bulk_result = $bulk->execute();
		$removed += $bulk_result->deleted_count;
	};
	my $error = $@;
	if ($error) {
		push @errors, $error;
	}

	return {removed => $removed, errors => \@errors};
}

1;
