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

ProductOpener::Apache2PostRequestHandler - Cleanup Handler for OpenTelemetry tracing

=head1 SYNOPSIS

C<ProductOpener::Apache2PostRequestHandler> is an Apache 2.0 cleanup handler (registered as PerlCleanupHandler) that is used to finalize trace spans after the response is sent.

=cut

package ProductOpener::Apache2PostRequestHandler;

use ProductOpener::PerlStandards;
use ProductOpener::Constants qw(OTEL_SPAN_PNOTES_KEY);
use ProductOpener::OpenTelemetry qw/get_otel/;

use Log::Any '$log', default_adapter => 'Stderr';
use Apache2::Const qw(:common);

sub handler {
	my $r = shift;

	# Retrieve the current span from the context
	my $span = $r->pnotes(OTEL_SPAN_PNOTES_KEY);
	if (defined $span) {
		$log->info('ProductOpener::Apache2PostRequestHandler::handler: span found, ending it')
			if $log->is_info();
		$span->attr('http.response.status_code', $r->status);
		$span->status(2, 'upstream refused') if $r->status >= 500;
		get_otel()->{tracer}->enqueue($span);
	}
	else {
		# Usually a subrequest/internal redirect whose own pnotes have no
		# span: the main request's span (if any) was already enqueued.
		$log->debug("ProductOpener::Apache2PostRequestHandler::handler: span not found for " . $r->uri)
			if $log->is_debug();
	}

	# Flush the exporter queue in-time: there is no background loop in
	# Product Opener, so the request that just enqueued its spans is the
	# tick. Bounded by the configured BSP/OTLP timeouts (see
	# ProductOpener::OpenTelemetry::tick).
	get_otel()->tick();

	return Apache2::Const::OK;
}

1;
