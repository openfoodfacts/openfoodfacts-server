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

package ProductOpener::OIDC::Server::Web::M::AccessToken;

use utf8;
use Modern::Perl '2012';
use parent 'OAuth::Lite2::Model::AccessToken';

use JSON::WebToken qw/
    encode_jwt
    decode_jwt
/;

my $ACCESS_TOKEN_EXPIRATION = 24*60*60;
my $ACCESS_TOKEN_HMAC_KEY = q{DUMMY_HMAC_KEY_FOR_ACCESS_TOKEN};

sub create {
    my ($class, $auth_info) = @_;
    return unless $auth_info;

    # generate token string
    my $ts = time();
    my $token = encode_jwt (
        {
            auth_id => $auth_info->id,
            expired_on => $ts + $ACCESS_TOKEN_EXPIRATION,
        },
        $ACCESS_TOKEN_HMAC_KEY,
    ); 

    # return instance
    return $class->new({
        auth_id => $auth_info->id,
        token => $token,
        expires_in => $ACCESS_TOKEN_EXPIRATION,
        created_on => $ts,
    });
}

sub validate {
    my ($class, $token) = @_;

    my $decoded;
    # if signature is invalid, JSON::WebToken cause error
    eval {
        $decoded = decode_jwt(
            $token,
            $ACCESS_TOKEN_HMAC_KEY
        ) or return;
    };
    return if $@;

    # verify expiration
    return unless ( $decoded->{expired_on} && 
                    $decoded->{expired_on} >= time() );

    # return instance
    return $class->new({
        auth_id => $decoded->{auth_id},
        token => $token,
        expires_in => $ACCESS_TOKEN_EXPIRATION,
        created_on => $decoded->{expired_on} - $ACCESS_TOKEN_EXPIRATION,
    });
}

1;
