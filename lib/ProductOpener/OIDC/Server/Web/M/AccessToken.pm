package ProductOpener::OIDC::Server::Web::M::AccessToken;
use strict;
use warnings;
use utf8;
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
