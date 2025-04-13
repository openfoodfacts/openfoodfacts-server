# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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

ProductOpener::Apache2PreRequestHandler - Output Filter for OpenTelemetry tracing

=head1 SYNOPSIS

C<ProductOpener::Apache2PreRequestHandler> is a Apache 2.0 output filter that can be used to trace the response data.

=cut

package ProductOpener::Apache2PreRequestHandler;

use ProductOpener::PerlStandards;

use Log::Any '$log', default_adapter => 'Stderr';
use Apache2::Const qw(:common);
use OpenTelemetry;
use OpenTelemetry::Context;
use OpenTelemetry::Propagator::TraceContext;
use OpenTelemetry::Trace;
use OpenTelemetry::SDK;
use ProductOpener::Version qw/$version/;

# Obtain the current default tracer provider
my $provider = OpenTelemetry->tracer_provider;

sub handler {
	my ($r) = @_;

	# Create a trace
	my $tracer = $provider->tracer(name => 'ProductOpener', version => $version);

	# Extract trace context from HTTP headers
	my $trace_context = OpenTelemetry::Propagator::TraceContext->new;
	my $headers_in = $r->headers_in;
	my $traceparent_string = $headers_in->{'traceparent'};
	my $context;
	if (defined $traceparent_string) {
		# If traceparent header is available, extract context from headers
		$log->debug('extracted traceparent from headers', {traceparent_string => $traceparent_string})
			if $log->is_debug();
		$context = $trace_context->extract(
			$headers_in,
			$context,
			sub {
				my ($carrier, $field) = @_;

				return $carrier->{$field};
			}
		);
	}
	else {
		# If traceparent header is not available, create a new context
		$log->debug('creating new trace context') if $log->is_debug();
		$context = OpenTelemetry::Context->new();
	}

	# Start a new span with the extracted context
	my $span = $tracer->create_span(
		name => $r->method . ' ' . $r->uri,
		parent => $context,
		attributes => {
			'http.method' => $r->method,
			'http.url' => $r->uri,
			'http.host' => $r->hostname,
		}
	);

	# Store the span in the context
	$context = OpenTelemetry::Trace->context_with_span($span);
	OpenTelemetry::Context->current = $context;
	$r->pnotes('OpenTelemetry::Span->current', $span);

	return Apache2::Const::OK;
}

1;
