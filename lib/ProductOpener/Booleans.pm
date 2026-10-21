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

ProductOpener::NBooleans - normalize boolean values sent in various formats

=head1 DESCRIPTION

=cut

package ProductOpener::Booleans;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&normalize_boolean
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use boolean;

=head1 FUNCTIONS			

=head2 normalize_boolean ($value)

Over the years, we have used different ways to store boolean values in products and to get their values from the API.
This function normalizes the value to a boolean value (true or false) and returns it.

True values:
- true (boolean type)
- "true" string
- 1 (integer or string)
- "checked", "on" (set by HTML checkboxes)

False values:
- false (boolean type)
- "false" string
- 0 (integer)
- "" empty string
- undef
- any other values that are not considered true values

=cut

sub normalize_boolean ($value) {
	if (not defined $value) {
		return false;
	}
	elsif (ref($value) eq "boolean") {
		return $value;
	}
	elsif ($value =~ /^(true|checked|on|1)$/i) {
		return true;
	}
	elsif ($value =~ /^(false|0)$/i) {
		return false;
	}

	return false;
}

1;

