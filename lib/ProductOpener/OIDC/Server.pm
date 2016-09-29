package ProductOpener::OIDC::Server;
use strict;
use warnings;
use utf8;

use ProductOpener::Display qw/:all/;

sub new {

	my $class = shift;
	return bless {}, $class;

}

sub auth {

	my $self = shift;
	if ( !defined $self->{auth} ) {
		my $oidc_collection = $database->get_collection('oidc_auth');
		$self->{auth} = $oidc_collection;
	}

	return $self->{auth};

}

sub clients {

	my $self = shift;
	if ( !defined $self->{clients} ) {
		my $oidc_collection = $database->get_collection('oidc_clients');
		$self->{clients} = $oidc_collection;
	}

	return $self->{clients};

}

1;
