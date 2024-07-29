# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

=head1 NAME

ProductOpener::Routing - determines which page to display or API to call based on the URL path

=head1 DESCRIPTION

=cut

package ProductOpener::Routing;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&load_routes
		&check_and_update_rate_limits
		&analyze_request
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Display
	qw/$formatted_subdomain %index_tag_types_set display_robots_txt_and_exit init_request redirect_to_url single_param get_owner_pretty_path/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/%tag_type_from_plural %tag_type_from_singular %tag_type_plural %tag_type_singular lang/;
use ProductOpener::API qw/:all/;
use ProductOpener::Tags
	qw/%taxonomy_fields canonicalize_taxonomy_tag_linkeddata canonicalize_taxonomy_tag_weblink get_taxonomyid/;
use ProductOpener::Food qw/%nutriments_labels/;
use ProductOpener::Index qw/%texts/;
use ProductOpener::Store qw/get_string_id_for_lang/;
use ProductOpener::Redis qw/:all/;
use ProductOpener::RequestStats qw/:all/;

use Encode;
use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Log::Any qw($log);

# Specific logger to track rate-limiter operations
our $ratelimiter_log = Log::Any->get_logger(category => 'ratelimiter');
my %routes = ();
my @regex_routes = ();

=head2 load_routes()

Load OFF routes

=pod

a route is registered with:
	- Pattern:
		- a simple string (e.g. "api") without '/'':
			when you simply want to route with the first component of the path e.g.
			 product/1234 -> product_route
			 No regex is involved. It uses a hash key

		- Or a pattern that capture arguments (e.g. "org/[orgid]"):
			- The value of the orgid param will be stored in $request_ref->{param}{orgid}
			- Ending the pattern with a / means that it can be followed by anything
			! Mind the priority of the routes, the first one that matches will be used
		
	- Handler (sub)
	- (optional) Options : {
		- name

		- regex: 1 if the pattern is a true regex, 0 by default. 
		  When you don't want to use the default limited one.
		  Use named captures to store the arguments in $request_ref->{param}

		- onlyif: a sub($request_ref, @components) that will be called to check if the route should be used
			Its a dynamic routing, using context of the request.
			Results is used as a boolean to decide if the route should be used.
		}

non regex routes will be matched first, then regex routes

=cut

sub load_routes() {
	my $routes = [
		# no priority
		['api', \&api_route],
		['search', \&search_route],
		['taxonomy', \&taxonomy_route],
		['properties', \&properties_route],
		['property', \&properties_route],
		['products', \&products_route],
		# with priority
		['', \&index_route],
		['^(?<page>\d+)$', \&index_route, {regex => 1}],
		['org/[orgid]/', \&org_route],
		# Known tag type? Catch all if no route matched
		['.*', \&facets_route, {regex => 1}],
	];

	# all translations for route 'missions' (e.g. missioni, missões ...)
	my @missions_route = (map {[$_, \&mission_route]} values %{$tag_type_singular{missions}});
	# all translations for route 'product' (e.g. produit, producto ...)
	my @product_route = (map {[$_, \&product_route]} values %{$tag_type_singular{products}});
	# all translations for route 'en:product' (e.g. fr:produit, es:producto ...)
	my @lc_product_route
		= (map {["$_:$tag_type_singular{products}{$_}", \&product_route]} keys %{$tag_type_singular{products}});

	# text route : index, index-pro, ...
	my @text_route;
	foreach my $text (keys %texts) {
		push @text_route, [
			$text,
			\&text_route,
			{
				onlyif => sub ($request_ref, @components) {
					return $texts{$text}{$request_ref->{lc}} || defined $texts{$text}{'en'};
				}
			}
		];
	}

	# Renamed text : en/nova-groups-for-food-processing -> nova, ...
	my @redirect_text_route = ();
	if (defined $options{redirect_texts}) {
		# we use a custom regex to exactly match "en/nova-groups-for-food-processing"
		@redirect_text_route = (map {["\^$_\$", \&redirect_text_route, {regex => 1}]} keys %{$options{redirect_texts}});
	}
	push(@$routes, @missions_route, @product_route, @text_route, @lc_product_route, @redirect_text_route,);

	register_route($routes);

	return 1;
}

