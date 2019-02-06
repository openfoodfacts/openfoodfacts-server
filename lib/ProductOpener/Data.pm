# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&execute_query
					&get_collection
					&get_products_collection
					&get_products_tags_collection
					&get_emb_codes_collection
					&get_recent_changes_collection

					);	# symbols to export on request
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
		  strategy => { Fibonacci => { max_retries_number => 3, } },
      )->run();
}

sub get_products_collection {
	return get_collection($mongodb, 'products');
}

sub get_products_tags_collection {
	return get_collection($mongodb, 'products_tags');
}

sub get_emb_codes_collection {
	return get_collection($mongodb, 'emb_codes');
}

sub get_recent_changes_collection {
	return get_collection($mongodb, 'recent_changes');
}

sub get_collection {
	my ($database, $collection) = @_;
	return get_mongodb_client()->get_database($database)->get_collection($collection);
}

sub get_mongodb_client() {
	if (!defined($client)) {
		$log->info("Creating new DB connection");
			$client = MongoDB::MongoClient->new(
				host => $mongodb_host
			);
	} else {
		$log->info("DB connection already exists");
	}

	return $client;
}

1;
