package ProductOpener::OIDC::Server::Request;
use strict;
use warnings;
use utf8;

sub new {

	my $class = shift;
	return bless {}, $class;

}

sub param($) {

	my ($self, $name) = @_;

	CGI::url_param($name);

}


sub parameters() {

	CGI::url_param();

}

1;
