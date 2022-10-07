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

use ProductOpener::PerlStandards;

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
use Apache2::Const qw(:common);

# The nginx reverse proxy turns /somepath?someparam=somevalue to /cgi/display.pl?/somepath?someparam=somevalue
# so that all non /cgi/ queries are sent to display.pl and that we can get the path in the query string
# CGI.pm thus adds somepath? at the start of the name of the first parameter.
# we need to remove it so that we can use the CGI.pm param() function to later access the parameters

my @params = multi_param();
if (defined $params[0]) {
	my $first_param = $params[0];
	my $first_param_value = single_param($first_param);
	$log->debug("replacing first param to remove path from parameter name", { first_param => $first_param, $first_param_value => $first_param_value });
	CGI::delete($first_param);
	$first_param =~ s/^(.*?)\?//;
	param($first_param, $first_param_value);
}

my $request_ref = ProductOpener::Display::init_request();

$log->debug("before analyze_request", { query_string => $request_ref->{query_string} });

# analyze request will fill request with action and parameters
analyze_request($request_ref);

# If we have an error, display the error page and return

if (defined $request_ref->{error_status}) {
	$log->debug("analyze_request error", { request_ref => $request_ref });
	display_error($request_ref->{error_message}, $request_ref->{error_status});
	$log->debug("analyze_request error - return Apache2::Const::OK");
	return Apache2::Const::OK;
}

$log->debug("after analyze_request", { tagid => $request_ref->{tagid}, urlsdate => $request_ref->{urlsdate}, urlid => $request_ref->{urlid}, user => $request_ref->{user}, query => $request_ref->{query} });

# Only display texts if products are private and no owner is defined
if ( ((defined $server_options{private_products}) and ($server_options{private_products}))
	and ((defined $request_ref->{api}) or (defined $request_ref->{product}) or (defined $request_ref->{groupby_tagtype}) or ((defined $request_ref->{tagtype}) and (defined $request_ref->{tagid})))
	and (not defined $Owner_id)) {

	display_error_and_exit(lang("no_owner_defined"), 200);
}

if ((defined $request_ref->{api}) and (defined $request_ref->{api_method})) {
	if (single_param("api_method") eq "search") {
		# /api/v0/search
		# FIXME: for an unknown reason, using display_search_results() here results in some attributes being randomly not set
		# because of missing fields like nova_group or nutriscore_data, but not for all products.
		# this does not seem to happen with display_tag()
		# display_search_results($request_ref);
		display_tag($request_ref);
	}
	elsif (single_param("api_method") =~ /^preferences(_(\w\w))?$/) {
		# /api/v0/preferences or /api/v0/preferences_[language code]
		display_preferences_api($request_ref, $2);
	}	
	elsif (single_param("api_method") =~ /^attribute_groups(_(\w\w))?$/) {
		# /api/v0/attribute_groups or /api/v0/attribute_groups_[language code]
		display_attribute_groups_api($request_ref, $2);
	}
	elsif (single_param("api_method") eq "taxonomy") {
		display_taxonomy_api($request_ref);
	}	
	else {
		# /api/v0/product/[code] or a local name like /api/v0/produit/[code] so that we can easily add /api/v0/ to any product url
		display_product_api($request_ref);
	}
}
elsif (defined $request_ref->{search}) {
	if (single_param("download") and single_param("format")) {
		$request_ref->{format} = single_param('format');
		search_and_export_products($request_ref,{}, undef);
	}
	else {
		display_search_results($request_ref);
	}
}
elsif (defined $request_ref->{properties}) {
	display_properties($request_ref);
}
elsif (defined $request_ref->{text}) {
	display_text($request_ref);
}
elsif (defined $request_ref->{mission}) {
	display_mission($request_ref);
}
elsif (defined $request_ref->{product}) {
	# if we are passed the field parameter, make the request an API request
	# this is so that we can easily add ?fields=something at the end of a product url
	if (defined single_param("fields")) {
		display_product_api($request_ref);
	}
	else {
		display_product($request_ref);
	}
}
elsif (defined $request_ref->{points}) {
	display_points($request_ref);
}
elsif ((defined $request_ref->{groupby_tagtype}) or ((defined $request_ref->{tagtype}) and (defined $request_ref->{tagid}))) {
	display_tag($request_ref);
}

exit 0;
