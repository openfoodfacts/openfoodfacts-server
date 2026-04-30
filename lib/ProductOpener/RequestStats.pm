
=head1 NAME

ProductOpener::RequestStats - measure and log some stats (e.g. execution time, database request time) for requests

=head1 DESCRIPTION


=cut

package ProductOpener::RequestStats;

use ProductOpener::Config qw/:all/;
use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&init_request_stats
		&set_request_stats_value
		&set_request_stats_time_start
		&set_request_stats_time_end
		&log_request_stats
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any qw/$log/;
use Time::Monotonic qw(monotonic_time);

# Specific logger to log request stats
our $requeststats_log = Log::Any->get_logger(category => 'requeststats');

sub init_request_stats() {

	my $stats_ref = {};
	set_request_stats_time_start($stats_ref, "request");
	set_request_stats_value($stats_ref, "request_t", time());
	set_request_stats_value($stats_ref, "pid", $$);
	return $stats_ref;
}

sub set_request_stats_value($stats_ref, $key, $value) {
	$stats_ref->{$key} = $value;
	return;
}

sub set_request_stats_time_start($stats_ref, $key) {
	$stats_ref->{$key . "_start"} = monotonic_time();
	return;
}

sub set_request_stats_time_end($stats_ref, $key) {
	$stats_ref->{$key . "_end"} = monotonic_time();
	return;
}

sub log_request_stats($stats_ref) {

	set_request_stats_time_end($stats_ref, "request");

	# Turn all keys ending with _start and _end to a key with the suffix _duration
	foreach my $key (keys %$stats_ref) {
		if ($key =~ /_start$/) {
			my $duration_key = $key;
			$duration_key =~ s/_start$/_duration/;
			my $key_prefix = $key;
			$key_prefix =~ s/_start$//;
			if (defined $stats_ref->{$key_prefix . "_end"}) {
				$stats_ref->{$duration_key} = $stats_ref->{$key_prefix . "_end"} - $stats_ref->{$key};
			}
			else {
				$log->warn("No end key for start key $key in request stats");
			}
			delete $stats_ref->{$key};
			delete $stats_ref->{$key_prefix . "_end"};
		}
	}

	$requeststats_log->info("request_stats", $stats_ref) if $requeststats_log->is_info();

	return;
}

1;
