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

ProductOpener::Apache2PostRequestHandler - Response Handler for OpenTelemetry tracing

=head1 SYNOPSIS

C<ProductOpener::Apache2PostRequestHandler> is a Apache 2.0 response handler output filter that can be used to trace the response data.

=cut

package ProductOpener::Apache2PostRequestHandler;

use ProductOpener::PerlStandards;

use Log::Any '$log', default_adapter => 'Stderr';
use Apache2::Const qw(:common);
use OpenTelemetry::Trace::Span;

my $provider = OpenTelemetry->tracer_provider;

sub handler {
	my $r = shift;

	# Retrieve the current span from the context
	my $span = $r->pnotes('OpenTelemetry::Span->current');
	if (defined $span) {
		$log->info('ProductOpener::Apache2PostRequestHandler::handler: span found, ending it',
			{recording => $span->recording})
			if $log->is_info();
		$span->set_attribute('http.response.status_code', $r->status);
		$span->end();
	}
	else {
		$log->debug('ProductOpener::Apache2PostRequestHandler::handler: span not found')
			if $log->is_debug();
	}

	my $flush_result;
	eval {$flush_result = $provider->force_flush()->get();};
	my $err = $@;
	if ($err) {
		$log->warn('ProductOpener::Apache2PostRequestHandler::handler: provider flush error', {error => $err})
			if $log->is_warn();
	}
	else {
		$log->debug('ProductOpener::Apache2PostRequestHandler::handler: provider flushed',
			{flush_result => $flush_result})
			if $log->is_debug();
	}

	OpenTelemetry::Context->current = OpenTelemetry::Context->new();

	return Apache2::Const::OK;
}

1;
