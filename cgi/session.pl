#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;



my $html = '';

if (defined $User_id) {
	$html = $Lang{hello}{$lang} . ' ' . $User{name} . $Lang{sep}{$lang} . "!";
	
	my $next_action = param('next_action');
	my $r = shift;
	my $referer = $r->headers_in->{Referer};
	my $url;
	
	if (defined $next_action) {
		if ($next_action eq 'product_add') {
			$url = "/cgi/product.pl?type=add&code=" . param('code');
		}
		elsif ($next_action eq 'product_edit') {
			$url = "/cgi/product.pl?type=edit&code=" . param('code');
		}
	}
	elsif ((defined $referer) and ($referer =~ /^https?:\/\/$subdomain\.$server_domain/) and (not ($referer =~ /(?:session|user)\.pl/))) {
		$url = $referer;
	}
	
	if (defined $url) {
		
		print STDERR "session.pl - redirection to $url\n";
	
        $r->err_headers_out->add('Set-Cookie' => $cookie);
		$r->headers_out->set(Location =>"$url");
		$r->status(301);
		return 301;	
	}
}
else {
	$html = $Lang{goodbye}{$lang};
}

if (param('jqm')) {

	my %response;
	if (defined $User_id) {
		$response{user_id} = $User_id;
		$response{name} = $User{name};
	}
	else {
		$response{error} = "undefined user";
	}
	my $data =  encode_json(\%response);
	
	print "Content-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\n\r\n" . $data;	
	
}
else {
	display_new( {
		title => lang('session_title'),
		content_ref => \$html
	});
}

