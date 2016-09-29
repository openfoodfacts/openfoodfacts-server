package ProductOpener::OIDC::Server::Web::M::Client;
use strict;
use warnings;
use utf8;

use JSON::PP qw/
    encode_json
    decode_json
/;
use Crypt::OpenSSL::Random qw/
    random_bytes
    random_pseudo_bytes
/;

use ProductOpener::OIDC::Server;
my $c = ProductOpener::OIDC::Server->new;

# sample client data
our $SAMPLE_CLIENTS = {
    'sample_client_id' => {
        'id' => 0,
        'name' => q{Sample Client},
        'client_id' => q{sample_client_id},
        'client_secret' => q{sample_client_secret},
        'redirect_uris' => [
            'www.hangy.de'
#            $c->config->{SampleClient}->{redirect_uri},
        ],
        'allowed_response_types' => [
            q{code}, q{id_token}, q{token},
            q{code id_token}, q{id_token token}, q{code token},
            q{code id_token token},
        ],
        'allowed_grant_types' => [
            q{authorization_code},
            q{refresh_token},
        ],
        'client_type' => 4,
        'is_disabled' => 0,
    },
};

my $CLIENT_TYPES = {
    '1' => {
        'display' => 'Web Client',
        'allowed_response_types' => [
            q{code}, q{code id_token},
        ],
        'allowed_grant_types' => [
            q{authorization_code},
            q{refresh_token},
        ],
    },
    '2' => {
        'display' => 'JavaScript Client',
        'allowed_response_types' => [
            q{id_token}, 
            q{id_token token},
        ],
        'allowed_grant_types' => [],
    },
    '3' => {
        'display' => 'Mobile App',
        'allowed_response_types' => [
            q{code},
            q{id_token},
            q{id_token token},
            q{code id_token token},
        ],
        'allowed_grant_types' => [
            q{authorization_code},
            q{refresh_token},
        ],
    },
    '4' => {
        'display' => 'Full Spec Client',
        'allowed_response_types' => [
            q{code}, q{id_token}, q{token},
            q{code id_token}, q{id_token token}, q{code token},
            q{code id_token token},
        ],
        'allowed_grant_types' => [
            q{authorization_code},
            q{refresh_token},
        ],
    },
};

sub create {
    my ($class, $args) = @_;

    return unless(
        $args->{name} &&
        $args->{redirect_uris}
    );

    $args->{client_type} = 4;
    my $credentials = $class->_gen_credentials();

    return {
        'id' => 0,
        'name' => $args->{name},
        'client_id' => $credentials->{client_id},
        'client_secret' => $credentials->{client_secret},
        'redirect_uris' => $args->{redirect_uris},
        'client_type' => $args->{client_type},
        'allowed_response_types' => $CLIENT_TYPES->{$args->{client_type}}->{allowed_response_types},
        'allowed_grant_types' => $CLIENT_TYPES->{$args->{client_type}}->{allowed_grant_types},
        'is_disabled' => $args->{is_disabled},
    };
}

sub insert {
    my ($class, $db, $args) = @_;

    $args->{is_disabled} = 0 unless defined $args->{is_disabled};
    
    my $row = $db->insert(
        'clients' => {
            name => $args->{name},
            client_id => $args->{client_id},
            client_secret => $args->{client_secret},
            redirect_uris => encode_json($args->{redirect_uris}),
            client_type => $args->{client_type},
            is_disabled => $args->{is_disabled},
        }
    );
    return $class->_row_to_hash_ref($row);
}

sub update {
    my ($class, $db, $args) = @_;
    
    my $row = $db->update(
        'clients',
        {
            name => $args->{name},
            client_id => $args->{client_id},
            client_secret => $args->{client_secret},
            redirect_uris => encode_json($args->{redirect_uris}),
            client_type => $args->{client_type},
            is_disabled => $args->{is_disabled} || 0,
        },
        {
            id => $args->{id},
        }
    );
}

sub find_by_client_id {
    my ($class, $db, $client_id) = @_;
    return unless $client_id;

    # find from sample Clients
    return $SAMPLE_CLIENTS->{$client_id} if $SAMPLE_CLIENTS->{$client_id};

    # find from DB
    my $row = $db->single(
        'clients',
        {
            client_id => $client_id,
            is_disabled => 0,
        }
    ) or return;
    return $class->_row_to_hash_ref($row);
}

sub find_by_id {
    my ($class, $db, $id) = @_;
    return unless ($db && $id);

    return $SAMPLE_CLIENTS->{sample_client_id} if $id == 0;

    # fetch from DB
    my $row = $db->single(
        'clients',
        {
            id => $id,
            is_disabled => 0,
        }
    ) or return;
    return $class->_row_to_hash_ref($row);
}

sub find_all {
    my ($class, $db) = @_;
    return unless $db;

    my @rows = $db->search(
        'clients',
        { is_disabled => 0 },
        { order_by => 'id' }
    );

    my @clients;
    foreach my $row (@rows) {
        push(@clients, $class->_row_to_hash_ref($row));
    }
    return \@clients;
}

sub _gen_credentials {
    my $class = shift;
    return {
        client_id => unpack('H*', random_pseudo_bytes(32)),
        client_secret => unpack('H*', random_bytes(32)),
    };
}

sub _row_to_hash_ref {
    my ($class, $row) = @_;
    return {
        'id' => $row->id,
        'name' => $row->name,
        'client_id' => $row->client_id,
        'client_secret' => $row->client_secret,
        'redirect_uris' => decode_json($row->redirect_uris),
        'allowed_response_types' => $CLIENT_TYPES->{$row->client_type}->{allowed_response_types},
        'allowed_grant_types' => $CLIENT_TYPES->{$row->client_type}->{allowed_grant_types},
        'client_type' => $row->client_type,
        'is_disabled' => $row->is_disabled,
    };
}

1;