=head2 analyze_request ( $request_ref )

Analyze request parameters and decide which method to call.

=head3 Parameters

=head4 $request_ref reference to a hash that will contain analyzed parameters

=head3 Details

It will analyze path and parameters.

Some information is set in request_ref, notably
- polished query_string
- page number (page)
- api version (e.g v3), api action (e.g product) and api method (e.g. GET or POST)
- requested page (text)
- some boolean for routing : search / taxonomy / mission / product / tag / points
- parameters for products, mission, tags, etc.

It handles redirect for renamed texts or products, .well-known/change-password

Sometimes we modify request parameters (param) to correspond to request_ref:
- parameters for response format : json, jsonp, xml, ...
- code parameter

=cut

sub analyze_request($request_ref) {
	sanitize_request($request_ref);
	my @components = @{$request_ref->{components}};
	return _analyze_request_impl($request_ref, @components);
}

sub _analyze_request_impl($request_ref, @components) {

	$log->debug("analyze_request", {components => \@components,}) if $log->is_debug();

	match_route($request_ref, @components);

	# Return noindex empty HTML page for web crawlers that crawl specific facet pages
	if (is_no_index_page($request_ref)) {
		# $request_ref->{no_index} is set to 0 by default in init_request()
		$request_ref->{no_index} = 1;
	}

	check_and_update_rate_limits($request_ref);

	$log->debug("request analyzed", {lc => $request_ref->{lc}, request_ref => $request_ref}) if $log->is_debug();

	return 1;
}

##### ROUTES #####

# /
# /[page]
sub index_route($request_ref, @components) {

	# Root, ex: https://world.openfoodfacts.org/
	$request_ref->{text} = 'index';
	$request_ref->{current_link} = '';

	# Root + page number, ex: https://world.openfoodfacts.org/2
	if (exists $request_ref->{param}{page}) {
		$request_ref->{page} = $request_ref->{param}{page};
	}

	# Index page on producers platform
	if (    (defined $request_ref->{text})
		and ($request_ref->{text} eq "index")
		and (defined $server_options{private_products})
		and ($server_options{private_products}))
	{
		$request_ref->{text} = 'index-pro';
	}

	set_request_stats_value($request_ref->{stats}, "route", "index");

	return 1;
}

# org/[orgid]
# org/[orgid]/*
sub org_route($request_ref, @components) {

	$log->debug("request looks like an organization", {components => \@components}) if $log->is_debug();
	$request_ref->{org} = 1;
	my $orgid = $request_ref->{param}{orgid};
	if (
		not defined $orgid
		# not on pro plaform
		or not defined $server_options{private_products} or not $server_options{private_products}
		)
	{
		$request_ref->{status_code} = 404;
		$request_ref->{error_message} = lang("error_invalid_address");
		return;
	}

	# only admin and pro moderators can change organization freely
	if ($orgid ne $Owner_id) {
		$log->debug("checking edit owner", {orgid => $orgid, ownerid => $Owner_id}) if $log->is_debug();
		my @errors = ();
		my $moderator;
		if ($request_ref->{admin} or $User{pro_moderator}) {
			$moderator = retrieve_user($request_ref->{user_id});
			ProductOpener::Users::check_edit_owner($moderator, \@errors, $orgid);
		}
		else {
			$request_ref->{status_code} = 404;
			$request_ref->{error_message} = lang("error_invalid_address");
			return;
		}
		if (scalar @errors eq 0) {
			set_owner_id();
			# will save the pro_moderator_owner field
			store_user($moderator);
		}
		else {
			$request_ref->{status_code} = 404;
			$request_ref->{error_message} = shift @errors;
		}
		# or sub brand ?
	}

	$request_ref->{ownerid} = $Owner_id;
	$request_ref->{canon_rel_url} = get_owner_pretty_path();

	shift @components;
	shift @components;
	$log->debug("org route", {orgid => $orgid, components => \@components}) if $log->is_debug();
	# /search
	# /product/[code]
	return _analyze_request_impl($request_ref, @components);
}

