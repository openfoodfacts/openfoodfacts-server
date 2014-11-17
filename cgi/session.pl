#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Users qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

Blogs::Display::init();
use Blogs::Lang qw/:all/;



my $html = '';

if (defined $User_id) {
	$html = $Lang{hello}{$lang} . ' ' . $User{name} . $Lang{sep}{$lang} . "!";
	
	my $next_action = param('next_action');
	my $url;
	
	if (defined $next_action) {
		if ($next_action eq 'product_add') {
			$url = "/cgi/product.pl?type=add&code=" . param('code');
		}
		elsif ($next_action eq 'product_edit') {
			$url = "/cgi/product.pl?type=edit&code=" . param('code');
		}
	}
	
	if (defined $url) {
		
		print STDERR "session.pl - redirection to $url\n";
	
		my $r = shift;
  
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
	my $data =  encode_json(\%response);
	
	print "Content-Type: application/json; charset=UTF-8\r\n\r\n" . $data;	
	
}
else {
	display(undef, undef, lang('session_title'), \$html, undef, undef);
}

