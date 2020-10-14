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

package ProductOpener::Data;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
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

use vars @EXPORT_OK ;

use experimental 'smartmatch';

use ProductOpener::Config qw/:all/;

use MongoDB;
use Tie::IxHash;
use Log::Any qw($log);

use Action::CircuitBreaker;
use Action::Retry;

my $client;
my $action = Action::CircuitBreaker->new();

sub execute_query {
	my ($sub) = @_;

	return Action::Retry->new(
		attempt_code => sub { $action->run($sub) },
		on_failure_code => sub { my ($error, $h) = @_; die $error; }, # by default Action::Retry would return undef
		# If we didn't get results from MongoDB, the server is probably overloaded
		# Do not retry the query, as it will make things worse
		strategy => { Fibonacci => { max_retries_number => 0, } },
	)->run();
}

sub get_products_collection {
	my ($timeout) = @_;
	return get_collection($mongodb, 'products', $timeout);
}

sub get_products_tags_collection {
	my ($timeout) = @_;
	return get_collection($mongodb, 'products_tags', $timeout);
}

sub get_emb_codes_collection {
	my ($timeout) = @_;
	return get_collection($mongodb, 'emb_codes', $timeout);
}

sub get_recent_changes_collection {
	my ($timeout) = @_;
	return get_collection($mongodb, 'recent_changes', $timeout);
}

sub get_collection {
	my ($database, $collection, $timeout) = @_;
	return get_mongodb_client($timeout)->get_database($database)->get_collection($collection);
}

sub get_database {
	$database = $_[0] // $mongodb;
	return get_mongodb_client()->get_database($database);
}

sub get_mongodb_client() {
	# Note that for web pages, $client will be cached in mod_perl,
	# so passing in different options for different queries won't do anything after the first call.
	my ($timeout) = @_;

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
		$log->info("Creating new DB connection", { socket_timeout_ms => $client_options{socket_timeout_ms} });
		$client = MongoDB::MongoClient->new(%client_options);
	} else {
		$log->info("DB connection already exists");
	}

	return $client;
}

1;