# api/v0/product(s)/[code]
# api/v0/search
sub api_route($request_ref, @components) {
	my $api = $components[1];    # v0
	my $api_action = $components[2];    # product

	my $api_version = $api;
	($api_version) = $api =~ /v(\d+)/;
	$api_version //= 0;

	# Also support "products" in order not to break apps that were using it
	if ($api_action eq 'products') {
		$api_action = 'product';
	}

	# If the api_action is different than "search", check if it is the local path for "product"
	# so that urls like https://fr.openfoodfacts.org/api/v3/produit/4324232423 work (produit instead of product)
	# this is so that we can quickly add /api/v3/ to get the API

	if (    ($api_action ne 'search')
		and ($api_action eq $tag_type_singular{products}{$request_ref->{lc}}))
	{
		$api_action = 'product';
	}

	# some API actions have an associated object
	if ($api_action eq "product") {    # api/v3/product/[code]
		param("code", $components[3]);
		$request_ref->{code} = $components[3];
	}
	elsif ($api_action eq "tag") {    # api/v3/tag/[type]/[tagid]
		param("tagtype", $components[3]);
		$request_ref->{tagtype} = $components[3];
		param("tagid", $components[4]);
		$request_ref->{tagid} = $components[5];
	}

	# If return format is not xml or jqm or jsonp, default to json
	if (    (not defined single_param("xml"))
		and (not defined single_param("jqm"))
		and (not defined single_param("jsonp")))
	{
		param("json", 1);
	}

	$request_ref->{api} = $api;
	$request_ref->{api_action} = $api_action;
	$request_ref->{api_version} = $api_version;
	$request_ref->{api_method} = $request_ref->{method};

	$log->debug(
		"got API request",
		{
			api => $request_ref->{api},
			api_version => $request_ref->{api_version},
			api_action => $request_ref->{api_action},
			api_method => $request_ref->{api_method},
			code => $request_ref->{code},
			jqm => single_param("jqm"),
			json => single_param("json"),
			xml => single_param("xml")
		}
	) if $log->is_debug();

	set_request_stats_value($request_ref->{stats}, "route", "api");
	set_request_stats_value($request_ref->{stats}, "api_action", $request_ref->{api_action});

	return 1;
}

# search :
#
sub search_route($request_ref, @components) {
	$request_ref->{search} = 1;
	set_request_stats_value($request_ref->{stats}, "route", "search");
	return 1;
}

# taxonomy:
#
# e.g. taxonomy?type=categories&tags=en:fruits,en:vegetables&fields=name,description,parents,children,vegan:en,inherited:vegetarian:en&lc=en,fr&include_children=1
sub taxonomy_route($request_ref, @components) {
	$request_ref->{taxonomy} = 1;
	set_request_stats_value($request_ref->{stats}, "route", "taxonomy");
	return 1;
}

# properties:
#
# Folksonomy engine properties endpoint
sub properties_route($request_ref, @components) {
	$request_ref->{properties} = 1;
	return 1;
}

# products/[code](+[code])*
# e.g. /8024884500403+3263855093192
sub products_route($request_ref, @components) {
	param("code", $components[0]);
	$request_ref->{search} = 1;
	set_request_stats_value($request_ref->{stats}, "route", "search");
	return 1;
}

# mission/[missionid]
sub mission_route($request_ref, @components) {
	$request_ref->{missionid} = $components[1];
	$request_ref->{mission} = 1;
	return 1;
}

# product/[code]
# product/[code]/[titleid]
sub product_route($request_ref, @components) {
	$log->debug("request looks like a product", {components => \@components}) if $log->is_debug();

	if ($components[1] =~ /^\d/) {
		$request_ref->{product} = 1;
		$request_ref->{code} = $components[1];
		$request_ref->{titleid} = $components[2] // '';
		set_request_stats_value($request_ref->{stats}, "route", "product");
	}
	else {
		$request_ref->{status_code} = 404;
		$request_ref->{error_message} = lang("error_invalid_address");
	}
	return 1;
}

