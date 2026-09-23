# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

ProductOpener::Health - heatlh contants

=head1 DESCRIPTION

=cut

package ProductOpener::Health;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);
use DateTime;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		$status_fail
		$status_pass
		$status_warn

		&current_time_iso8601
		&sanitize_url

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

$status_fail = 'fail';
$status_pass = 'pass';
$status_warn = 'warn';

=head2 current_time_iso8601()

Return the current time as an ISO 8601 / RFC 3339 string in UTC, suitable for
the C<time> field of a health-check object as described in
L<https://inadarei.github.io/rfc-healthcheck/>.

=cut

sub current_time_iso8601() {
	return DateTime->now(time_zone => 'UTC')->iso8601 . 'Z';
}

=head2 sanitize_url($url)

Strip userinfo (credentials) from a URL before including it in a response.

Handles any URL scheme, e.g. C<postgresql://user:pass@host/db> becomes
C<postgresql://host/db>.

=cut

sub sanitize_url ($url) {
	return unless defined $url;
	$url =~ s{^([a-z][a-z0-9+\-.]*://)([^\@/]*\@)}{$1}i;
	return $url;
}

1;

