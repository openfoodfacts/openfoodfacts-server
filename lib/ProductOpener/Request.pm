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

ProductOpener::Request - abstraction over the Request object from the underlying Web framework

=cut

package ProductOpener::Request;
use ProductOpener::PerlStandards;


use ProductOpener::Utils ();


use CGI qw(referer); # qw(:cgi :cgi-lib :form escapeHTML');
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::Const qw(:http :common);



sub new ($class, $initial_request_ref, $log) {

	# shallow-copy the supplied hashref into a fresh object
	my $self = bless {%$initial_request_ref}, $class;


	# Initialize the request object
	$self->{referer} = referer();
	$self->{original_query_string} = $ENV{QUERY_STRING};
	# Get the cgi script path if the URL was to a /cgi/ script
	# unset it if it is /cgi/display.pl (default route for non /cgi/ scripts)
	$self->{script_name} = $ENV{SCRIPT_NAME};
	if ($self->{script_name} eq "/cgi/display.pl") {
		delete $self->{script_name};
	}

	# Depending on web server configuration, we may get or not get a / at the start of the QUERY_STRING environment variable
	# remove the / to normalize the query string, as we use it to build some redirect urls
	$self->{original_query_string} =~ s/^\///;

	# Set $self->{is_crawl_bot}
	$self->set_user_agent_request_ref_attributes();

	# `no_index` specifies whether we send an empty HTML page with a <meta name="robots" content="noindex">
	# in the HTML headers. This is only done for known web crawlers (Google, Bing, Yandex,...) on webpages that
	# trigger heavy DB aggregation queries and overload our server.
	$self->{no_index} = 0;
	# If deny_all_robots_txt=1, serve a version of robots.txt where all agents are denied access (Disallow: /)
	$self->{deny_all_robots_txt} = 0;


	# CONTINUE HERE


	my $r = Apache2::RequestUtil->request();
	$self->{method} = $r->method();


	# sub-domain format:
	#
	# [2 letters country code or "world"] -> set cc + default language for the country
	# [2 letters country code or "world"]-[2 letters language code] -> set cc + lc
	#
	# Note: cc and lc can be overridden by query parameters
	# (especially for the API so that we can use only one subdomain : api.openfoodfacts.org)

	my $hostname = $r->hostname;
	$subdomain = lc($hostname);

	local $log->context->{hostname} = $hostname;
	local $log->context->{ip} = remote_addr();
	local $log->context->{query_string} = $self->{original_query_string};

	$subdomain =~ s/\..*//;

	$original_subdomain = $subdomain;    # $subdomain can be changed if there are cc and/or lc overrides

	$log->debug("initializing request", {subdomain => $subdomain}) if $log->is_debug();

	if ($subdomain eq 'world') {
		($cc, $country, $lc) = ('world', 'en:world', 'en');
	}
	elsif (defined $country_codes{$subdomain}) {
		# subdomain is the country code: fr.openfoodfacts.org, uk.openfoodfacts.org,...
		local $log->context->{subdomain_format} = 1;

		$cc = $subdomain;
		$country = $country_codes{$cc};
		$lc = $country_languages{$cc}[0];    # first official language

		$log->debug("subdomain matches known country code",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
			if $log->is_debug();

		if (not exists $Langs{$lc}) {
			$log->debug("current lc does not exist, falling back to lc = en",
				{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
				if $log->is_debug();
			$lc = 'en';
		}

	}
	elsif ($subdomain =~ /(.*?)-(.*)/) {
		# subdomain contains the country code and the language code: world-fr.openfoodfacts.org, ch-it.openfoodfacts.org,...
		local $log->context->{subdomain_format} = 2;
		$log->debug("subdomain in cc-lc format - checking values",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
			if $log->is_debug();

		if (defined $country_codes{$1}) {
			$cc = $1;
			$country = $country_codes{$cc};
			$lc = $country_languages{$cc}[0];    # first official language
			if (defined $language_codes{$2}) {
				$lc = $2;
				$lc =~ s/-/_/;    # pt-pt -> pt_pt
			}

			$log->debug("subdomain matches known country code",
				{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
				if $log->is_debug();
		}
	}
	elsif (defined $country_names{$subdomain}) {
		local $log->context->{subdomain_format} = 3;
		($cc, $country, $lc) = @{$country_names{$subdomain}};

		$log->debug("subdomain matches known country name",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
			if $log->is_debug();
	}
	elsif ($self->{original_query_string} !~ /^api\//) {
		# redirect
		my $redirect_url
			= get_world_subdomain()
			. ($self->{script_name} ? $self->{script_name} . "?" : '/')
			. $self->{original_query_string};
		$log->info("request could not be matched to a known country, redirecting to world",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect_url})
			if $log->is_info();
		redirect_to_url($self, 302, $redirect_url);
	}

	$lc =~ s/_.*//;    # PT_PT doest not work yet: categories

	if ((not defined $lc) or (($lc !~ /^\w\w(_|-)\w\w$/) and (length($lc) != 2))) {
		$log->debug("replacing unknown lc with en", {lc => $lc}) if $log->debug();
		$lc = 'en';
	}

	# If the language is equal to the first language of the country, but we are on a different subdomain, redirect to the main country subdomain. (fr-fr => fr)
	if (    (defined $lc)
		and (defined $cc)
		and (defined $country_languages{$cc}[0])
		and ($country_languages{$cc}[0] eq $lc)
		and ($subdomain ne $cc)
		and ($subdomain !~ /^(ssl-)?api/)
		and ($r->method() eq 'GET')
		and ($self->{original_query_string} !~ /^api\//))
	{
		# redirect
		my $ccdom = format_subdomain($cc);
		my $redirect_url
			= $ccdom
			. ($self->{script_name} ? $self->{script_name} . "?" : '/')
			. $self->{original_query_string};
		$log->info(
			"lc is equal to first lc of the country, redirecting to countries main domain",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect_url}
		) if $log->is_info();
		redirect_to_url($self, 302, $redirect_url);
	}

	# Allow cc and lc overrides as query parameters
	# do not redirect to the corresponding subdomain
	my $cc_lc_overrides = 0;
	my $param_cc = single_param('cc');
	if ((defined $param_cc) and ((defined $country_codes{lc($param_cc)}) or (lc($param_cc) eq 'world'))) {
		$cc = lc($param_cc);
		$country = $country_codes{$cc};
		$cc_lc_overrides = 1;
		$log->debug("cc override from request parameter", {cc => $cc}) if $log->is_debug();
	}
	my $param_lc = single_param('lc');
	if (defined $param_lc) {
		# allow multiple languages in an ordered list
		@lcs = split(/,/, lc($param_lc));
		if (defined $language_codes{$lcs[0]}) {
			$lc = $lcs[0];
			$cc_lc_overrides = 1;
			$log->debug("lc override from request parameter", {lc => $lc, lcs => \@lcs}) if $log->is_debug();
		}
		else {
			@lcs = ($lc);
		}
	}
	else {
		@lcs = ($lc);
	}
	# change the subdomain if we have overrides so that links to product pages are properly constructed
	if ($cc_lc_overrides) {
		$subdomain = $cc;
		if (not((defined $country_languages{$cc}[0]) and ($lc eq $country_languages{$cc}[0]))) {
			$subdomain .= "-" . $lc;
		}
	}

	# If lc is not one of the official languages of the country and if the request comes from
	# a bot crawler, don't index the webpage (return an empty noindex HTML page)
	# We also disable indexing for all subdomains that don't have the format world, cc or cc-lc
	if ((!($lc ~~ $country_languages{$cc})) or $subdomain =~ /^(ssl-)?api/) {
		# Use robots.txt with disallow: / for all agents
		$self->{deny_all_robots_txt} = 1;

		if ($self->{is_crawl_bot} eq 1) {
			$self->{no_index} = 1;
		}
	}

	# select the nutriment table format according to the country
	$nutriment_table = $cc_nutriment_table{default};
	if (exists $cc_nutriment_table{$cc}) {
		$nutriment_table = $cc_nutriment_table{$cc};
	}

	if ($test) {
		$subdomain =~ s/\.openfoodfacts/.test.openfoodfacts/;
	}

	$log->debug(
		"URI parsed for additional information",
		{
			subdomain => $subdomain,
			original_subdomain => $original_subdomain,
			lc => $lc,
			cc => $cc,
			country => $country
		}
	) if $log->is_debug();

	my $error = ProductOpener::Users::init_user($self);
	if ($error) {
		# We were sent bad user_id / password credentials

		# If it is an API v3 query, the error will be handled by API::process_api_request()
		if ((defined $self->{api_version}) and ($self->{api_version} >= 3)) {
			$log->debug(
				"init_request - init_user error - API v3: continue",
				{init_user_error => $self->{init_user_error}}
			) if $log->is_debug();
			add_error(
				$self->{api_response},
				{
					message => {id => "invalid_user_id_and_password"},
					impact => {id => "failure"},
				},
				403
			);
		}
		# /cgi/auth.pl returns a JSON body
		# for requests to /cgi/auth.pl, we will now return a JSON body, set in /cgi/auth.pl
		elsif ($r->uri() =~ /\/cgi\/auth\.pl/) {
			$log->debug(
				"init_request - init_user error - /cgi/auth.pl: continue",
				{init_user_error => $self->{init_user_error}}
			) if $log->is_debug();
		}
		# Otherwise we return an error page in HTML (including for v0 / v1 / v2 API queries)
		else {
			$log->debug(
				"init_request - init_user error - display error page",
				{init_user_error => $self->{init_user_error}}
			) if $log->is_debug();
			display_error_and_exit($error, 403);
		}
	}

	# %admin is defined in Config.pm
	# admins can change permissions for all users
	if (is_admin_user($User_id)) {
		$admin = 1;
	}
	$self->{admin} = $admin;
	# TODO: remove the $admin global variable, and use $self->{admin} instead.

	$self->{moderator} = $User{moderator};
	$self->{pro_moderator} = $User{pro_moderator};

	# Producers platform: not logged in users, or users with no permission to add products

	if (($server_options{producers_platform})
		and not((defined $Owner_id) and (($Owner_id =~ /^org-/) or ($User{moderator}) or $User{pro_moderator})))
	{
		$styles .= <<CSS
.hide-when-no-access-to-producers-platform {display:none}
CSS
			;
	}
	else {
		$styles .= <<CSS
.show-when-no-access-to-producers-platform {display:none}
CSS
			;
	}

	# Not logged in users

	if (defined $User_id) {
		$styles .= <<CSS
.hide-when-logged-in {display:none}
CSS
			;
	}
	else {
		$styles .= <<CSS
.show-when-logged-in {display:none}
CSS
			;
	}

	# call format_subdomain($subdomain) only once
	$formatted_subdomain = format_subdomain($subdomain);
	$producers_platform_url = $formatted_subdomain . '/';

	# If we are not already on the producers platform: add .pro
	if ($producers_platform_url !~ /\.pro\.open/) {
		$producers_platform_url =~ s/\.open/\.pro\.open/;
	}

	# Enable or disable user food preferences: used to compute attributes and to display
	# personalized product scores and search results
	if (((defined $options{product_type}) and ($options{product_type} eq "food"))) {
		$self->{user_preferences} = 1;
	}
	else {
		$self->{user_preferences} = 0;
	}

	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		$show_ecoscore = 1;
		$attributes_options_ref = {};
		$knowledge_panels_options_ref = {};
	}
	else {
		$show_ecoscore = 0;
		$attributes_options_ref = {
			skip_ecoscore => 1,
			skip_forest_footprint => 1,
		};
		$knowledge_panels_options_ref = {
			skip_ecoscore => 1,
			skip_forest_footprint => 1,
		};
	}

	if ($self->{admin}) {
		$knowledge_panels_options_ref->{admin} = 1;
	}
	if ($User{moderator}) {
		$knowledge_panels_options_ref->{moderator} = 1;
	}
	if ($server_options{producers_platform}) {
		$knowledge_panels_options_ref->{producers_platform} = 1;
	}

	$log->debug(
		"owner, org and user",
		{
			private_products => $server_options{private_products},
			owner_id => $Owner_id,
			user_id => $User_id,
			org_id => $Org_id
		}
	) if $log->is_debug();

	# Set cc, lc and lcs in the request object
	# Ideally, we should rely on those fields in the request object
	# and remove the $lc, $cc and @lcs global variables
	$self->{lc} = $lc;
	$self->{cc} = $cc;
	$self->{country} = $country;
	$self->{lcs} = \@lcs;

	return $self;
}

	


=head2 set_user_agent_request_ref_attributes

Set two attributes to `request_ref`:

- `user_agent`: the request User-Agent
- `is_crawl_bot`: a flag (0 or 1) that indicates whether the request comes
  from a known web crawler (Google, Bing,...). We only use User-Agent value
  to set this flag.
- `is_denied_crawl_bot`: a flag (0 or 1) that indicates whether the request
  comes from a web crawler we want to deny access to.

=cut

sub set_user_agent_request_ref_attributes ($self) {
	my $user_agent_str = user_agent();
	$self->{user_agent} = $user_agent_str;

	my $is_crawl_bot = 0;
	my $is_denied_crawl_bot = 0;
	if ($user_agent_str
		=~ /\b(Googlebot|Googlebot-Image|Google-InspectionTool|bingbot|Applebot|Yandex|DuckDuck|DotBot|Seekport|Ahrefs|DataForSeo|Seznam|ZoomBot|Mojeek|QRbot|Qwant|facebookexternalhit|Bytespider|GPTBot|SEOkicks|Searchmetrics|MJ12|SurveyBot|SEOdiver|wotbox|Cliqz|Paracrawl|Scrapy|VelenPublicWebCrawler|Semrush|MegaIndex\.ru|Amazon|aiohttp|python-request)/i
		)
	{
		$is_crawl_bot = 1;
		if ($user_agent_str
			=~ /\b(bingbot|Seekport|Ahrefs|DataForSeo|Seznam|ZoomBot|Mojeek|QRbot|Bytespider|SEOkicks|Searchmetrics|MJ12|SurveyBot|SEOdiver|wotbox|Cliqz|Paracrawl|Scrapy|VelenPublicWebCrawler|Semrush|MegaIndex\.ru|YandexMarket|Amazon)/
			)
		{
			$is_denied_crawl_bot = 1;
		}
	}
	$self->{is_crawl_bot} = $is_crawl_bot;
	$self->{is_denied_crawl_bot} = $is_denied_crawl_bot;
	return;
}



1;

