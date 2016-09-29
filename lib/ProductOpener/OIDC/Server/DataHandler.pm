package ProductOpener::OIDC::Server::DataHandler;
use strict;
use warnings;
use utf8;
use parent 'OIDC::Lite::Server::DataHandler';

use OIDC::Lite::Server::Scope;
use OIDC::Lite::Model::IDToken;
use ProductOpener::OIDC::Server;
use ProductOpener::OIDC::Server::Web::M::AccessToken;
use ProductOpener::OIDC::Server::Web::M::AuthInfo;
use ProductOpener::OIDC::Server::Web::M::Client;

use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;

my $client;
my $c = ProductOpener::OIDC::Server->new;

sub get_client_info {
    my $self = shift;
    # return hash ref of client info
    return $client;
}

sub validate_client_by_id {
    my ($self, $client_id) = @_;
    return unless $client_id;

    # obtain Client info
    unless ( $client && $client->{client_id} eq $client_id ) {
        $client = undef;
        $client = ProductOpener::OIDC::Server::Web::M::Client->find_by_client_id($c->db, $client_id)
            or return;
    }

    return ($client);
}

sub validate_client_for_authorization {
    my ($self, $client_id, $response_type) = @_;
    return unless ( $client_id && $response_type );
    return unless $self->validate_client_by_id($client_id);

    ## TODO: return $client->is_allowed_response_type($response_type)
    my %allowed_response_type_hash;
    $allowed_response_type_hash{$_}++ foreach @{$client->{allowed_response_types}};

    return (exists $allowed_response_type_hash{$response_type});
}

sub validate_redirect_uri {
    my ($self, $client_id, $redirect_uri) = @_;
    return unless ( $client_id && $redirect_uri );
    return unless $self->validate_client_by_id($client_id);

    ## TODO: return $client->is_valid_redirect_uri($redirect_uri)
    my %redirect_uri_hash;
    $redirect_uri_hash{$_}++ foreach @{$client->{redirect_uris}};

    return (exists $redirect_uri_hash{$redirect_uri});
}

sub validate_scope {
    my ($self, $client_id, $scope) = @_;
    return unless ( $client_id && $scope );
    return unless $self->validate_client_by_id($client_id);

    # Only OpenID Connect Scope are allowed
    my @scopes = split(/\s/, $scope);
    return unless OIDC::Lite::Server::Scope->is_openid_request(\@scopes);

    ## TODO: return $client->is_allowed_scope($scope)
    return 1;
}

# Optional request param are not validated
sub validate_display {
    my ($self, $display) = @_;
    return 1;
}

sub validate_prompt {
    my ($self, $prompt) = @_;
    return 1;
}

sub validate_max_age {
    my ($self, $param) = @_;
    return 1;
}

sub validate_ui_locales {
    my ($self, $ui_locales) = @_;
    return 1;
}

sub validate_claims_locales {
    my ($self, $claims_locales) = @_;
    return 1;
}

sub validate_id_token_hint {
    my ($self, $param) = @_;
    return 1;
}

sub validate_login_hint {
    my ($self, $param) = @_;
    return 1;
}

sub validate_request {
    my ($self, $param) = @_;
    return 1;
}

sub validate_request_uri {
    my ($self, $param) = @_;
    return 1;
}

sub validate_acr_values {
    my ($self, $param) = @_;
    return 1;
}

sub get_user_id_for_authorization {
    my ($self, $session) = @_;
    return $User_id;
}

sub create_id_token {
    my ($self) = @_;
    return unless ( $self->{request} && $oidc );
    
    my $oidc_config = $oidc;
    my $ts = time();
    my $payload = {
        sub => $self->get_user_id_for_authorization(),
        iss => $oidc_config->{id_token}->{iss},
        iat => $ts,
        exp => $ts + $oidc_config->{id_token}->{expires_in},
        aud => $client->{client_id},
    };
    $payload->{nonce} = $self->{request}->param('nonce') if $self->{request}->param('nonce');

    return OIDC::Lite::Model::IDToken->new(
        header => {
            typ => q{JOSE},
            alg => q{RS256},
            kid => 1,
        },
        payload => $payload,
        key     => $oidc_config->{id_token}->{priv_key},
    );
}

sub create_or_update_auth_info {
    my ($self, %args) = @_;
    return unless ( %args && 
                    $self->{request} &&
                    $self->{request}->param('redirect_uri'));
  
    $args{redirect_uri} = $self->{request}->param('redirect_uri');
    # create AuthInfo Object
    my $info = ProductOpener::OIDC::Server::Web::M::AuthInfo->create(%args);
    $info->set_code;
    $info->save($c->db);
    return $info;
}

sub create_or_update_access_token {
    my ($self, %args) = @_;
    return unless $args{auth_info};

    my $auth_info = $args{auth_info};
    # If the request is for token endpoint, the code in AuthInfo is deleted
    if ($self->{request}->param('grant_type') && 
        $self->{request}->param('grant_type') eq q{authorization_code}) {
        $auth_info->set_refresh_token($c->db);
        $auth_info->unset_code($c->db);
        $auth_info->save($c->db);
    }
    return ProductOpener::OIDC::Server::Web::M::AccessToken->create($args{auth_info});
}

sub validate_client {
    my ($self, $client_id, $client_secret, $grant_type) = @_;
    return unless ( $client_id && $grant_type );
    return unless $self->validate_client_by_id($client_id);

    # verify client_secret
    return unless $client->{client_secret} eq $client_secret;

    ## TODO: return $client->is_allowed_grant_type($response_type)
    my %allowed_grant_type_hash;
    $allowed_grant_type_hash{$_}++ foreach @{$client->{allowed_grant_types}};

    return (exists $allowed_grant_type_hash{$grant_type});
}

sub get_auth_info_by_code {
    my ($self, $code) = @_;
    return ProductOpener::OIDC::Server::Web::M::AuthInfo->find_by_code($c->db, $code);
}

sub get_auth_info_by_refresh_token {
    my ($self, $refresh_token) = @_;
    return ProductOpener::OIDC::Server::Web::M::AuthInfo->find_by_refresh_token($c->db, $refresh_token);
}

sub get_access_token {
    my ($self, $token) = @_;
    return ProductOpener::OIDC::Server::Web::M::AccessToken->validate($token);
}

sub get_auth_info_by_id {
    my ($self, $id) = @_;
    return ProductOpener::OIDC::Server::Web::M::AuthInfo->find_by_id($c->db, $id);
}

1;
