# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

ProductOpener::Utils - various utility functions

=cut

package ProductOpener::Users;
use ProductOpener::PerlStandards;


=head1 FUNCTIONS

=head2 generate_token()

C<generate_token()> generates a secure token for the session IDs. More information: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html#Session_ID_Content_.28or_Value.29

=head3 Return values

Creates a new session ID

=cut

sub generate_token ($name_length) {

	my @chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
	return join '', map {$chars[irand @chars]} 1 .. $name_length;
}

1;
