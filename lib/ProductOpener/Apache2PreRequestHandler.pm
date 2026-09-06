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

ProductOpener::Apache2PreRequestHandler - Pre-Request Handler for OpenTelemetry tracing

=head1 SYNOPSIS

C<ProductOpener::Apache2PreRequestHandler> is an Apache 2.0 pre-request handler (registered as PerlPostReadRequestHandler) that is used to trace incoming requests.

=head1 DESCRIPTION

This handler is invoked early in the Apache request processing pipeline, before the request is processed.
It extracts trace context from incoming HTTP headers (traceparent) and creates a new span for the request.
The span is stored in Apache's pnotes for use by other handlers.

The OpenTelemetry SDK is initialized via environment variables:
- OTEL_EXPORTER_OTLP_ENDPOINT: The OTLP collector endpoint
- OTEL_SERVICE_NAME: The service name for traces
- Other standard OTEL environment variables

The SDK initialization happens automatically when the OpenTelemetry module is loaded.

=cut

package ProductOpener::Apache2PreRequestHandler;

use ProductOpener::PerlStandards;

use Log::Any '$log', default_adapter => 'Stderr';
use Apache2::Const qw(:common);
use ProductOpener::Version qw/$version/;
use ProductOpener::Constants qw(OTEL_SPAN_PNOTES_KEY);
use ProductOpener::OpenTelemetry qw/get_otel/;

use Punk::OpenTelemetry();

# Obtain the current default tracer provider
sub handler {
	my ($r) = @_;

	my $o = get_otel();

	my $span;
	if (defined $o->{tracer}) {
		# Extract trace context from HTTP headers
		my $headers_in = $r->headers_in;
		my $ctx = Punk::OpenTelemetry::Propagate::extract($headers_in);
		$span = $o->{tracer}->start($r->method . ' ' . $r->uri, kind => 2, parent => $ctx);
		if ($span) {
			$span->attr('http.method' => $r->method);
			$span->attr('http.url' => $r->uri);
			$span->attr('http.host' => $r->hostname);
		}
	}

	# Store the span in the context
	$r->pnotes(OTEL_SPAN_PNOTES_KEY, $span);

	return Apache2::Const::OK;
}

1;
