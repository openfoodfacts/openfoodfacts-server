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

package ProductOpener::Cache;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		$memd
		$max_memcached_object_size
		&generate_cache_key
		&get_cache_results
		&set_cache_results
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/can_use_cache_results/;

use Cache::Memcached::Fast;
use JSON;
use Digest::MD5 qw(md5_hex);
use Log::Any qw($log);
use Devel::Size qw(total_size);

# special logger to make it easy to measure memcached hit and miss rates
our $mongodb_log = Log::Any->get_logger(category => 'mongodb');
$mongodb_log->info("start") if $mongodb_log->is_info();

# Initialize exported variables

$memd = Cache::Memcached::Fast->new(
	{
		'servers' => $memd_servers,
		'utf8' => 1,
		compress_threshold => 10000,
	}
);

# Maximum object size that we can store in memcached
$max_memcached_object_size = 1048576;

my $json = JSON->new->utf8->allow_nonref->canonical;

=head1 FUNCTIONS

=head2  generate_cache_key($name, $context_ref)

Generate a key to use for caching, that depends on the content of the $context_ref object.
The key is prepended by the name of the variable we want to store, so that we can set multiple variables for the same context
(e.g. a count of search results + the search results themselves)

=head3 Arguments

=head4 $name Name of the variable we want to cache.

=head4 $object_ref Reference to all the context / parameters etc. that have an influence on what we want to cache

=head3 Return values

MD5 of the key.

=cut

sub generate_cache_key ($name, $context_ref) {

	# We generate a sorted JSON so that we always have the same key for the context object
	# even if it contains hashes (Storable::freeze may not have the same order of keys)
	my $context_json = $json->encode($context_ref);
	my $key = $server_domain . ':' . $name . '/' . md5_hex($context_json);
	$log->debug("generate_cache_key", {context_ref => $context_ref, context_json => $context_json, key => $key})
		if $log->is_debug();
	return $key;
}

=head2 get_cache_results ($key, $data_debug_ref)

Get the results of a query from the cache.

=head3 Arguments

=head4 $key

=head4 $data_debug_ref Reference to a string that will be appended with debug information

=head3 Return values

The results of the query, or undef if the query was not found in the cache.

=cut

sub get_cache_results ($key, $data_debug_ref) {

	my $results;

	$log->debug("hashed query cache key", {key => $key}) if $log->is_debug();

	if (can_use_cache_results($data_debug_ref)) {
		$log->debug("Retrieving value for cache query key", {key => $key}) if $log->is_debug();
		$results = $memd->get($key);
		if (not defined $results) {
			$log->debug("Did not find a value for cache query key", {key => $key}) if $log->is_debug();
			$mongodb_log->info("get_cache_results - miss - key: $key") if $mongodb_log->is_info();
			$$data_debug_ref .= "cache_miss\n";
		}
		else {
			$log->debug("Found a value for cache query key", {key => $key}) if $log->is_debug();
			$mongodb_log->info("get_cache_results - hit - key: $key") if $mongodb_log->is_info();
			$$data_debug_ref .= "cache_hit\n";
		}
	}
	return $results;
}

=head2 set_cache_results ($key, $results, $data_debug_ref)

Set the results of a query in the cache.

=head3 Arguments

=head4 $key

=head4 $results

=head4 $data_debug_ref Reference to a string that will be appended with debug information

=head3 Return values

=cut

sub set_cache_results ($key, $results, $data_debug_ref) {

	$log->debug("Setting value for cache query key", {key => $key}) if $log->is_debug();
	my $result_size = total_size($results);

	# $max_memcached_object_size is defined is Cache.pm
	# we assume that compression will reduce the size by at least 50%
	my $factor = 2;
	if ($result_size >= $max_memcached_object_size * $factor) {
		$mongodb_log->info(
			"set_cache_results - skipping - setting value - key: $key (uncompressed total_size: $result_size > max size * $factor ($max_memcached_object_size * $factor))"
		);
		$$data_debug_ref
			.= "set_cache_results: skipping, value to large - (uncompressed total_size: $result_size > max size * $factor ($max_memcached_object_size * $factor))\n";
		return;
	}

	if ($mongodb_log->is_info()) {
		$mongodb_log->info("set_cache_results - setting value - key: $key - uncompressed total_size: $result_size");
	}

	if ($memd->set($key, $results, 3600)) {
		$mongodb_log->info("set_cache_results - updated - key: $key - uncompressed total_size: $result_size")
			if $mongodb_log->is_info();
		$$data_debug_ref .= "set_cache_results: updated\n";
	}
	else {
		$log->debug("Could not set value for MongoDB query key", {key => $key});
		$mongodb_log->info("set_cache_results - error - key: $key - uncompressed total_size: $result_size")
			if $mongodb_log->is_info();
		$$data_debug_ref .= "set_cache_results: error\n";
	}

	return;
}

1;
