package ProductOpener::OIDC::Server::Web::M::ResourceOwner;
use strict;
use warnings;
use utf8;

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
