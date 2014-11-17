#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;

use Apache2::RequestRec ();
use Apache2::Const ();

Blogs::Display::init();

my %request = (
'query_string'=>$ENV{QUERY_STRING},
'referer'=>referer()
);

print STDERR "display.pl : query_string: " . $request{query_string} . "\n"; 

analyze_request(\%request);

print STDERR "display.pl blogid: $request{blogid} tagid: $request{tagid} urlsdate: $request{urlsdate} urlid: $request{urlid} user: $request{user} query: $request{query} \n";

if (defined $request{api}) {
	display_api(\%request);
}
elsif (defined $request{text}) {
	display_text(\%request);
}
elsif (defined $request{mission}) {
	display_mission(\%request);
}
elsif (defined $request{product}) {
	display_product(\%request);
}
elsif ((defined $request{groupby_tagtype}) or ((defined $request{tagtype}) and (defined $request{tagid}))) {
	display_tag(\%request);
}



if (0) {

	if (($request{tag} ne $request{tagid}) and ($request{tagid} ne 'all') and (not defined $request{query}) and (not defined $request{user}) and (not defined $request{menuid})) {
		# my $location =  URI::Escape::XS::encodeURIComponent($request{canon_tag});
		my $location = "/by/" . $request{tagid};
		
		my $r = shift;

		$r->headers_out->set(Location =>$location);
		$r->status(301);  
		return 301;
		
	}
	

	display_news(\%request);
}

if (defined $request{redirect}) {
		my $r = shift;

		$r->headers_out->set(Location => $request{redirect});
		$r->status(301);  
		return 301;
}

exit(0);

