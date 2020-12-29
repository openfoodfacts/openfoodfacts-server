#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Log::Any qw($log);

use Apache2::RequestRec ();
use Apache2::Const ();

# The nginx reverse proxy turns /somepath?someparam=somevalue to /cgi/display.pl?/somepath?someparam=somevalue
# so that all non /cgi/ queries are sent to display.pl and that we can get the path in the querty string
# CGI.pm thus adds somepath? at the start of the name of the first parameter.
# we need to remove it so that we can use the CGI.pm param() function to later access the parameters

my @params = param();
if (defined $params[0]) {
	my $first_param = $params[0];
	my $first_param_value = param($first_param);
	$log->debug("replacing first param to remove path from parameter name", { first_param => $first_param, $first_param_value => $first_param_value });
	CGI::delete($first_param);
	$first_param =~ s/^(.*?)\?//;
	param($first_param, $first_param_value);
}

ProductOpener::Display::init();

my %request = (
'query_string'=>$ENV{QUERY_STRING},
'referer'=>referer()
);

$log->debug("before analyze_request", { query_string => $request{query_string} });

analyze_request(\%request);

$log->debug("after analyze_request", { blogid => $request{blogid}, tagid => $request{tagid}, urlsdate => $request{urlsdate}, urlid => $request{urlid}, user => $request{user}, query => $request{query} });

# Only display texts if products are private and no owner is defined
if ( ((defined $server_options{private_products}) and ($server_options{private_products}))
	and ((defined $request{api}) or (defined $request{product}) or (defined $request{groupby_tagtype}) or ((defined $request{tagtype}) and (defined $request{tagid})))
	and (not defined $Owner_id)) {

	display_error(lang("no_owner_defined"), 200);
}

if (defined $request{api}) {
	if (param("api_method") eq "search") {
		# /api/v0/search
		# FIXME: for an unknown reason, using display_search_results() here results in some attributes being randomly not set
		# because of missing fields like nova_group or nutriscore_data, but not for all products.
		# this does not seem to happen with display_tag()
		# display_search_results(\%request);
		display_tag(\%request);
	}
	elsif (param("api_method") =~ /^preferences(_(\w\w))?$/) {
		# /api/v0/preferences or /api/v0/preferences_[language code]
		display_preferences_api(\%request, $2);
	}	
	elsif (param("api_method") =~ /^attribute_groups(_(\w\w))?$/) {
		# /api/v0/attribute_groups or /api/v0/attribute_groups_[language code]
		display_attribute_groups_api(\%request, $2);
	}
	else {
		# /api/v0/product/[code] or a local name like /api/v0/produit/[code] so that we can easily add /api/v0/ to any product url
		display_product_api(\%request);
	}
}
elsif (defined $request{search}) {
	if (param("download") and param("format")) {
		$request{format} = param('format');
		search_and_export_products(\%request,{}, undef);
	}
	else {
		display_search_results(\%request);
	}
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

if (defined $request{redirect}) {
	my $r = shift;

	$r->headers_out->set(Location => $request{redirect});
	$r->status(301);
	return 301;
}

exit 0;
