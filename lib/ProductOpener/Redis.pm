
package ProductOpener::Redis;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&push_to_search_service

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use Log::Any qw($log);
use ProductOpener::Config2;
use Redis::Client;

sub init_redis() {

	$log->debug("init_redis", { redis_url_env => $ENV{REDIS_URL}, redis_url => $ProductOpener::Config2::redis_url } ) if $log->is_debug();
	
	$log->warn("REDIS_URL env", {redis_url => $ENV{REDIS_URL} }) if $log->is_warn();
	if ($ProductOpener::Config2::redis_url eq "")
	{
		$log->warn("Redis URL not provided for search indexing", { error => $@ }) if $log->is_warn();
		return undef;
	}
	my $redis_client;
	eval {
		$redis_client = Redis::Client->new(host => $ProductOpener::Config2::redis_url);
	};
	if ($@) {
		$log->warn("Error connecting to Redis", { error => $@ }) if $log->is_warn();
	}
	else {
		return $redis_client;
	}
	return undef;
}

my $redis_client = init_redis();

sub push_to_search_service($product_ref) {
	if (defined($redis_client)) {
		eval {
                	$redis_client->rpush('search_import_queue', $product_ref->{code});
		};
	}

        return;
}

1;
