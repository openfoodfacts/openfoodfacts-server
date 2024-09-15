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
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

use Cache::Memcached::Fast;
use JSON;
use Digest::MD5 qw(md5_hex);
use Log::Any qw($log);

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

1;
