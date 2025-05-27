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

ProductOpener::Apache2ChildExitHandler - Child Exit Handler for OpenTelemetry tracing

=head1 SYNOPSIS

C<ProductOpener::Apache2ChildExitHandler> is a Apache 2.0 child exit handler that flushed any trace listeners.

=cut

package ProductOpener::Apache2ChildExitHandler;

use ProductOpener::PerlStandards;

use Log::Any '$log', default_adapter => 'Stderr';
use Apache2::Const qw(:common);

use Future::AsyncAwait;

async sub handler {
	my $provider = OpenTelemetry->tracer_provider;
	if (not($provider)) {
		return;
	}

	my $flush_result;
	eval {$flush_result = await $provider->force_flush();};
	my $err = $@;
	if ($err) {
		$log->warn('ProductOpener::Apache2ChildExitHandler::handler: provider flush error', {error => $err})
			if $log->is_warn();
	}
	else {
		$log->debug('ProductOpener::Apache2ChildExitHandler::handler: provider flushed',
			{flush_result => $flush_result})
			if $log->is_debug();
	}

	return Apache2::Const::OK;
}

1;