# index, index-pro, ...
sub text_route($request_ref, @components) {
	my $text = $components[0];

	$log->debug("text_route", {textid => \%texts, text => $text}) if $log->is_debug();

	if (defined $texts{$text}{$request_ref->{lc}} || defined $texts{$text}{'en'}) {
		$request_ref->{text} = $text;
		$request_ref->{canon_rel_url} = "/" . $text;
		set_request_stats_value($request_ref->{stats}, "route", "text");
	}
	else {
		$request_ref->{status_code} = 404;
		$request_ref->{error_message} = lang("error_invalid_address");
	}

	return 1;
}

# en/nova-groups-for-food-processing -> nova, ...
sub redirect_text_route($request_ref, @components) {
	$log->debug("redirect_text_route", {request_ref => $request_ref}) if $log->is_debug();

	$request_ref->{redirect}
		= $formatted_subdomain
		. $request_ref->{canon_rel_url} . '/'
		. $options{redirect_texts}{$request_ref->{lc} . '/' . $components[1]};
	$log->info('redirect_text_route', {textid => $components[1], redirect => $request_ref->{redirect}})
		if $log->is_info();
	redirect_to_url($request_ref, 302, $request_ref->{redirect});
	return 1;
}

# lc:product/[code]
sub lc_product_route($request_ref, @components) {
	# check the product code looks like a number
	if ($components[1] =~ /^\d/) {
		$request_ref->{redirect}
			= $formatted_subdomain
			. $request_ref->{canon_rel_url} . '/'
			. $tag_type_singular{products}{$request_ref->{lc}} . '/'
			. $components[1];
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}
	else {
		$request_ref->{status_code} = 404;
		$request_ref->{error_message} = lang("error_invalid_address");
	}
	return 1;
}

sub facets_route($request_ref, @components) {

	my $target_lc = $request_ref->{lc};
	$request_ref->{canon_rel_url} = '';
	my $canon_rel_url_suffix = '';

	# We may have a page number
	if ($#components >= 0) {
		# The last component can be a page number
		if (($components[-1] =~ /^\d+$/) and ($components[-1] <= 1000)) {
			$request_ref->{page} = pop @components;
			$log->debug("got a page number", {$request_ref->{page}}) if $log->is_debug();
		}
	}

	# Extract tag type / tag value pairs and store them in an array $request_ref->{tags}
	# e.g. /category/breakfast-cereals/label/organic/brand/monoprix
	extract_tagtype_and_tag_value_pairs_from_components($request_ref, \@components);

	# list of (categories) tags with stats for a nutriment
	if (    ($#components == 1)
		and (defined $tag_type_from_plural{$target_lc}{$components[0]})
		and ($tag_type_from_plural{$target_lc}{$components[0]} eq "categories")
		and (defined $nutriments_labels{$target_lc}{$components[1]}))
	{

		$request_ref->{groupby_tagtype} = $tag_type_from_plural{$target_lc}{$components[0]};
		$request_ref->{stats_nid} = $nutriments_labels{$target_lc}{$components[1]};
		$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$target_lc};
		$canon_rel_url_suffix .= "/" . $components[1];
		pop @components;
		pop @components;
		$log->debug("request looks like a list of tags - categories with nutrients",
			{groupby => $request_ref->{groupby_tagtype}, stats_nid => $request_ref->{stats_nid}})
			if $log->is_debug();
	}

	# if we have at least one component, check if the last component is a plural of a tagtype -> list of tags
	if (defined $components[-1]) {

		my $lc;
		if (defined $tag_type_from_plural{$target_lc}{$components[-1]}) {
			$lc = $target_lc;
		}
		else {
			$lc = undef if not defined $tag_type_from_plural{'en'}{$components[-1]};
		}

		if (defined $lc) {
			$request_ref->{groupby_tagtype} = $tag_type_from_plural{$lc}{pop @components};
			# use $target_lc for canon url
			$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$target_lc};
			$log->debug("request looks like a list of tags", {groupby => $request_ref->{groupby_tagtype}, lc => $lc})
				if $log->is_debug();
		}
	}

	# Old Open Food Hunt points
	if ((defined $components[0]) and ($components[0] eq 'points')) {
		$request_ref->{points} = 1;
		$request_ref->{canon_rel_url} .= "/points";
	}

	if ($#components >= 0) {
		# We have a component left, but we don't know what it is
		$log->warn("invalid address, confused by number of components left", {left_components => \@components})
			if $log->is_warn();
		$request_ref->{status_code} = 404;
		$request_ref->{error_message} = lang("error_invalid_address");
		return;
	}

	$request_ref->{canon_rel_url} .= $canon_rel_url_suffix;

	if (defined $request_ref->{groupby_tagtype}) {
		set_request_stats_value($request_ref->{stats}, "route", "facets_tags");
		set_request_stats_value($request_ref->{stats}, "groupby_tagtype", $request_ref->{groupby_tagtype});
	}
	else {
		set_request_stats_value($request_ref->{stats}, "route", "facets_products");
	}
	set_request_stats_value($request_ref->{stats}, "facets_tags", (scalar @{$request_ref->{tags}}));
	return 1;
}

