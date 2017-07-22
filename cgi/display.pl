#!/usr/bin/perl

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;

use Apache2::RequestRec ();
use Apache2::Const ();

ProductOpener::Display::init();

my %request = (
'query_string'=>$ENV{QUERY_STRING},
'referer'=>referer()
);

print STDERR "display.pl : query_string: " . $request{query_string} . "\n"; 

analyze_request(\%request);

print STDERR "display.pl blogid: $request{blogid} tagid: $request{tagid} urlsdate: $request{urlsdate} urlid: $request{urlid} user: $request{user} query: $request{query} \n";

if (defined $request{api}) {
	display_product_api(\%request);
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
elsif (defined $request{points}) {
	display_points(\%request);
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

