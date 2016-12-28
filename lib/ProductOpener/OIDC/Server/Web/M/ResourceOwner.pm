# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2016 Association Open Food Facts
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

package ProductOpener::OIDC::Server::Web::M::ResourceOwner;

use utf8;
use Modern::Perl '2012';

use JSON::PP;

# sample user data
our $RESOURCE_OWNERS = {
    1 => {
        sub => 1,
        name => q{Taro "Testuser" Tokyo},
        given_name => q{Taro},
        family_name => q{Tokyo},
        middle_name => q{Testuser},
        nickname => q{Testuser},
        preferred_username => q{Testuser},
        profile => q{https://profile.example.com/users/1},
        picture => q{https://profile.example.com/users/1/image.png},
        website => q{http://testuser.example.com},
        email => q{user_1@example.com},
#        email_verified => JSON::PP:true,
        gender => q{male},
        birthdate => q{2000-12-31},
        zoneinfo => q{Asia/Tokyo},
        locale => q{jp-JP},
        phone_number => q{+81 (90) 0000 0000},
#        phone_number_verified => JSON::PP:true,
        address => {
            formatted => q{2400 Camino Ramon, Suite 375 San Ramon, CA 94583 United States},
            street_address => q{2400 Camino Ramon, Suite 375},
            locality => q{San Ramon},
            region =>q{CA},
            postal_code => q{94853},
            country => q{United States}
        },
        updated_at => 1356966000,
    },
};

sub find_by_id {
    my ($class, $id) = @_;
    return unless $id;

    # find from sample user data
    return $RESOURCE_OWNERS->{$id} if $RESOURCE_OWNERS->{$id};

    # find from DB
    # TBD
    return;
}

1;
