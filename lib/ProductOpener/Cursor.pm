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

package ProductOpener::Cursor;

use ProductOpener::PerlStandards;

sub new ($class, @list) {
    my $self = {
        index => -1,
        list => @list
    };

    return bless $self, $class;
}

sub next ($self) {
    $self->{index}++;
    if ($self->{index} < scalar $self->{list}) {
        return $self->{list}[$self->{index}];
    }

    return undef;
}

sub all ($self) {
   return $self->{list};
}

1;