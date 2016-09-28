package ProductOpener::OIDC::Server;
use strict;
use warnings;
use utf8;

use ProductOpener::Display qw/:all/;

sub new {

	my $class = shift;
	return bless {}, $class;

}

sub db {

	my $self = shift;
	if ( !defined $self->{db} ) {
		my $oidc_collection = $database->get_collection('oidc');
		$self->{db} = $oidc_collection;
	}

	return $self->{db};

}

1;