##### END ROUTES #####

=head2 register_route($routes_to_register)

Register routes in the routes hash and regex_routes array.

=head3 Parameters

=head4 $routes_to_register

Array of arrays.

Each array should contain 3 elements:
- the pattern
- the route handler (sub)
- (optional) options {
	- route_name
	- regex: if present then the pattern is considered as a true regex pattern 
		   and the default and limited one won't be used
	}

=cut

sub register_route($routes_to_register) {

	foreach my $route (@$routes_to_register) {
		my ($pattern, $handler, $opt) = @$route;
		my $is_regex = 1;

		if (not exists $opt->{regex}) {
			# check if we catch an arg
			if ($pattern !~ /\[.*\]/ and $pattern ne '') {
				# its a simple route
				$is_regex = undef;
			}
			else {

				# if pattern ends with a /, we remove it
				# and it means it can be followed by anything
				my $anypath = '';
				if ($pattern =~ /\/$/) {
					$pattern =~ s/\/$//;
					$anypath = '(/.*)?';
				}

				$pattern =~ s#\[(\w+)\]#'(?<' . $1 . '>[^/]+)'#ge;
				$pattern = "\^$pattern$anypath\$";
			}
		}

		if ($is_regex) {
			push @regex_routes, {pattern => qr/$pattern/, handler => $handler, opt => $opt};
		}
		else {
			# use a hash key for fast match
			$routes{$pattern} = {handler => $handler, opt => $opt};
		}
	}
	return 1;
}

=head2 match_route($request_ref, @components)

Match a route based on the components of the request.
non regex routes are matched first, then regex routes

=cut

sub match_route ($request_ref, @components) {
	$log->debug("matching route", {components => \@components, query => $request_ref->{query_string}})
		if $log->is_debug();

	# Simple routing with fast hash key match with first component #
	# api -> api_route
	if (exists $routes{$components[0]}) {
		my $route = $routes{$components[0]};
		$log->debug("route matched", {route => $components[0]}) if $log->is_debug();
		if ((not defined $route->{opt}{onlyif}) or ($route->{opt}{onlyif}($request_ref, @components))) {
			$route->{handler}($request_ref, @components);
			return 1;
		}
	}

	my $tmp_query_string = join("/", @components);
	# Routing with regex #
	# @components can be gradually eaten by handlers when processing the route recursively is needed
	# so we can't rely on the full query string sanitized at the begining.
	# e.g.
	# (_analyze_request_impl)
	# 	-> (match_route) 'org/[orgid]/product/1234'
	#	 -> org_route -> (_analyze_request_impl)
	#     -> (match_route) 'product/1234'
	#      -> product_route

	foreach my $route (@regex_routes) {
		if ($tmp_query_string =~ $route->{pattern}) {
			$log->debug("regex route matched", {pattern => $route->{pattern}, query_string => $tmp_query_string})
				if $log->is_debug();
			my %matches = %+;
			$request_ref->{param} = \%matches;
			if ((not defined $route->{opt}{onlyif}) or ($route->{opt}{onlyif}($request_ref, @components))) {
				$route->{handler}($request_ref, @components);
				return 1;
			}
		}
	}
	return;
}

