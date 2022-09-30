use Redis::Client;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&push_to_search_service

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

sub init_redis() {
	if ($ProductOpener::Config2::redis_url eq "")
	{
		$log->warn("Redis URL not provided for search indexing", { error => $@ }) if $log->is_warn();
		return undef;
	}
	# Now send the barcode to Redis so that it can be indexed
	eval {
		my $redis_client = Redis::Client->new(host => $ProductOpener::Config2::redis_url);
		return $redis_client;
	
	};
	if ($@) {
		$log->warn("Error connecting to Redis", { error => $@ }) if $log->is_warn();
	}
	return undef;
}

my $redis_client = init_redis();

sub push_to_search_service {
	if (defined($redis_client)) {
                $redis_client->rpush('search_import_queue', $_[0]->{code});
	}

        return;
}

1;
