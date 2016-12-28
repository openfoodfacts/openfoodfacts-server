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

package ProductOpener::OIDC::Server::Web::M::AuthInfo;

use utf8;
use Modern::Perl '2012';
use parent 'OIDC::Lite::Model::AuthInfo';
__PACKAGE__->mk_accessors(qw(
	code_expired_on
	refresh_token_expired_on
));

use JSON::PP qw/
	decode_json
	encode_json
/;
use Digest::SHA qw/
	hmac_sha256_base64
/;
use Crypt::OpenSSL::Random qw/
	random_pseudo_bytes
/;
use OIDC::Lite::Server::Scope;

use ProductOpener::Config qw/:all/;

my $CODE_EXPIRATION = 5*60;
my $CODE_HMAC_KEY = q{DUMMY_HMAC_KEY_FOR_AUTHRIZATION_CODE};
my $REFRESH_TOKEN_EXPIRATION = 30*24*60*60;
my $REFRESH_TOKEN_HMAC_KEY = q{DUMMY_HMAC_KEY_FOR_AUTHRIZATION_CODE};

sub create {
	my ($class, %args) = @_;
	return unless %args;

	$args{id} = undef;
	$args{code} = q{};
	$args{code_expired_on} = 0;
	$args{refresh_token} = q{};
	$args{refresh_token_expired_on} = 0;
	my @scopes = split(/\s/, $args{scope});
	$args{userinfo_claims} = OIDC::Lite::Server::Scope->to_normal_claims(\@scopes);
	return $class->new(\%args);
}

sub set_code {
	my $self = shift;

	$self->code_expired_on(time() + $CODE_EXPIRATION);
	my $code = hmac_sha256_base64(
		$self->client_id.
		$self->code_expired_on.
		unpack('H*', random_pseudo_bytes(32)),
		$CODE_HMAC_KEY);
	$self->code($code);
}

sub unset_code {
	my $self = shift;

	$self->code_expired_on(0);
	$self->code(q{});
}

sub set_refresh_token {
	my $self = shift;

	$self->refresh_token_expired_on(time() + $REFRESH_TOKEN_EXPIRATION);
	my $refresh_token = hmac_sha256_base64(
		$self->client_id.
		$self->refresh_token_expired_on.
		unpack('H*', random_pseudo_bytes(32)),
		$REFRESH_TOKEN_HMAC_KEY);
	$self->refresh_token($refresh_token);
}

sub save {
	my ($self, $db) = @_;

	my @scopes = split(/\s/, $self->scope);
	$self->userinfo_claims(OIDC::Lite::Server::Scope->to_normal_claims(\@scopes));

	my $row;
	if (!$self->id) {
		my $res = $db->insert_one(
			{
				client_id => $self->client_id,
				user_id => $self->user_id,
				scope => $self->scope,
				refresh_token => $self->refresh_token,
				code => $self->code,
				redirect_uri => $self->redirect_uri,
				id_token => $self->id_token,
				userinfo_claims => encode_json($self->userinfo_claims),
				code_expired_on => $self->code_expired_on,
				refresh_token_expired_on => $self->refresh_token_expired_on,
			}
		);
		$self->id($res->inserted_id->value);
	} else {
		$row = $db->find_one_and_update(
			{
				_id => $self->id,
			},
			{
				client_id => $self->client_id,
				user_id => $self->user_id,
				scope => $self->scope,
				refresh_token => $self->refresh_token,
				code => $self->code,
				redirect_uri => $self->redirect_uri,
				id_token => $self->id_token,
				userinfo_claims => encode_json($self->userinfo_claims),
				code_expired_on => $self->code_expired_on,
				refresh_token_expired_on => $self->refresh_token_expired_on,
			}
		);
	}
}

sub find_by_code {
	my ($self, $db, $code) = @_;
	return unless ($db && $code);

	# fetch from DB
	my $row;
	eval {
		$row = $db->find_one({ code => $code });
	};
	if ($@) {
		return;
	}

	# verify expiration
	return unless $row->code_expired_on >= time();
	return $self->_row_to_obj($row);
}

sub find_by_refresh_token {
	my ($self, $db, $refresh_token) = @_;
	return unless ($db && $refresh_token);

	# fetch from DB
	my $row;
	eval {
		$row = $db->find_one({ refresh_token => $refresh_token });
	};
	if ($@) {
		return;
	}

	# verify expiration
	return unless $row->refresh_token_expired_on >= time();
	return $self->_row_to_obj($row);
}

sub find_by_id {
	my ($self, $db, $id) = @_;
	return unless ($db && $id);

	# fetch from DB
	my $row;
	eval {
		$row = $db->find_one({ id => $id });
	};
	if ($@) {
		return;
	}

	return $self->_row_to_obj($row);
}

sub _row_to_obj {
	my ($class, $row) = @_;

	return $class->new({
		id => $row->_id,
		client_id => $row->client_id,
		user_id => $row->user_id,
		scope => $row->scope,
		refresh_token => $row->refresh_token,
		code => $row->code,
		redirect_uri => $row->redirect_uri,
		id_token => $row->id_token,
		userinfo_claims => decode_json($row->userinfo_claims),
		code_expired_on => $row->code_expired_on,
		refresh_token_expired_on => $row->refresh_token_expired_on,
	});
}

1;