sub sanitize_request($request_ref) {
	my $target_lc = $request_ref->{lc};

	$request_ref->{query_string} = $request_ref->{original_query_string};

	$log->debug("analyzing query_string, step 0 - unmodified", {query_string => $request_ref->{query_string}})
		if $log->is_debug();

	if ($request_ref->{query_string} eq "robots.txt") {
		# robots.txt depends on the subdomain. It can either be:
		# - the standard robots.txt, available in html/robots/standard.txt
		# - a robots.txt where we deny all trafic, only for non-authorized cc-lc
		#   combinations. The file is available in html/robots/deny.txt
		display_robots_txt_and_exit($request_ref);
	}

	# Remove ref and utm_* parameters
	# Examples:
	# https://world.openfoodfacts.org/?utm_content=bufferbd4aa&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer
	# https://world.openfoodfacts.org/?ref=producthunt

	if ($request_ref->{query_string} =~ /(\&|\?)(utm_|ref=)/) {
		$request_ref->{query_string} = $`;
	}

	# cc and lc query overrides have already been consumed by init_request(), remove them
	# so that they do not interfere with the query string analysis after
	$request_ref->{query_string} =~ s/(\&|\?)(cc|lc)=([^&]*)//g;

	$log->debug("analyzing query_string, step 1 - utm, cc, and lc removed",
		{query_string => $request_ref->{query_string}})
		if $log->is_debug();

	# Process API parameters: fields, formats, revision

	# API calls may request JSON, JSONP or XML by appending .json, .jsonp or .xml at the end of the query string
	# .jqm returns results in HTML specifically formatted for the OFF mobile app (which uses jquerymobile)
	# for calls to /cgi/ actions (e.g. search.pl), the format can also be indicated with a parameter &json=1 &jsonp=1 &xml=1 &jqm=1
	# (or ?json=1 if it's the first parameter)

	# check suffixes .json etc. and set the corresponding CGI parameter so that we can retrieve it with param() later

	foreach my $parameter ('json', 'jsonp', 'jqm', 'xml') {

		if ($request_ref->{query_string} =~ /\.$parameter(\b|$)/) {

			param($parameter, 1);
			$request_ref->{query_string} =~ s/\.$parameter(\b|$)//;

			$log->debug("parameter was set from extension in URL path",
				{parameter => $parameter, value => $request_ref->{$parameter}})
				if $log->is_debug();
		}
	}

	$log->debug("analyzing query_string, step 2 - fields, rev, json, jsonp, jqm, and xml removed",
		{query_string => $request_ref->{query_string}})
		if $log->is_debug();

	# some sites like FB can add query parameters, remove all of them
	# make sure that all query parameters of interest have already been consumed above

	$request_ref->{query_string} =~ s/(\&|\?).*//;

	$log->debug("analyzing query_string, step 3 - removed all query parameters",
		{query_string => $request_ref->{query_string}})
		if $log->is_debug();

	# Split query string by "/" to know where it points
	my @components = ();
	foreach my $component (split(/\//, $request_ref->{query_string})) {
		# Decode the escaped characters in the query string
		push(@components, decode("utf8", URI::Escape::XS::decodeURIComponent($component)));
	}

	$request_ref->{components} = \@components;

	$log->debug("analyzing query_string, step 4 - components split and UTF8 decoded", {components => \@components})
		if $log->is_debug();

	$request_ref->{page} = 1;

	# if the query request json or xml, either through the json=1 parameter or a .json extension
	# set the $request_ref->{api} field
	if ((defined single_param('json')) or (defined single_param('jsonp')) or (defined single_param('xml'))) {
		$request_ref->{api} = 'v0';
	}
	return;
}

=head2 sub extract_tagtype_and_tag_value_pairs_from_components($request_ref, $components_ref)

Extract tag type / tag value pairs and store them in an array $request_ref->{tags}

e.g. /category/breakfast-cereals/label/organic/brand/monoprix

Tags can be prefixed by a - to indicate that we want products without this tag

=cut

sub extract_tagtype_and_tag_value_pairs_from_components ($request_ref, $components_ref) {

	my $target_lc = $request_ref->{lc};

	$request_ref->{tags} = [];

	while (
		(scalar @$components_ref >= 2)
		and (  (defined $tag_type_from_singular{$target_lc}{$components_ref->[0]})
			or (defined $tag_type_from_singular{"en"}{$components_ref->[0]}))
		)
	{
		my $tagtype;
		my $tag_prefix;
		my $tag;
		my $tagid;

		$log->debug("request looks like a singular tag",
			{lc => $target_lc, tagtype => $components_ref->[0], tagid => $components_ref->[1]})
			if $log->is_debug();

		# If the first component is a valid singular tag type, use it as the tag type
		if (defined $tag_type_from_singular{$target_lc}{$components_ref->[0]}) {
			$tagtype = $tag_type_from_singular{$target_lc}{shift @$components_ref};
		}
		# Otherwise, use "en" as the default language and try again
		else {
			$tagtype = $tag_type_from_singular{"en"}{shift @$components_ref};
		}

		$tag = shift @$components_ref;

		# if there is a leading dash - before the tag, it indicates we want products without it
		if ($tag =~ /^-/) {
			$tag_prefix = "-";
			$tag = $';
		}
		else {
			$tag_prefix = "";
		}
		# If the tag type is a valid taxonomy field, try to canonicalize the tag ID
		if (defined $taxonomy_fields{$tagtype}) {
			my $parsed_tag = canonicalize_taxonomy_tag_linkeddata($tagtype, $tag);
			if (not $parsed_tag) {
				$parsed_tag = canonicalize_taxonomy_tag_weblink($tagtype, $tag);
			}

			if ($parsed_tag) {
				$tagid = $parsed_tag;
			}
			else {
				if ($tag !~ /^(\w\w):/) {
					$tag = $target_lc . ":" . $tag;
				}

				$tagid = get_taxonomyid($target_lc, $tag);
			}
		}
		else {
			# Use "no_language" normalization
			$tagid = get_string_id_for_lang("no_language", $tag);
		}

		$request_ref->{canon_rel_url}
			.= "/" . $tag_type_singular{$tagtype}{$target_lc} . "/" . $tag_prefix . $tagid;

		# Add the tag properties to the list of tags
		push @{$request_ref->{tags}}, {tagtype => $tagtype, tag => $tagid, tagid => $tagid, tag_prefix => $tag_prefix};

		# Temporarily store the tag properties in %request_ref keys tag, tagid, tagtype, tag_prefix and tag2 etc.
		# to remain compatible with the rest of the code
		# TODO: remove this once the rest of the code has been updated

		if (scalar keys @{$request_ref->{tags}} == 1) {
			$request_ref->{tag} = $tagid;
			$request_ref->{tagid} = $tagid;
			$request_ref->{tagtype} = $tagtype;
			$request_ref->{tag_prefix} = $tag_prefix;
		}
		elsif (scalar keys @{$request_ref->{tags}} == 2) {
			$request_ref->{tag2} = $tagid;
			$request_ref->{tagid2} = $tagid;
			$request_ref->{tagtype2} = $tagtype;
			$request_ref->{tag2_prefix} = $tag_prefix;
		}
	}

	return;
}

=head2 is_no_index_page ($request_ref)

Return 1 if the page should not be indexed by web crawlers based on analyzed request, 0 otherwise.

=cut

sub is_no_index_page ($request_ref) {
	return scalar(
		($request_ref->{is_crawl_bot}) and (
			# if is_denied_crawl_bot == 1, we don't accept any request from this bot
			($request_ref->{is_denied_crawl_bot})
			# All list of tags pages should be non-indexable
			or (defined $request_ref->{groupby_tagtype})
			or (
				(
					defined $request_ref->{tagtype} and (
						# Only allow indexation of a selected number of facets
						# Ingredients were left out because of the number of possible ingredients (1.2M)
						(not exists($index_tag_types_set{$request_ref->{tagtype}}))
						# Don't index facet pages with page number > 1 (we want only 1 index page per facet value)
						or ((defined $request_ref->{page}) and ($request_ref->{page} >= 2))
						# Don't index web pages with 2 nested tags: as an example, there are billions of combinations for
						# category x ingredient alone
						or (defined $request_ref->{tagtype2})
					)
				)
			)
		)
	);
}

# component was specified as en:product, fr:produit etc.
sub _component_is_singular_tag_in_specific_lc ($component, $tag) {

	my $component_lc;
	if ($component =~ /^(\w\w):/) {
		$component_lc = $1;
		$component = $';
	}
	else {
		return 0;
	}

	$log->debug(
		"checking if component is a singular tag in a specific language",
		{
			component => $component,
			lc => $component_lc,
			tag => $tag,
			aa => $tag_type_singular{$tag},
		}
	) if $log->is_debug();

	my $match = $tag_type_singular{$tag}{$component_lc};
	if ((defined $match) and ($match eq $component)) {
		return 1;
	}
	else {
		return 0;
	}
}

=head2 set_rate_limit_attributes ($request_ref, $ip)

Set attributes related to rate-limiting in the request object:

- rate_limiter_user_requests: the number of requests performed by the user for the current minute
- rate_limiter_limit: the maximum number of requests allowed for the current minute
- rate_limiter_blocking: 1 if the user has reached the rate-limit, 0 otherwise


=cut

sub set_rate_limit_attributes ($request_ref, $ip) {
	$request_ref->{rate_limiter_user_requests} = undef;
	$request_ref->{rate_limiter_limit} = undef;
	$request_ref->{rate_limiter_blocking} = 0;

	my $api_action = $request_ref->{api_action};
	if (not defined $api_action) {
		# The request is not an API request, we don't need to check the rate-limiter
		return;
	}
	$request_ref->{rate_limiter_user_requests} = get_rate_limit_user_requests($ip, $api_action);

	my $limit;
	if (($api_action eq "search") or ($request_ref->{search})) {
		$limit = $options{rate_limit_search};
	}
	elsif ($api_action eq "product") {
		$limit = $options{rate_limit_product};
	}
	else {
		# No rate-limit is defined for this API action
		return;
	}
	$request_ref->{rate_limiter_limit} = $limit;

	if (
		# if $limit is not defined, the rate-limiter is disabled for this API action
		defined $limit
		and defined $request_ref->{rate_limiter_user_requests}
		and $request_ref->{rate_limiter_user_requests} >= $limit
		)
	{
		my $block_message = "Rate-limiter blocking: the user has reached the rate-limit";
		# Check if rate-limit blocking is enabled
		if ($rate_limiter_blocking_enabled) {
			# Check that the ip is not local (e.g. integration tests)
			if ($ip eq "127.0.0.1") {
				# The IP address is local, we don't block the request
				$block_message
					= "Rate-limiter blocking is disabled for local IP addresses, but the user has reached the rate-limit";
			}
			# Check that the IP address is not in the allow list
			elsif (defined $options{rate_limit_allow_list}{$ip}) {
				# The IP address is in the allow list, we don't block the request
				$block_message
					= "Rate-limiter blocking is disabled for the user, but the user has reached the rate-limit";
			}
			else {
				# The user has reached the rate-limit, we block the request
				$request_ref->{rate_limiter_blocking} = 1;
			}
		}
		else {
			# Rate-limit blocking is disabled, we just log a warning
			$block_message = "Rate-limiter blocking is disabled, but the user has reached the rate-limit";
		}
		$ratelimiter_log->info(
			$block_message,
			{
				ip => $ip,
				api_action => $api_action,
				user_requests => $request_ref->{rate_limiter_user_requests},
				limit => $limit
			}
		) if $ratelimiter_log->is_info();
	}
	return;
}

sub check_and_update_rate_limits($request_ref) {
	# There is no need to check the rate-limiter if we return a no-index page
	if (not $request_ref->{no_index}) {
		my $ip_address = remote_addr();
		# Set rate-limiter related request attributes
		set_rate_limit_attributes($request_ref, $ip_address);
		my $api_action = $request_ref->{api_action};

		if (defined $api_action) {
			# Increment the number of requests performed by the user for the current minute
			increment_rate_limit_requests($ip_address, $api_action);
		}
	}
	return;
}

1;
