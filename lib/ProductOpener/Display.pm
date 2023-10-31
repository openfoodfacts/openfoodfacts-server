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

ProductOpener::Display - list, create and save products

=head1 SYNOPSIS

C<ProductOpener::Display> generates the HTML code for the web site
and the JSON responses for the API.

=head1 DESCRIPTION



=cut

package ProductOpener::Display;

use ProductOpener::PerlStandards;
use Exporter qw(import);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&startup
		&init_request
		&redirect_to_url
		&single_param
		&request_param

		&display_date
		&display_date_tag
		&display_date_iso
		&display_pagination
		&get_packager_code_coordinates
		&display_icon

		&display_structured_response
		&display_no_index_page_and_exit
		&display_robots_txt_and_exit
		&display_page
		&display_text
		&display_points
		&display_mission
		&display_tag
		&display_search_results
		&display_error
		&display_error_and_exit

		&add_product_nutriment_to_stats
		&compute_stats_for_products
		&compare_product_nutrition_facts_to_categories
		&data_to_display_nutrition_table
		&display_nutrition_table
		&display_product
		&display_product_api
		&display_product_history
		&display_preferences_api
		&display_attribute_groups_api
		&get_search_field_path_components
		&get_search_field_title_and_details
		&search_and_display_products
		&search_and_export_products
		&search_and_graph_products
		&search_and_map_products
		&display_recent_changes
		&add_tag_prefix_to_link
		&display_taxonomy_api
		&map_of_products

		&display_nested_list_of_ingredients
		&display_ingredients_analysis_details
		&display_ingredients_analysis
		&display_possible_improvement_description
		&display_properties

		&get_world_subdomain

		&data_to_display_nutriscore
		&data_to_display_nutrient_levels
		&data_to_display_ingredients_analysis
		&data_to_display_ingredients_analysis_details
		&data_to_display_image

		&count_products
		&add_params_to_query

		&url_for_text
		&process_template

		@search_series

		%index_tag_types_set

		$admin
		$memd
		$default_request_ref

		$scripts
		$initjs
		$styles
		$header
		$bodyabout

		$original_subdomain
		$subdomain
		$formatted_subdomain
		$images_subdomain
		$static_subdomain
		$producers_platform_url
		$test
		@lcs
		$cc
		$country
		$tt

		$nutriment_table

		%file_timestamps

		$show_ecoscore
		$attributes_options_ref
		$knowledge_panels_options_ref

		&display_nutriscore_calculation_details
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::HTTP qw(:all);
use ProductOpener::Store qw(:all);
use ProductOpener::Config qw(:all);
use ProductOpener::Tags qw(:all);
use ProductOpener::TagsEntries qw(:all);
use ProductOpener::Users qw(:all);
use ProductOpener::Index qw(:all);
use ProductOpener::Lang qw(:all);
use ProductOpener::Images qw(:all);
use ProductOpener::Food qw(:all);
use ProductOpener::Ingredients qw(:all);
use ProductOpener::Products qw(:all);
use ProductOpener::Missions qw(:all);
use ProductOpener::MissionsConfig qw(:all);
use ProductOpener::URL qw(:all);
use ProductOpener::Data qw(:all);
use ProductOpener::Text qw(:all);
use ProductOpener::Nutriscore qw(:all);
use ProductOpener::Ecoscore qw(:all);
use ProductOpener::Attributes qw(:all);
use ProductOpener::KnowledgePanels qw(:all);
use ProductOpener::KnowledgePanelsTags qw(:all);
use ProductOpener::Orgs qw(:all);
use ProductOpener::Web qw(:all);
use ProductOpener::Recipes qw(:all);
use ProductOpener::PackagerCodes qw(:all);
use ProductOpener::Export qw(:all);
use ProductOpener::API qw(:all);
use ProductOpener::Units qw/:all/;
use ProductOpener::Cache qw/:all/;

use Encode;
use URI::Escape::XS;
use CGI qw(:cgi :cgi-lib :form escapeHTML');
use HTML::Entities;
use DateTime;
use DateTime::Locale;
use experimental 'smartmatch';
use MongoDB;
use Tie::IxHash;
use JSON::PP;
use Text::CSV;
use XML::Simple;
use CLDR::Number;
use CLDR::Number::Format::Decimal;
use CLDR::Number::Format::Percent;
use Storable qw(dclone freeze);
use boolean;
use Excel::Writer::XLSX;
use Template;
use Devel::Size qw(size total_size);
use Data::DeepAccess qw(deep_get);
use Log::Log4perl;
use LWP::UserAgent;

use Log::Any '$log', default_adapter => 'Stderr';

# special logger to make it easy to measure memcached hit and miss rates
our $mongodb_log = Log::Log4perl->get_logger('mongodb');
$mongodb_log->info("start") if $mongodb_log->is_info();

use Apache2::RequestRec ();
use Apache2::Const qw(:http :common);

use URI::Find;

my $uri_finder = URI::Find->new(
	sub ($uri, $orig_uri) {
		if ($uri =~ /\http/) {
			return qq|<a href="$uri">$orig_uri</a>|;
		}
		else {
			return $orig_uri;
		}
	}
);

=head1 VARIABLES

Exported variables that are available for other modules.

=head2 %file_timestamps

When the module is loaded (at the start of Apache with mod_perl), we record the modification date
of static files like CSS styles an JS code so that we can add a version parameter to the request
in order to make sure the browser will not serve an old cached version.

=head3 Synopsis

    $scripts .= <<HTML
        <script type="text/javascript" src="/js/dist/product-multilingual.js?v=$file_timestamps{"js/dist/product-multilingual.js"}"></script>
    HTML
    ;

=head3 Configuration

The files that need to be checked need to be specified in the code of Display.pm.

	e.g.

    %file_timestamps = (
    	"css/dist/app.css" => "CSS file generated by the 'npm run build' command",
    	"css/dist/product-multilingual.css" => "CSS file generated by the 'npm run build' command",
    	"js/dist/product-multilingual.js" => "JS file generated by the 'npm run build' command",
    );

=cut

%file_timestamps = (
	"css/dist/app-ltr.css" => "CSS file generated by the 'npm run build' command",
	"css/dist/app-rtl.css" => "CSS file generated by the 'npm run build' command",
	"css/dist/product-multilingual.css" => "CSS file generated by the 'npm run build' command",
	"js/dist/product-multilingual.js" => "JS file generated by the 'npm run build' command",
);

my $start_time = time();
foreach my $file (sort keys %file_timestamps) {

	if (-e "$www_root/$file") {
		$file_timestamps{$file} = (stat "$www_root/$file")[9];
	}
	else {
		#$log->trace("A timestamped file does not exist. Falling back to process start time, in case we are running in different Docker containers.", { path => "$www_root/$file", source => $file_timestamps{$file}, fallback => $start_time }) if $log->is_trace();
		$file_timestamps{$file} = $start_time;
	}
}

# On demand exports can be very big, limit the number of products
my $export_limit = 10000;

my $tags_page_size = 10000;

if (defined $options{export_limit}) {
	$export_limit = $options{export_limit};
}

# Save all tag types to index in a set to make checks easier
%index_tag_types_set = ();
@index_tag_types_set{@ProductOpener::Config::index_tag_types} = ();

# Initialize the Template module
$tt = Template->new(
	{
		INCLUDE_PATH => $data_root . '/templates',
		INTERPOLATE => 1,
		EVAL_PERL => 1,
		STAT_TTL => 60,    # cache templates in memory for 1 min before checking if the source changed
		COMPILE_EXT => '.ttc',    # compile templates to Perl code for much faster reload
		COMPILE_DIR => $data_root . "/tmp/templates",
		ENCODING => 'UTF-8',
		RECURSION => 1,    # Needed for the knowledge panels that contain subpanels
	}
);

# Initialize exported variables

$default_request_ref = {page => 1,};

# Initialize internal variables
# - using my $variable; is causing problems with mod_perl, it looks
# like inside subroutines below, they retain the first value they were
# called with. (but no "$variable will not stay shared" warning).
# Converting them to global variables.
# - better solution: create a class?

use vars qw();

sub get_world_subdomain() {
	my $prefix = ($lc eq "en") ? "world" : "world-$lc";
	return format_subdomain($prefix);
}

$static_subdomain = format_subdomain('static');
$images_subdomain = format_subdomain('images');

=head1 FUNCTIONS


=head2 url_for_text ( $textid )

Return the localized URL for a text. (e.g. "data" points to /data in English and /donnees in French)
Note: This currently only has ecoscore

=cut

# Note: the following urls are currently hardcoded, but the idea is to build the mapping table
# at startup from the available translated texts in the repository. (TODO)
my %urls_for_texts = (
	"ecoscore" => {
		en => "eco-score-the-environmental-impact-of-food-products",
		de => "eco-score-die-umweltauswirkungen-von-lebensmitteln",
		es => "eco-score-el-impacto-medioambiental-de-los-productos-alimenticios",
		fr => "eco-score-l-impact-environnemental-des-produits-alimentaires",
		it => "eco-score-impatto-ambientale-dei-prodotti-alimentari",
		nl => "eco-score-de-milieu-impact-van-voedingsproducten",
		pt => "eco-score-o-impacto-ambiental-dos-produtos-alimentares",
	},
);

sub url_for_text ($textid) {

	# remove starting / if passed
	$textid =~ s/^\///;

	if (not defined $urls_for_texts{$textid}) {
		return "/" . $textid;
	}
	elsif (defined $urls_for_texts{$textid}{$lc}) {
		return "/" . $urls_for_texts{$textid}{$lc};
	}
	elsif ($urls_for_texts{$textid}{en}) {
		return "/" . $urls_for_texts{$textid}{en};
	}
	else {
		return "/" . $textid;
	}
}

=head2 process_template ( $template_filename , $template_data_ref , $result_content_ref )

Add some functions and variables needed by many templates and process the template with template toolkit.

=cut

sub process_template ($template_filename, $template_data_ref, $result_content_ref) {

	# Add functions and values that are passed to all templates

	$template_data_ref->{server_options_private_products} = $server_options{private_products};
	$template_data_ref->{server_options_producers_platform} = $server_options{producers_platform};
	$template_data_ref->{producers_platform_url} = $producers_platform_url;
	$template_data_ref->{server_domain} = $server_domain;
	$template_data_ref->{static_subdomain} = $static_subdomain;
	$template_data_ref->{images_subdomain} = $images_subdomain;
	$template_data_ref->{formatted_subdomain} = $formatted_subdomain;
	(not defined $template_data_ref->{user_id}) and $template_data_ref->{user_id} = $User_id;
	(not defined $template_data_ref->{user}) and $template_data_ref->{user} = \%User;
	(not defined $template_data_ref->{org_id}) and $template_data_ref->{org_id} = $Org_id;

	$template_data_ref->{product_type} = $options{product_type};
	$template_data_ref->{admin} = $admin;
	$template_data_ref->{moderator} = $User{moderator};
	$template_data_ref->{pro_moderator} = $User{pro_moderator};
	$template_data_ref->{sep} = separator_before_colon($lc);
	$template_data_ref->{lang} = \&lang;
	$template_data_ref->{f_lang} = \&f_lang;
	$template_data_ref->{lang_sprintf} = \&lang_sprintf;
	$template_data_ref->{lc} = $lc;
	$template_data_ref->{cc} = $cc;
	$template_data_ref->{display_icon} = \&display_icon;
	$template_data_ref->{time_t} = time();
	$template_data_ref->{display_date_without_time} = \&display_date_without_time;
	$template_data_ref->{display_date_ymd} = \&display_date_ymd;
	$template_data_ref->{display_date_tag} = \&display_date_tag;
	$template_data_ref->{url_for_text} = \&url_for_text;
	$template_data_ref->{product_url} = \&product_url;
	$template_data_ref->{product_action_url} = \&product_action_url;
	$template_data_ref->{product_name_brand_quantity} = \&product_name_brand_quantity;

	# select2 options generator for all entries in a taxonomy
	$template_data_ref->{generate_select2_options_for_taxonomy_to_json} = sub ($tagtype) {
		return generate_select2_options_for_taxonomy_to_json($lc, $tagtype);
	};

	# Return a link to one taxonomy entry in the target language
	$template_data_ref->{canonicalize_taxonomy_tag_link} = sub ($tagtype, $tag) {
		return canonicalize_taxonomy_tag_link($lc, $tagtype, $tag);
	};

	# Display one taxonomy entry in the target language
	$template_data_ref->{display_taxonomy_tag} = sub ($tagtype, $tag) {
		return display_taxonomy_tag($lc, $tagtype, $tag);
	};

	# Display one taxonomy entry in the target language, without language prefix
	$template_data_ref->{display_taxonomy_tag_name} = sub ($tagtype, $tag) {
		return display_taxonomy_tag_name($lc, $tagtype, $tag);
	};

	# Display a list of taxonomy entries in the target language
	$template_data_ref->{display_taxonomy_tags_list} = sub ($tagtype, $tags_ref) {
		if (defined $tags_ref) {
			return join(", ", map {display_taxonomy_tag($lc, $tagtype, $_)} @$tags_ref);
		}
		else {
			return "";
		}
	};

	$template_data_ref->{round} = sub ($var) {
		return sprintf("%.0f", $var);
	};
	$template_data_ref->{sprintf} = sub ($var1, $var2) {
		return sprintf($var1, $var2);
	};

	$template_data_ref->{encode_json} = sub ($var) {
		return decode_utf8(JSON::PP->new->utf8->canonical->encode($var));
	};

	return ($tt->process($template_filename, $template_data_ref, $result_content_ref));
}

=head2 redirect_to_url($request_ref, $status_code, $redirect_url)

This function instructs mod_perl to print redirect HTTP header (Location) and to terminate the request immediately.
The mod_perl process is not terminated and will continue to serve future requests.

=head3 Arguments

=head4 Request object $request_ref

The request object may contain a cookie.

=head4 Status code $status_code

e.g. 302 for a temporary redirect

=head4 Redirect url $redirect_url

=cut

sub redirect_to_url ($request_ref, $status_code, $redirect_url) {

	my $r = Apache2::RequestUtil->request();

	$r->headers_out->set(Location => $redirect_url);

	if (defined $request_ref->{cookie}) {
		# Note: mod_perl will not output the Set-Cookie header on a 302 response
		# unless it is set with err_headers_out instead of headers_out
		# https://perl.apache.org/docs/2.0/api/Apache2/RequestRec.html#C_err_headers_out_
		$r->err_headers_out->set("Set-Cookie" => $request_ref->{cookie});
	}

	$r->status($status_code);
	# note: under mod_perl, exit() will end the request without terminating the Apache mod_perl process
	exit();
}

=head2 single_param ($param_name)

CGI.pm param() function returns a list when called in a list context
(e.g. when param() is an argument of a function, or the value of a field in a hash).
This causes issues for function signatures that expect a scalar, and that may get passed an empty list
if the parameter is not set.

So instead of calling CGI.pm param() directly, we call single_param() to prefix it with scalar.

=head3 Arguments

=head4 CGI parameter name $param_name

=head3 Return value

A scalar value for the parameter, or undef if the parameter is not defined.

=cut

sub single_param ($param_name) {
	return scalar param($param_name);
}

=head2 request_param ($request_ref, $param_name)

Return a request parameter. The parameter can be passed in the query string,
as a POST multipart form data parameter, or in a POST JSON body

=head3 Arguments

=head4 Parameter name $param_name

=head3 Return value

A scalar value for the parameter, or undef if the parameter is not defined.

=cut

sub request_param ($request_ref, $param_name) {
	return (scalar param($param_name)) || deep_get($request_ref, "body_json", $param_name);
}

=head2 init_request ()

C<init_request()> is called at the start of each new request (web page or API).
It initializes a number of variables, in particular:

$cc : country code

$lc : language code

$knowledge_panels_options_ref: Reference to a hashmap that collect options to display knowledge panels for current request
See also L<ProductOpener::KnowledgePanels/knowledge_panels_options_ref>
It also initializes a request object that is returned.

=head3 Parameters

=head4 (optional) Request object reference $request_ref

This function may be passed an existing request object reference
(e.g. pre-containing some fields of the request, like a JSON body).

If not passed, a new request object will be created.


=head3 Return value

Reference to request object.

=cut

sub init_request ($request_ref = {}) {

	$log->debug("init_request - start", {request_ref => $request_ref}) if $log->is_debug();

	# Clear the context
	delete $log->context->{user_id};
	delete $log->context->{user_session};
	$log->context->{request} = generate_token(16);

	# Initialize the request object
	$request_ref->{referer} = referer();
	$request_ref->{original_query_string} = $ENV{QUERY_STRING};
	# Get the cgi script path if the URL was to a /cgi/ script
	# unset it if it is /cgi/display.pl (default route for non /cgi/ scripts)
	$request_ref->{script_name} = $ENV{SCRIPT_NAME};
	if ($request_ref->{script_name} eq "/cgi/display.pl") {
		delete $request_ref->{script_name};
	}

	# Depending on web server configuration, we may get or not get a / at the start of the QUERY_STRING environment variable
	# remove the / to normalize the query string, as we use it to build some redirect urls
	$request_ref->{original_query_string} =~ s/^\///;

	# Set $request_ref->{is_crawl_bot}
	set_user_agent_request_ref_attributes($request_ref);

	# `no_index` specifies whether we send an empty HTML page with a <meta name="robots" content="noindex">
	# in the HTML headers. This is only done for known web crawlers (Google, Bing, Yandex,...) on webpages that
	# trigger heavy DB aggregation queries and overload our server.
	$request_ref->{no_index} = 0;
	# If deny_all_robots_txt=1, serve a version of robots.txt where all agents are denied access (Disallow: /)
	$request_ref->{deny_all_robots_txt} = 0;

	# TODO: global variables should be moved to $request_ref
	$styles = '';
	$scripts = '';
	$initjs = '';
	$header = '';
	$bodyabout = '';
	$admin = 0;

	my $r = Apache2::RequestUtil->request();
	$request_ref->{method} = $r->method();

	$cc = 'world';
	$lc = 'en';
	@lcs = ();
	$country = 'en:world';

	$r->headers_out->set(Server => "Product Opener");
	$r->headers_out->set("X-Frame-Options" => "DENY");
	$r->headers_out->set("X-Content-Type-Options" => "nosniff");
	$r->headers_out->set("X-Download-Options" => "noopen");
	$r->headers_out->set("X-XSS-Protection" => "1; mode=block");
	$r->headers_out->set("X-Request-ID" => $log->context->{request});

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
	local $log->context->{query_string} = $request_ref->{original_query_string};

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
	elsif ($request_ref->{original_query_string} !~ /^api\//) {
		# redirect
		my $redirect_url
			= get_world_subdomain()
			. ($request_ref->{script_name} ? $request_ref->{script_name} . "?" : '/')
			. $request_ref->{original_query_string};
		$log->info("request could not be matched to a known country, redirecting to world",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect_url})
			if $log->is_info();
		redirect_to_url($request_ref, 302, $redirect_url);
	}

	$lc =~ s/_.*//;    # PT_PT doest not work yet: categories

	if ((not defined $lc) or (($lc !~ /^\w\w(_|-)\w\w$/) and (length($lc) != 2))) {
		$log->debug("replacing unknown lc with en", {lc => $lc}) if $log->debug();
		$lc = 'en';
	}

	$lang = $lc;

	# If the language is equal to the first language of the country, but we are on a different subdomain, redirect to the main country subdomain. (fr-fr => fr)
	if (    (defined $lc)
		and (defined $cc)
		and (defined $country_languages{$cc}[0])
		and ($country_languages{$cc}[0] eq $lc)
		and ($subdomain ne $cc)
		and ($subdomain !~ /^(ssl-)?api/)
		and ($r->method() eq 'GET')
		and ($request_ref->{original_query_string} !~ /^api\//))
	{
		# redirect
		my $ccdom = format_subdomain($cc);
		my $redirect_url
			= $ccdom
			. ($request_ref->{script_name} ? $request_ref->{script_name} . "?" : '/')
			. $request_ref->{original_query_string};
		$log->info(
			"lc is equal to first lc of the country, redirecting to countries main domain",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect_url}
		) if $log->is_info();
		redirect_to_url($request_ref, 302, $redirect_url);
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
			$lang = $lc;
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
		$request_ref->{deny_all_robots_txt} = 1;

		if ($request_ref->{is_crawl_bot} eq 1) {
			$request_ref->{no_index} = 1;
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
			lang => $lang,
			cc => $cc,
			country => $country
		}
	) if $log->is_debug();

	my $error = ProductOpener::Users::init_user($request_ref);
	if ($error) {
		# We were sent bad user_id / password credentials

		# If it is an API v3 query, the error will be handled by API::process_api_request()
		if ((defined $request_ref->{api_version}) and ($request_ref->{api_version} >= 3)) {
			$log->debug(
				"init_request - init_user error - API v3: continue",
				{init_user_error => $request_ref->{init_user_error}}
			) if $log->is_debug();
			add_error(
				$request_ref->{api_response},
				{
					message => {id => "invalid_user_id_and_password"},
					impact => {id => "failure"},
				}
			);
		}
		# /cgi/auth.pl returns a JSON body
		# for requests to /cgi/auth.pl, we will now return a JSON body, set in /cgi/auth.pl
		elsif ($r->uri() =~ /\/cgi\/auth\.pl/) {
			$log->debug(
				"init_request - init_user error - /cgi/auth.pl: continue",
				{init_user_error => $request_ref->{init_user_error}}
			) if $log->is_debug();
		}
		# Otherwise we return an error page in HTML (including for v0 / v1 / v2 API queries)
		else {
			$log->debug(
				"init_request - init_user error - display error page",
				{init_user_error => $request_ref->{init_user_error}}
			) if $log->is_debug();
			display_error_and_exit($error, 403);
		}
	}

	# %admin is defined in Config.pm
	# admins can change permissions for all users
	if (is_admin_user($User_id)) {
		$admin = 1;
	}
	$request_ref->{admin} = $admin;
	# TODO: remove the $admin global variable, and use $request_ref->{admin} instead.

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
		$request_ref->{user_preferences} = 1;
	}
	else {
		$request_ref->{user_preferences} = 0;
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
	$request_ref->{lc} = $lc;
	$request_ref->{cc} = $cc;
	$request_ref->{country} = $country;
	$request_ref->{lcs} = \@lcs;

	return $request_ref;
}

=head2 set_user_agent_request_ref_attributes ($request_ref)

Set two attributes to `request_ref`:

- `user_agent`: the request User-Agent
- `is_crawl_bot`: a flag (0 or 1) that indicates whether the request comes
  from a known web crawler (Google, Bing,...). We only use User-Agent value
  to set this flag.
- `is_denied_crawl_bot`: a flag (0 or 1) that indicates whether the request
  comes from a web crawler we want to deny access to.

=cut

sub set_user_agent_request_ref_attributes ($request_ref) {
	my $user_agent_str = user_agent();
	$request_ref->{user_agent} = $user_agent_str;

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
	$request_ref->{is_crawl_bot} = $is_crawl_bot;
	$request_ref->{is_denied_crawl_bot} = $is_denied_crawl_bot;
	return;
}

sub _get_date ($t) {

	if (defined $t) {
		my @codes = DateTime::Locale->codes;
		my $locale;
		if (grep {$_ eq $lc} @codes) {
			$locale = DateTime::Locale->load($lc);
		}
		else {
			$locale = DateTime::Locale->load('en');
		}

		my $dt = DateTime->from_epoch(
			locale => $locale,
			time_zone => $reference_timezone,
			epoch => $t
		);
		return $dt;
	}
	else {
		return;
	}

}

sub display_date ($t) {

	my $dt = _get_date($t);

	if (defined $dt) {
		return $dt->format_cldr($dt->locale()->datetime_format_long);
	}
	else {
		return;
	}

}

sub display_date_without_time ($t) {

	my $dt = _get_date($t);

	if (defined $dt) {
		return $dt->format_cldr($dt->locale()->date_format_long);
	}
	else {
		return;
	}

}

sub display_date_ymd ($t) {

	my $dt = _get_date($t);
	if (defined $dt) {
		return $dt->ymd;
	}
	else {
		return;
	}
}

sub display_date_tag ($t) {

	my $dt = _get_date($t);
	if (defined $dt) {
		my $iso = $dt->iso8601;
		my $dts = $dt->format_cldr($dt->locale()->datetime_format_long);
		return "<time datetime=\"$iso\">$dts</time>";
	}
	else {
		return;
	}
}

sub display_date_iso ($t) {

	my $dt = _get_date($t);
	if (defined $dt) {
		my $iso = $dt->iso8601;
		return $iso;
	}
	else {
		return;
	}
}

=head2 display_error ( $error_message, $status_code )

Display an error message using the site template.

The request is not terminated by this function, it will continue to run.

=cut

sub display_error ($error_message, $status_code) {

	my $html = "<p>$error_message</p>";
	display_page(
		{
			title => lang('error'),
			content_ref => \$html,
			status_code => $status_code,
			page_type => "error",
		}
	);
	return;
}

=head2 display_error_and_exit ( $error_message, $status_code )

Display an error message using the site template, and terminate the request immediately.

Any code after the call to display_error_and_exit() will not be executed.

=cut

sub display_error_and_exit ($error_message, $status_code) {

	display_error($error_message, $status_code);
	exit();
}

=head2 display_no_index_page_and_exit ()

Return an empty HTML page with a '<meta name="robots" content="noindex">' directive
in the HTML header.

This is useful to prevent web crawlers to overload our servers by querying webpages
that require a lot of resources (especially aggregation queries).

=cut

sub display_no_index_page_and_exit () {
	my $html
		= '<!DOCTYPE html><html><head><meta name="robots" content="noindex"></head><body><h1>NOINDEX</h1><p>We detected that your browser is a web crawling bot, and this page should not be indexed by web crawlers. If this is unexpected, contact us on Slack or write us an email at <a href="mailto:contact@openfoodfacts.org">contact@openfoodfacts.org</a>.</p></body></html>';
	my $http_headers_ref = {
		'-status' => 200,
		'-expires' => '-1d',
		'-charset' => 'UTF-8',
	};

	print header(%$http_headers_ref);

	my $r = Apache2::RequestUtil->request();
	$r->rflush;
	# Setting the status makes mod_perl append a default error to the body
	# Send 200 instead.
	$r->status(200);
	binmode(STDOUT, ":encoding(UTF-8)");
	print $html;
	exit();
}

=head2 display_robots_txt_and_exit ($request_ref)

Return robots.txt page and exit.

robots.txt is dynamically generated based on lc, it's content depends on $request_ref:
- if $request_ref->{deny_all_robots_txt} is 1: a robots.txt where we deny all traffic
  combinations.
- otherwise: the standard robots.txt. We disallow indexing of most facet pages, the
  exceptions can be found in ProductOpener::Config::index_tag_types

=cut

sub display_robots_txt_and_exit ($request_ref) {
	my $template_data_ref = {facets => []};
	my $vars = {deny_access => $request_ref->{deny_all_robots_txt}, disallow_paths_localized => []};
	my %disallow_paths_localized_set = ();

	foreach my $type (sort keys %tag_type_singular) {
		# Get facet name for both english and the request language
		foreach my $lang ('en', $request_ref->{lc}) {
			my $tag_value_singular = $tag_type_singular{$type}{$lang};
			my $tag_value_plural = $tag_type_plural{$type}{$lang};
			if (
					defined $tag_value_singular
				and length($tag_value_singular) != 0
				and not(exists($disallow_paths_localized_set{$tag_value_singular}))
				# check that it's not one of the exception
				# we don't perform this check below for list of tags pages as all list of
				# tags pages are not indexable
				and not(exists($index_tag_types_set{$type}))
				)
			{
				$disallow_paths_localized_set{$tag_value_singular} = undef;
				push(@{$vars->{disallow_paths_localized}}, $tag_value_singular);
			}
			if (
				defined $tag_value_plural
				and length($tag_value_plural)
				!= 0
				# ecoscore has the same value for singular and plural, and products should not be disabled
				and ($type !~ /^ecoscore|products$/) and not(exists($disallow_paths_localized_set{$tag_value_plural}))
				)
			{
				$disallow_paths_localized_set{$tag_value_plural} = undef;
				push(@{$vars->{disallow_paths_localized}}, $tag_value_plural);
			}
		}
	}

	my $text;
	$tt->process("web/pages/robots/robots.tt.txt", $vars, \$text);
	my $r = Apache2::RequestUtil->request();
	$r->content_type("text/plain");
	print $text;
	exit();
}

# Specific index for producer on the platform for producers
sub display_index_for_producer ($request_ref) {

	# Check if there are data quality issues or improvement opportunities

	my $template_data_ref = {facets => []};

	foreach my $tagtype ("data_quality_errors_producers", "data_quality_warnings_producers", "improvements") {

		my $count = count_products($request_ref, {$tagtype . "_tags" => {'$exists' => true, '$ne' => []}});

		if ($count > 0) {
			push @{$template_data_ref->{facets}},
				{
				url => "/" . $tag_type_plural{$tagtype}{$lc},
				number_of_products => lang("number_of_products_with_" . $tagtype),
				count => $count,
				};
		}
	}

	# Display a message if some product updates have not been published yet
	# Updates can also be on obsolete products

	$template_data_ref->{count_to_be_exported} = count_products({}, {states_tags => "en:to-be-exported"});
	$template_data_ref->{count_obsolete_to_be_exported} = count_products({}, {states_tags => "en:to-be-exported"}, 1);

	my $html;

	process_template('web/common/includes/producers_platform_front_page.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

sub display_text ($request_ref) {

	my $textid = $request_ref->{text};

	$request_ref->{page_type} = "text";

	if ($textid =~ /open-food-facts-mobile-app|application-mobile-open-food-facts/) {
		# we want the mobile app landing page to be included in a <div class="row">
		# so we display it under the `banner` page format, which is the page format
		# used on product pages, with a colored banner on top
		$request_ref->{page_format} = "banner";
	}

	my $text_lang = $lang;

	# if a page does not exist in the local language, use the English version
	# e.g. Index, Discover, Contribute pages.
	if ((not defined $texts{$textid}{$text_lang}) and (defined $texts{$textid}{en})) {
		$text_lang = 'en';
	}

	my $file = "$data_root/lang/$text_lang/texts/" . $texts{$textid}{$text_lang};

	open(my $IN, "<:encoding(UTF-8)", $file);
	my $html = join('', (<$IN>));
	close($IN);

	my $country_name = display_taxonomy_tag($lc, "countries", $country);

	$html =~ s/<cc>/$cc/g;
	$html =~ s/<country_name>/$country_name/g;

	my $title = undef;

	if ($textid eq 'index') {
		$html =~ s/<\/h1>/ - $country_name<\/h1>/;
	}

	# Add org name to index title on producers platform

	if (($textid eq 'index-pro') and (defined $Owner_id)) {
		my $owner_user_or_org = $Owner_id;
		if (defined $Org_id) {
			if ((defined $Org{name}) and ($Org{name} ne "")) {
				$owner_user_or_org = $Org{name};
			}
			else {
				$owner_user_or_org = $Org_id;
			}
		}
		$html =~ s/<\/h1>/ - $owner_user_or_org<\/h1>/;
	}

	$log->info("displaying text from file",
		{cc => $cc, lc => $lc, lang => $lang, textid => $textid, textlang => $text_lang, file => $file})
		if $log->is_info();

	# if page number is higher than 1, then keep only the h1 header
	# e.g. index page
	if ((defined $request_ref->{page}) and ($request_ref->{page} > 1)) {
		$html =~ s/<\/h1>.*//is;
		$html .= '</h1>';
	}

	my $replace_file = sub ($fileid) {
		($fileid =~ /\.\./) and return '';
		$fileid =~ s/^texts\///;
		my $file = "$data_root/lang/$lc/texts/$fileid";
		my $html = '';
		if (-e $file) {
			open(my $IN, "<:encoding(UTF-8)", "$file");
			$html .= join('', (<$IN>));
			close($IN);
		}
		else {
			$html .= "<!-- file $file not found -->";
		}
		return $html;
	};

	if ($file =~ /\/index-pro/) {
		# On the producers platform, display products only if the owner is logged in
		# and has an associated org or is a moderator
		if ((defined $Owner_id) and (($Owner_id =~ /^org-/) or ($User{moderator}) or $User{pro_moderator})) {
			$html .= display_index_for_producer($request_ref);
			$html .= search_and_display_products($request_ref, {}, "last_modified_t", undef, undef);
		}
	}
	elsif ($file =~ /\/index/) {
		# Display all products
		$html .= search_and_display_products($request_ref, {}, "last_modified_t_complete_first", undef, undef);
	}

	# Replace included texts
	$html =~ s/\[\[(.*?)\]\]/$replace_file->($1)/eg;

	while ($html =~ /<scripts>(.*?)<\/scripts>/s) {
		$html = $` . $';
		$scripts .= $1;
	}

	while ($html =~ /<initjs>(.*?)<\/initjs>/s) {
		$html = $` . $';
		$initjs .= $1;
	}

	# wikipedia style links [url text]
	$html =~ s/\[(http\S*?) ([^\]]+)\]/<a href="$1">$2<\/a>/g;

	# Remove the title from the content to put it in the title field
	if ($html =~ /<h1>(.*?)<\/h1>/) {
		$title = $1;
		$html = $` . $';
	}

	# Generate a table of content

	if ($html =~ /<toc>/) {

		my $toc = '';
		my $text = $html;
		my $new_text = '';

		my $current_root_level = -1;
		my $current_level = -1;
		my $nb_headers = 0;

		while ($text =~ /<h(\d)([^<]*)>(.*?)<\/h(\d)>/si) {
			my $level = $1;
			my $h_attributes = $2;
			my $header = $3;

			$text = $';
			$new_text .= $`;
			my $match = $&;

			# Skip h1
			if ($level == 1) {
				$new_text .= $match;
				next;
			}

			$nb_headers++;

			my $header_id = $header;
			# Remove tags
			$header_id =~ s/<(([^>]|\n)*)>//g;
			$header_id = get_string_id_for_lang("no_language", $header_id);
			$header_id =~ s/-/_/g;

			my $header_id_html = " id=\"$header_id\"";

			if ($h_attributes =~ /id="([^<]+)"/) {
				$header_id = $1;
				$header_id_html = '';
			}

			$new_text .= "<h$level${header_id_html}${h_attributes}>$header</h$level>";

			if ($current_root_level == -1) {
				$current_root_level = $level;
				$current_level = $level;
			}

			for (my $i = $current_level; $i < $level; $i++) {
				$toc .= "<ul>\n";
			}

			for (my $i = $level; $i < $current_level; $i++) {
				$toc .= "</ul>\n";
			}

			for (; $current_level < $current_root_level; $current_root_level--) {
				$toc = "<ul>\n" . $toc;
			}

			$current_level = $level;

			$header =~ s/<br>//sig;

			$toc .= "<li><a href=\"#$header_id\">$header</a></li>\n";
		}

		for (my $i = $current_root_level; $i < $current_level; $i++) {
			$toc .= "</ul>\n";
		}

		$new_text .= $text;

		$new_text =~ s/<toc>/<ul>$toc<\/ul>/;

		$html = $new_text;

	}

	if ($html =~ /<styles>(.*)<\/styles>/s) {
		$html = $` . $';
		$styles .= $1;
	}

	if ($html =~ /<header>(.*)<\/header>/s) {
		$html = $` . $';
		$header .= $1;
	}

	if ((defined $request_ref->{page}) and ($request_ref->{page} > 1)) {
		$request_ref->{title} = $title . lang("title_separator") . sprintf(lang("page_x"), $request_ref->{page});
	}
	else {
		$request_ref->{title} = $title;
	}

	$request_ref->{content_ref} = \$html;
	if ($textid ne 'index') {
		$request_ref->{canon_url} = "/$textid";
	}

	display_page($request_ref);
	exit();
}

sub display_mission ($request_ref) {

	my $missionid = $request_ref->{missionid};

	open(my $IN, "<:encoding(UTF-8)", "$data_root/lang/$lang/missions/$missionid.html");
	my $html = join('', (<$IN>));

	$request_ref->{content_ref} = \$html;
	$request_ref->{canon_url} = canonicalize_tag_link("missions", $missionid);

	display_page($request_ref);
	exit();
}

sub get_cache_results ($key, $request_ref) {

	my $results;

	$log->debug("MongoDB hashed query key", {key => $key}) if $log->is_debug();

	# disable caching if ?no_cache=1
	# or if the user is logged in and no_cache is different from 0
	my $param_no_cache = single_param("no_cache");
	if (   ($param_no_cache)
		or ((defined $User_id) and not((defined $param_no_cache) and ($param_no_cache == 0))))
	{

		$log->debug("MongoDB no_cache parameter, skip caching", {key => $key}) if $log->is_debug();
		$mongodb_log->info("get_cache_results - skip - key: $key") if $mongodb_log->is_info();

	}
	else {

		$log->debug("Retrieving value for MongoDB query key", {key => $key}) if $log->is_debug();
		$results = $memd->get($key);
		if (not defined $results) {
			$log->debug("Did not find a value for MongoDB query key", {key => $key}) if $log->is_debug();
			$mongodb_log->info("get_cache_results - miss - key: $key") if $mongodb_log->is_info();
		}
		else {
			$log->debug("Found a value for MongoDB query key", {key => $key}) if $log->is_debug();
			$mongodb_log->info("get_cache_results - hit - key: $key") if $mongodb_log->is_info();
		}
	}
	return $results;
}

sub set_cache_results ($key, $results) {

	$log->debug("Setting value for MongoDB query key", {key => $key}) if $log->is_debug();
	my $result_size = total_size($results);

	# $max_memcached_object_size is defined is Cache.pm
	if ($result_size >= $max_memcached_object_size) {
		$mongodb_log->info(
			"set_cache_results - skipping - setting value - key: $key (total_size: $result_size > max size)");
		return;
	}

	if ($mongodb_log->is_debug()) {
		$mongodb_log->debug("set_cache_results - setting value - key: $key - total_size: $result_size");
	}

	if ($memd->set($key, $results, 3600)) {
		$mongodb_log->info("set_cache_results - updated - key: $key") if $mongodb_log->is_info();
	}
	else {
		$log->debug("Could not set value for MongoDB query key", {key => $key});
		$mongodb_log->info("set_cache_results - error - key: $key") if $mongodb_log->is_info();
	}

	return;
}

sub can_use_query_cache() {
	return (    ((not defined single_param("no_cache")) or (not single_param("no_cache")))
			and (not $server_options{producers_platform}));
}

sub generate_query_cache_key ($name, $context_ref) {
	# Generates a cache key taking the obsolete parameter into account
	if (scalar request_param("obsolete")) {
		$name .= '_obsolete';
	}
	return generate_cache_key($name, $context_ref);
}

sub query_list_of_tags ($request_ref, $query_ref) {

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	my $groupby_tagtype = $request_ref->{groupby_tagtype};

	my $page = $request_ref->{page};
	# Flag that indicates whether we cache MongoDB results in Memcached
	# Caching is disabled for crawling bots, as they tend to explore
	# all pages (and make caching inefficient)
	my $cache_results_flag = scalar(not $request_ref->{is_crawl_bot});

	# Add a meta robot noindex for pages related to users
	if (    (defined $groupby_tagtype)
		and ($groupby_tagtype =~ /^(users|correctors|editors|informers|correctors|photographers|checkers)$/))
	{

		$header .= '<meta name="robots" content="noindex">' . "\n";
	}

	# support for returning json / xml results

	$request_ref->{structured_response} = {tags => [],};

	$log->debug("MongoDB query built", {query => $query_ref}) if $log->is_debug();

	# define limit and skip values
	my $limit;

	#If ?stats=1 or ?filter=  then do not limit results size
	if (   (defined single_param("stats"))
		or (defined single_param("filter"))
		or (defined single_param("status"))
		or (defined single_param("translate")))
	{
		$limit = 999999999999;
	}
	elsif (defined $request_ref->{tags_page_size}) {
		$limit = $request_ref->{tags_page_size};
	}
	else {
		$limit = $tags_page_size;
	}

	my $skip = 0;
	if (defined $page) {
		$skip = ($page - 1) * $limit;
	}
	elsif (defined $request_ref->{page}) {
		$page = $request_ref->{page};
		$skip = ($page - 1) * $limit;
	}
	else {
		$page = 1;
	}

	# groupby_tagtype

	my $aggregate_count_parameters = [
		{"\$match" => $query_ref},
		{"\$unwind" => ("\$" . $groupby_tagtype . "_tags")},
		{"\$group" => {"_id" => ("\$" . $groupby_tagtype . "_tags")}},
		{"\$count" => ($groupby_tagtype . "_tags")}
	];

	my $aggregate_parameters = [
		{"\$match" => $query_ref},
		{"\$unwind" => ("\$" . $groupby_tagtype . "_tags")},
		{"\$group" => {"_id" => ("\$" . $groupby_tagtype . "_tags"), "count" => {"\$sum" => 1}}},
		{"\$sort" => {"count" => -1}},
		{"\$skip" => $skip},
		{"\$limit" => $limit}
	];

	if ($groupby_tagtype eq 'users') {
		$aggregate_parameters = [
			{"\$match" => $query_ref},
			{"\$group" => {"_id" => ("\$creator"), "count" => {"\$sum" => 1}}},
			{"\$sort" => {"count" => -1}}
		];
	}

	if (($groupby_tagtype eq 'nutrition_grades') or ($groupby_tagtype eq 'nova_groups')) {
		$aggregate_parameters = [
			{"\$match" => $query_ref},
			{"\$unwind" => ("\$" . $groupby_tagtype . "_tags")},
			{"\$group" => {"_id" => ("\$" . $groupby_tagtype . "_tags"), "count" => {"\$sum" => 1}}},
			{"\$sort" => {"_id" => 1}}
		];
	}

	#get cache results for aggregate query
	my $key = generate_query_cache_key("aggregate", $aggregate_parameters);
	$log->debug("MongoDB query key", {key => $key}) if $log->is_debug();
	my $results = get_cache_results($key, $request_ref);

	if ((not defined $results) or (ref($results) ne "ARRAY") or (not defined $results->[0])) {
		$results = undef;
		# do not use the postgres cache if ?no_cache=1
		# or if we are on the producers platform
		if (can_use_query_cache()) {
			$results = execute_aggregate_tags_query($aggregate_parameters);
		}

		if (not defined $results) {
			eval {
				$log->debug("Executing MongoDB aggregate query on products collection",
					{query => $aggregate_parameters})
					if $log->is_debug();
				$results = execute_query(
					sub {
						return get_products_collection(get_products_collection_request_parameters($request_ref))
							->aggregate($aggregate_parameters, {allowDiskUse => 1});
					}
				);
				# the return value of aggregate has changed from version 0.702
				# and v1.4.5 of the perl MongoDB module
				$results = [$results->all] if defined $results;
			};
			my $err = $@;
			if ($err) {
				$log->warn("MongoDB error", {error => $err}) if $log->is_warn();
			}
			else {
				$log->info("MongoDB query ok", {error => $err}) if $log->is_info();
			}

			$log->debug("MongoDB query done", {error => $err}) if $log->is_debug();
		}

		$log->trace("aggregate query done") if $log->is_trace();

		if (defined $results) {
			if (defined $results->[0] and $cache_results_flag) {
				set_cache_results($key, $results);
			}
		}
		else {
			$log->debug("No results for aggregate MongoDB query key", {key => $key}) if $log->is_debug();
		}
	}

	# If it is the first page and the number of results we got is inferior to the limit
	# we do not need to count the results

	my $number_of_results;

	if (defined $results) {
		$number_of_results = scalar @{$results};
		$log->debug("MongoDB query results count", {number_of_results => $number_of_results}) if $log->is_debug();
	}

	if (($skip == 0) and (defined $number_of_results) and ($number_of_results < $limit)) {
		$request_ref->{structured_response}{count} = $number_of_results;
		$log->debug("Directly setting structured_response count", {number_of_results => $number_of_results})
			if $log->is_debug();
	}
	else {

		#get total count for aggregate (without limit) and put result in cache
		my $key_count = generate_query_cache_key("aggregate_count", $aggregate_count_parameters);
		$log->debug("MongoDB aggregate count query key", {key => $key_count}) if $log->is_debug();
		my $results_count = get_cache_results($key_count, $request_ref);

		if (not defined $results_count) {

			my $count_results;
			# do not use the smaller postgres cache if ?no_cache=1
			# or if we are on the producers platform
			if (can_use_query_cache()) {
				$count_results = execute_aggregate_tags_query($aggregate_count_parameters);
			}

			if (not defined $count_results) {
				eval {
					$log->debug("Executing MongoDB aggregate count query on products collection",
						{query => $aggregate_count_parameters})
						if $log->is_debug();
					$count_results = execute_query(
						sub {
							return get_products_collection(get_products_collection_request_parameters($request_ref))
								->aggregate($aggregate_count_parameters, {allowDiskUse => 1});
						}
					);
					$count_results = [$count_results->all]->[0] if defined $count_results;
				}
			}

			if (defined $count_results) {
				$request_ref->{structured_response}{count} = $count_results->{$groupby_tagtype . "_tags"};

				if ($cache_results_flag) {
					set_cache_results($key_count, $request_ref->{structured_response}{count});
					$log->debug(
						"Set cached aggregate count for query key",
						{
							key => $key_count,
							results_count => $request_ref->{structured_response}{count},
							count_results => $count_results
						}
					) if $log->is_debug();
				}
			}
		}
		else {
			$request_ref->{structured_response}{count} = $results_count;
			$log->debug("Got cached aggregate count for query key",
				{key => $key_count, results_count => $results_count})
				if $log->is_debug();
		}
	}

	return $results;
}

sub display_list_of_tags ($request_ref, $query_ref) {

	my $results = query_list_of_tags($request_ref, $query_ref);

	my $html = '';
	my $html_pages = '';

	my $countries_map_links = {};
	my $countries_map_names = {};
	my $countries_map_data = {};

	if ((not defined $results) or (ref($results) ne "ARRAY") or (not defined $results->[0])) {

		$log->debug("results for aggregate MongoDB query key", {"results" => $results}) if $log->is_debug();
		$html .= "<p>" . lang("no_products") . "</p>";
		$request_ref->{structured_response}{count} = 0;
	}
	else {

		my @tags = @{$results};
		my $tagtype = $request_ref->{groupby_tagtype};

		if (not defined $request_ref->{structured_response}{count}) {
			$request_ref->{structured_response}{count} = ($#tags + 1);
		}

		$request_ref->{title} = sprintf(lang("list_of_x"), $Lang{$tagtype . "_p"}{$lang});

		if (  -e "$data_root/lang/$lc/texts/"
			. get_string_id_for_lang("no_language", $Lang{$tagtype . "_p"}{$lang})
			. ".list.html")
		{
			open(
				my $IN,
				q{<},
				"$data_root/lang/$lc/texts/"
					. get_string_id_for_lang("no_language", $Lang{$tagtype . "_p"}{$lang})
					. ".list.html"
			);
			$html .= join("\n", (<$IN>));
			close $IN;
		}

		foreach (my $line = 1; (defined $Lang{$tagtype . "_facet_description_" . $line}); $line++) {
			$html .= "<p>" . $Lang{$tagtype . "_facet_description_" . $line}{$lc} . "</p>";
		}

		$html
			.= "<p>"
			. $request_ref->{structured_response}{count} . " "
			. $Lang{$tagtype . "_p"}{$lang}
			. separator_before_colon($lc) . ":</p>";

		my $th_nutriments = '';

		#if ($tagtype eq 'categories') {
		#	$th_nutriments = "<th>" . ucfirst($Lang{"products_with_nutriments"}{$lang}) . "</th>";
		#}

		my $categories_nutriments_ref = $categories_nutriments_per_country{$cc};
		my @cols = ();

		if ($tagtype eq 'categories') {
			if (defined $request_ref->{stats_nid}) {
				push @cols, '100g', 'std', 'min', '10', '50', '90', 'max';
				foreach my $col (@cols) {
					$th_nutriments .= "<th>" . lang("nutrition_data_per_$col") . "</th>";
				}
			}
			else {
				$th_nutriments .= "<th>*</th>";
			}
		}
		elsif (defined $taxonomy_fields{$tagtype}) {
			$th_nutriments .= "<th>*</th>";
		}

		if ($tagtype eq 'additives') {
			$th_nutriments .= "<th>" . lang("risk_level") . "</th>";
		}

		$html
			.= "<div style=\"max-width:600px;\"><table id=\"tagstable\">\n<thead><tr><th>"
			. ucfirst($Lang{$tagtype . "_s"}{$lang})
			. "</th><th>"
			. ucfirst($Lang{"products"}{$lang}) . "</th>"
			. $th_nutriments
			. "</tr></thead>\n<tbody>\n";

		my $main_link = '';
		my $nofollow = '';
		if (defined $request_ref->{tagid}) {
			local $log->context->{tagtype} = $request_ref->{tagtype};
			local $log->context->{tagid} = $request_ref->{tagid};

			$log->trace("determining main_link for the tag") if $log->is_trace();
			if (defined $taxonomy_fields{$request_ref->{tagtype}}) {
				$main_link = canonicalize_taxonomy_tag_link($lc, $request_ref->{tagtype}, $request_ref->{tagid});
				$log->debug("main_link determined from the taxonomy tag", {main_link => $main_link})
					if $log->is_debug();
			}
			else {
				$main_link = canonicalize_tag_link($request_ref->{tagtype}, $request_ref->{tagid});
				$log->debug("main_link determined from the canonical tag", {main_link => $main_link})
					if $log->is_debug();
			}
			$nofollow = ' rel="nofollow"';
		}

		# add back leading dash when a tag is excluded
		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} ne '')) {
			my $prefix = $request_ref->{tag_prefix};
			$main_link = add_tag_prefix_to_link($main_link, $prefix);
			$log->debug("Found tag prefix for main_link", {request => $request_ref}) if $log->is_debug();
		}

		my %products = ();    # number of products by tag, used for histogram of nutrition grades colors

		$log->debug("going through all tags", {}) if $log->is_debug();

		my $i = 0;
		my $j = 0;

		my $path = $tag_type_singular{$tagtype}{$lc};

		if (not defined $tag_type_singular{$tagtype}{$lc}) {
			$log->error("no path defined for tagtype", {tagtype => $tagtype, lc => $lc}) if $log->is_error();
			die();
		}

		my %stats = (
			all_tags => 0,
			all_tags_products => 0,
			known_tags => 0,
			known_tags_products => 0,
			unknown_tags => 0,
			unknown_tags_products => 0,
		);

		my $missing_property = single_param("missing_property");
		if ((defined $missing_property) and ($missing_property !~ /:/)) {
			$missing_property .= ":en";
			$log->debug("missing_property defined", {missing_property => $missing_property});
		}

		foreach my $tagcount_ref (@tags) {

			$i++;

			if (($i % 10000 == 0) and ($log->is_debug())) {
				$log->debug("going through all tags", {i => $i});
			}

			my $tagid = $tagcount_ref->{_id};
			my $count = $tagcount_ref->{count};

			# allow filtering tags with a search pattern
			if (defined single_param("filter")) {
				my $tag_ref = get_taxonomy_tag_and_link_for_lang($lc, $tagtype, $tagid);
				my $display = $tag_ref->{display};
				my $regexp = quotemeta(decode("utf8", URI::Escape::XS::decodeURIComponent(single_param("filter"))));
				next if ($display !~ /$regexp/i);
			}

			$products{$tagid} = $count;

			$stats{all_tags}++;
			$stats{all_tags_products} += $count;

			my $link;
			my $products = $count;
			if ($products == 0) {
				$products = "";
			}

			my $td_nutriments = '';
			#if ($tagtype eq 'categories') {
			#	$td_nutriments .= "<td style=\"text-align:right\">" . $countries_tags{$country}{$tagtype . "_nutriments"}{$tagid} . "</td>";
			#}

			# known tag?

			my $known = 0;

			if ($tagtype eq 'categories') {

				if (defined $request_ref->{stats_nid}) {

					foreach my $col (@cols) {
						if ((defined $categories_nutriments_ref->{$tagid})) {
							$td_nutriments
								.= "<td>"
								. $categories_nutriments_ref->{$tagid}{nutriments}
								{$request_ref->{stats_nid} . '_' . $col} . "</td>";
						}
						else {
							$td_nutriments .= "<td></td>";
							# next;	 # datatables sorting does not work with empty values
						}
					}
				}
				else {
					if (exists_taxonomy_tag('categories', $tagid)) {
						$td_nutriments .= "<td></td>";
						$stats{known_tags}++;
						$stats{known_tags_products} += $count;
						$known = 1;
					}
					else {
						$td_nutriments .= "<td style=\"text-align:center\">*</td>";
						$stats{unknown_tags}++;
						$stats{unknown_tags_products} += $count;
					}
				}
			}
			# show a * next to fields that do not exist in the taxonomy
			elsif (defined $taxonomy_fields{$tagtype}) {
				if (exists_taxonomy_tag($tagtype, $tagid)) {
					$td_nutriments .= "<td></td>";
					$stats{known_tags}++;
					$stats{known_tags_products} += $count;
					$known = 1;
					# ?missing_property=vegan
					# keep only known tags without a defined value for the property
					if ($missing_property) {
						next if (defined get_inherited_property($tagtype, $tagid, $missing_property));
					}
					if ((defined single_param("status")) and (single_param("status") eq "unknown")) {
						next;
					}
				}
				else {
					$td_nutriments .= "<td style=\"text-align:center\">*</td>";
					$stats{unknown_tags}++;
					$stats{unknown_tags_products} += $count;

					# ?missing_property=vegan
					# keep only known tags
					next if ($missing_property);
					if ((defined single_param("status")) and (single_param("status") eq "known")) {
						next;
					}
				}
			}

			$j++;

			# allow limiting the number of results returned
			if ((defined single_param("limit")) and ($j >= single_param("limit"))) {
				last;
			}

			# do not compute the tag display if we just need stats
			next if ((defined single_param("stats")) and (single_param("stats")));

			my $info = '';
			my $css_class = '';

			# For taxonomy tags
			my $tag_ref;

			if (defined $taxonomy_fields{$tagtype}) {
				$tag_ref = get_taxonomy_tag_and_link_for_lang($lc, $tagtype, $tagid);
				$link = "/$path/" . $tag_ref->{tagurl};
				$css_class = $tag_ref->{css_class};
			}
			else {
				$link = canonicalize_tag_link($tagtype, $tagid);

				if (
					not(   ($tagtype eq 'photographers')
						or ($tagtype eq 'editors')
						or ($tagtype eq 'informers')
						or ($tagtype eq 'correctors')
						or ($tagtype eq 'checkers'))
					)
				{
					$css_class = "tag";    # not sure if it's needed
				}
			}

			my $extra_td = '';

			my $icid = $tagid;
			my $canon_tagid = $tagid;
			$icid =~ s/^(.*)://;    # additives

			if ($tagtype eq 'additives') {

				if (    (defined $properties{$tagtype})
					and (defined $properties{$tagtype}{$canon_tagid})
					and (defined $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"}))
				{

					my $tagtype_field = "additives_efsa_evaluation_overexposure_risk";
					my $valueid = $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"};
					$valueid =~ s/^en://;
					my $alt = $Lang{$tagtype_field . "_icon_alt_" . $valueid}{$lc};
					$extra_td
						= '<td class="additives_efsa_evaluation_overexposure_risk_' . $valueid . '">' . $alt . '</td>';
				}
				else {
					$extra_td = '<td></td>';
				}
			}

			my $product_link = $main_link . $link;

			$html .= "<tr><td>";

			my $display = '';
			my @sameAs = ();
			if ($tagtype eq 'nutrition_grades') {
				my $grade;
				if ($tagid =~ /^[abcde]$/) {
					$grade = uc($tagid);
				}
				elsif ($tagid eq "not-applicable") {
					$grade = lang("not_applicable");
				}
				else {
					$grade = lang("unknown");
				}
				$display
					= "<img src=\"/images/attributes/nutriscore-$tagid.svg\" alt=\"$Lang{nutrition_grade_fr_alt}{$lc} "
					. $grade
					. "\" title=\"$Lang{nutrition_grade_fr_alt}{$lc} "
					. $grade
					. "\" style=\"max-height:80px;\">";
			}
			elsif ($tagtype eq 'ecoscore') {
				my $grade;

				if ($tagid =~ /^[abcde]$/) {
					$grade = uc($tagid);
				}
				elsif ($tagid eq "not-applicable") {
					$grade = lang("not_applicable");
				}
				else {
					$grade = lang("unknown");
				}
				$display
					= "<img src=\"/images/attributes/ecoscore-$tagid.svg\" alt=\"$Lang{ecoscore}{$lc} "
					. $grade
					. "\" title=\"$Lang{ecoscore}{$lc} "
					. $grade
					. "\" style=\"max-height:80px;\">";
			}
			elsif ($tagtype eq 'nova_groups') {
				if ($tagid =~ /^en:(1|2|3|4)/) {
					my $group = $1;
					$display = display_taxonomy_tag($lc, $tagtype, $tagid);
				}
				else {
					$display = lang("unknown");
				}
			}
			elsif (defined $taxonomy_fields{$tagtype}) {
				$display = $tag_ref->{display};
				if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$tagid})) {
					foreach my $key (keys %weblink_templates) {
						next if not defined $properties{$tagtype}{$tagid}{$key};
						push @sameAs, sprintf($weblink_templates{$key}{href}, $properties{$tagtype}{$tagid}{$key});
					}
				}
			}
			else {
				$display = canonicalize_tag2($tagtype, $tagid);
				$display = display_tag_name($tagtype, $display);
			}

			$css_class =~ s/^\s+|\s+$//g;
			$info .= ' class="' . $css_class . '"';
			$html .= "<a href=\"$product_link\"$info$nofollow>" . $display . "</a>";
			$html .= "</td>\n<td style=\"text-align:right\">$products</td>" . $td_nutriments . $extra_td . "</tr>\n";

			my $tagentry = {
				id => $tagid,
				name => $display,
				url => $formatted_subdomain . $product_link,
				products => $products + 0,    # + 0 to make the value numeric
				known => $known,    # 1 if the ingredient exists in the taxonomy, 0 if not
			};

			if (($#sameAs >= 0)) {
				$tagentry->{sameAs} = \@sameAs;
			}

			if (defined $tags_images{$lc}{$tagtype}{get_string_id_for_lang("no_language", $icid)}) {
				my $img = $tags_images{$lc}{$tagtype}{get_string_id_for_lang("no_language", $icid)};
				$tagentry->{image} = $static_subdomain . "/images/lang/$lc/$tagtype/$img";
			}

			push @{$request_ref->{structured_response}{tags}}, $tagentry;

			# Maps for countries (and origins)

			if (($tagtype eq 'countries') or ($tagtype eq 'origins') or ($tagtype eq 'manufacturing_places')) {
				my $region = $tagid;

				if (($tagtype eq 'origins') or ($tagtype eq 'manufacturing_places')) {
					# try to find a matching country
					$region =~ s/.*://;
					$region = canonicalize_taxonomy_tag($lc, 'countries', $region);
					$display = display_taxonomy_tag($lc, $tagtype, $tagid);

				}

				if (exists($country_codes_reverse{$region})) {
					$region = uc($country_codes_reverse{$region});
					if ($region eq 'UK') {
						$region = 'GB';
					}

					# In case there are multiple country names and thus links that map to the region
					# only keep the first one, which has the biggest count (and is likely to be the correct name)
					if (not defined $countries_map_links->{$region}) {
						$countries_map_links->{$region} = $product_link;
						my $name = $display;
						$name =~ s/<(.*?)>//g;
						$countries_map_names->{$region} = $name;
					}

					if (not defined $countries_map_data->{$region}) {
						$countries_map_data->{$region} = $products;
					}
					else {
						$countries_map_data->{$region} = $countries_map_data->{$region} + $products;
					}
				}
			}
		}

		$html .= "</tbody></table></div>";

		# if there are more than $tags_page_size lines, add pagination. Except for ?stats=1 and ?filter display
		if (    $request_ref->{structured_response}{count} >= $tags_page_size
			and not(defined single_param("stats"))
			and not(defined single_param("filter")))
		{
			$html .= "\n<hr>"
				. display_pagination($request_ref, $request_ref->{structured_response}{count},
				$tags_page_size, $request_ref->{page});
		}

		if ((defined single_param("stats")) and (single_param("stats"))) {
			#TODO: HERE WE ARE DOING A LOT OF EXTRA WORK BY FIRST CREATING THE TABLE AND THEN DESTROYING IT
			$html =~ s/<table(.*)<\/table>//is;

			if ($stats{all_tags} > 0) {

				$html .= <<"HTML"
<table>
<tr>
<th>Type</th>
<th>Unique tags</th>
<th>Occurrences</th>
</tr>
HTML
					;
				foreach my $type ("known", "unknown", "all") {
					$html
						.= "<tr><td><a href=\"?status=$type\">"
						. $type
						. "</a></td>" . "<td>"
						. $stats{$type . "_tags"} . " ("
						. sprintf("%2.2f", $stats{$type . "_tags"} / $stats{"all_tags"} * 100)
						. "%)</td>" . "<td>"
						. $stats{$type . "_tags_products"} . " ("
						. sprintf("%2.2f", $stats{$type . "_tags_products"} / $stats{"all_tags_products"} * 100)
						. "%)</td>";

				}
				$html =~ s/\?status=all//;

				$html .= <<"HTML"
</table>
HTML
					;
			}

			foreach my $tagid (sort keys %stats) {
				my $tagentry = {
					id => $tagid,
					name => $tagid,
					url => "",
					products => $stats{$tagid} + 0,    # + 0 to make the value numeric
				};

				if ($tagid =~ /_tags_products$/) {
					$tagentry->{percent} = $stats{$tagid} / $stats{"all_tags_products"} * 100;
				}
				else {
					$tagentry->{percent} = $stats{$tagid} / $stats{"all_tags"} * 100;
				}

				push @{$request_ref->{structured_response}{tags}}, $tagentry;
			}
		}

		$log->debug("going through all tags - done", {}) if $log->is_debug();

		# Nutri-Score nutrition grades colors histogram / Eco-Score / NOVA groups histogram

		if (   ($request_ref->{groupby_tagtype} eq 'nutrition_grades')
			or ($request_ref->{groupby_tagtype} eq 'ecoscore')
			or ($request_ref->{groupby_tagtype} eq 'nova_groups'))
		{

			my $categories;
			my $series_data;
			my $colors;

			my $y_title = lang("number_of_products");
			my $x_title = lang($request_ref->{groupby_tagtype} . "_p");

			if ($request_ref->{groupby_tagtype} eq 'nutrition_grades') {
				$categories = "'A','B','C','D','E','" . lang("not_applicable") . "','" . lang("unknown") . "'";
				$colors = "'#1E8F4E','#60AC0E','#EEAE0E','#FF6F1E','#DF1F1F','#a0a0a0','#a0a0a0'";
				$series_data = '';
				foreach my $nutrition_grade ('a', 'b', 'c', 'd', 'e', 'not-applicable', 'unknown') {
					$series_data .= ($products{$nutrition_grade} + 0) . ',';
				}
			}
			elsif ($request_ref->{groupby_tagtype} eq 'ecoscore') {
				$categories = "'A','B','C','D','E','" . lang("not_applicable") . "','" . lang("unknown") . "'";
				$colors = "'#1E8F4E','#60AC0E','#EEAE0E','#FF6F1E','#DF1F1F','#a0a0a0','#a0a0a0'";
				$series_data = '';
				foreach my $ecoscore_grade ('a', 'b', 'c', 'd', 'e', 'not-applicable', 'unknown') {
					$series_data .= ($products{$ecoscore_grade} + 0) . ',';
				}
			}
			elsif ($request_ref->{groupby_tagtype} eq 'nova_groups') {
				$categories = "'NOVA 1','NOVA 2','NOVA 3','NOVA 4','" . lang("unknown") . "'";
				$colors = "'#00ff00','#ffff00','#ff6600','#ff0000','#a0a0a0'";
				$series_data = '';
				foreach my $nova_group (
					"en:1-unprocessed-or-minimally-processed-foods", "en:2-processed-culinary-ingredients",
					"en:3-processed-foods", "en:4-ultra-processed-food-and-drink-products",
					)
				{
					$series_data .= ($products{$nova_group} + 0) . ',';
				}
			}

			$series_data =~ s/,$//;

			my $sep = separator_before_colon($lc);

			my $js = <<JS
			chart = new Highcharts.Chart({
				chart: {
					renderTo: 'container',
					type: 'column',
				},
				legend: {
					enabled: false
				},
				title: {
					text: '$request_ref->{title}'
				},
				subtitle: {
					text: '$Lang{data_source}{$lc}$sep: $formatted_subdomain'
				},
				xAxis: {
					title: {
						enabled: true,
						text: '${x_title}'
					},
					categories: [
						$categories
					]
				},
				colors: [
					$colors
				],
				yAxis: {

					min:0,
					title: {
						text: '${y_title}'
					}
				},

				plotOptions: {
		column: {
		   colorByPoint: true,
			groupPadding: 0,
			shadow: false,
					stacking: 'normal',
					dataLabels: {
						enabled: false,
						color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white',
						style: {
							textShadow: '0 0 3px black, 0 0 3px black'
						}
					}
		}
				},
				series: [
					{
						name: "${y_title}",
						data: [$series_data]
					}
				]
			});
JS
				;
			$initjs .= $js;

			$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/dist/highcharts.js"></script>
SCRIPTS
				;

			$html = <<HTML
<div id="container" style="height: 400px"></div>
<p>&nbsp;</p>
HTML
				. $html;

		}

		# countries map?
		if (keys %{$countries_map_data} > 0) {
			my $json = JSON::PP->new->utf8(0);
			$initjs .= 'var countries_map_data=JSON.parse(' . $json->encode($json->encode($countries_map_data)) . ');'
				.= 'var countries_map_links=JSON.parse(' . $json->encode($json->encode($countries_map_links)) . ');'
				.= 'var countries_map_names=JSON.parse(' . $json->encode($json->encode($countries_map_names)) . ');'
				.= <<"JS";
displayWorldMap('#world-map', { 'data': countries_map_data, 'links': countries_map_links, 'names': countries_map_names });
JS
			$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/dist/jsvectormap.js"></script>
<script src="$static_subdomain/js/dist/world-merc.js"></script>
<script src="$static_subdomain/js/dist/display-list-of-tags.js"></script>
SCRIPTS
				;
			my $map_html = <<HTML
  <div id="world-map" style="min-width: 250px; max-width: 600px; min-height: 250px; max-height: 400px;"></div>

HTML
				;
			$html = $map_html . $html;

		}

		#if ($tagtype eq 'categories') {
		#	$html .= "<p>La colonne * indique que la catégorie ne fait pas partie de la hiérarchie de la catégorie. S'il y a une *, la catégorie n'est pas dans la hiérarchie.</p>";
		#}

		my $tagtype_p = $Lang{$tagtype . "_p"}{$lang};

		my $extra_column_searchable = "";
		if (defined $taxonomy_fields{$tagtype}) {
			$extra_column_searchable .= ', {"searchable": false}';
		}

		$initjs .= <<JS
oTable = \$('#tagstable').DataTable({
	language: {
		search: "$Lang{tagstable_search}{$lang}",
		info: "_TOTAL_ $tagtype_p",
		infoFiltered: " - $Lang{tagstable_filtered}{$lang}"
	},
	paging: false,
	order: [[ 1, "desc" ]],
	columns: [
		null,
		{"searchable": false} $extra_column_searchable
	]
});
JS
			;

		$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/datatables.min.js"></script>
SCRIPTS
			;

		$header .= <<HEADER
<link rel="stylesheet" href="$static_subdomain/js/datatables.min.css">
HEADER
			;

	}

	$log->debug("end", {}) if $log->is_debug();

	return $html;
}

sub display_list_of_tags_translate ($request_ref, $query_ref) {

	my $results = query_list_of_tags($request_ref, $query_ref);

	my $html = '';
	my $html_pages = '';

	my $template_data_ref_tags_translate = {};

	$template_data_ref_tags_translate->{results} = $results;
	$template_data_ref_tags_translate->{ref_results} = ref($results);
	$template_data_ref_tags_translate->{results_zero} = $results->[0];

	if ((not defined $results) or (ref($results) ne "ARRAY") or (not defined $results->[0])) {

		$log->debug("results for aggregate MongoDB query key", {"results" => $results}) if $log->is_debug();
		$request_ref->{structured_response}{count} = 0;

	}
	else {

		my @tags = @{$results};
		my $tagtype = $request_ref->{groupby_tagtype};

		$request_ref->{structured_response}{count} = ($#tags + 1);

		$request_ref->{title} = sprintf(lang("list_of_x"), $Lang{$tagtype . "_p"}{$lang});

		# $html .= "<h3>" . sprintf(lang("translate_taxonomy_to"), $Lang{$tagtype . "_p"}{$lang}, $Languages{$lc}{$lc}) . "</h3>";
		# Display the message in English until we have translated the translate_taxonomy_to message in many languages,
		# to avoid mixing local words with English words

		$template_data_ref_tags_translate->{tagtype_s} = ucfirst($Lang{$tagtype . "_s"}{$lang});
		$template_data_ref_tags_translate->{translate_taxonomy}
			= sprintf($Lang{"translate_taxonomy_to"}{en}, $Lang{$tagtype . "_p"}{en}, $Languages{$lc}{en});

		#var availableTags = [
		#      "ActionScript",
		#      "Scala",
		#      "Scheme"
		#    ];

		my $main_link = '';
		my $nofollow = '';
		if (defined $request_ref->{tagid}) {
			local $log->context->{tagtype} = $request_ref->{tagtype};
			local $log->context->{tagid} = $request_ref->{tagid};

			$log->trace("determining main_link for the tag") if $log->is_trace();
			if (defined $taxonomy_fields{$request_ref->{tagtype}}) {
				$main_link = canonicalize_taxonomy_tag_link($lc, $request_ref->{tagtype}, $request_ref->{tagid});
				$log->debug("main_link determined from the taxonomy tag", {main_link => $main_link})
					if $log->is_debug();
			}
			else {
				$main_link = canonicalize_tag_link($request_ref->{tagtype}, $request_ref->{tagid});
				$log->debug("main_link determined from the canonical tag", {main_link => $main_link})
					if $log->is_debug();
			}
			$nofollow = ' rel="nofollow"';
		}

		my $users_translations_ref = {};

		load_users_translations_for_lc($users_translations_ref, $tagtype, $lc);

		my %products = ();    # number of products by tag, used for histogram of nutrition grades colors

		$log->debug("going through all tags") if $log->is_debug();

		my $i = 0;    # Number of tags
		my $j = 0;    # Number of tags displayed

		my $to_be_translated = 0;
		my $translated = 0;

		my $path = $tag_type_singular{$tagtype}{$lc};

		my @tagcounts;

		my $param_translate = single_param("translate");

		foreach my $tagcount_ref (@tags) {

			$i++;

			if (($i % 10000 == 0) and ($log->is_debug())) {
				$log->debug("going through all tags", {i => $i});
			}

			my $tagid = $tagcount_ref->{_id};
			my $count = $tagcount_ref->{count};

			$products{$tagid} = $count;

			my $link;
			my $products = $count;
			if ($products == 0) {
				$products = "";
			}

			my $info = '';
			my $css_class = '';

			my $tag_ref = get_taxonomy_tag_and_link_for_lang($lc, $tagtype, $tagid);

			$log->debug("display_list_of_tags_translate - tagf_ref", $tag_ref) if $log->is_debug();

			# Keep only known tags that do not have a translation in the current lc
			if (not $tag_ref->{known}) {
				$log->debug("display_list_of_tags_translate - entry $tagid is not known") if $log->is_debug();
				next;
			}

			if (
				(not($param_translate eq "all"))
				and (   (defined $tag_ref->{display_lc})
					and (($tag_ref->{display_lc} eq $lc) or ($tag_ref->{display_lc} ne "en")))
				)
			{

				$log->debug("display_list_of_tags_translate - entry $tagid already has a translation to $lc")
					if $log->is_debug();
				next;
			}

			my $new_translation = "";

			# Check to see if we already have a user translation
			if (defined $users_translations_ref->{$lc}{$tagid}) {

				$translated++;

				$log->debug("display_list_of_tags_translate - entry $tagid has existing user translation to $lc",
					$users_translations_ref->{$lc}{$tagid})
					if $log->is_debug();

				if ($param_translate eq "add") {
					# Add mode: show only entries without translations
					$log->debug("display_list_of_tags_translate - translate="
							. $param_translate
							. " - skip $tagid entry with existing user translation")
						if $log->is_debug();
					next;
				}
				# All, Edit or Review mode: show the new translation
				$new_translation
					= "<div>"
					. lang("current_translation") . " : "
					. $users_translations_ref->{$lc}{$tagid}{to} . " ("
					. $users_translations_ref->{$lc}{$tagid}{userid}
					. ")</div>";
			}
			else {
				$to_be_translated++;

				$log->debug("display_list_of_tags_translate - entry $tagid does not have user translation to $lc")
					if $log->is_debug();

				if ($param_translate eq "review") {
					# Review mode: show only entries with new translations
					$log->debug("display_list_of_tags_translate - translate="
							. $param_translate
							. " - skip $tagid entry without existing user translation")
						if $log->is_debug();
					next;
				}
			}

			$j++;

			$link = "/$path/" . $tag_ref->{tagurl};    # "en:yule-log"

			my $display = $tag_ref->{display};    # "en:Yule log"
			my $display_lc = $tag_ref->{display_lc};    # "en"

			# $synonyms_for keys don't have language codes, so we need to strip it off $display to get a valid lookup
			# E.g. 'yule-log' => ['Yule log','Christmas log cake']
			my $display_without_lc = $display =~ s/^..://r;    # strip lc off -> "Yule log"
			my $synonyms = "";
			my $lc_tagid = get_string_id_for_lang($display_lc, $display_without_lc);    # "yule-log"

			if (    (defined $synonyms_for{$tagtype}{$display_lc})
				and (defined $synonyms_for{$tagtype}{$display_lc}{$lc_tagid}))
			{
				$synonyms = join(", ", @{$synonyms_for{$tagtype}{$display_lc}{$lc_tagid}});
			}

			# Google Translate link

			# https://translate.google.com/#view=home&op=translate&sl=en&tl=de&text=
			my $escaped_synonyms = $synonyms;
			$escaped_synonyms =~ s/ /\%20/g;

			my $google_translate_link
				= "https://translate.google.com/#view=home&op=translate&sl=en&tl=$lc&text=$escaped_synonyms";

			push(
				@tagcounts,
				{
					link => $link,
					display => $display,
					nofollow => $nofollow,
					synonyms => $synonyms,
					j => $j,
					tagid => $tagid,
					google_translate_link => $google_translate_link,
					new_translation => $new_translation,
					products => $products
				}
			);

		}

		my $counts
			= ($#tags + 1) . " "
			. $Lang{$tagtype . "_p"}{$lang} . " ("
			. lang("translated")
			. " : $translated, "
			. lang("to_be_translated")
			. " : $to_be_translated)";

		$template_data_ref_tags_translate->{tagcounts} = \@tagcounts;
		$template_data_ref_tags_translate->{tagtype} = $tagtype;
		$template_data_ref_tags_translate->{counts} = $counts;

		$log->debug("going through all tags - done", {}) if $log->is_debug();

		my $tagtype_p = $Lang{$tagtype . "_p"}{$lang};

		$initjs .= <<JS
oTable = \$('#tagstable').DataTable({
	language: {
		search: "$Lang{tagstable_search}{$lang}",
		info: "_TOTAL_ $tagtype_p",
		infoFiltered: " - $Lang{tagstable_filtered}{$lang}"
	},
	paging: false,
	order: [[ 1, "desc" ]],
	columns: [
		null,
		{ "searchable": false },
		{ "searchable": false }
	]
});


var buttonId;

\$("button.save").click(function(event){

	event.stopPropagation();
	event.preventDefault();
	buttonId = this.id;
	console.log("buttonId " + buttonId);

	buttonIdArray = buttonId.split("_");
	console.log("Split in " + buttonIdArray[0] + " " + buttonIdArray[1])

	var tagtype = \$("#tagtype").val()
	var fromId = "from_" + buttonIdArray[1];
	var from = \$("#"+fromId).val();
	var toId = "to_" + buttonIdArray[1];
	var to = \$("#"+toId).val();
	var saveId = "save_" + buttonIdArray[1];
	console.log("tagtype = " + tagtype);
	console.log("from = " + from);
	console.log("to = " + to);

	\$("#"+saveId).hide();

var jqxhr = \$.post( "/cgi/translate_taxonomy.pl", { tagtype: tagtype, from: from, to: to },
	function(data) {
  \$("#"+toId+"_div").html(to);
  \$("#"+saveId+"_div").html("Saved");

})
  .fail(function() {
    \$("#"+saveId).show();
  });

});

JS
			;

		$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/datatables.min.js"></script>
SCRIPTS
			;

		$header .= <<HEADER
<link rel="stylesheet" href="$static_subdomain/js/datatables.min.css">
HEADER
			;

	}

	$log->debug("end", {}) if $log->is_debug();

	process_template('web/common/includes/display_list_of_tags_translate.tt.html',
		$template_data_ref_tags_translate, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

sub display_points_ranking ($tagtype, $tagid) {

	local $log->context->{tagtype} = $tagtype;
	local $log->context->{tagid} = $tagid;

	$log->info("displaying points ranking") if $log->is_info();

	my $ranktype = "users";
	if ($tagtype eq "users") {
		$ranktype = "countries";
	}

	my $html = "";

	my $points_ref;
	my $ambassadors_points_ref;

	if ($tagtype eq 'users') {
		$points_ref = retrieve("$data_root/data/index/users_points.sto");
		$ambassadors_points_ref = retrieve("$data_root/data/index/ambassadors_users_points.sto");
	}
	else {
		$points_ref = retrieve("$data_root/data/index/countries_points.sto");
		$ambassadors_points_ref = retrieve("$data_root/data/index/ambassadors_countries_points.sto");
	}

	$html .= "\n\n<table id=\"${tagtype}table\">\n";

	$html
		.= "<tr><th>"
		. ucfirst(lang($ranktype . "_p"))
		. "</th><th>Explorer rank</th><th>Explorer points</th><th>Ambassador rank</th><th>Ambassador points</th></tr>\n";

	my %ambassadors_ranks = ();

	my $i = 1;
	my $j = 1;
	my $current = -1;
	foreach my $key (
		sort {$ambassadors_points_ref->{$tagid}{$b} <=> $ambassadors_points_ref->{$tagid}{$a}}
		keys %{$ambassadors_points_ref->{$tagid}}
		)
	{
		# ex-aequo: keep track of current high score
		if ($ambassadors_points_ref->{$tagid}{$key} != $current) {
			$j = $i;
			$current = $ambassadors_points_ref->{$tagid}{$key};
		}
		$ambassadors_ranks{$key} = $j;
		$i++;
	}

	my $n_ambassadors = --$i;

	$i = 1;
	$j = 1;
	$current = -1;

	foreach my $key (sort {$points_ref->{$tagid}{$b} <=> $points_ref->{$tagid}{$a}} keys %{$points_ref->{$tagid}}) {
		# ex-aequo: keep track of current high score
		if ($points_ref->{$tagid}{$key} != $current) {
			$j = $i;
			$current = $points_ref->{$tagid}{$key};
		}
		my $rank = $j;
		$i++;

		my $display_key = $key;
		my $link = canonicalize_taxonomy_tag_link($lc, $ranktype, $key) . "/points";

		if ($ranktype eq "countries") {
			$display_key = display_taxonomy_tag($lc, "countries", $key);
			$link = format_subdomain($country_codes_reverse{$key}) . "/points";
		}

		$html
			.= "<tr><td><a href=\"$link\">$display_key</a></td><td>$rank</td><td>"
			. $points_ref->{$tagid}{$key}
			. "</td><td>"
			. $ambassadors_ranks{$key}
			. "</td><td>"
			. $ambassadors_points_ref->{$tagid}{$key}
			. "</td></tr>\n";

	}

	my $n_explorers = --$i;

	$html .= "</table>\n";

	my $tagtype_p = $Lang{$ranktype . "_p"}{$lang};

	$initjs .= <<JS
${tagtype}Table = \$('#${tagtype}table').DataTable({
	language: {
		search: "$Lang{tagstable_search}{$lang}",
		info: "_TOTAL_ $tagtype_p",
		infoFiltered: " - $Lang{tagstable_filtered}{$lang}"
	},
	paging: false,
	order: [[ 1, "desc" ]]
});
JS
		;

	my $title;

	if ($tagtype eq 'users') {
		if ($tagid ne '_all_') {
			$title = sprintf(lang("points_user"), $tagid, $n_explorers, $n_ambassadors);
		}
		else {
			$title = sprintf(lang("points_all_users"), $n_explorers, $n_ambassadors);
		}
		$title =~ s/ (0|1) countries/ $1 country/g;
	}
	elsif ($tagtype eq 'countries') {
		if ($tagid ne '_all_') {
			$title = sprintf(
				lang("points_country"),
				display_taxonomy_tag($lc, $tagtype, $tagid),
				$n_explorers, $n_ambassadors
			);
		}
		else {
			$title = sprintf(lang("points_all_countries"), $n_explorers, $n_ambassadors);
		}
		$title =~ s/ (0|1) (explorer|ambassador|explorateur|ambassadeur)s/ $1 $2/g;
	}

	return "<p>$title</p>\n" . $html;
}

# explorers and ambassadors points
# can be called without a tagtype or a tagid, or with a user or a country tag

sub display_points ($request_ref) {

	my $html = "<p>" . lang("openfoodhunt_points") . "</p>\n";

	my $title;

	my $tagtype = $request_ref->{tagtype};
	my $tagid = $request_ref->{tagid};
	my $display_tag;
	my $newtagid;
	my $newtagidpath;
	my $canon_tagid = undef;

	local $log->context->{tagtype} = $tagtype;
	local $log->context->{tagid} = $tagid;

	$log->info("displaying points") if $log->is_info();

	if (defined $tagid) {
		if (defined $taxonomy_fields{$tagtype}) {
			$canon_tagid = canonicalize_taxonomy_tag($lc, $tagtype, $tagid);
			$display_tag = display_taxonomy_tag($lc, $tagtype, $canon_tagid);
			$title = $display_tag;
			$newtagid = get_taxonomyid($lc, $display_tag);
			$log->debug("displaying points for a taxonomy tag",
				{canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title})
				if $log->is_debug();
			if ($newtagid !~ /^(\w\w):/) {
				$newtagid = $lc . ':' . $newtagid;
			}
			$newtagidpath = canonicalize_taxonomy_tag_link($lc, $tagtype, $newtagid);
			$request_ref->{current_link} = $newtagidpath;
			$request_ref->{world_current_link} = canonicalize_taxonomy_tag_link($lc, $tagtype, $canon_tagid);
		}
		else {
			$display_tag = canonicalize_tag2($tagtype, $tagid);
			$newtagid = get_string_id_for_lang($lc, $display_tag);
			$display_tag = display_tag_name($tagtype, $display_tag);
			if ($tagtype eq 'emb_codes') {
				$canon_tagid = $newtagid;
				$canon_tagid =~ s/-($ec_code_regexp)$/-ec/ie;
			}
			$title = $display_tag;
			$newtagidpath = canonicalize_tag_link($tagtype, $newtagid);
			$request_ref->{current_link} = $newtagidpath;
			my $current_lang = $lang;
			my $current_lc = $lc;
			$lang = 'en';
			$lc = 'en';
			$request_ref->{world_current_link} = canonicalize_tag_link($tagtype, $newtagid);
			$lang = $current_lang;
			$lc = $current_lc;
			$log->debug("displaying points for a normal tag",
				{canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title})
				if $log->is_debug();
		}
	}

	$request_ref->{current_link} .= "/points";

	if ((defined $tagid) and ($newtagid ne $tagid)) {
		$request_ref->{redirect} = $formatted_subdomain . $request_ref->{current_link};
		$log->info(
			"newtagid does not equal the original tagid, redirecting",
			{newtagid => $newtagid, redirect => $request_ref->{redirect}}
		) if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	my $description = '';

	my $products_title = $display_tag;

	if ($tagtype eq 'users') {
		my $user_ref = retrieve("$data_root/users/$tagid.sto");
		if (defined $user_ref) {
			if ((defined $user_ref->{name}) and ($user_ref->{name} ne '')) {
				$title = $user_ref->{name} . " ($tagid)";
				$products_title = $user_ref->{name};
			}
		}
	}

	if ($cc ne 'world') {
		$tagtype = 'countries';
		$tagid = $country;
		$title = display_taxonomy_tag($lc, $tagtype, $tagid);
	}

	if (not defined $tagid) {
		$tagid = '_all_';
	}

	if (defined $tagtype) {
		$html .= display_points_ranking($tagtype, $tagid);
		$request_ref->{title}
			= "Open Food Hunt" . lang("title_separator") . lang("points_ranking") . lang("title_separator") . $title;
	}
	else {
		$html .= display_points_ranking("users", "_all_");
		$html .= display_points_ranking("countries", "_all_");
		$request_ref->{title} = "Open Food Hunt" . lang("title_separator") . lang("points_ranking_users_and_countries");
	}

	$request_ref->{content_ref} = \$html;

	$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/datatables.min.js"></script>
SCRIPTS
		;

	$header .= <<HEADER
<link rel="stylesheet" href="$static_subdomain/js/datatables.min.css">
<meta property="og:image" content="https://world.openfoodfacts.org/images/misc/open-food-hunt-2015.1304x893.png">
HEADER
		;

	display_page($request_ref);

	return;
}

# See issue 1960
# a tag prefix, such as a minus sign, can indicate that a tag value should be excluded from a query
# during processing this prefix may be removed from the current url link
# this will add the prefix back
# it will put the prefix before the string following the last forward slash in the link
sub add_tag_prefix_to_link ($link, $tag_prefix) {
	$link =~ s/^(.*)\/(.*)$/$1\/$tag_prefix$2/;
	return $link;
}

=head2 display_tag ( $request_ref )

This function is called to display either:

1. Products that have a specific tag:  /category/cakes
  or that don't have a specific tag /category/-cakes
  or that have 2 specific tags /category/cake/brand/oreo
2. List of tags of a given type:  /labels
  possibly for products that have a specific tag: /category/cakes/labels
  or 2 specific tags:  /category/cakes/label/organic/additives

When displaying products for a tag, the function generates tag type specific HTML
that is displayed at the top of the page:
- tag parents and children
- maps for tag types that have a location (e.g. packaging codes)
- special properties for some tag types (e.g. additives)

The function then calls search_and_display_products() to display the paginated list of products.

When displaying a list of tags, the function calls display_list_of_tags().

=cut

sub display_tag ($request_ref) {

	my $title;

	my $tagtype = $request_ref->{tagtype};
	my $tagid = $request_ref->{tagid};
	my $display_tag;
	my $newtagid;
	my $newtagidpath;
	my $canon_tagid = undef;

	local $log->context->{tagtype} = $tagtype;
	local $log->context->{tagid} = $tagid;

	my $tagtype2 = $request_ref->{tagtype2};
	my $tagid2 = $request_ref->{tagid2};
	my $display_tag2;
	my $newtagid2;
	my $newtagid2path;
	my $canon_tagid2 = undef;

	local $log->context->{tagtype2} = $tagtype2;
	local $log->context->{tagid2} = $tagid2;

	init_tags_texts() unless %tags_texts;

	# Add a meta robot noindex for pages related to users
	if (
		(
				(defined $tagtype)
			and ($tagtype =~ /^(users|correctors|editors|informers|correctors|photographers|checkers)$/)
		)
		or (    (defined $tagtype2)
			and ($tagtype2 =~ /^(users|correctors|editors|informers|correctors|photographers|checkers)$/))
		)
	{

		$header .= '<meta name="robots" content="noindex">' . "\n";

	}

	if (defined $tagid) {
		if (defined $taxonomy_fields{$tagtype}) {
			$canon_tagid = canonicalize_taxonomy_tag($lc, $tagtype, $tagid);
			$display_tag = display_taxonomy_tag($lc, $tagtype, $canon_tagid);
			$title = $display_tag;
			$newtagid = get_taxonomyid($lc, $display_tag);
			$log->info("displaying taxonomy tag", {canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title})
				if $log->is_info();
			if ($newtagid !~ /^(\w\w):/) {
				$newtagid = $lc . ':' . $newtagid;
			}
			$newtagidpath = canonicalize_taxonomy_tag_link($lc, $tagtype, $newtagid);
			$request_ref->{current_link} = $newtagidpath;
			$request_ref->{world_current_link} = canonicalize_taxonomy_tag_link($lc, $tagtype, $canon_tagid);
		}
		else {
			$display_tag = canonicalize_tag2($tagtype, $tagid);
			# Use "no_language" normalization for tags types without a taxonomy
			$newtagid = get_string_id_for_lang("no_language", $display_tag);
			$display_tag = display_tag_name($tagtype2, $display_tag);
			if ($tagtype eq 'emb_codes') {
				$canon_tagid = $newtagid;
				$canon_tagid =~ s/-($ec_code_regexp)$/-ec/ie;
			}
			$title = $display_tag;
			$newtagidpath = canonicalize_tag_link($tagtype, $newtagid);
			$request_ref->{current_link} = $newtagidpath;
			my $current_lang = $lang;
			my $current_lc = $lc;
			$lang = 'en';
			$lc = 'en';
			$request_ref->{world_current_link} = canonicalize_tag_link($tagtype, $newtagid);
			$lang = $current_lang;
			$lc = $current_lc;
			$log->info("displaying normal tag", {canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title})
				if $log->is_info();
		}

		# add back leading dash when a tag is excluded
		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} ne '')) {
			my $prefix = $request_ref->{tag_prefix};
			$request_ref->{current_link} = add_tag_prefix_to_link($request_ref->{current_link}, $prefix);
			$request_ref->{world_current_link} = add_tag_prefix_to_link($request_ref->{world_current_link}, $prefix);
			$log->debug("Found tag prefix ", {request => $request_ref}) if $log->is_debug();
		}

		$request_ref->{canon_tagid} = $canon_tagid;
	}
	else {
		$log->warn("no tagid found") if $log->is_warn();
	}

	# 2nd tag?
	if (defined $tagid2) {
		if (defined $taxonomy_fields{$tagtype2}) {
			$canon_tagid2 = canonicalize_taxonomy_tag($lc, $tagtype2, $tagid2);
			$display_tag2 = display_taxonomy_tag($lc, $tagtype2, $canon_tagid2);
			$title .= " / " . $display_tag2;
			$newtagid2 = get_taxonomyid($lc, $display_tag2);
			$log->info(
				"2nd level tag is a taxonomy tag",
				{
					tagtype2 => $tagtype2,
					tagid2 => $tagid2,
					canon_tagid2 => $canon_tagid2,
					newtagid2 => $newtagid2,
					title => $title
				}
			) if $log->is_info();
			if ($newtagid2 !~ /^(\w\w):/) {
				$newtagid2 = $lc . ':' . $newtagid2;
			}
			$newtagid2path = canonicalize_taxonomy_tag_link($lc, $tagtype2, $newtagid2);
			$request_ref->{current_link} .= $newtagid2path;
			$request_ref->{world_current_link} .= canonicalize_taxonomy_tag_link($lc, $tagtype2, $canon_tagid2);
		}
		else {
			$display_tag2 = canonicalize_tag2($tagtype2, $tagid2);
			$newtagid2 = get_string_id_for_lang("no_language", $display_tag2);
			$display_tag2 = display_tag_name($tagtype2, $display_tag2);
			$title .= " / " . $display_tag2;

			if ($tagtype2 eq 'emb_codes') {
				$canon_tagid2 = $newtagid2;
				$canon_tagid2 =~ s/-($ec_code_regexp)$/-ec/ie;
			}
			$newtagid2path = canonicalize_tag_link($tagtype2, $newtagid2);
			$request_ref->{current_link} .= $newtagid2path;
			my $current_lang = $lang;
			my $current_lc = $lc;
			$lang = 'en';
			$lc = 'en';
			$request_ref->{world_current_link} .= canonicalize_tag_link($tagtype2, $newtagid2);
			$lang = $current_lang;
			$log->info(
				"2nd level tag is a normal tag",
				{
					tagtype2 => $tagtype2,
					tagid2 => $tagid2,
					canon_tagid2 => $canon_tagid2,
					newtagid2 => $newtagid2,
					title => $title
				}
			) if $log->is_info();
			$lc = $current_lc;
		}

		# add back leading dash when a tag is excluded
		if ((defined $request_ref->{tag2_prefix}) and ($request_ref->{tag2_prefix} ne '')) {
			my $prefix = $request_ref->{tag2_prefix};
			$request_ref->{current_link} = add_tag_prefix_to_link($request_ref->{current_link}, $prefix);
			$request_ref->{world_current_link} = add_tag_prefix_to_link($request_ref->{world_current_link}, $prefix);
			$log->debug("Found tag prefix 2 ", {request => $request_ref}) if $log->is_debug();
		}

		$request_ref->{canon_tagid2} = $canon_tagid2;
	}

	if (defined $request_ref->{groupby_tagtype}) {
		$request_ref->{current_link} .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
		$request_ref->{world_current_link} .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
	}

	# If the query contained tags in non-canonical form, redirect to the form with the canonical tags
	# The redirect is temporary (302), as the canonicalization could change if the corresponding taxonomies change
	if (((defined $newtagid) and ($newtagid ne $tagid)) or ((defined $newtagid2) and ($newtagid2 ne $tagid2))) {
		$request_ref->{redirect} = $formatted_subdomain . $request_ref->{current_link};
		# Re-add file suffix, so that the correct response format is kept. https://github.com/openfoodfacts/openfoodfacts-server/issues/894
		$request_ref->{redirect} .= '.json' if single_param("json");
		$request_ref->{redirect} .= '.jsonp' if single_param("jsonp");
		$request_ref->{redirect} .= '.xml' if single_param("xml");
		$request_ref->{redirect} .= '.jqm' if single_param("jqm");
		$log->info("one or more tagids mismatch, redirecting to correct url", {redirect => $request_ref->{redirect}})
			if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	my $weblinks_html = '';
	my @wikidata_objects = ();
	if (    ($tagtype ne 'additives')
		and (not defined $request_ref->{groupby_tagtype}))
	{
		my @weblinks = ();
		if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid})) {
			foreach my $key (keys %weblink_templates) {
				next if not defined $properties{$tagtype}{$canon_tagid}{$key};
				my $weblink = {
					text => $weblink_templates{$key}{text},
					href => sprintf($weblink_templates{$key}{href}, $properties{$tagtype}{$canon_tagid}{$key}),
					hreflang => $weblink_templates{$key}{hreflang},
				};
				$weblink->{title} = sprintf($weblink_templates{$key}{title}, $properties{$tagtype}{$canon_tagid}{$key})
					if defined $weblink_templates{$key}{title};
				push @weblinks, $weblink;
			}

			if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid}{'wikidata:en'})) {
				push @wikidata_objects, $properties{$tagtype}{$canon_tagid}{'wikidata:en'};
			}
		}

		if (($#weblinks >= 0)) {
			$weblinks_html
				.= '<div class="weblinks" style="float:right;width:300px;margin-left:20px;margin-bottom:20px;padding:10px;border:1px solid #cbe7ff;background-color:#f0f8ff;"><h3>'
				. lang('tag_weblinks')
				. '</h3><ul>';
			foreach my $weblink (@weblinks) {
				$weblinks_html .= '<li><a href="' . encode_entities($weblink->{href}) . '" itemprop="sameAs"';
				$weblinks_html .= ' hreflang="' . encode_entities($weblink->{hreflang}) . '"'
					if defined $weblink->{hreflang};
				$weblinks_html .= ' title="' . encode_entities($weblink->{title}) . '"' if defined $weblink->{title};
				$weblinks_html .= '>' . encode_entities($weblink->{text}) . '</a></li>';
			}

			$weblinks_html .= '</ul></div>';
		}
	}

	my $description = '';

	my $products_title = $display_tag;

	my $icid = $tagid;
	(defined $icid) and $icid =~ s/^.*://;

	# Gather data that will be passed to the tag template
	my $tag_template_data_ref = {};

	$tag_template_data_ref->{groupby_tagtype} = $request_ref->{groupby_tagtype};

	if (defined $tagtype) {

		# check if there is a template to display additional fields from the taxonomy
		# the template is set in the Config.pm file
		# This feature was coded before the introduction of knowledge panels
		# It is in maintenance mode, and should be reimplemented as facets knowledge panels
		# (server side, or with client side facets knowledge panels)

		if (exists $options{"display_tag_" . $tagtype}) {

			print STDERR "option display_tag_$tagtype\n";

			foreach my $field_orig (@{$options{"display_tag_" . $tagtype}}) {

				my $field = $field_orig;

				$log->debug("display_tag - field", {field => $field}) if $log->is_debug();

				my $array = 0;
				if ($field =~ /^\@/) {
					$field = $';
					$array = 1;
				}

				# Section title?

				if ($field =~ /^title:/) {
					$field = $';
					my $title = lang($tagtype . "_" . $field);
					($title eq "") and $title = lang($field);
					$description .= "<h3>" . $title . "</h3>\n";
					$log->debug("display_tag - section title", {field => $field}) if $log->is_debug();
					next;
				}

				# Special processing

				if ($field eq 'efsa_evaluation_exposure_table') {

					$log->debug(
						"display_tag - efsa_evaluation_exposure_table",
						{
							efsa_evaluation_overexposure_risk =>
								$properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en:"}
						}
					) if $log->is_debug();

					if (    (defined $properties{$tagtype})
						and (defined $properties{$tagtype}{$canon_tagid})
						and (defined $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"})
						and ($properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"} ne 'en:no'))
					{

						$log->debug("display_tag - efsa_evaluation_exposure_table - yes", {}) if $log->is_debug();

						my @groups = qw(infants toddlers children adolescents adults elderly);
						my @percentiles = qw(mean 95th);
						my @doses = qw(noael adi);
						my %doses = ();

						my %exposure = (mean => {}, '95th' => {});

						# in taxonomy:
						# efsa_evaluation_exposure_95th_greater_than_adi:en: en:adults, en:elderly, en:adolescents, en:children, en:toddlers, en:infants

						foreach my $dose (@doses) {
							foreach my $percentile (@percentiles) {
								my $exposure_property
									= "efsa_evaluation_exposure_" . $percentile . "_greater_than_" . $dose . ":en";
								if (!defined $properties{$tagtype}{$canon_tagid}{$exposure_property}) {
									next;
								}
								foreach
									my $groupid (split(/,/, $properties{$tagtype}{$canon_tagid}{$exposure_property}))
								{
									my $group = $groupid;
									$group =~ s/^\s*en://;
									$group =~ s/\s+$//;

									# NOAEL has priority over ADI
									if (exists $exposure{$percentile}{$group}) {
										next;
									}
									$exposure{$percentile}{$group} = $dose;
									$doses{$dose} = 1;    # to display legend for the dose
									$log->debug("display_tag - exposure_table ",
										{group => $group, percentile => $percentile, dose => $dose})
										if $log->is_debug();
								}
							}
						}

						$styles .= <<CSS
.exposure_table {

}

.exposure_table td,th {
	text-align: center;
	background-color:white;
	color:black;
}

CSS
							;

						my $table = <<HTML
<div style="overflow-x:auto;">
<table class="exposure_table">
<thead>
<tr>
<th>&nbsp;</th>
HTML
							;

						foreach my $group (@groups) {

							$table .= "<th>" . lang($group) . "</th>";
						}

						$table .= "</tr>\n</thead>\n<tbody>\n<tr>\n<td>&nbsp;</td>\n";

						foreach my $group (@groups) {

							$table
								.= '<td style="background-color:black;color:white;">' . lang($group . "_age") . "</td>";
						}

						$table .= "</tr>\n";

						my %icons = (
							adi => 'moderate',
							noael => 'high',
						);

						foreach my $percentile (@percentiles) {

							$table
								.= "<tr><th>"
								. lang("exposure_title_" . $percentile) . "<br>("
								. lang("exposure_description_" . $percentile)
								. ")</th>";

							foreach my $group (@groups) {

								$table .= "<td>";

								my $dose = $exposure{$percentile}{$group};

								if (not defined $dose) {
									$table .= "&nbsp;";
								}
								else {
									$table
										.= '<img src="/images/misc/'
										. $icons{$dose}
										. '.svg" alt="'
										. lang(
										"additives_efsa_evaluation_exposure_" . $percentile . "_greater_than_" . $dose)
										. '">';
								}

								$table .= "</td>";
							}

							$table .= "</tr>\n";
						}

						$table .= "</tbody>\n</table>\n</div>";

						$description .= $table;

						foreach my $dose (@doses) {
							if (exists $doses{$dose}) {
								$description
									.= "<p>"
									. '<img src="/images/misc/'
									. $icons{$dose}
									. '.svg" width="30" height="30" style="vertical-align:middle" alt="'
									. lang("additives_efsa_evaluation_exposure_greater_than_" . $dose)
									. '"> <span>: '
									. lang("additives_efsa_evaluation_exposure_greater_than_" . $dose)
									. "</span></p>\n";
							}
						}
					}
					next;
				}

				my $fieldid = get_string_id_for_lang($lc, $field);
				$fieldid =~ s/-/_/g;

				my %propertyid = ();

				# Check if we have properties in the interface language, otherwise use English

				if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid})) {

					$log->debug("display_tag - checking properties",
						{tagtype => $tagtype, canon_tagid => $canon_tagid, field => $field})
						if $log->is_debug();

					foreach my $key ('property', 'description', 'abstract', 'url', 'date') {

						my $suffix = "_" . $key;
						if ($key eq 'property') {
							$suffix = '';
						}

						if (defined $properties{$tagtype}{$canon_tagid}{$fieldid . $suffix . ":" . $lc}) {
							$propertyid{$key} = $fieldid . $suffix . ":" . $lc;
							$log->debug(
								"display_tag - property key is defined for lc $lc",
								{
									tagtype => $tagtype,
									canon_tagid => $canon_tagid,
									field => $field,
									key => $key,
									propertyid => $propertyid{$key}
								}
							) if $log->is_debug();
						}
						elsif (defined $properties{$tagtype}{$canon_tagid}{$fieldid . $suffix . ":" . "en"}) {
							$propertyid{$key} = $fieldid . $suffix . ":" . "en";
							$log->debug(
								"display_tag - property key is defined for en",
								{
									tagtype => $tagtype,
									canon_tagid => $canon_tagid,
									field => $field,
									key => $key,
									propertyid => $propertyid{$key}
								}
							) if $log->is_debug();
						}
						else {
							$log->debug(
								"display_tag - property key is not defined",
								{
									tagtype => $tagtype,
									canon_tagid => $canon_tagid,
									field => $field,
									key => $key,
									propertyid => $propertyid{$key}
								}
							) if $log->is_debug();
						}
					}
				}

				$log->debug(
					"display_tag",
					{
						tagtype => $tagtype,
						canon_tagid => $canon_tagid,
						field_orig => $field_orig,
						field => $field,
						propertyid => $propertyid{property},
						array => $array
					}
				) if $log->is_debug();

				if ((defined $propertyid{property}) or (defined $propertyid{abstract})) {

					# wikipedia abstract?

					if ((defined $propertyid{abstract}) and ($fieldid eq "wikipedia")) {

						my $site = $fieldid;

						$log->debug("display_tag - showing abstract", {site => $site}) if $log->is_debug();

						$description .= "<p>" . $properties{$tagtype}{$canon_tagid}{$propertyid{abstract}};

						if (defined $propertyid{url}) {

							my $lang_site = lang($site);
							if ((defined $lang_site) and ($lang_site ne "")) {
								$site = $lang_site;
							}
							$description
								.= ' - <a href="'
								. $properties{$tagtype}{$canon_tagid}{$propertyid{url}} . '">'
								. $site . '</a>';
						}

						$description .= "</p>";

						next;
					}

					my $title;
					my $tagtype_field = $tagtype . '_' . $fieldid;
					# $tagtype_field =~ s/_/-/g;
					if (exists $Lang{$tagtype_field}{$lc}) {
						$title = $Lang{$tagtype_field}{$lc};
					}
					elsif (exists $Lang{$fieldid}{$lc}) {
						$title = $Lang{$fieldid}{$lc};
					}

					$log->debug("display_tag - title", {tagtype => $tagtype, title => $title}) if $log->is_debug();

					$description .= "<p>";

					if (defined $title) {
						$description .= "<b>" . $title . "</b>" . separator_before_colon($lc) . ": ";
					}

					my @values = ($properties{$tagtype}{$canon_tagid}{$propertyid{property}});

					if ($array) {
						@values = split(/,/, $properties{$tagtype}{$canon_tagid}{$propertyid{property}});
					}

					my $values_display = "";

					foreach my $value_orig (@values) {

						my $value = $value_orig;    # make a copy so that we can modify it inside the foreach loop

						next if $value =~ /^\s*$/;

						$value =~ s/^\s+//;
						$value =~ s/\s+$//;

						my $property_tagtype = $fieldid;

						$property_tagtype =~ s/-/_/g;

						if (not exists $taxonomy_fields{$property_tagtype}) {
							# try with an additional s
							$property_tagtype .= "s";
						}

						$log->debug("display_tag", {property_tagtype => $property_tagtype, lc => $lc, value => $value})
							if $log->is_debug();

						my $display = $value;

						if (exists $taxonomy_fields{$property_tagtype}) {

							$display = display_taxonomy_tag($lc, $property_tagtype, $value);

							$log->debug("display_tag - $property_tagtype is a taxonomy", {display => $display})
								if $log->is_debug();

							if (    (defined $properties{$property_tagtype})
								and (defined $properties{$property_tagtype}{$value}))
							{

								# tooltip

								my $tooltip;

								if (defined $properties{$property_tagtype}{$value}{"description:$lc"}) {
									$tooltip = $properties{$property_tagtype}{$value}{"description:$lc"};
								}
								elsif (defined $properties{$property_tagtype}{$value}{"description:en"}) {
									$tooltip = $properties{$property_tagtype}{$value}{"description:en"};
								}

								if (defined $tooltip) {
									$display
										= '<span data-tooltip aria-haspopup="true" class="has-tip top" style="font-weight:normal" data-disable-hover="false" tabindex="2" title="'
										. $tooltip . '">'
										. $display
										. '</span>';
								}
								else {
									$log->debug("display_tag - no tooltip",
										{property_tagtype => $property_tagtype, value => $value})
										if $log->is_debug();
								}

							}
							else {
								$log->debug("display_tag - no property found",
									{property_tagtype => $property_tagtype, value => $value})
									if $log->is_debug();
							}
						}
						else {
							$log->debug("display_tag - not a taxonomy",
								{property_tagtype => $property_tagtype, value => $value})
								if $log->is_debug();

							# Do we have a translation for the field?

							my $valueid = $value;
							$valueid =~ s/^en://;

							# check if the value translate to a field specific value

							if (exists $Lang{$tagtype_field . "_" . $valueid}{$lc}) {
								$display = $Lang{$tagtype_field . "_" . $valueid}{$lc};
							}

							# check if we have an icon
							if (exists $Lang{$tagtype_field . "_icon_alt_" . $valueid}{$lc}) {
								my $alt = $Lang{$tagtype_field . "_icon_alt_" . $valueid}{$lc};
								my $iconid = $tagtype_field . "_icon_" . $valueid;
								$iconid =~ s/_/-/g;
								$display = <<HTML
<div class="row">
<div class="small-2 large-1 columns">
<img src="/images/misc/$iconid.svg" alt="$alt">
</div>
<div class="small-10 large-11 columns">
$display
</div>
</div>
HTML
									;
							}

							# otherwise check if we have a general value

							elsif (exists $Lang{$valueid}{$lc}) {
								$display = $Lang{$valueid}{$lc};
							}

							$log->debug("display_tag - display value", {display => $display}) if $log->is_debug();

							# tooltip

							if (exists $Lang{$valueid . "_description"}{$lc}) {

								my $tooltip = $Lang{$valueid . "_description"}{$lc};

								$display
									= '<span data-tooltip aria-haspopup="true" class="has-tip top" data-disable-hover="false" tabindex="2" title="'
									. $tooltip . '">'
									. $display
									. '</span>';

							}
							else {
								$log->debug("display_tag - no description", {valueid => $valueid}) if $log->is_debug();
							}

							# link

							if (exists $propertyid{url}) {
								$display
									= '<a href="'
									. $properties{$tagtype}{$canon_tagid}{$propertyid{url}} . '">'
									. $display . "</a>";
							}
							if (exists $Lang{$valueid . "_url"}{$lc}) {
								$display = '<a href="' . $Lang{$valueid . "_url"}{$lc} . '">' . $display . "</a>";
							}
							else {
								$log->debug("display_tag - no url", {valueid => $valueid}) if $log->is_debug();
							}

							# date

							if (exists $propertyid{date}) {
								$display .= " (" . $properties{$tagtype}{$canon_tagid}{$propertyid{date}} . ")";
							}
							if (exists $Lang{$valueid . "_date"}{$lc}) {
								$display .= " (" . $Lang{$valueid . "_date"}{$lc} . ")";
							}
							else {
								$log->debug("display_tag - no date", {valueid => $valueid}) if $log->is_debug();
							}

							# abstract
							if (exists $propertyid{abstract}) {
								$display
									.= "<blockquote>"
									. $properties{$tagtype}{$canon_tagid}{$propertyid{abstract}}
									. "</blockquote>";
							}

						}

						$values_display .= $display . ", ";
					}
					$values_display =~ s/, $//;

					$description .= $values_display . "</p>\n";

					# Display an optional description of the property

					if (exists $Lang{$tagtype_field . "_description"}{$lc}) {
						$description .= "<p>" . $Lang{$tagtype_field . "_description"}{$lc} . "</p>";
					}

				}
				else {
					$log->debug("display_tag - property not defined",
						{tagtype => $tagtype, property_id => $propertyid{property}, canon_tagid => $canon_tagid})
						if $log->is_debug();
				}
			}

			# Remove titles without content

			$description =~ s/<h3>([^<]+)<\/h3>\s*(<h3>)/<h3>/isg;
			$description =~ s/<h3>([^<]+)<\/h3>\s*$//isg;
		}
		else {
			# Do we have a description for the tag in the taxonomy?
			if (    (defined $properties{$tagtype})
				and (defined $properties{$tagtype}{$canon_tagid})
				and (defined $properties{$tagtype}{$canon_tagid}{"description:$lc"}))
			{

				$description .= "<p>" . $properties{$tagtype}{$canon_tagid}{"description:$lc"} . "</p>";
			}
		}

		$description =~ s/<tag>/$title/g;

		if (defined $ingredients_classes{$tagtype}) {
			my $class = $tagtype;

			if ($class eq 'additives') {
				$icid =~ s/-.*//;
			}
			if ($ingredients_classes{$class}{$icid}{other_names} =~ /,/) {
				$description
					.= "<p>"
					. lang("names")
					. separator_before_colon($lc) . ": "
					. $ingredients_classes{$class}{$icid}{other_names} . "</p>";
			}

			if ($ingredients_classes{$class}{$icid}{description} ne '') {
				$description .= "<p>" . $ingredients_classes{$class}{$icid}{description} . "</p>";
			}

			if ($ingredients_classes{$class}{$icid}{level} > 0) {

				my $warning = $ingredients_classes{$class}{$icid}{warning};
				$warning =~ s/(<br>|<br\/>|<br \/>|\n)/<\li>\n<li>/g;
				$warning = "<li>" . $warning . "</li>";

				if (defined $Lang{$class . '_' . $ingredients_classes{$class}{$icid}{level}}{$lang}) {
					$description
						.= "<p class=\""
						. $class . '_'
						. $ingredients_classes{$class}{$icid}{level} . "\">"
						. $Lang{$class . '_' . $ingredients_classes{$class}{$icid}{level}}{$lang}
						. "</p>\n";
				}

				$description .= "<ul>" . $warning . '</ul>';
			}
		}
		if ((defined $tagtype2) and (defined $ingredients_classes{$tagtype2})) {
			my $class = $tagtype2;
			if ($class eq 'additives') {
				$tagid2 =~ s/-.*//;
			}
		}

		# We may have a text corresponding to the tag

		if (defined $tags_texts{$lc}{$tagtype}{$icid}) {
			my $tag_text = $tags_texts{$lc}{$tagtype}{$icid};
			if ($tag_text =~ /<h1>(.*?)<\/h1>/) {
				$title = $1;
				$tag_text =~ s/<h1>(.*?)<\/h1>//;
			}
			if ($request_ref->{page} <= 1) {
				$description .= $tag_text;
			}
		}

		my @markers = ();
		if ($tagtype eq 'emb_codes') {

			my $city_code = get_city_code($tagid);

			local $log->context->{city_code} = $city_code;
			$log->debug("city code for tag with emb_code type") if $log->debug();

			init_emb_codes() unless %emb_codes_cities;
			if (defined $emb_codes_cities{$city_code}) {
				$description
					.= "<p>"
					. lang("cities_s")
					. separator_before_colon($lc) . ": "
					. display_tag_link('cities', $emb_codes_cities{$city_code}) . "</p>";
			}

			$log->debug("checking if the canon_tagid is a packager code") if $log->is_debug();
			if (exists $packager_codes{$canon_tagid}) {
				$log->debug("packager code found for the canon_tagid", {cc => $packager_codes{$canon_tagid}{cc}})
					if $log->is_debug();

				# Generate a map if we have coordinates
				my ($lat, $lng) = get_packager_code_coordinates($canon_tagid);
				if ((defined $lat) and (defined $lng)) {
					my @geo = ($lat + 0.0, $lng + 0.0);
					push @markers, \@geo;
				}

				if ($packager_codes{$canon_tagid}{cc} eq 'ch') {
					$description .= <<HTML
<p>$packager_codes{$canon_tagid}{full_address}</p>
HTML
						;
				}

				if ($packager_codes{$canon_tagid}{cc} eq 'es') {
					# Razón Social;Provincia/Localidad
					$description .= <<HTML
<p>$packager_codes{$canon_tagid}{razon_social}<br>
$packager_codes{$canon_tagid}{provincia_localidad}
</p>
HTML
						;
				}

				if ($packager_codes{$canon_tagid}{cc} eq 'fr') {
					$description .= <<HTML
<p>$packager_codes{$canon_tagid}{raison_sociale_enseigne_commerciale}<br>
$packager_codes{$canon_tagid}{adresse} $packager_codes{$canon_tagid}{code_postal} $packager_codes{$canon_tagid}{commune}<br>
SIRET : $packager_codes{$canon_tagid}{siret} - <a href="$packager_codes{$canon_tagid}{section}">Source</a>
</p>
HTML
						;
				}

				if ($packager_codes{$canon_tagid}{cc} eq 'hr') {
					$description .= <<HTML
<p>$packager_codes{$canon_tagid}{approved_establishment}<br>
$packager_codes{$canon_tagid}{street_address} $packager_codes{$canon_tagid}{town_and_postal_code} ($packager_codes{$canon_tagid}{county})
</p>
HTML
						;
				}

				if ($packager_codes{$canon_tagid}{cc} eq 'uk') {

					my $district = '';
					my $local_authority = '';
					if ($packager_codes{$canon_tagid}{district} =~ /\w/) {
						$district = "District: $packager_codes{$canon_tagid}{district}<br>";
					}
					if ($packager_codes{$canon_tagid}{local_authority} =~ /\w/) {
						$local_authority = "Local authority: $packager_codes{$canon_tagid}{local_authority}<br>";
					}
					$description .= <<HTML
<p>$packager_codes{$canon_tagid}{name}<br>
$district
$local_authority
</p>
HTML
						;
					# FSA ratings
					if (exists $packager_codes{$canon_tagid}{fsa_rating_business_name}) {
						my $logo = '';
						my $img = "images/countries/uk/ratings/large/72ppi/"
							. lc($packager_codes{$canon_tagid}{fsa_rating_key}) . ".jpg";
						if (-e "$www_root/$img") {
							$logo = <<HTML
<img src="/$img" alt="Rating">
HTML
								;
						}
						$description .= <<HTML
<div>
<a href="https://ratings.food.gov.uk/">Food Hygiene Rating</a> from the Food Standards Agency (FSA):
<p>
Business name: $packager_codes{$canon_tagid}{fsa_rating_business_name}<br>
Business type: $packager_codes{$canon_tagid}{fsa_rating_business_type}<br>
Address: $packager_codes{$canon_tagid}{fsa_rating_address}<br>
Local authority: $packager_codes{$canon_tagid}{fsa_rating_local_authority}<br>
Rating: $packager_codes{$canon_tagid}{fsa_rating_value}<br>
Rating date: $packager_codes{$canon_tagid}{fsa_rating_date}<br>
</p>
$logo
</div>
HTML
							;
					}
				}
			}
		}

		my $map_html;
		if (((scalar @wikidata_objects) > 0) or ((scalar @markers) > 0)) {
			my $json = JSON::PP->new->utf8(0);
			my $map_template_data_ref = {
				lang => \&lang,
				encode_json => sub ($obj_ref) {
					return $json->encode($obj_ref);
				},
				wikidata => \@wikidata_objects,
				pointers => \@markers
			};
			process_template('web/pages/tags_map/map_of_tags.tt.html', $map_template_data_ref, \$map_html)
				|| ($map_html .= 'template error: ' . $tt->error());
		}

		if ($map_html) {
			$description = <<HTML
<div class="row">

	<div id="tag_description" class="large-12 columns">
		$description
	</div>
	<div id="tag_map" class="large-9 columns" style="display: none;">
		<div id="container" style="height: 300px"></div>
	</div>

</div>
$map_html
HTML
				;
		}

		if ($tagtype =~ /^(users|correctors|editors|informers|correctors|photographers|checkers)$/) {

			# Users starting with org- are organizations, not actual users

			my $user_or_org_ref;
			my $orgid;

			if ($tagid =~ /^org-/) {

				# Organization

				$orgid = $';
				$user_or_org_ref = retrieve_org($orgid);

				if (not defined $user_or_org_ref) {
					display_error_and_exit(lang("error_unknown_org"), 404);
				}
			}
			elsif ($tagid =~ /\./) {
				# App user (format "[app id].[app uuid]")

				my $appid = $`;
				my $uuid = $';

				my $app_name = deep_get(\%options, "apps_names", $appid) || $appid;
				my $app_user = f_lang("f_app_user", {app_name => $app_name});

				$title = $app_user;
				$products_title = $app_user;
				$display_tag = $app_user;
			}
			else {

				# User

				$user_or_org_ref = retrieve("$data_root/users/$tagid.sto");

				if (not defined $user_or_org_ref) {
					display_error_and_exit(lang("error_unknown_user"), 404);
				}
			}

			if (defined $user_or_org_ref) {

				if ($user_or_org_ref->{name} ne '') {
					$title = $user_or_org_ref->{name} || $tagid;
					$products_title = $user_or_org_ref->{name};
					$display_tag = $user_or_org_ref->{name};
				}

				# Display the user or organization profile

				my $user_template_data_ref = dclone($user_or_org_ref);

				my $profile_html = "";

				if ($tagid =~ /^org-/) {

					# Display the organization profile

					if (is_user_in_org_group($user_or_org_ref, $User_id, "admins") or $admin) {
						$user_template_data_ref->{edit_profile} = 1;
						$user_template_data_ref->{orgid} = $orgid;
					}

					process_template('web/pages/org_profile/org_profile.tt.html',
						$user_template_data_ref, \$profile_html)
						or $profile_html
						= "<p>web/pages/org_profile/org_profile.tt.html template error: " . $tt->error() . "</p>";
				}
				else {

					# Display the user profile

					if (($tagid eq $User_id) or $admin) {
						$user_template_data_ref->{edit_profile} = 1;
						$user_template_data_ref->{userid} = $tagid;
					}

					$user_template_data_ref->{links} = [
						{
							text => sprintf(lang('contributors_products'), $products_title),
							url => canonicalize_tag_link("users", get_string_id_for_lang("no_language", $tagid)),
						},
						{
							text => sprintf(lang('editors_products'), $products_title),
							url => canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $tagid)),
						},
						{
							text => sprintf(lang('photographers_products'), $products_title),
							url =>
								canonicalize_tag_link("photographers", get_string_id_for_lang("no_language", $tagid)),
						},
					];

					if (defined $user_or_org_ref->{registered_t}) {
						$user_template_data_ref->{registered_t} = $user_or_org_ref->{registered_t};
					}

					process_template('web/pages/user_profile/user_profile.tt.html',
						$user_template_data_ref, \$profile_html)
						or $profile_html = "<p>user_profile.tt.html template error: " . $tt->error() . "</p>";
				}

				$description .= $profile_html;
			}
		}

		if (    (defined $options{product_type})
			and ($options{product_type} eq "food")
			and ($tagtype eq 'categories'))
		{

			my $categories_nutriments_ref = $categories_nutriments_per_country{$cc};

			$log->debug("checking if this category has stored statistics",
				{cc => $cc, tagtype => $tagtype, tagid => $tagid})
				if $log->is_debug();
			if (    (defined $categories_nutriments_ref)
				and (defined $categories_nutriments_ref->{$canon_tagid})
				and (defined $categories_nutriments_ref->{$canon_tagid}{stats}))
			{
				$log->debug(
					"statistics found for the tag, addind stats to description",
					{cc => $cc, tagtype => $tagtype, tagid => $tagid}
				) if $log->is_debug();

				$description
					.= "<h2>"
					. lang("nutrition_data") . "</h2>" . "<p>"
					. sprintf(
					lang("nutrition_data_average"),
					$categories_nutriments_ref->{$canon_tagid}{n},
					$display_tag, $categories_nutriments_ref->{$canon_tagid}{count}
					)
					. "</p>"
					. display_nutrition_table($categories_nutriments_ref->{$canon_tagid}, undef);
			}
		}

		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} eq '-')) {
			$products_title = sprintf(lang($tagtype . '_without_products'), $products_title);
		}
		else {
			$products_title = sprintf(lang($tagtype . '_products'), $products_title);
		}

		if (defined $tagid2) {
			$products_title .= lang("title_separator");
			if ((defined $request_ref->{tag2_prefix}) and ($request_ref->{tag2_prefix} eq '-')) {
				$products_title .= sprintf(lang($tagtype2 . '_without_products'), $display_tag2);
			}
			else {
				$products_title .= sprintf(lang($tagtype2 . '_products'), $display_tag2);
			}
		}

		if (not defined $request_ref->{groupby_tagtype}) {

			# Pass template data to generate navigation links
			# These are variables that ae used to inject data
			# Used in tag.tt.html
			#-------------------------------------------------------
			# Results of these variables based for category/en:snacks
			#---- tagtype would return-> categories -----
			#---- tagtype_path would return-> /categories -----
			#---- tagtype_name would return-> category -----
			#---- tagid would return-> en:snacks -----
			#---- tagid_path would return-> /category/snacks -----
			#---- tag_name would return-> Snacks -----

			$tag_template_data_ref->{tagtype} = $tagtype;
			$tag_template_data_ref->{tagtype_path} = '/' . $tag_type_plural{$tagtype}{$lc};
			$tag_template_data_ref->{tagtype_name} = lang($tagtype . '_s');
			$tag_template_data_ref->{tagid} = $tagid;
			$tag_template_data_ref->{tagid_path} = $newtagidpath;
			$tag_template_data_ref->{tag_name} = $display_tag;
			$tag_template_data_ref->{canon_tagid} = $canon_tagid // $tagid;

			if (defined $tagid2) {
				$tag_template_data_ref->{tagtype2} = $tagtype2;
				$tag_template_data_ref->{tagtype2_path} = '/' . $tag_type_plural{$tagtype2}{$lc};
				$tag_template_data_ref->{tagtype2_name} = lang($tagtype2 . '_s');
				$tag_template_data_ref->{tagid2} = $tagid2;
				$tag_template_data_ref->{tagid2_path} = $newtagid2path;
				$tag_template_data_ref->{tag2_name} = $display_tag2;
				$tag_template_data_ref->{canon_tagid2} = $canon_tagid2 // $tagid2;
			}
			else {

				# We are on the main page of the tag (not a sub-page with another tag)
				# so we display more information related to the tag

				my $tag_logo_html = display_tags_hierarchy_taxonomy($lc, $tagtype, [$canon_tagid]);

				$tag_logo_html =~ s/.*<\/a>(<br \/>)?//;    # remove link, keep only tag logo

				$tag_template_data_ref->{tag_logo} = $tag_logo_html;

				$tag_template_data_ref->{canon_url} = $request_ref->{canon_url};
				$tag_template_data_ref->{title} = $title;

				$tag_template_data_ref->{parents_and_children}
					= display_parents_and_children($lc, $tagtype, $canon_tagid);

				if ($weblinks_html ne "") {
					$tag_template_data_ref->{weblinks} = $weblinks_html;
				}

				if ($description ne "") {
					$tag_template_data_ref->{description} = $description;
				}

				# Display knowledge panels for the tag, if any

				initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
				my $tag_ref = {};    # Object to store the knowledge panels
				my $panels_created
					= create_tag_knowledge_panels($tag_ref, $lc, $cc, $knowledge_panels_options_ref, $tagtype,
					$canon_tagid);
				if ($panels_created) {
					$tag_template_data_ref->{tag_panels}
						= display_knowledge_panel($tag_ref, $tag_ref->{"knowledge_panels_" . $lc}, "root");
				}
			}

			$tag_template_data_ref->{products_title} = $products_title;
		}

	}    # end of if (defined $tagtype)

	$tag_template_data_ref->{country} = $country;
	$tag_template_data_ref->{country_code} = $cc;
	$tag_template_data_ref->{facets_kp_url} = $facets_kp_url;

	if ($country ne 'en:world') {

		my $world_link = "";
		if (defined $request_ref->{groupby_tagtype}) {
			$world_link = lang('view_list_for_products_from_the_entire_world');
		}
		else {
			$world_link = lang('view_products_from_the_entire_world');
		}

		$tag_template_data_ref->{world_link} = $world_link;
		$tag_template_data_ref->{world_link_url} = get_world_subdomain() . $request_ref->{world_current_link};

	}

	my $query_ref = {};
	my $sort_by;
	if ($tagtype eq 'users') {
		$query_ref->{creator} = $tagid;
		$sort_by = 'last_modified_t';
	}
	elsif (defined $canon_tagid) {
		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} ne '')) {
			$query_ref->{($tagtype . "_tags")} = {"\$ne" => $canon_tagid};
		}
		else {
			$query_ref->{($tagtype . "_tags")} = $canon_tagid;
		}
		$sort_by = 'last_modified_t';
	}
	elsif (defined $tagid) {
		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} ne '')) {
			$query_ref->{($tagtype . "_tags")} = {"\$ne" => $tagid};
		}
		else {
			$query_ref->{($tagtype . "_tags")} = $tagid;
		}
		$sort_by = 'last_modified_t';
	}

	# db.myCol.find({ mylist: { $ne: 'orange' } })

	# unknown / empty value
	# warning: unknown is a value for pnns_groups_1 and 2
	if (
		(
			   ($tagid eq get_string_id_for_lang($lc, lang("unknown")))
			or ($tagid eq ($lc . ":" . get_string_id_for_lang($lc, lang("unknown"))))
		)
		and ($tagtype !~ /^pnns_groups_/)
		)
	{
		#$query_ref = { ($tagtype . "_tags") => "[]"};
		$query_ref = {"\$or" => [{($tagtype) => undef}, {$tagtype => ""}]};
	}

	if (defined $tagid2) {

		my $field = $tagtype2 . "_tags";
		my $value = $tagid2;
		$sort_by = 'last_modified_t';

		if ($tagtype2 eq 'users') {
			$field = "creator";
		}

		if (defined $canon_tagid2) {
			$value = $canon_tagid2;
		}

		my $tag2_is_negative = (defined $request_ref->{tag2_prefix} and $request_ref->{tag2_prefix} eq '-') ? 1 : 0;

		$log->debug("tag2_is_negative " . $tag2_is_negative) if $log->is_debug();
		# 2 criteria on the same field?
		# we need to use the $and MongoDB syntax

		if (defined $query_ref->{$field}) {
			my $and = [{$field => $query_ref->{$field}}];
			# fix for issue #2657: negative query on tag2 was not being honored if both tag types are the same
			if ($tag2_is_negative) {
				push @{$and}, {$field => {"\$ne" => $value}};
			}
			else {
				push @{$and}, {$field => $value};
			}
			delete $query_ref->{$field};
			$query_ref->{"\$and"} = $and;
		}
		# unknown / empty value
		elsif (
			(
				   ($tagid2 eq get_string_id_for_lang($lc, lang("unknown")))
				or ($tagid2 eq ($lc . ":" . get_string_id_for_lang($lc, lang("unknown"))))
			)
			and ($tagtype2 !~ /^pnns_groups_/)
			)
		{
			$query_ref->{"\$or"} = [{($tagtype2) => undef}, {$tagtype2 => ""}];
		}
		else {
			# issue 2285: second tag was not supporting the 'minus' query
			$query_ref->{$field} = $tag2_is_negative ? {"\$ne" => $value} : $value;
		}
	}
	# Rendering Page tags
	my $tag_html;
	# TODO: is_crawl_bot should be added directly by process_template(),
	# but we would need to add a new $request_ref parameter to process_template(), will do later
	$tag_template_data_ref->{is_crawl_bot} = $request_ref->{is_crawl_bot};
	process_template('web/pages/tag/tag.tt.html', $tag_template_data_ref, \$tag_html)
		or $tag_html = "<p>tag.tt.html template error: " . $tt->error() . "</p>";

	if (defined $request_ref->{groupby_tagtype}) {
		if (defined single_param("translate")) {
			${$request_ref->{content_ref}} .= $tag_html . display_list_of_tags_translate($request_ref, $query_ref);
		}
		else {
			${$request_ref->{content_ref}} .= $tag_html . display_list_of_tags($request_ref, $query_ref);
		}
		if ($products_title ne '') {
			$request_ref->{title} .= " " . lang("for") . " " . lcfirst($products_title);
		}
		$request_ref->{title} .= lang("title_separator") . display_taxonomy_tag($lc, "countries", $country);
		$request_ref->{page_type} = "list_of_tags";
	}
	else {
		if ((defined $request_ref->{page}) and ($request_ref->{page} > 1)) {
			$request_ref->{title} = $title . lang("title_separator") . sprintf(lang("page_x"), $request_ref->{page});
		}
		else {
			$request_ref->{title} = $title;
		}

		if ($tagtype eq "brands") {
			$request_ref->{schema_org_itemtype} = "https://schema.org/Brand";
		}
		else {
			$request_ref->{schema_org_itemtype} = "https://schema.org/Thing";
		}

		# TODO: Producer

		my $search_results_html = search_and_display_products($request_ref, $query_ref, $sort_by, undef, undef);

		${$request_ref->{content_ref}} .= $tag_html . $search_results_html;
	}

	# If we have no resultings products or aggregated tags, and the tag value does not exist in the taxonomy,
	# we do not output the tag value in the page title and content
	if (
		($request_ref->{structured_response}{count} == 0)
		and (
			(
				(
					(defined $tagid)
					and (
						not(    (defined $taxonomy_fields{$tagtype})
							and (exists_taxonomy_tag($tagtype, $canon_tagid)))
					)
				)
			)
			or (
				(defined $tagid2)
				and (
					not(    (defined $taxonomy_fields{$tagtype2})
						and (exists_taxonomy_tag($tagtype2, $canon_tagid2)))
				)
			)
		)
		)
	{
		display_error_and_exit(lang("no_products"), 404);
	}
	else {
		display_page($request_ref);
	}

	return;
}

=head2 display_search_results ( $request_ref )

This function builds the HTML returned by the /search endpoint.

The results can be displayed in different ways:

1. a paginated list of products (default)
The function calls search_and_display_products() to display the paginated list of products.

2. results filtered and ranked on the client-side
2.1. according to user preferences that are locally saved on the client: &user_preferences=1
2.2. according to preferences passed in the url: &preferences=..

3. on a graph (histogram or scatter plot): &graph=1 -- TODO: not supported yet

4. on a map &map=1 -- TODO: not supported yet

=cut

sub display_search_results ($request_ref) {

	my $html = '';

	$request_ref->{title} = lang("search_results") . " - " . display_taxonomy_tag($lc, "countries", $country);

	my $current_link = '';

	foreach my $field (multi_param()) {
		if (
			   ($field eq "page")
			or ($field eq "fields")
			or ($field eq "keywords")    # returned by CGI.pm when there are not params: keywords=search
			)
		{
			next;
		}

		$current_link .= "\&$field=" . URI::Escape::XS::encodeURIComponent(decode utf8 => single_param($field));
	}

	$current_link =~ s/^\&/\?/;
	$current_link = "/search" . $current_link;

	if ((defined single_param("user_preferences")) and (single_param("user_preferences")) and not($request_ref->{api}))
	{

		# The results will be filtered and ranked on the client side

		my $search_api_url = $formatted_subdomain . "/api/v0" . $current_link;
		$search_api_url =~ s/(\&|\?)(page|page_size|limit)=(\d+)//;
		$search_api_url .= "&fields=code,product_display_name,url,image_front_small_url,attribute_groups";
		$search_api_url .= "&page_size=100";
		if ($search_api_url !~ /\?/) {
			$search_api_url =~ s/\&/\?/;
		}

		my $contributor_prefs_json = decode_utf8(
			encode_json(
				{
					display_barcode => $User{display_barcode},
					edit_link => $User{edit_link},
				}
			)
		);

		my $preferences_text = lang("classify_products_according_to_your_preferences");

		$scripts .= <<JS
<script type="text/javascript">
var page_type = "products";
var preferences_text = "$preferences_text";
var contributor_prefs = $contributor_prefs_json;
var products = [];
</script>
JS
			;

		$scripts .= <<JS
<script src="/js/product-preferences.js"></script>
<script src="/js/product-search.js"></script>
JS
			;

		$initjs .= <<JS
display_user_product_preferences("#preferences_selected", "#preferences_selection_form", function () {
	rank_and_display_products("#search_results", products, contributor_prefs);
});
search_products("#search_results", products, "$search_api_url");
JS
			;

		my $template_data_ref = {
			lang => \&lang,
			display_pagination => \&display_pagination,
		};

		if (not process_template('web/pages/search_results/search_results.tt.html', $template_data_ref, \$html)) {
			$html = $tt->error();
		}
	}
	else {

		# The server generates the search results

		my $query_ref = {};

		if (defined single_param('parent_ingredients')) {
			$html .= search_and_analyze_recipes($request_ref, $query_ref);
		}
		else {
			$html .= search_and_display_products($request_ref, $query_ref, undef, undef, undef);
		}
	}

	$request_ref->{content_ref} = \$html;
	$request_ref->{page_type} = "products";

	display_page($request_ref);

	return;
}

sub add_country_and_owner_filters_to_query ($request_ref, $query_ref) {

	delete $query_ref->{lc};

	# Country filter

	if (defined $country) {

		# Do not add a country restriction if the query specifies a list of codes

		if (($country ne 'en:world') and (not defined $query_ref->{code})) {
			# we may already have a condition on countries (e.g. from the URL /country/germany )
			if (not defined $query_ref->{countries_tags}) {
				$query_ref->{countries_tags} = $country;
			}
			else {
				my $field = "countries_tags";
				my $value = $country;
				my $and;
				# we may also have a $and list of conditions (on countries_tags or other fields)
				if (defined $query_ref->{"\$and"}) {
					$and = $query_ref->{"\$and"};
				}
				else {
					$and = [];
				}
				push @{$and}, {$field => $query_ref->{$field}};
				push @{$and}, {$field => $value};
				delete $query_ref->{$field};
				$query_ref->{"\$and"} = $and;
			}
		}

	}

	# Owner filter

	# Restrict the products to the owner on databases with private products
	if (    (defined $server_options{private_products})
		and ($server_options{private_products}))
	{
		if ($Owner_id ne 'all') {    # Administrator mode to see all products
			$query_ref->{owner} = $Owner_id;
		}
	}

	$log->debug("result of add_country_and_owner_filters_to_query", {request => $request_ref, query => $query_ref})
		if $log->is_debug();

	return;
}

sub count_products ($request_ref, $query_ref, $obsolete = 0) {

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	my $count;

	eval {
		$log->debug("Counting MongoDB documents for query", {query => $query_ref}) if $log->is_debug();
		$count = execute_query(
			sub {
				return get_products_collection({obsolete => $obsolete})->count_documents($query_ref);
			}
		);
	};

	return $count;
}

=head2 get_products_collection_request_parameters ($request_ref, $additional_parameters_ref = {} )

This function looks at the request object to set parameters to pass to the get_products_collection() function.

=head3 Arguments

=head4 $request_ref request object

=head4 $additional_parameters_ref

An optional reference to a hash of parameters that should be added to the parameters extracted from the request object.

=head3 Return value

A reference to a parameters object that can be passed to get_products_collection()

=cut

sub get_products_collection_request_parameters ($request_ref, $additional_parameters_ref = {}) {

	my $parameters_ref = {};

	# If the request is for obsolete products, we will select a specific products collection
	# for obsolete products
	$parameters_ref->{obsolete} = request_param($request_ref, "obsolete");

	# Admin users can request a specific query_timeout for MongoDB queries
	if ($request_ref->{admin}) {
		$parameters_ref->{timeout} = request_param($request_ref, "timeout");
	}

	# Add / overwrite request parameters with additional parameters passed as arguments
	foreach my $parameter (keys %$additional_parameters_ref) {
		$parameters_ref->{$parameter} = $additional_parameters_ref->{$parameter};
	}

	return $parameters_ref;
}

=head2 add_params_to_query ( $request_ref, $query_ref )

This function is used to parse search query parameters that are passed
to the API (/api/v?/search endpoint) or to the web site search (/search endpoint)
either as query string parameters (e.g. ?labels_tags=en:organic) or
POST parameters.

The function adds the corresponding query filters in the MongoDB query.

=head3 Parameters

=head4 $request_ref (output)

Reference to the internal request object.

=head4 $query_ref (output)

Reference to the MongoDB query object.

=cut

# Parameters that are not query filters

my %ignore_params = (
	fields => 1,
	format => 1,
	json => 1,
	jsonp => 1,
	xml => 1,
	keywords => 1,    # added by CGI.pm
	api_version => 1,
	api_action => 1,
	api_method => 1,
	search_simple => 1,
	search_terms => 1,
	userid => 1,
	password => 1,
	action => 1,
	type => 1,
	nocache => 1,
	no_cache => 1,
	no_count => 1,
);

# Parameters that can be query filters
# It is safer to use a positive list, instead of just the %ignore_params list

my %valid_params = (code => 1,);

sub add_params_to_query ($request_ref, $query_ref) {

	$log->debug("add_params_to_query", {params => {CGI::Vars()}}) if $log->is_debug();

	# nocache was renamed to no_cache
	if (defined single_param('nocache')) {
		param('no_cache', single_param('nocache'));
	}

	my $and = $query_ref->{"\$and"};

	foreach my $field (multi_param()) {

		$log->debug("add_params_to_query - field", {field => $field}) if $log->is_debug();

		# skip params that are not query filters
		next if (defined $ignore_params{$field});

		if (($field eq "page") or ($field eq "page_size")) {
			$request_ref->{$field} = single_param($field) + 0;    # Make sure we have a number
		}

		elsif ($field eq "sort_by") {
			$request_ref->{$field} = single_param($field);
		}

		# Tags fields can be passed with taxonomy ids as values (e.g labels_tags=en:organic)
		# or with values in a given language (e.g. labels_tags_fr=bio)

		elsif ($field =~ /^(.*)_tags(_(\w\w))?/) {
			my $tagtype = $1;
			my $tag_lc = $lc;
			if (defined $3) {
				$tag_lc = $3;
			}

			# Possible values:
			# xyz_tags=a
			# xyz_tags=a,b	products with tag a and b
			# xyz_tags=a|b	products with either tag a or tag b
			# xyz_tags=-c	products without the c tag
			# xyz_tags=a,b,-c,-d

			my $values = remove_tags_and_quote(decode utf8 => single_param($field));

			$log->debug("add_params_to_query - tags param",
				{field => $field, lc => $lc, tag_lc => $tag_lc, values => $values})
				if $log->is_debug();

			foreach my $tag (split(/,/, $values)) {

				my $suffix = "_tags";

				# If there is more than one criteria on the same field, we need to use a $and query
				my $remove = 0;
				if (defined $query_ref->{$tagtype . $suffix}) {
					$remove = 1;
					if (not defined $and) {
						$and = [];
					}
					push @$and, {$tagtype . $suffix => $query_ref->{$tagtype . $suffix}};
				}

				my $not;
				if ($tag =~ /^-/) {
					$not = 1;
					$tag = $';
				}

				# Multiple values separated by |
				if ($tag =~ /\|/) {
					my @tagids = ();
					foreach my $tag2 (split(/\|/, $tag)) {
						my $tagid2;
						if (defined $taxonomy_fields{$tagtype}) {
							$tagid2 = get_taxonomyid($tag_lc, canonicalize_taxonomy_tag($tag_lc, $tagtype, $tag2));
							if ($tagtype eq 'additives') {
								$tagid2 =~ s/-.*//;
							}
						}
						else {
							$tagid2 = get_string_id_for_lang("no_language", canonicalize_tag2($tagtype, $tag2));
						}
						push @tagids, $tagid2;
					}

					$log->debug(
						"add_params_to_query - tags param - multiple values (OR) separated by | ",
						{field => $field, lc => $lc, tag_lc => $tag_lc, tag => $tag, tagids => \@tagids}
					) if $log->is_debug();

					if ($not) {
						$query_ref->{$tagtype . $suffix} = {'$nin' => \@tagids};
					}
					else {
						$query_ref->{$tagtype . $suffix} = {'$in' => \@tagids};
					}
				}
				# Single value
				else {
					my $tagid;
					if (defined $taxonomy_fields{$tagtype}) {
						$tagid = get_taxonomyid($tag_lc, canonicalize_taxonomy_tag($tag_lc, $tagtype, $tag));
						if ($tagtype eq 'additives') {
							$tagid =~ s/-.*//;
						}
					}
					else {
						$tagid = get_string_id_for_lang("no_language", canonicalize_tag2($tagtype, $tag));
					}
					$log->debug("add_params_to_query - tags param - single value",
						{field => $field, lc => $lc, tag_lc => $tag_lc, tag => $tag, tagid => $tagid})
						if $log->is_debug();

					if ($not) {
						$query_ref->{$tagtype . $suffix} = {'$ne' => $tagid};
					}
					else {
						$query_ref->{$tagtype . $suffix} = $tagid;
					}
				}

				if ($remove) {
					push @$and, {$tagtype . $suffix => $query_ref->{$tagtype . $suffix}};
					delete $query_ref->{$tagtype . $suffix};
					$query_ref->{"\$and"} = $and;
				}
			}
		}

		# Conditions on nutrients

		# e.g. saturated-fat_prepared_serving=<3=0
		# the parameter name is exactly the same as the key in the nutriments hash of the product

		elsif ($field =~ /^(.*?)_(100g|serving)$/) {

			# We can have multiple conditions, separated with a comma
			# e.g. sugars_100g=>10,<=20

			my $conditions = single_param($field);

			$log->debug("add_params_to_query - nutrient conditions", {field => $field, conditions => $conditions})
				if $log->is_debug();

			foreach my $condition (split(/,/, $conditions)) {

				# the field value is a number, possibly preceded by <, >, <= or >=

				my $operator;
				my $value;

				if ($condition =~ /^(<|>|<=|>=)(\d.*)$/) {
					$operator = $1;
					$value = $2;
				}
				else {
					$operator = '=';
					$value = single_param($field);
				}

				$log->debug("add_params_to_query - nutrient condition",
					{field => $field, condition => $condition, operator => $operator, value => $value})
					if $log->is_debug();

				my %mongo_operators = (
					'<' => 'lt',
					'<=' => 'lte',
					'>' => 'gt',
					'>=' => 'gte',
				);

				if ($operator eq '=') {
					$query_ref->{"nutriments." . $field}
						= $value + 0.0;    # + 0.0 to force scalar to be treated as a number
				}
				else {
					if (not defined $query_ref->{$field}) {
						$query_ref->{"nutriments." . $field} = {};
					}
					$query_ref->{"nutriments." . $field}{'$' . $mongo_operators{$operator}} = $value + 0.0;
				}
			}
		}

		# Exact match on a specific field (e.g. "code")
		elsif (defined $valid_params{$field}) {

			my $values = remove_tags_and_quote(decode utf8 => single_param($field));

			# Possible values:
			# xyz=a
			# xyz=a|b xyz=a,b xyz=a+b	products with either xyz a or xyz b

			if ($values =~ /\||\+|,/) {
				# Multiple values: construct a MongoDB $in query
				my @values = split(/\||\+|,/, $values);
				if ($field eq "code") {
					# normalize barcodes: add missing leading 0s
					$query_ref->{$field} = {'$in' => [map {normalize_code($_)} @values]};
				}
				else {
					$query_ref->{$field} = {'$in' => \@values};
				}
			}
			else {
				# Single value
				if ($field eq "code") {
					$query_ref->{$field} = normalize_code($values);
				}
				else {
					$query_ref->{$field} = $values;
				}
			}
		}
	}
	return;
}

=head2 search_and_display_products ($request_ref, $query_ref, $sort_by, $limit, $page)

Search products and return an HTML snippet that should be included in the webpage.

=head3 Parameters

=head4 $request_ref

Reference to the internal request object.

=head4 $query_ref

Reference to the MongoDB query object.

=head4 $sort_by

A string indicating how to sort results (created_t, popularity,...), or a sorting subroutine.

=head4 $limit

Limit of the number of products to return.

=head4 $page

Requested page (first page starts at 1).

=cut

sub search_and_display_products ($request_ref, $query_ref, $sort_by, $limit, $page) {

	$request_ref->{page_type} = "products";

	# Flag that indicates whether we cache MongoDB results in Memcached
	# Caching is disabled for crawling bots, as they tend to explore
	# all pages (and make caching inefficient)
	my $cache_results_flag = scalar(not $request_ref->{is_crawl_bot});
	my $template_data_ref = {};

	add_params_to_query($request_ref, $query_ref);

	$log->debug("search_and_display_products",
		{request_ref => $request_ref, query_ref => $query_ref, sort_by => $sort_by})
		if $log->is_debug();

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	if (defined $limit) {
	}
	elsif (defined $request_ref->{page_size}) {
		$limit = $request_ref->{page_size};
	}
	# If user preferences are turned on, return 100 products per page
	elsif ((not defined $request_ref->{api}) and ($request_ref->{user_preferences})) {
		$limit = 100;
	}
	else {
		$limit = $page_size;
	}

	my $skip = 0;
	if (defined $page) {
		$skip = ($page - 1) * $limit;
	}
	elsif (defined $request_ref->{page}) {
		$page = $request_ref->{page};
		$skip = ($page - 1) * $limit;
	}
	else {
		$page = 1;
	}

	# support for returning structured results in json / xml etc.

	my $sort_ref = Tie::IxHash->new();

	# Use the sort order provided by the query if it is defined (overrides default sort order)
	# e.g. ?sort_by=popularity
	if (defined $request_ref->{sort_by}) {
		$sort_by = $request_ref->{sort_by};
		$log->debug("sort_by was passed through request_ref", {sort_by => $sort_by}) if $log->is_debug();
	}
	# otherwise use the sort order from the last_sort_by cookie
	elsif (defined cookie('last_sort_by')) {
		$sort_by = cookie('last_sort_by');
		$log->debug("sort_by was passed through last_sort_by cookie", {sort_by => $sort_by}) if $log->is_debug();
	}
	elsif (defined $sort_by) {
		$log->debug("sort_by was passed as a function parameter", {sort_by => $sort_by}) if $log->is_debug();
	}

	if (
		(not defined $sort_by)
		or (    ($sort_by ne 'created_t')
			and ($sort_by ne 'last_modified_t')
			and ($sort_by ne 'last_modified_t_complete_first')
			and ($sort_by ne 'scans_n')
			and ($sort_by ne 'unique_scans_n')
			and ($sort_by ne 'product_name')
			and ($sort_by ne 'completeness')
			and ($sort_by ne 'popularity_key')
			and ($sort_by ne 'popularity')
			and ($sort_by ne 'nutriscore_score')
			and ($sort_by ne 'nova_score')
			and ($sort_by ne 'ecoscore_score')
			and ($sort_by ne 'nothing'))
		)
	{

		if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
			$sort_by = 'popularity_key';
		}
		else {
			$sort_by = 'last_modified_t';
		}
	}

	if ((defined $sort_by) and ($sort_by ne "nothing")) {
		my $order = 1;
		my $sort_by_key = $sort_by;

		if ($sort_by eq 'last_modified_t_complete_first') {
			# replace last_modified_t_complete_first (used on front page of a country) by popularity
			$sort_by = 'popularity';
			$sort_by_key = "popularity_key";
			$order = -1;
		}
		elsif ($sort_by eq "popularity") {
			$sort_by_key = "popularity_key";
			$order = -1;
		}
		elsif ($sort_by eq "popularity_key") {
			$order = -1;
		}
		elsif ($sort_by eq "ecoscore_score") {
			$order = -1;
		}
		elsif ($sort_by eq "nutriscore_score") {
			$sort_by_key = "nutriscore_score_opposite";
			$order = -1;
		}
		elsif ($sort_by eq "nova_score") {
			$sort_by_key = "nova_score_opposite";
			$order = -1;
		}
		elsif ($sort_by =~ /^((.*)_t)_complete_first/) {
			$order = -1;
		}
		elsif ($sort_by =~ /_t/) {
			$order = -1;
		}
		elsif ($sort_by =~ /scans_n/) {
			$order = -1;
		}

		$sort_ref->Push($sort_by_key => $order);
	}

	# Sort options

	$template_data_ref->{sort_options} = [];

	# Nutri-Score and Eco-Score are only for food products
	# and currently scan data is only loaded for Open Food Facts
	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {

		push @{$template_data_ref->{sort_options}},
			{
			value => "popularity",
			link => $request_ref->{current_link} . "?sort_by=popularity",
			name => lang("sort_by_popularity")
			};
		push @{$template_data_ref->{sort_options}},
			{
			value => "nutriscore_score",
			link => $request_ref->{current_link} . "?sort_by=nutriscore_score",
			name => lang("sort_by_nutriscore_score")
			};

		# Show Eco-score sort only for some countries, or for moderators
		if ($show_ecoscore) {
			push @{$template_data_ref->{sort_options}},
				{
				value => "ecoscore_score",
				link => $request_ref->{current_link} . "?sort_by=ecoscore_score",
				name => lang("sort_by_ecoscore_score")
				};
		}
	}

	push @{$template_data_ref->{sort_options}},
		{
		value => "created_t",
		link => $request_ref->{current_link} . "?sort_by=created_t",
		name => lang("sort_by_created_t")
		};
	push @{$template_data_ref->{sort_options}},
		{
		value => "last_modified_t",
		link => $request_ref->{current_link} . "?sort_by=last_modified_t",
		name => lang("sort_by_last_modified_t")
		};

	my $count;
	my $page_count = 0;

	my $fields_ref;

	# - for API (json, xml, rss,...), display all fields
	if (   single_param("json")
		or single_param("jsonp")
		or single_param("xml")
		or single_param("jqm")
		or $request_ref->{rss})
	{
		$fields_ref = {};
	}
	# - if we use user preferences, we need a lot of fields to compute product attributes: load them all
	elsif ($request_ref->{user_preferences}) {
		# we restrict the fields that are queried to MongoDB, and use the basic ones and those necessary
		# by Attributes.pm to compute attributes.
		# This list should be updated if new attributes are added.
		$fields_ref = {
			# generic fields
			"owner" => 1,    # needed on pro platform to generate the images urls
			"lc" => 1,
			"code" => 1,
			"product_name" => 1,
			"product_name_$lc" => 1,
			"generic_name" => 1,
			"generic_name_$lc" => 1,
			"abbreviated_product_name" => 1,
			"abbreviated_product_name_$lc" => 1,
			"brands" => 1,
			"images" => 1,
			"quantity" => 1,
			# fields necessary for personal search
			"additives_n" => 1,
			"allergens_tags" => 1,
			"categories_tags" => 1,
			"ecoscore_data" => 1,
			"ecoscore_grade" => 1,
			"ecoscore_score" => 1,
			"forest_footprint_data" => 1,
			"ingredients_analysis_tags" => 1,
			"ingredients_n" => 1,
			"labels_tags" => 1,
			"nova_group" => 1,
			"nutrient_levels" => 1,
			"nutriments" => 1,
			"nutriscore_data" => 1,
			"nutriscore_grade" => 1,
			"nutrition_grades" => 1,
			"traces_tags" => 1,
			"unknown_ingredients_n" => 1
		};
	}
	else {
		#for HTML, limit the fields we retrieve from MongoDB
		$fields_ref = {
			"lc" => 1,
			"code" => 1,
			"product_name" => 1,
			"product_name_$lc" => 1,
			"generic_name" => 1,
			"generic_name_$lc" => 1,
			"abbreviated_product_name" => 1,
			"abbreviated_product_name_$lc" => 1,
			"brands" => 1,
			"images" => 1,
			"quantity" => 1
		};

		# For the producer platform, we also need the owner
		if ((defined $server_options{private_products}) and ($server_options{private_products})) {
			$fields_ref->{owner} = 1;
		}
	}

	# tied hashes can't be encoded directly by JSON::PP, freeze the sort tied hash
	my $mongodb_query_ref = [
		lc => $lc,
		query => $query_ref,
		fields => $fields_ref,
		sort => freeze($sort_ref),
		limit => $limit,
		skip => $skip
	];

	my $key = generate_query_cache_key("search_products", $mongodb_query_ref);

	$log->debug("MongoDB query key - search_products", {key => $key}) if $log->is_debug();

	$request_ref->{structured_response} = get_cache_results($key, $request_ref);

	if (not defined $request_ref->{structured_response}) {

		$request_ref->{structured_response} = {
			page => $page,
			page_size => 0 + $limit,
			skip => $skip,
			products => [],
		};

		my $cursor;
		eval {
			$count = estimate_result_count($request_ref, $query_ref, $cache_results_flag);

			$log->debug("Executing MongoDB query",
				{query => $query_ref, fields => $fields_ref, sort => $sort_ref, limit => $limit, skip => $skip})
				if $log->is_debug();
			$cursor = execute_query(
				sub {
					return get_products_collection(get_products_collection_request_parameters($request_ref))
						->query($query_ref)->fields($fields_ref)->sort($sort_ref)->limit($limit)->skip($skip);
				}
			);
			$log->info("MongoDB query ok", {error => $@}) if $log->is_info();
		};
		if ($@) {
			$log->warn("MongoDB error", {error => $@}) if $log->is_warn();
		}
		else {
			$log->info("MongoDB query ok", {error => $@}) if $log->is_info();

			while (my $product_ref = $cursor->next) {
				push @{$request_ref->{structured_response}{products}}, $product_ref;
				$page_count++;
			}

			$request_ref->{structured_response}{page_count} = $page_count;

			# The page count may be higher than the count from the query service which is updated every night
			# in that case, set $count to $page_count
			# It's also possible that the count query had a timeout and that $count is 0 even though we have results
			if ($page_count > $count) {
				$count = $page_count;
			}

			$request_ref->{structured_response}{count} = $count;

			# Don't set the cache if no_count was set
			if (not single_param('no_count') and $cache_results_flag) {
				set_cache_results($key, $request_ref->{structured_response});
			}
		}
	}

	$count = $request_ref->{structured_response}{count};
	$page_count = $request_ref->{structured_response}{page_count};

	if (defined $request_ref->{description}) {
		$request_ref->{description} =~ s/<nb_products>/$count/g;
	}

	my $html = '';
	my $html_count = '';
	my $error = '';

	my $decf = get_decimal_formatter($lc);

	if (not defined $request_ref->{jqm_loadmore}) {
		if ($count < 0) {
			$error = lang("error_database");
		}
		elsif ($count == 0) {
			$error = lang("no_products");
		}
		elsif ($count == 1) {
			$html_count .= lang("1_product");
		}
		elsif ($count > 1) {
			$html_count .= sprintf(lang("n_products"), $decf->format($count));
		}
		$template_data_ref->{error} = $error;
		$template_data_ref->{html_count} = $html_count;
	}

	$template_data_ref->{jqm} = single_param("jqm");
	$template_data_ref->{country} = $country;
	$template_data_ref->{world_subdomain} = get_world_subdomain();
	$template_data_ref->{current_link} = $request_ref->{current_link};
	$template_data_ref->{sort_by} = $sort_by;

	# Query from search form: display a link back to the search form
	if (defined($request_ref->{current_link}) && $request_ref->{current_link} =~ /action=process/) {
		$template_data_ref->{current_link_query_edit} = $request_ref->{current_link};
		$template_data_ref->{current_link_query_edit} =~ s/action=process/action=display/;
	}

	$template_data_ref->{count} = $count;

	if ($count > 0) {

		# Show a download link only for search queries (and not for the home page of facets)

		if ($request_ref->{search}) {
			$request_ref->{current_link_query_download} = $request_ref->{current_link};
			if ($request_ref->{current_link} =~ /\?/) {
				$request_ref->{current_link_query_download} .= "&download=on";
			}
			else {
				$request_ref->{current_link_query_download} .= "?download=on";
			}
		}

		$template_data_ref->{current_link_query_download} = $request_ref->{current_link_query_download};
		$template_data_ref->{export_limit} = $export_limit;

		if ($log->is_debug()) {
			my $debug_log = "search - count: $count";
			defined $request_ref->{search} and $debug_log .= " - request_ref->{search}: " . $request_ref->{search};
			defined $request_ref->{tagid2} and $debug_log .= " - tagid2 " . $request_ref->{tagid2};
			$log->debug($debug_log);
		}

		if (    (not defined $request_ref->{search})
			and ($count >= 5)
			and (not defined $request_ref->{tagid2})
			and (not defined $request_ref->{product_changes_saved}))
		{
			$template_data_ref->{explore_products} = 'true';
			my $nofollow = '';
			if (defined $request_ref->{tagid}) {
				# Prevent crawlers from going too deep in facets #938:
				# Make the 2nd facet level "nofollow"
				$nofollow = ' rel="nofollow"';
			}

			my @current_drilldown_fields = @ProductOpener::Config::drilldown_fields;
			if ($country eq 'en:world') {
				unshift(@current_drilldown_fields, "countries");
			}

			foreach my $newtagtype (@current_drilldown_fields) {

				# Eco-score: currently only for moderators

				if ($newtagtype eq 'ecoscore') {
					next if not($show_ecoscore);
				}

				push @{$template_data_ref->{current_drilldown_fields}},
					{
					current_link => $request_ref->{current_link},
					tag_type_plural => $tag_type_plural{$newtagtype}{$lc},
					nofollow => $nofollow,
					tagtype => $newtagtype,
					};
			}
		}

		$template_data_ref->{separator_before_colon} = separator_before_colon($lc);
		$template_data_ref->{jqm_loadmore} = $request_ref->{jqm_loadmore};

		for my $product_ref (@{$request_ref->{structured_response}{products}}) {
			my $img_url;

			my $code = $product_ref->{code};
			my $img = display_image_thumb($product_ref, 'front');

			my $product_name = remove_tags_and_quote(product_name_brand_quantity($product_ref));

			# Prevent the quantity "750 g" to be split on two lines
			$product_name =~ s/(.*) (.*?)/$1\&nbsp;$2/;

			my $url = product_url($product_ref);
			$product_ref->{url} = $formatted_subdomain . $url;

			add_images_urls_to_product($product_ref, $lc);

			my $jqm = single_param("jqm");    # Assigning to a scalar to make sure we get a scalar

			push @{$template_data_ref->{structured_response_products}},
				{
				code => $code,
				product_name => $product_name,
				img => $img,
				jqm => $jqm,
				url => $url,
				};

			# remove some debug info
			delete $product_ref->{additives};
			delete $product_ref->{additives_prev};
			delete $product_ref->{additives_next};
		}

		# For API queries, if the request specified a value for the fields parameter, return only the fields listed
		# For non API queries with user preferences, we need to add attributes
		# For non API queries, we need to compute attributes for personal search
		my $fields;
		if ((not defined $request_ref->{api}) and ($request_ref->{user_preferences})) {
			$fields = "code,product_display_name,url,image_front_small_url,attribute_groups";
		}
		else {
			$fields = single_param('fields') || 'all';
		}

		my $customized_products_ref = [];

		for my $product_ref (@{$request_ref->{structured_response}{products}}) {

			my $customized_product_ref = customize_response_for_product($request_ref, $product_ref, $fields);

			push @{$customized_products_ref}, $customized_product_ref;
		}

		$request_ref->{structured_response}{products} = $customized_products_ref;

		# Disable nested ingredients in ingredients field (bug #2883)

		# 2021-02-25: we now store only nested ingredients, flatten them if the API is <= 1

		if ($request_ref->{api_version} <= 1) {

			for my $product_ref (@{$request_ref->{structured_response}{products}}) {
				if (defined $product_ref->{ingredients}) {

					flatten_sub_ingredients($product_ref);

					foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {
						# Delete sub-ingredients, keep only flattened ingredients
						exists $ingredient_ref->{ingredients} and delete $ingredient_ref->{ingredients};
					}
				}
			}
		}

		$template_data_ref->{request} = $request_ref;
		$template_data_ref->{page_count} = $page_count;
		$template_data_ref->{page_limit} = $limit;
		$template_data_ref->{page} = $page;
		$template_data_ref->{current_link} = $request_ref->{current_link};
		$template_data_ref->{pagination} = display_pagination($request_ref, $count, $limit, $page);
	}

	# if cc and/or lc have been overridden, change the relative paths to absolute paths using the new subdomain

	if ($subdomain ne $original_subdomain) {
		$log->debug("subdomain not equal to original_subdomain, converting relative paths to absolute paths",
			{subdomain => $subdomain, original_subdomain => $original_subdomain})
			if $log->is_debug();
		$html =~ s/(href|src)=("\/)/$1="$formatted_subdomain\//g;
	}

	if ($request_ref->{user_preferences}) {

		my $preferences_text
			= sprintf(lang("classify_the_d_products_below_according_to_your_preferences"), $page_count);

		my $products_json = '[]';

		if (defined $request_ref->{structured_response}{products}) {
			$products_json = decode_utf8(encode_json($request_ref->{structured_response}{products}));
		}

		my $contributor_prefs_json = decode_utf8(
			encode_json(
				{
					display_barcode => $User{display_barcode},
					edit_link => $User{edit_link},
				}
			)
		);

		$scripts .= <<JS
<script type="text/javascript">
var page_type = "products";
var preferences_text = "$preferences_text";
var contributor_prefs = $contributor_prefs_json;
var products = $products_json;
</script>
JS
			;

		$scripts .= <<JS
<script src="/js/product-preferences.js"></script>
<script src="/js/product-search.js"></script>
JS
			;

		$initjs .= <<JS
display_user_product_preferences("#preferences_selected", "#preferences_selection_form", function () {
	rank_and_display_products("#search_results", products, contributor_prefs);
});
rank_and_display_products("#search_results", products, contributor_prefs);
JS
			;

	}

	process_template('web/common/includes/list_of_products.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();
	return $html;
}

sub estimate_result_count ($request_ref, $query_ref, $cache_results_flag) {
	my $count;
	my $err;

	$log->debug("Counting MongoDB documents for query", {query => $query_ref}) if $log->is_debug();
	# test if query_ref is empty
	if (single_param('no_count')) {
		# Skip the count if it is not needed
		# e.g. for some API queries
		$log->debug("no_count is set, skipping count") if $log->is_debug();
	}
	elsif (keys %{$query_ref} > 0) {
		#check if count results is in cache
		my $key_count = generate_query_cache_key("search_products_count", $query_ref);
		$log->debug("MongoDB query key - search_products_count", {key => $key_count}) if $log->is_debug();
		$count = get_cache_results($key_count, $request_ref);
		if (not defined $count) {

			$log->debug("count not in cache for query", {key => $key_count}) if $log->is_debug();

			# Count queries are very expensive, if possible, execute them on the postgres cache
			if (can_use_query_cache()) {
				$count = execute_count_tags_query($query_ref);
			}

			if (not defined $count) {
				$count = execute_query(
					sub {
						$log->debug("count_documents on complete products collection", {key => $key_count})
							if $log->is_debug();
						return get_products_collection(get_products_collection_request_parameters($request_ref))
							->count_documents($query_ref);
					}
				);
				$err = $@;
				if ($err) {
					$log->warn("MongoDB error during count", {error => $err}) if $log->is_warn();
				}
			}

			if ((defined $count) and $cache_results_flag) {
				$log->debug("count query complete, setting cache", {key => $key_count, count => $count})
					if $log->is_debug();
				set_cache_results($key_count, $count);
			}
		}
		else {
			# Cached result
			$log->debug("count in cache for query", {key => $key_count, count => $count})
				if $log->is_debug();
		}
	}
	else {
		# if query_ref is empty (root URL world.openfoodfacts.org) use estimated_document_count for better performance
		$count = execute_query(
			sub {
				$log->debug("empty query_ref, use estimated_document_count fot better performance", {})
					if $log->is_debug();
				return get_products_collection(get_products_collection_request_parameters($request_ref))
					->estimated_document_count();
			}
		);
		$err = $@;
	}
	$log->info("Count query done", {error => $err, count => $count}) if $log->is_info();

	return $count;
}

=head2 display_pagination( $request_ref , $count , $limit , $page )

This function is used for page navigation and gets called when there is more
than one page of products.  The URL can be different, either page=<number> , or
/<number> . page=<number> is used for search queries. /<number> is used for
facets.

=cut

sub display_pagination ($request_ref, $count, $limit, $page) {

	my $html = '';
	my $html_pages = '';

	my $nb_pages = int(($count - 1) / $limit) + 1;

	my $current_link = $request_ref->{current_link};
	if (not defined $current_link) {
		$current_link = $request_ref->{world_current_link};
	}

	$log->info("current link", {current_link => $current_link}) if $log->is_info();

	if (single_param("jqm")) {
		$current_link .= "&jqm=1";
	}

	my $next_page_url;

	# To avoid robots to query and index too many pages,
	# make links to subsequent pages nofollow for list of tags (not lists of products)
	my $nofollow = '';
	if (defined $request_ref->{groupby_tagtype}) {
		$nofollow = ' nofollow';
	}

	if ((($nb_pages > 1) and (defined $current_link)) and (not defined $request_ref->{product_changes_saved})) {

		my $prev = '';
		my $next = '';
		my $skip = 0;

		for (my $i = 1; $i <= $nb_pages; $i++) {
			if ($i == $page) {
				$html_pages .= '<li class="current"><a href="">' . $i . '</a></li>';
				$skip = 0;
			}
			else {

				# do not show 5425423 pages...

				if (($i > 3) and ($i <= $nb_pages - 3) and (($i > $page + 3) or ($i < $page - 3))) {
					$html_pages .= "<unavailable>";
				}
				else {

					my $link;

					if ($current_link !~ /\?/) {
						$link = $current_link;
						#check if groupby_tag is used
						if (defined $request_ref->{groupby_tagtype}) {
							if (("/" . $request_ref->{groupby_tagtype}) ne $current_link) {
								$link = $current_link . "/" . $request_ref->{groupby_tagtype};
							}
						}
						if ($i > 1) {
							$link .= "/$i";
						}
						if ($link eq '') {
							$link = "/";
						}
						if (defined $request_ref->{sort_by}) {
							$link .= "?sort_by=" . $request_ref->{sort_by};
						}
					}
					else {
						$link = $current_link . "&page=$i";

						# issue 2010: the limit, aka page_size is not persisted through the navigation links from some workflows,
						# so it is lost on subsequent pages
						if (defined $limit && $link !~ /page_size/) {
							$log->info("Using limit " . $limit) if $log->is_info();
							$link .= "&page_size=" . $limit;
						}
						if (defined $request_ref->{sort_by}) {
							$link .= "&sort_by=" . $request_ref->{sort_by};
						}
					}

					$html_pages .= '<li><a href="' . $link . '">' . $i . '</a></li>';

					if ($i == $page - 1) {
						$prev = '<li><a href="' . $link . '" rel="prev$nofollow">' . lang("previous") . '</a></li>';
					}
					elsif ($i == $page + 1) {
						$next = '<li><a href="' . $link . '" rel="next$nofollow">' . lang("next") . '</a></li>';
						$next_page_url = $link;
					}
				}
			}
		}

		$html_pages =~ s/(<unavailable>)+/<li class="unavailable">&hellip;<\/li>/g;

		$html_pages
			= '<ul id="pages" class="pagination">'
			. "<li class=\"unavailable\">"
			. lang("pages") . "</li>"
			. $prev
			. $html_pages
			. $next
			. "<li class=\"unavailable\">("
			. sprintf(lang("d_products_per_page"), $limit)
			. ")</li>"
			. "</ul>\n";
	}

	# Close the list

	if (defined single_param("jqm")) {
		if (defined $next_page_url) {
			my $loadmore = lang("loadmore");
			$html .= <<HTML
<li id="loadmore" style="text-align:center"><a href="${formatted_subdomain}/${next_page_url}&jqm_loadmore=1" id="loadmorelink">$loadmore</a></li>
HTML
				;
		}
		else {
			$html .= '<br><br>';
		}
	}

	if (not defined $request_ref->{jqm_loadmore}) {
		$html .= "</ul>\n";
	}

	if (not defined single_param("jqm")) {
		$html .= $html_pages;
	}
	return $html;
}

sub search_and_export_products ($request_ref, $query_ref, $sort_by) {

	my $format = "csv";
	if ((defined $request_ref->{format}) and ($request_ref->{format} eq "xlsx")) {
		$format = $request_ref->{format};
	}

	add_params_to_query($request_ref, $query_ref);

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	$log->debug("search_and_export_products - MongoDB query", {format => $format, query => $query_ref})
		if $log->is_debug();

	my $max_count = $export_limit;

	# Allow admins to change the export limit
	if (($admin) and (defined single_param("export_limit"))) {
		$max_count = single_param("export_limit");
	}

	my $args_ref = {
		cc => $cc,    # used to localize Eco-Score fields
		format => $format,
		filehandle => \*STDOUT,
		filename => "openfoodfacts_export." . $format,
		send_http_headers => 1,
		query => $query_ref,
		max_count => $max_count,
		export_computed_fields => 1,
		export_canonicalized_tags_fields => 1,
	};

	# Extra parameters
	foreach my $parameter (qw(fields extra_fields separator)) {
		if (defined $request_ref->{$parameter}) {
			$args_ref->{$parameter} = $request_ref->{$parameter};
		}
	}

	my $count = export_csv($args_ref);

	my $html = '';

	if ((not defined $count) or ($count < 0)) {
		$html .= "<p>" . lang("error_database") . "</p>";
	}
	elsif ($count == 0) {
		$html .= "<p>" . lang("no_products") . "</p>";
	}
	elsif ($count > $max_count) {
		$html .= "<p>" . sprintf(lang("error_too_many_products_to_export"), $count, $export_limit) . "</p>";
	}
	else {
		# export_csv has already output HTTP headers and the export file, we can return
		return;
	}

	# Display an error message

	$html .= search_permalink($request_ref);

	$request_ref->{title} = lang("search_results");
	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
	return;
}

sub escape_single_quote ($s) {

	# some app escape single quotes already, so we have \' already
	if (not defined $s) {
		return '';
	}
	$s =~ s/\\'/'/g;
	$s =~ s/'/\\'/g;
	$s =~ s/\n/ /g;
	return $s;
}

@search_series = (qw/organic fairtrade with_sweeteners default/);

my %search_series_colors = (
	default => {r => 0, g => 0, b => 255},
	organic => {r => 0, g => 212, b => 0},
	fairtrade => {r => 255, g => 102, b => 0},
	with_sweeteners => {r => 0, g => 204, b => 255},
);

my %nutrition_grades_colors = (
	a => {r => 0, g => 255, b => 0},
	b => {r => 255, g => 255, b => 0},
	c => {r => 255, g => 102, b => 0},
	d => {r => 255, g => 1, b => 128},
	e => {r => 255, g => 0, b => 0},
	unknown => {r => 128, g => 128, b => 128},
);

# Return the path (list of nodes) to the search field

# field name from the search form
# it can be:
# - a nutrient id like "saturated-fat"
# - a direct field like ingredients_n
# - an indirect field like packagings_materials.all.weight_100g

sub get_search_field_path_components ($field) {
	my @fields;
	# direct fields
	if (($field =~ /_n$/) or ($field eq "product_quantity") or ($field eq "nova_group") or ($field eq "ecoscore_score"))
	{
		@fields = ($field);
	}
	# indirect fields separated with the . character
	elsif ($field =~ /\./) {
		@fields = split(/\./, $field);
	}
	# forest footprint
	elsif ($field eq "forest_footprint") {
		@fields = ('forest_footprint_data', 'footprint_per_kg');
	}
	# we assume other fields are nutrients ids
	else {
		@fields = ("nutriments", $field . "_100g");
	}
	return @fields;
}

sub get_search_field_title_and_details ($field) {

	my ($title, $unit, $unit2, $allow_decimals) = ('', '', '', '');

	if ($field eq 'additives_n') {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote(lang("number_of_additives"));
	}
	elsif ($field eq "forest_footprint") {
		$allow_decimals = "allowDecimals:true,\n";
		$title = escape_single_quote(lang($field));
	}
	elsif ($field =~ /_n$/) {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote(lang($field . "_s"));
	}
	elsif ($field eq "product_quantity") {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote(lang("quantity"));
		$unit = ' (g)';
		$unit2 = 'g';
	}
	elsif ($field eq "nova_group") {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote(lang("nova_groups_s"));
	}
	elsif ($field eq "ecoscore_score") {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote(lang("ecoscore_score"));
	}
	elsif ($field =~ /^packagings_materials\.([^.]+)\.([^.]+)$/) {
		my $material = $1;
		my $subfield = $2;
		$title = lang("packaging") . " - ";
		if ($material eq "all") {
			$title .= lang("packagings_materials_all");
		}
		else {
			$title .= display_taxonomy_tag($lc, "packaging_materials", $material);
		}
		$title .= ' - ' . lang($subfield);
		if ($subfield =~ /_percent$/) {
			$unit = ' %';
			$unit2 = '%';
		}
		elsif ($subfield =~ /_100g$/) {
			$unit = ' (g/100g)';
			$unit2 = 'g/100g';
		}
		else {
			$unit = ' (g)';
			$unit2 = 'g';
		}
	}
	else {
		$title = display_taxonomy_tag($lc, "nutrients", "zz:" . $field);
		$unit2 = $title;    # displayed in the tooltip
		$unit
			= " ("
			. (get_property("nutrients", "zz:" . $field, "unit:en") // 'g') . " "
			. lang("nutrition_data_per_100g") . ")";
		$unit =~ s/\&nbsp;/ /g;
	}

	return ($title, $unit, $unit2, $allow_decimals);
}

=head2 display_scatter_plot ($graph_ref, $products_ref)

Called by search_and_graph_products() to display a scatter plot of products on 2 axis

=head3 Arguments

=head4 $graph_ref

Options for the graph, set by /cgi/search.pl

=head4 $products_ref

List of search results from search_and_graph_products()

=cut

sub display_scatter_plot ($graph_ref, $products_ref) {

	my @products = @{$products_ref};
	my $count = scalar @products;

	my $html = '';

	my %axis_details = ();
	my %min = ();    # Minimum for the axis, 0 except -15 for Nutri-Score score
	my %fields = ();    # fields path components for each axis, to use with deep_get()

	foreach my $axis ("x", "y") {
		# Set the titles and details of each axis
		my $field = $graph_ref->{"axis_" . $axis};
		my ($title, $unit, $unit2, $allow_decimals) = get_search_field_title_and_details($field);
		$axis_details{$axis} = {
			title => $title,
			unit => $unit,
			unit2 => $unit2,
			allow_decimals => $allow_decimals,
		};

		# Set the minimum value for the axis (0 in most cases, except for Nutri-Score)
		$min{$axis} = 0;

		if ($field =~ /^nutrition-score/) {
			$min{$axis} = -15;
		}

		# Store the field path components
		$fields{$field} = [get_search_field_path_components($field)];
	}

	my %nutriments = ();

	my $i = 0;

	my %series = ();
	my %series_n = ();

	foreach my $product_ref (@products) {

		# Gather the data for the 2 axis

		my %data;

		foreach my $axis ('x', 'y') {

			my $field = $graph_ref->{"axis_" . $axis};
			my $value = deep_get($product_ref, @{$fields{$field}});

			# For nutrients except energy-kcal, convert to the default nutrient unit
			if ((defined $value) and ($fields{$field}[0] eq "nutriments") and ($field !~ /energy-kcal/)) {
				$value = g_to_unit($value, (get_property("nutrients", "zz:$field", "unit:en") // 'g'));
			}

			if (defined $value) {
				$value = $value + 0;    # Make sure the value is a number
			}

			$data{$axis} = $value;
		}

		# Keep only products that have known values for both x and y
		if ((not defined $data{x}) or (not defined $data{y})) {
			$log->debug("Skipping product with unknown values ", {data => \%data}) if $log->is_debug();
			next;
		}

		# Add values to stats, and set min axis
		foreach my $axis ('x', 'y') {
			my $field = $graph_ref->{"axis_" . $axis};
			add_product_nutriment_to_stats(\%nutriments, $field, $data{$axis});
		}

		# Identify the series id
		my $seriesid = 0;
		# series value, we start high for first series
		# and second series value will have s / 10, etc.
		my $s = 1000000;

		# default, organic, fairtrade, with_sweeteners
		# order: organic, organic+fairtrade, organic+fairtrade+sweeteners, organic+sweeteners, fairtrade, fairtrade + sweeteners
		#

		# Colors for nutrition grades
		if ($graph_ref->{"series_nutrition_grades"}) {
			if (defined $product_ref->{"nutrition_grade_fr"}) {
				$seriesid = $product_ref->{"nutrition_grade_fr"};
			}
			else {
				$seriesid = 'unknown';
			}
		}
		else {
			# Colors for labels and labels combinations
			foreach my $series (@search_series) {
				# Label?
				if ($graph_ref->{"series_$series"}) {
					if (defined lang("search_series_${series}_label")) {
						if (has_tag($product_ref, "labels", 'en:' . lc($Lang{"search_series_${series}_label"}{en}))) {
							$seriesid += $s;
						}
						else {
						}
					}

					if ($product_ref->{$series}) {
						$seriesid += $s;
					}
				}

				if (($series eq 'default') and ($seriesid == 0)) {
					$seriesid += $s;
				}
				$s = $s / 10;
			}
		}

		$series{$seriesid} = $series{$seriesid} // '';

		$data{product_name} = $product_ref->{product_name};
		$data{url} = $formatted_subdomain . product_url($product_ref->{code});
		$data{img} = display_image_thumb($product_ref, 'front');

		# create data entry for series
		defined $series{$seriesid} or $series{$seriesid} = '';
		$series{$seriesid} .= JSON::PP->new->encode(\%data) . ',';
		# count entries / series
		defined $series_n{$seriesid} or $series_n{$seriesid} = 0;
		$series_n{$seriesid}++;
		$i++;

	}

	my $series_data = '';
	my $legend_title = '';

	# Colors for nutrition grades
	if ($graph_ref->{"series_nutrition_grades"}) {

		my $title_text = lang("nutrition_grades_p");
		$legend_title = <<JS
title: {
style: {"text-align" : "center"},
text: "$title_text"
},
JS
			;

		foreach my $nutrition_grade ('a', 'b', 'c', 'd', 'e', 'unknown') {
			my $title = uc($nutrition_grade);
			if ($nutrition_grade eq 'unknown') {
				$title = ucfirst(lang("unknown"));
			}
			my $r = $nutrition_grades_colors{$nutrition_grade}{r};
			my $g = $nutrition_grades_colors{$nutrition_grade}{g};
			my $b = $nutrition_grades_colors{$nutrition_grade}{b};
			my $seriesid = $nutrition_grade;
			$series_n{$seriesid} //= 0;
			$series_data .= <<JS
{
	name: '$title : $series_n{$seriesid} $Lang{products}{$lc}',
	color: 'rgba($r, $g, $b, .9)',
	turboThreshold : 0,
	data: [ $series{$seriesid} ]
},
JS
				;
		}

	}
	else {
		# Colors for labels and labels combinations
		foreach my $seriesid (sort {$b <=> $a} keys %series) {
			$series{$seriesid} =~ s/,\n$//;

			# Compute the name and color

			my $remainingseriesid = $seriesid;
			my $matching_series = 0;
			my ($r, $g, $b) = (0, 0, 0);
			my $title = '';
			my $s = 1000000;
			foreach my $series (@search_series) {

				if ($remainingseriesid >= $s) {
					$title ne '' and $title .= ', ';
					$title .= lang("search_series_${series}");
					$r += $search_series_colors{$series}{r};
					$g += $search_series_colors{$series}{g};
					$b += $search_series_colors{$series}{b};
					$matching_series++;
					$remainingseriesid -= $s;
				}

				$s = $s / 10;
			}

			$log->debug(
				"rendering series colour as JavaScript",
				{
					seriesid => $seriesid,
					matching_series => $matching_series,
					s => $s,
					remainingseriesid => $remainingseriesid,
					title => $title
				}
			) if $log->is_debug();

			$r = int($r / $matching_series);
			$g = int($g / $matching_series);
			$b = int($b / $matching_series);    ## no critic (RequireLocalizedPunctuationVars)

			$series_data .= <<JS
{
	name: '$title : $series_n{$seriesid} $Lang{products}{$lc}',
	color: 'rgba($r, $g, $b, .9)',
	turboThreshold : 0,
	data: [ $series{$seriesid} ]
},
JS
				;
		}
	}
	$series_data =~ s/,\n$//;

	my $legend_enabled = 'false';
	if (scalar keys %series > 1) {
		$legend_enabled = 'true';
	}

	my $sep = separator_before_colon($lc);

	my $js = <<JS
        chart = new Highcharts.Chart({
            chart: {
                renderTo: 'container',
                type: 'scatter',
                zoomType: 'xy'
            },
			legend: {
				$legend_title
				enabled: $legend_enabled
			},
            title: {
                text: '$graph_ref->{graph_title}'
            },
            subtitle: {
                text: '$Lang{data_source}{$lc}$sep: $formatted_subdomain'
            },
            xAxis: {
				$axis_details{x}{allow_decimals}
				min:$min{x},
                title: {
                    enabled: true,
                    text: '$axis_details{x}{title}$axis_details{x}{unit}'
                },
                startOnTick: true,
                endOnTick: true,
                showLastLabel: true
            },
            yAxis: {
				$axis_details{y}{allow_decimals}
				min:$min{y},
                title: {
                    text: '$axis_details{y}{title}$axis_details{y}{unit}'
                }
            },
            tooltip: {
				useHTML: true,
				followPointer : false,
				stickOnContact: true,
				formatter: function() {
                    return '<a href="' + this.point.url + '">' + this.point.product_name + '<br>'
						+ this.point.img + '</a><br>'
						+ '$Lang{nutrition_data_per_100g}{$lc} :'
						+ '<br>$axis_details{x}{title}$sep: '+ this.x + ' $axis_details{x}{unit2}'
						+ '<br>$axis_details{y}{title}$sep: ' + this.y + ' $axis_details{y}{unit2}';
                }
			},

            plotOptions: {
                scatter: {
                    marker: {
                        radius: 5,
						symbol: 'circle',
                        states: {
                            hover: {
                                enabled: true,
                                lineColor: 'rgb(100,100,100)'
                            }
                        }
                    },
					tooltip : { followPointer : false, stickOnContact: true },
                    states: {
                        hover: {
                            marker: {
                                enabled: false
                            }
                        }
                    }
                }
            },
			series: [
				$series_data
			]
        });
JS
		;
	$initjs .= $js;

	my $count_string = sprintf(lang("graph_count"), $count, $i);

	$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/dist/highcharts.js"></script>
SCRIPTS
		;

	$html .= <<HTML
<p>$count_string</p>
<div id="container" style="height: 400px"></div>

HTML
		;

	# Display stats

	my $stats_ref = {};

	compute_stats_for_products($stats_ref, \%nutriments, $count, $i, 5, 'search');

	$html .= display_nutrition_table($stats_ref, undef);

	$html .= "<p>&nbsp;</p>";

	return $html;

}

=head2 display_histogram ($graph_ref, $products_ref)

Called by search_and_graph_products() to display an histogram of products on 1 axis

=head3 Arguments

=head4 $graph_ref

Options for the graph, set by /cgi/search.pl

=head4 $products_ref

List of search results from search_and_graph_products()

=cut

sub display_histogram ($graph_ref, $products_ref) {

	my @products = @{$products_ref};
	my $count = @products;

	my $html = '';

	my %axis_details = ();
	my %min = ();    # Minimum for the axis, 0 except -15 for Nutri-Score score

	foreach my $axis ("x") {
		# Set the titles and details of each axis
		my $field = $graph_ref->{"axis_" . $axis};
		my ($title, $unit, $unit2, $allow_decimals) = get_search_field_title_and_details($field);
		$axis_details{$axis} = {
			title => $title,
			unit => $unit,
			unit2 => $unit2,
			allow_decimals => $allow_decimals,
		};

		# Set the minimum value for the axis (0 in most cases, except for Nutri-Score)
		$min{$axis} = 0;

		if ($field =~ /^nutrition-score/) {
			$min{$axis} = -15;
		}
	}

	$axis_details{"y"} = {
		title => escape_single_quote(lang("number_of_products")),
		allow_decimals => "allowDecimals:false,\n",
		unit => '',
		unit2 => '',
	};

	my $i = 0;

	my %series = ();
	my %series_n = ();
	my @all_values = ();

	my $min = 10000000000000;
	my $max = -10000000000000;

	my $field = $graph_ref->{"axis_x"};
	my @fields = get_search_field_path_components($field);

	foreach my $product_ref (@products) {

		my $value = deep_get($product_ref, @fields);

		# For nutrients except energy-kcal, convert to the default nutrient unit
		if ((defined $value) and ($fields[0] eq "nutriments") and ($field !~ /energy-kcal/)) {
			$value = g_to_unit($value, (get_property("nutrients", "zz:$field", "unit:en") // 'g'));
		}

		# Keep only products that have known values for both x and y
		if (not defined $value) {
			next;
		}

		$value = $value + 0;    # Make sure the value is a number

		if ($value < $min) {
			$min = $value;
		}
		if ($value > $max) {
			$max = $value;
		}

		# Identify the series id
		my $seriesid = 0;
		my $s = 1000000;

		# default, organic, fairtrade, with_sweeteners
		# order: organic, organic+fairtrade, organic+fairtrade+sweeteners, organic+sweeteners, fairtrade, fairtrade + sweeteners
		#

		foreach my $series (@search_series) {
			# Label?
			if ($graph_ref->{"series_$series"}) {
				if (defined lang("search_series_${series}_label")) {
					if (has_tag($product_ref, "labels", 'en:' . lc($Lang{"search_series_${series}_label"}{en}))) {
						$seriesid += $s;
					}
					else {
					}
				}

				if ($product_ref->{$series}) {
					$seriesid += $s;
				}
			}

			if (($series eq 'default') and ($seriesid == 0)) {
				$seriesid += $s;
			}
			$s = $s / 10;
		}

		push @all_values, $value;

		defined $series{$seriesid} or $series{$seriesid} = [];
		push @{$series{$seriesid}}, $value;

		defined $series_n{$seriesid} or $series_n{$seriesid} = 0;
		$series_n{$seriesid}++;
		$i++;

	}

	# define intervals

	$max += 0.0000000001;

	my @intervals = ();
	my $intervals = 10;
	my $interval = 1;
	if (defined single_param('intervals')) {
		$intervals = single_param('intervals');
		$intervals > 0 or $intervals = 10;
	}

	if ($i == 0) {
		return "";
	}
	elsif ($i == 1) {
		push @intervals, [$min, $max, "$min"];
	}
	else {
		if (($field =~ /_n$/) or ($field =~ /^nutrition-score/)) {
			$interval = 1;
			$intervals = 0;
			for (my $j = $min; $j <= $max; $j++) {
				push @intervals, [$j, $j, $j + 0.0];
				$intervals++;
			}
		}
		else {
			$interval = ($max - $min) / 10;
			for (my $k = 0; $k < $intervals; $k++) {
				my $mink = $min + $k * $interval;
				my $maxk = $mink + $interval;
				push @intervals,
					[$mink, $maxk, '>' . (sprintf("%.2e", $mink) + 0.0) . ' <' . (sprintf("%.2e", $maxk) + 0.0)];
			}
		}
	}

	$log->debug("hisogram for all 'i' values", {i => $i, min => $min, max => $max}) if $log->is_debug();

	my %series_intervals = ();
	my $categories = '';

	for (my $k = 0; $k < $intervals; $k++) {
		$categories .= '"' . $intervals[$k][2] . '", ';
	}
	$categories =~ s/,\s*$//;

	foreach my $seriesid (keys %series) {
		$series_intervals{$seriesid} = [];
		for (my $k = 0; $k < $intervals; $k++) {
			$series_intervals{$seriesid}[$k] = 0;
			$log->debug("computing histogram", {k => $k, min => $intervals[$k][0], max => $intervals[$k][1]})
				if $log->is_debug();
		}
		foreach my $value (@{$series{$seriesid}}) {
			for (my $k = 0; $k < $intervals; $k++) {
				if (   ($value >= $intervals[$k][0]) and (($value < $intervals[$k][1]))
					or (($intervals[$k][1] == $intervals[$k][0])) and ($value == $intervals[$k][1]))
				{
					$series_intervals{$seriesid}[$k]++;
				}
			}
		}
	}

	my $series_data = '';

	foreach my $seriesid (sort {$b <=> $a} keys %series) {
		$series{$seriesid} =~ s/,\n$//;

		# Compute the name and color

		my $remainingseriesid = $seriesid;
		my $matching_series = 0;
		my ($r, $g, $b) = (0, 0, 0);
		my $title = '';
		my $s = 1000000;
		foreach my $series (@search_series) {

			if ($remainingseriesid >= $s) {
				$title ne '' and $title .= ', ';
				$title .= lang("search_series_${series}");
				$r += $search_series_colors{$series}{r};
				$g += $search_series_colors{$series}{g};
				$b += $search_series_colors{$series}{b};
				$matching_series++;
				$remainingseriesid -= $s;
			}

			$s = $s / 10;
		}

		$log->debug(
			"rendering series as JavaScript",
			{
				seriesid => $seriesid,
				matching_series => $matching_series,
				s => $s,
				remainingseriesid => $remainingseriesid,
				title => $title
			}
		) if $log->is_debug();

		$r = int($r / $matching_series);
		$g = int($g / $matching_series);
		$b = int($b / $matching_series);    ## no critic (RequireLocalizedPunctuationVars)

		$series_data .= <<JS
			{
                name: '$title',
				total: $series_n{$seriesid},
				shortname: '$title',
                color: 'rgba($r, $g, $b, .9)',
				turboThreshold : 0,
                data: [
JS
			;
		$series_data .= join(',', @{$series_intervals{$seriesid}});

		$series_data .= <<JS
				]
            },
JS
			;
	}
	$series_data =~ s/,\n$//;

	my $legend_enabled = 'false';
	if (scalar keys %series > 1) {
		$legend_enabled = 'true';
	}

	my $sep = separator_before_colon($lc);

	my $js = <<JS
        chart = new Highcharts.Chart({
            chart: {
                renderTo: 'container',
                type: 'column',
            },
			legend: {
				enabled: $legend_enabled,
				labelFormatter: function() {
              return this.name + ': ' + this.options.total;
			}
			},
            title: {
                text: '$graph_ref->{graph_title}'
            },
            subtitle: {
                text: '$Lang{data_source}{$lc}$sep: $formatted_subdomain'
            },
            xAxis: {
                title: {
                    enabled: true,
                    text: '$axis_details{x}{title}$axis_details{x}{unit}'
                },
				categories: [
					$categories
				]
            },
            yAxis: {

				$axis_details{y}{allow_decimals}
				min:0,
                title: {
                    text: '$axis_details{y}{title}'
                },
				stackLabels: {
                enabled: true,
                style: {
                    fontWeight: 'bold',
                    color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'
                }
            }
            },
        tooltip: {
            headerFormat: '<b>$axis_details{x}{title} {point.key}</b><br>$axis_details{x}{unit}<table>',
            pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
                '<td style="padding:0"><b>{point.y}</b></td></tr>',
            footerFormat: '</table>Total: <b>{point.total}</b>',
            shared: true,
            useHTML: true,
			formatter: function() {
            var points='<table class="tip"><caption>$axis_details{x}{title} ' + this.x + '</b><br>$axis_details{x}{unit}</caption><tbody>';
            //loop each point in this.points
            \$.each(this.points,function(i,point){
                points+='<tr><th style="color: '+point.series.color+'">'+point.series.name+': </th>'
                      + '<td style="text-align: right">'+point.y+'</td></tr>'
            });
            points+='<tr><th>Total: </th>'
            +'<td style="text-align:right"><b>'+this.points[0].total+'</b></td></tr>'
            +'</tbody></table>';
            return points;
			}

        },



            plotOptions: {
    column: {
        //pointPadding: 0,
        //borderWidth: 0,
        groupPadding: 0,
        shadow: false,
                stacking: 'normal',
                dataLabels: {
                    enabled: false,
                    color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white',
                    style: {
                        textShadow: '0 0 3px black, 0 0 3px black'
                    }
                }
    }
            },
			series: [
				$series_data
			]
        });
JS
		;
	$initjs .= $js;

	my $count_string = sprintf(lang("graph_count"), $count, $i);

	$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/dist/highcharts.js"></script>
SCRIPTS
		;

	$html .= <<HTML
<p>$count_string</p>
<div id="container" style="height: 400px"></div>
<p>&nbsp;</p>
HTML
		;

	return $html;

}

sub search_and_graph_products ($request_ref, $query_ref, $graph_ref) {

	add_params_to_query($request_ref, $query_ref);

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	my $cursor;

	$log->info("retrieving products from MongoDB to display them in a graph") if $log->is_info();

	if ($admin) {
		$log->debug("Executing MongoDB query", {query => $query_ref}) if $log->is_debug();
	}

	# Limit the fields we retrieve from MongoDB
	my $fields_ref;

	if ($graph_ref->{axis_y} ne 'products_n') {

		$fields_ref = {
			lc => 1,
			code => 1,
			product_name => 1,
			"product_name_$lc" => 1,
			labels_tags => 1,
			images => 1,
		};

		# For the producer platform, we also need the owner
		if ((defined $server_options{private_products}) and ($server_options{private_products})) {
			$fields_ref->{owner} = 1;
		}
	}

	# Add fields for the axis
	foreach my $axis ('x', 'y') {
		my $field = $graph_ref->{"axis_$axis"};
		# Get the field path components
		my @fields = get_search_field_path_components($field);
		# Convert to dot notation to get the MongoDB field
		$fields_ref->{join(".", @fields)} = 1;
	}

	if ($graph_ref->{"series_nutrition_grades"}) {
		$fields_ref->{"nutrition_grade_fr"} = 1;
	}
	elsif ((scalar keys %{$graph_ref}) > 0) {
		$fields_ref->{"labels_tags"} = 1;
	}

	eval {
		$cursor = execute_query(
			sub {
				return get_products_collection(get_products_collection_request_parameters($request_ref))
					->query($query_ref)->fields($fields_ref);
			}
		);
	};
	if ($@) {
		$log->warn("MongoDB error", {error => $@}) if $log->is_warn();
	}
	else {
		$log->info("MongoDB query ok", {error => $@}) if $log->is_info();
	}

	$log->info("retrieved products from MongoDB to display them in a graph") if $log->is_info();

	my @products = $cursor->all;
	my $count = @products;

	my $html = '';

	if ($count < 0) {
		$html .= "<p>" . lang("error_database") . "</p>";
	}
	elsif ($count == 0) {
		$html .= "<p>" . lang("no_products") . "</p>";
	}

	$html .= search_permalink($request_ref);

	if ($count <= 0) {
		# $request_ref->{content_html} = $html;
		$log->warn("could not retrieve enough products for a graph", {count => $count}) if $log->is_warn();
		return $html;
	}

	if ($count > 0) {

		$graph_ref->{graph_title} = escape_single_quote($graph_ref->{graph_title});

		# 1 axis: histogram / bar chart -> axis_y == "product_n" or is empty
		# 2 axis: scatter plot

		if (   (not defined $graph_ref->{axis_y})
			or ($graph_ref->{axis_y} eq "")
			or ($graph_ref->{axis_y} eq 'products_n'))
		{
			$html .= display_histogram($graph_ref, \@products);
		}
		else {
			$html .= display_scatter_plot($graph_ref, \@products);
		}

		if (defined $request_ref->{current_link}) {
			$request_ref->{current_link_query_display} = $request_ref->{current_link};
			$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
			$html .= "&rarr; <a href=\"$request_ref->{current_link}\">" . lang("search_graph_link") . "</a><br>";
		}

		$html .= "<p>" . lang("search_graph_warning") . "</p>";

		$html .= lang("search_graph_blog");
	}

	return $html;
}

=head2  get_packager_code_coordinates ($emb_code)

Transform a traceability code (emb code) into a latitude / longitude pair.

We try using packagers_codes taxonomy, or fsa_rating or geocode for uk,
or city.

=head3 parameters

=head4 $emb_code - string

The traceability code

=head3 returns - list of 2 elements
(latitude, longitude) if found, or (undef, undef) otherwise

=cut

sub get_packager_code_coordinates ($emb_code) {

	my $lat;
	my $lng;

	if (exists $packager_codes{$emb_code}) {
		if (exists $packager_codes{$emb_code}{lat}) {
			# some lat/lng have , for floating point numbers
			$lat = $packager_codes{$emb_code}{lat};
			$lng = $packager_codes{$emb_code}{lng};
			$lat =~ s/,/\./g;
			$lng =~ s/,/\./g;
		}
		elsif (exists $packager_codes{$emb_code}{fsa_rating_business_geo_lat}) {
			$lat = $packager_codes{$emb_code}{fsa_rating_business_geo_lat};
			$lng = $packager_codes{$emb_code}{fsa_rating_business_geo_lng};
		}
		elsif ($packager_codes{$emb_code}{cc} eq 'uk') {
			#my $address = 'uk' . '.' . $packager_codes{$emb_code}{local_authority};
			my $address = 'uk' . '.' . $packager_codes{$emb_code}{canon_local_authority};
			if (exists $geocode_addresses{$address}) {
				$lat = $geocode_addresses{$address}[0];
				$lng = $geocode_addresses{$address}[1];
			}
		}
	}

	my $city_code = get_city_code($emb_code);

	init_emb_codes() unless %emb_codes_geo;
	if (((not defined $lat) or (not defined $lng)) and (defined $emb_codes_geo{$city_code})) {

		# some lat/lng have , for floating point numbers
		$lat = $emb_codes_geo{$city_code}[0];
		$lng = $emb_codes_geo{$city_code}[1];
		$lat =~ s/,/\./g;
		$lng =~ s/,/\./g;
	}

	# filter out empty coordinates
	if ((not defined $lat) or (not defined $lng)) {
		return (undef, undef);
	}

	return ($lat, $lng);

}

# an iterator over a cursor to unify cases between mongodb and external data (like filtered jsonl)
sub cursor_iter ($cursor) {
	return sub {
		return $cursor->next();
	};
}

=head2 map_of_products($products_iter, $request_ref, $graph_ref)

Build the HTML to display a map of products

=head3 parameters

=head4 $products_iter - iterator

Must return a reference to a function that on each call return a product, or undef to end iteration


=head4 $request_ref - hashmap ref

=head4 $graph_ref - hashmap ref

Specifications for the graph

=cut

sub map_of_products ($products_iter, $request_ref, $graph_ref) {

	my $html = '';

	# be sure to have packager codes loaded
	init_emb_codes();
	init_packager_codes();
	init_geocode_addresses();

	$graph_ref->{graph_title} = escape_single_quote($graph_ref->{graph_title});

	my $matching_products = 0;
	my $places = 0;
	my $emb_codes = 0;
	my $seen_products = 0;

	my %seen = ();
	my @pointers = ();

	while (my $product_ref = $products_iter->()) {
		my $url = $formatted_subdomain . product_url($product_ref->{code});

		my $manufacturing_places = escape_single_quote($product_ref->{"manufacturing_places"});
		$manufacturing_places =~ s/,( )?/, /g;
		if ($manufacturing_places ne '') {
			$manufacturing_places
				= ucfirst(lang("manufacturing_places_p"))
				. separator_before_colon($lc) . ": "
				. $manufacturing_places . "<br>";
		}

		my $origins = escape_single_quote($product_ref->{origins});
		$origins =~ s/,( )?/, /g;
		if ($origins ne '') {
			$origins = ucfirst(lang("origins_p")) . separator_before_colon($lc) . ": " . $origins . "<br>";
		}

		$origins = $manufacturing_places . $origins;

		my $pointer = {
			product_name => $product_ref->{product_name},
			brands => $product_ref->{brands},
			url => $url,
			origins => $origins,
			img => display_image_thumb($product_ref, 'front')
		};

		# Loop on cities: multiple emb codes can be on one product

		my $field = 'emb_codes';
		if (defined $product_ref->{"emb_codes_tags"}) {

			my %current_seen = ();    # only one product when there are multiple city codes for the same city

			foreach my $emb_code (@{$product_ref->{"emb_codes_tags"}}) {

				my ($lat, $lng) = get_packager_code_coordinates($emb_code);

				if ((defined $lat) and ($lat ne '') and (defined $lng) and ($lng ne '')) {
					my $geo = "$lat,$lng";
					if (not defined $current_seen{$geo}) {

						$current_seen{$geo} = 1;
						my @geo = ($lat + 0.0, $lng + 0.0);
						$pointer->{geo} = \@geo;
						push @pointers, $pointer;
						$emb_codes++;
						if (not defined $seen{$geo}) {
							$seen{$geo} = 1;
							$places++;
						}
					}
				}
			}

			if (scalar keys %current_seen > 0) {
				$seen_products++;
			}
		}

		$matching_products++;
	}

	# no products --> no map
	if ($matching_products <= 0) {
		if ($matching_products == 0) {
			$html .= "<p>" . lang("no_products") . "</p>";
		}
		$log->warn("could not retrieve enough products for a map", {count => $matching_products}) if $log->is_warn();
		return $html;
	}

	$log->info(
		"rendering map for matching products",
		{
			count => $matching_products,
			matching_products => $matching_products,
			products => $seen_products,
			emb_codes => $emb_codes
		}
	) if $log->is_debug();

	# Points to display?
	my $count_string = q{};
	if ($emb_codes > 0) {
		$count_string = sprintf(lang("map_count"), $matching_products, $seen_products);
	}

	if (defined $request_ref->{current_link}) {
		$request_ref->{current_link_query_display} = $request_ref->{current_link};
		$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
	}

	my $json = JSON::PP->new->utf8(0);
	my $map_template_data_ref = {
		lang => \&lang,
		encode_json => sub ($obj_ref) {
			return $json->encode($obj_ref);
		},
		title => $count_string,
		pointers => \@pointers,
		current_link => $request_ref->{current_link},
	};
	process_template('web/pages/products_map/map_of_products.tt.html', $map_template_data_ref, \$html)
		|| ($html .= 'template error: ' . $tt->error());

	return $html;
}

=head2 search_products_for_map($request_ref, $query_ref)

Build the MongoDB query corresponding to a search to display a map

=head3 parameters

=head4 $request_ref - hashmap

=head4 $query_ref - hashmap

Base query that will be modified to be able to build the map

=head3 returns - MongoDB::Cursor instance

=cut

sub search_products_for_map ($request_ref, $query_ref) {

	add_params_to_query($request_ref, $query_ref);

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	my $cursor;

	$log->info("retrieving products from MongoDB to display them in a map") if $log->is_info();

	eval {
		$cursor = execute_query(
			sub {
				return get_products_collection(get_products_collection_request_parameters($request_ref))
					->query($query_ref)->fields(
					{
						code => 1,
						lc => 1,
						product_name => 1,
						"product_name_$lc" => 1,
						brands => 1,
						images => 1,
						manufacturing_places => 1,
						origins => 1,
						emb_codes_tags => 1,
					}
					);
			}
		);
	};
	if ($@) {
		$log->warn("MongoDB error", {error => $@}) if $log->is_warn();
	}
	else {
		$log->info("MongoDB query ok", {error => $@}) if $log->is_info();
	}

	$log->info("retrieved products from MongoDB to display them in a map") if $log->is_info();
	$cursor->immortal(1);
	return $cursor;
}

=head2 search_and_map_products ($request_ref, $query_ref, $graph_ref)

Trigger a search and build a map

=head3 parameters

=head4 $request_ref - hashmap ref

=head4 $query_ref - hashmap ref

Base query for this search

=head4 $graph_ref

Specification of the graph

=cut

sub search_and_map_products ($request_ref, $query_ref, $graph_ref) {

	my $cursor = search_products_for_map($request_ref, $query_ref);

	# add search link
	my $html = '';

	$html .= search_permalink($request_ref);

	eval {$html .= map_of_products(cursor_iter($cursor), $request_ref, $graph_ref);} or do {
		$html .= "<p>" . lang("error_database") . "</p>";
	};
	return $html;
}

=head2 search_permalink($request_ref)

add a permalink to a search result page

=head3 return - string - generated HTML
=cut

sub search_permalink ($request_ref) {
	my $html = '';
	if (defined $request_ref->{current_link}) {
		$request_ref->{current_link_query_display} = $request_ref->{current_link};
		$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
		$html
			.= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">"
			. lang("search_edit")
			. "</a><br>";
	}
	return $html;
}

sub display_page ($request_ref) {

	$log->trace("Start of display_page") if $log->is_trace();

	my $template_data_ref = {};

	# If the client is requesting json, jsonp, xml or jqm,
	# and if we have a response in structure format,
	# do not generate an HTML response and serve the structured data

	if (
		(
			   single_param("json")
			or single_param("jsonp")
			or single_param("xml")
			or single_param("jqm")
			or $request_ref->{rss}
		)
		and (exists $request_ref->{structured_response})
		)
	{

		display_structured_response($request_ref);
		return;
	}

	my $title = $request_ref->{title};
	my $description = $request_ref->{description};
	my $content_ref = $request_ref->{content_ref};

	my $meta_description = '';

	my $content_header = '';

	$log->debug("displaying page", {title => $title}) if $log->is_debug();

	my $type;
	my $id;

	my $site = "<a href=\"/\">" . lang("site_name") . "</a>";

	${$content_ref} =~ s/<SITE>/$site/g;

	my $textid = undef;
	if ((defined $description) and ($description =~ /^textid:/)) {
		$textid = $';
		$description = undef;
	}
	if (${$content_ref} =~ /\<p id="description"\>(.*?)\<\/p\>/s) {
		$description = $1;
	}

	if (defined $description) {
		$description =~ s/<([^>]*)>//g;
		$description =~ s/"/'/g;
		$meta_description = "<meta name=\"description\" content=\"$description\">";
	}

	my $canon_title = '';
	if (defined $title) {
		$title =~ s/<SITE>/$site/g;

		$title =~ s/<([^>]*)>//g;

		$title = remove_tags_and_quote($title);
	}
	my $canon_description = '';
	if (defined $description) {
		$description = remove_tags_and_quote($description);
	}
	if ($canon_description eq '') {
		$canon_description = lang("site_description");
	}
	my $canon_image_url = "";
	my $canon_url = $formatted_subdomain;

	if (defined $request_ref->{canon_url}) {
		if ($request_ref->{canon_url} =~ /^(http|https):/) {
			$canon_url = $request_ref->{canon_url};
		}
		else {
			$canon_url .= $request_ref->{canon_url};
		}
	}
	elsif (defined $request_ref->{canon_rel_url}) {
		$canon_url .= $request_ref->{canon_rel_url};
	}
	elsif (defined $request_ref->{current_link}) {
		$canon_url .= $request_ref->{current_link};
	}
	elsif (defined $request_ref->{url}) {
		$canon_url = $request_ref->{url};
	}

	# More images?

	my $og_images = '';
	my $og_images2 = '<meta property="og:image" content="' . lang("og_image_url") . '">';
	my $more_images = 0;

	# <img id="og_image" src="https://recettes.de/images/misc/recettes-de-cuisine-logo.gif" width="150" height="200">
	if (${$content_ref} =~ /<img id="og_image" src="([^"]+)"/) {
		my $img_url = $1;
		$img_url =~ s/\.200\.jpg/\.400\.jpg/;
		if ($img_url !~ /^(http|https):/) {
			$img_url = $static_subdomain . $img_url;
		}
		$og_images .= '<meta property="og:image" content="' . $img_url . '">' . "\n";
		if ($img_url !~ /misc/) {
			$og_images2 = '';
		}
	}

	my $og_type = 'food';
	if (defined $request_ref->{og_type}) {
		$og_type = $request_ref->{og_type};
	}

	$template_data_ref->{server_domain} = $server_domain;
	$template_data_ref->{language} = $lang;
	$template_data_ref->{title} = $title;
	$template_data_ref->{og_type} = $og_type;
	$template_data_ref->{fb_config} = 219331381518041;
	$template_data_ref->{canon_url} = $canon_url;
	$template_data_ref->{meta_description} = $meta_description;
	$template_data_ref->{canon_title} = $canon_title;
	$template_data_ref->{og_images} = $og_images;
	$template_data_ref->{og_images2} = $og_images2;
	$template_data_ref->{options_favicons} = $options{favicons};
	$template_data_ref->{static_subdomain} = $static_subdomain;
	$template_data_ref->{images_subdomain} = $images_subdomain;
	$template_data_ref->{formatted_subdomain} = $formatted_subdomain;
	$template_data_ref->{css_timestamp} = $file_timestamps{'css/dist/app-' . lang('text_direction') . '.css'};
	$template_data_ref->{header} = $header;
	$template_data_ref->{page_type} = $request_ref->{page_type} || "other";
	$template_data_ref->{page_format} = $request_ref->{page_format} || "normal";

	if ($request_ref->{schema_org_itemtype}) {
		$template_data_ref->{schema_org_itemtype} = $request_ref->{schema_org_itemtype};
	}

	my $site_name = $Lang{site_name}{$lang};
	if ($server_options{producers_platform}) {
		$site_name = $Lang{producers_platform}{$lc};
	}

	# Override Google Analytics from Config.pm with server_options
	# defined in Config2.pm if it exists

	if (exists $server_options{google_analytics}) {
		$google_analytics = $server_options{google_analytics};
	}

	$template_data_ref->{styles} = $styles;
	$template_data_ref->{google_analytics} = $google_analytics;
	$template_data_ref->{bodyabout} = $bodyabout;
	$template_data_ref->{site_name} = $site_name;

	my $en = 0;
	my $langs = '';
	my $selected_lang = '';

	foreach my $olc (@{$country_languages{$cc}}, 'en') {
		if ($olc eq 'en') {
			if ($en) {
				next;
			}
			else {
				$en = 1;
			}
		}
		if (exists $Langs{$olc}) {
			my $osubdomain = "$cc-$olc";
			if ($olc eq $country_languages{$cc}[0]) {
				$osubdomain = $cc;
			}
			if (($olc eq $lc)) {
				$selected_lang = "<a href=\"" . format_subdomain($osubdomain) . "/\">$Langs{$olc}</a>\n";
			}
			else {
				$langs .= "<li><a href=\"" . format_subdomain($osubdomain) . "/\">$Langs{$olc}</a></li>";
			}
		}
	}

	$template_data_ref->{langs} = $langs;
	$template_data_ref->{selected_lang} = $selected_lang;

	# Join us on Slack <a href="http://slack.openfoodfacts.org">Slack</a>:
	my $join_us_on_slack
		= sprintf($Lang{footer_join_us_on}{$lc}, '<a href="https://slack.openfoodfacts.org">Slack</a>');

	my $twitter_account = lang("twitter_account");
	if (defined $Lang{twitter_account_by_country}{$cc}) {
		$twitter_account = $Lang{twitter_account_by_country}{$cc};
	}
	$template_data_ref->{twitter_account} = $twitter_account;
	# my $facebook_page = lang("facebook_page");

	my $torso_class = "anonymous";
	if (defined $User_id) {
		$torso_class = "loggedin";
	}

	my $search_terms = '';
	if (defined single_param('search_terms')) {
		$search_terms = remove_tags_and_quote(decode utf8 => single_param('search_terms'));
	}

	my $image_banner = "";
	my $link = lang("donate_link");
	my $image;
	my @banners = qw(independent personal research);
	my $banner = $banners[time() % @banners];
	$image = "/images/banners/donate/donate-banner.$banner.$lc.800x150.svg";
	my $image_en = "/images/banners/donate/donate-banner.$banner.en.800x150.svg";

	$template_data_ref->{lc} = $lc;
	$template_data_ref->{image} = $image;
	$template_data_ref->{image_en} = $image_en;
	$template_data_ref->{link} = $link;
	$template_data_ref->{lc} = $lc;

	my $tagline = lang("tagline");

	if ($server_options{producers_platform}) {
		$tagline = "";
	}

	# Display a banner from users on Android or iOS

	my $user_agent = $ENV{HTTP_USER_AGENT};

	# add a user_agent parameter so that we can test from desktop easily
	if (defined single_param('user_agent')) {
		$user_agent = single_param('user_agent');
	}

	my $device;
	my $system;

	# windows phone must be first as its user agent includes the string android
	if ($user_agent =~ /windows phone/i) {

		$device = "windows";
	}
	elsif ($user_agent =~ /android/i) {

		$device = "android";
		$system = "android";
	}
	elsif ($user_agent =~ /iphone/i) {

		$device = "iphone";
		$system = "ios";
	}
	elsif ($user_agent =~ /ipad/i) {

		$device = "ipad";
		$system = "ios";
	}

	if ((defined $device) and (defined $Lang{"get_the_app_$device"}) and (not $server_options{producers_platform})) {

		$template_data_ref->{mobile} = {
			device => $device,
			system => $system,
			link => lang($system . "_app_link"),
			text => lang("app_banner_text"),
		};
	}

	# Extract initjs code from content

	while ($$content_ref =~ /<initjs>(.*?)<\/initjs>/s) {
		$$content_ref = $` . $';
		$initjs .= $1;
	}
	while ($$content_ref =~ /<scripts>(.*?)<\/scripts>/s) {
		$$content_ref = $` . $';
		$scripts .= $1;
	}

	$template_data_ref->{search_terms} = ${search_terms};
	$template_data_ref->{torso_class} = $torso_class;
	$template_data_ref->{tagline} = $tagline;
	$template_data_ref->{title} = $title;
	$template_data_ref->{content} = $$content_ref;
	$template_data_ref->{join_us_on_slack} = $join_us_on_slack;

	# init javascript code

	$template_data_ref->{scripts} = $scripts;
	$template_data_ref->{initjs} = $initjs;
	$template_data_ref->{request} = $request_ref;

	my $html;
	process_template('web/common/site_layout.tt.html', $template_data_ref, \$html)
		|| ($html = "template error: " . $tt->error());

	# disable equalizer
	# e.g. for product edit form, pages that load iframes (twitter embeds etc.)
	if ($html =~ /<!-- disable_equalizer -->/) {

		$html =~ s/data-equalizer(-watch)?//g;
	}

	# Twitter account
	$html =~ s/<twitter_account>/$twitter_account/g;

	# Replace urls for texts in links like <a href="/ecoscore"> with a localized name
	$html =~ s/(href=")(\/[^"]+)/$1 . url_for_text($2)/eg;

	my $status_code = $request_ref->{status_code} || 200;

	my $http_headers_ref = {
		'-status' => $status_code,
		'-expires' => '-1d',
		'-charset' => 'UTF-8',
	};

	# init_user() may set or unset the session cookie
	if (defined $request_ref->{cookie}) {
		$http_headers_ref->{'-cookie'} = [$request_ref->{cookie}];
	}

	print header(%$http_headers_ref);

	my $r = Apache2::RequestUtil->request();
	$r->rflush;
	# Setting the status makes mod_perl append a default error to the body
	# Send 200 instead.
	$r->status(200);

	binmode(STDOUT, ":encoding(UTF-8)");

	$log->debug("display done", {lc => $lc, lang => $lang, mongodb => $mongodb, data_root => $data_root})
		if $log->is_debug();

	print $html;
	return;
}

sub display_image_box ($product_ref, $id, $minheight_ref) {

	# print STDERR "display_image_box : $id\n";

	my $img = display_image($product_ref, $id, $small_size);
	if ($img ne '') {
		my $code = $product_ref->{code};
		my $linkid = $id;
		if ($img =~ /<meta itemprop="imgid" content="([^"]+)"/) {
			$linkid = $1;
		}

		if ($id eq 'front') {

			$img =~ s/<img/<img id="og_image"/;

		}

		my $alt = lang('image_attribution_link_title');
		$img = <<"HTML"
<figure id="image_box_$id" class="image_box" itemprop="image" itemscope itemtype="https://schema.org/ImageObject">
$img
<figcaption><a href="/cgi/product_image.pl?code=$code&amp;id=$linkid" title="$alt">@{[ display_icon('cc') ]}</a></figcaption>
</figure>
HTML
			;

		if ($img =~ /height="(\d+)"/) {
			${$minheight_ref} = $1 + 22;
		}

		# Unselect button for moderators
		if ($User{moderator}) {

			my $idlc = $id;

			# <img src="$static/images/products/$path/$id.$rev.$thumb_size.jpg"
			if ($img =~ /src="([^"]*)\/([^\.]+)\./) {
				$idlc = $2;
			}

			my $unselect_image = lang('unselect_image');

			my $html = <<HTML
<div class="button_div unselectbuttondiv_$idlc"><button class="unselectbutton_$idlc tiny button" type="button">$unselect_image</button></div>
HTML
				;

			my $filename = '';
			my $size = 'full';
			if (    (defined $product_ref->{images})
				and (defined $product_ref->{images}{$idlc})
				and (defined $product_ref->{images}{$idlc}{sizes})
				and (defined $product_ref->{images}{$idlc}{sizes}{$size}))
			{
				$filename = $idlc . '.' . $product_ref->{images}{$idlc}{rev};
			}

			my $path = product_path($product_ref);

			if (-e "$www_root/images/products/$path/$filename.full.json") {
				$html .= <<HTML
<a href="$images_subdomain/images/products/$path/$filename.full.json">OCR result</a>
HTML
					;
			}

			$img .= $html;

			$initjs .= <<JS
	\$(".unselectbutton_$idlc").click({imagefield:"$idlc"},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		\$('div.unselectbuttondiv_$idlc').html('<img src="/images/misc/loading2.gif"> Unselecting image');
		\$.post('/cgi/product_image_unselect.pl',
				{code: "$code", id: "$idlc" }, function(data) {

			if (data.status_code === 0) {
				\$('div.unselectbuttondiv_$idlc').html("Unselected image");
				\$('div[id="image_box_$id"]').html("");
			}
			else {
				\$('div.unselectbuttondiv_$idlc').html("Could not unselect image");
			}
			\$(document).foundation('equalizer', 'reflow');
		}, 'json');

		\$(document).foundation('equalizer', 'reflow');

	});
JS
				;

		}

	}
	return $img;
}

=head2 display_possible_improvement_description( PRODUCT_REF, TAGID )

Display an explanation of the possible improvement, using the improvement
data stored in $product_ref->{improvements_data}

=cut

sub display_possible_improvement_description ($product_ref, $tagid) {

	my $html = "";

	if ((defined $product_ref->{improvements_data}) and (defined $product_ref->{improvements_data}{$tagid})) {

		my $template_data_ref_improvement = {};

		$template_data_ref_improvement->{tagid} = $tagid;

		# Comparison of product nutrition facts to other products of the same category

		if ($tagid =~ /^en:nutrition-(very-)?high/) {
			$template_data_ref_improvement->{product_ref_improvements_data} = $product_ref->{improvements_data};
			$template_data_ref_improvement->{product_ref_improvements_data_tagid}
				= $product_ref->{improvements_data}{$tagid};
			$template_data_ref_improvement->{product_ref_improvements_data_tagid_product_100g}
				= $product_ref->{improvements_data}{$tagid}{product_100g};
			$template_data_ref_improvement->{product_ref_improvements_data_tagid_category_100g}
				= $product_ref->{improvements_data}{$tagid}{category_100g};
			$template_data_ref_improvement->{display_taxonomy_tag_improvements_data_category} = sprintf(
				lang("value_for_the_category"),
				display_taxonomy_tag($lc, "categories", $product_ref->{improvements_data}{$tagid}{category})
			);
		}

		# Opportunities to improve the Nutri-Score by slightly changing the nutrients

		if ($tagid =~ /^en:better-nutri-score/) {
			# msgid "The Nutri-Score can be changed from %s to %s by changing the %s value from %s to %s (%s percent difference)."
			$template_data_ref_improvement->{nutriscore_sprintf_data} = sprintf(
				lang("better_nutriscore"),
				uc($product_ref->{improvements_data}{$tagid}{current_nutriscore_grade}),
				uc($product_ref->{improvements_data}{$tagid}{new_nutriscore_grade}),
				lc(lang("nutriscore_points_for_" . $product_ref->{improvements_data}{$tagid}{nutrient})),
				$product_ref->{improvements_data}{$tagid}{current_value},
				$product_ref->{improvements_data}{$tagid}{new_value},
				sprintf("%d", $product_ref->{improvements_data}{$tagid}{difference_percent})
			);
		}

		process_template('web/common/includes/display_possible_improvement_description.tt.html',
			$template_data_ref_improvement, \$html)
			|| return "template error: " . $tt->error();

	}

	return $html;
}

sub display_product ($request_ref) {

	my $request_code = $request_ref->{code};
	my $code = normalize_code($request_code);
	local $log->context->{code} = $code;

	if ($code !~ /^\d{4,24}$/) {
		display_error_and_exit($Lang{invalid_barcode}{$lang}, 403);
	}

	my $product_id = product_id_for_owner($Owner_id, $code);

	my $html = '';
	my $title = undef;
	my $description = "";

	my $template_data_ref = {request_ref => $request_ref,};

	$scripts .= <<SCRIPTS
<script src="/js/dist/webcomponentsjs/webcomponents-loader.js"></script>
<script src="$static_subdomain/js/dist/display-product.js"></script>
SCRIPTS
		;
	# call equalizer when dropdown content is shown
	$initjs .= <<JS
\$('.f-dropdown').on('opened.fndtn.dropdown', function() {
   \$(document).foundation('equalizer', 'reflow');
});
\$('.f-dropdown').on('closed.fndtn.dropdown', function() {
   \$(document).foundation('equalizer', 'reflow');
});
JS
		;

	# Check that the product exist, is published, is not deleted, and has not moved to a new url

	$log->info("displaying product", {request_code => $request_code, product_id => $product_id}) if $log->is_info();

	$title = $code;

	my $product_ref;

	my $rev = single_param("rev");
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision") if $log->is_info();
		$product_ref = retrieve_product_rev($product_id, $rev);
		$header .= '<meta name="robots" content="noindex,follow">';
	}
	else {
		$product_ref = retrieve_product($product_id);
	}

	if (not defined $product_ref) {
		display_error_and_exit(sprintf(lang("no_product_for_barcode"), $code), 404);
	}

	$title = product_name_brand_quantity($product_ref);
	my $titleid = get_string_id_for_lang($lc, product_name_brand($product_ref));

	if (not $title) {
		$title = $code;
	}

	if (defined $rev) {
		$title .= " version $rev";
	}

	$description = sprintf(lang("product_description"), $title);

	$request_ref->{canon_url} = product_url($product_ref);

	if ($lc eq 'en') {
		$request_ref->{canon_url} = get_world_subdomain() . product_url($product_ref);
	}

	# Old UPC-12 in url? Redirect to EAN-13 url
	if ($request_code ne $code) {
		$request_ref->{redirect} = $request_ref->{canon_url};
		$log->info(
			"302 redirecting user because request_code does not match code",
			{redirect => $request_ref->{redirect}, lc => $lc, request_code => $code}
		) if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	# Check that the titleid is the right one

	if (
		(not defined $rev)
		and (  (($titleid ne '') and ((not defined $request_ref->{titleid}) or ($request_ref->{titleid} ne $titleid)))
			or (($titleid eq '') and ((defined $request_ref->{titleid}) and ($request_ref->{titleid} ne ''))))
		)
	{
		$request_ref->{redirect} = $request_ref->{canon_url};
		$log->info(
			"302 redirecting user because titleid is incorrect",
			{
				redirect => $request_ref->{redirect},
				lc => $lc,
				product_lc => $product_ref->{lc},
				titleid => $titleid,
				request_titleid => $request_ref->{titleid}
			}
		) if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	# Note: the product_url function is automatically added to all templates
	# so we need to use a different field name for the displayed product url

	my $product_url = product_url($product_ref);
	$template_data_ref->{this_product_url} = $product_url;

	# Environmental impact and Eco-Score
	# Limit to the countries for which we have computed the Eco-Score
	# for alpha test to moderators, display eco-score for all countries

	# Note: the Eco-Score data needs to be localized before we create the knowledge panels.

	if (($show_ecoscore) and (defined $product_ref->{ecoscore_data})) {

		localize_ecoscore($cc, $product_ref);

		$template_data_ref->{ecoscore_grade} = uc($product_ref->{ecoscore_data}{"grade"});
		$template_data_ref->{ecoscore_grade_lc} = $product_ref->{ecoscore_data}{"grade"};
		$template_data_ref->{ecoscore_score} = $product_ref->{ecoscore_data}{"score"};
		$template_data_ref->{ecoscore_data} = $product_ref->{ecoscore_data};
		$template_data_ref->{ecoscore_calculation_details}
			= display_ecoscore_calculation_details($cc, $product_ref->{ecoscore_data});
	}

	# Activate knowledge panels for all users

	initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
	create_knowledge_panels($product_ref, $lc, $cc, $knowledge_panels_options_ref);
	$template_data_ref->{environment_card_panel}
		= display_knowledge_panel($product_ref, $product_ref->{"knowledge_panels_" . $lc}, "environment_card");
	$template_data_ref->{health_card_panel}
		= display_knowledge_panel($product_ref, $product_ref->{"knowledge_panels_" . $lc}, "health_card");
	if ($product_ref->{"knowledge_panels_" . $lc}{"contribution_card"}) {
		$template_data_ref->{contribution_card_panel}
			= display_knowledge_panel($product_ref, $product_ref->{"knowledge_panels_" . $lc}, "contribution_card");
	}

	# The front product image is rendered with the same template as the ingredients, nutrition and packaging images
	# that are displayed directly through the knowledge panels
	$template_data_ref->{front_image} = data_to_display_image($product_ref, "front", $lc);

	# On the producers platform, show a link to the public platform

	if ($server_options{producers_platform}) {
		my $public_product_url = $formatted_subdomain . $product_url;
		$public_product_url =~ s/\.pro\./\./;
		$template_data_ref->{public_product_url} = $public_product_url;
	}

	$template_data_ref->{product_changes_saved} = $request_ref->{product_changes_saved};
	$template_data_ref->{structured_response_count} = $request_ref->{structured_response}{count};

	if ($request_ref->{product_changes_saved}) {
		my $query_ref = {};
		$query_ref->{("states_tags")} = "en:to-be-completed";

		my $search_result = search_and_display_products($request_ref, $query_ref, undef, undef, undef);
		$template_data_ref->{search_result} = $search_result;
	}

	$template_data_ref->{title} = $title;
	$template_data_ref->{code} = $code;
	$template_data_ref->{user_moderator} = $User{moderator};

	# my @fields = qw(generic_name quantity packaging br brands br categories br labels origins br manufacturing_places br emb_codes link purchase_places stores countries);
	my @fields = @ProductOpener::Config::display_fields;

	$bodyabout = " about=\"" . product_url($product_ref) . "\" typeof=\"food:foodProduct\"";

	$template_data_ref->{user_id} = $User_id;
	$template_data_ref->{robotoff_url} = $robotoff_url;
	$template_data_ref->{lc} = $lc;

	my $itemtype = 'https://schema.org/Product';
	if (has_tag($product_ref, 'categories', 'en:dietary-supplements')) {
		$itemtype = 'https://schema.org/DietarySupplement';
	}

	$template_data_ref->{itemtype} = $itemtype;

	if ($code =~ /^2000/) {    # internal code
	}
	else {
		$template_data_ref->{upc_code} = 'defined';
		# Also display UPC code if the EAN starts with 0
		my $upc = "";
		if (length($code) == 13) {
			$upc .= "(EAN / EAN-13)";
			if ($code =~ /^0/) {
				$upc .= " " . $' . " (UPC / UPC-A)";
			}
		}
		$template_data_ref->{upc} = $upc;
	}

	# obsolete product

	if ((defined $product_ref->{obsolete}) and ($product_ref->{obsolete})) {
		$template_data_ref->{product_is_obsolete} = $product_ref->{obsolete};
		my $warning = $Lang{obsolete_warning}{$lc};
		if ((defined $product_ref->{obsolete_since_date}) and ($product_ref->{obsolete_since_date} ne '')) {
			$warning
				.= " ("
				. $Lang{obsolete_since_date}{$lc}
				. $Lang{sep}{$lc} . ": "
				. $product_ref->{obsolete_since_date} . ")";
		}
		$template_data_ref->{warning} = $warning;
	}

	# GS1-Prefixes for restricted circulation numbers within a company - warn for possible conflicts
	if ($code =~ /^(?:(?:0{7}[0-9]{5,6})|(?:04[0-9]{10,11})|(?:[02][0-9]{2}[0-9]{5}))$/) {
		$template_data_ref->{gs1_prefixes} = 'defined';
	}

	$template_data_ref->{rev} = $rev;
	if (defined $rev) {
		$template_data_ref->{display_rev_info} = display_rev_info($product_ref, $rev);
	}
	elsif (not has_tag($product_ref, "states", "en:complete")) {
		$template_data_ref->{not_has_tag} = "states-en:complete";
	}

	# photos and data sources

	if (defined $product_ref->{sources}) {

		$template_data_ref->{unique_sources} = [];

		my %unique_sources = ();

		foreach my $source_ref (@{$product_ref->{sources}}) {
			$unique_sources{$source_ref->{id}} = $source_ref;
		}
		foreach my $source_id (sort keys %unique_sources) {
			my $source_ref = $unique_sources{$source_id};

			if (not defined $source_ref->{name}) {
				$source_ref->{name} = $source_id;
			}

			push @{$template_data_ref->{unique_sources}}, $source_ref;
		}
	}

	# If the product has an owner, identify it as the source
	if (    (not $server_options{producers_platform})
		and (defined $product_ref->{owner})
		and ($product_ref->{owner} =~ /^org-/))
	{

		# Organization
		my $orgid = $';
		my $org_ref = retrieve_org($orgid);
		if (defined $org_ref) {
			$template_data_ref->{owner} = $product_ref->{owner};
			$template_data_ref->{owner_org} = $org_ref;
		}

		# Indicate data sources

		if (defined $product_ref->{data_sources_tags}) {
			foreach my $data_source_tagid (@{$product_ref->{data_sources_tags}}) {
				if ($data_source_tagid =~ /^database-/) {
					my $database_id = $';
					my $database_name = deep_get(\%options, "import_sources", $database_id);

					# Data sources like Agena3000, CodeOnline, Equadis
					if (defined $database_name) {
						$template_data_ref->{"data_source_database_provider"} = f_lang(
							"f_data_source_database_provider",
							{
								manufacturer => '<a href="/editor/'
									. $product_ref->{owner} . '">'
									. $org_ref->{name} . '</a>',
								provider => '<a href="/data-source/'
									. $data_source_tagid . '">'
									. $database_name . '</a>',
							}
						);
					}

					# For CodeOnline, display an extra note about the producers platform
					if ($database_id eq "codeonline") {
						$template_data_ref->{"data_source_database_note_about_the_producers_platform"}
							= lang("data_source_database_note_about_the_producers_platform");
						$template_data_ref->{"data_source_database_note_about_the_producers_platform"}
							=~ s/<producers_platform_url>/$producers_platform_url/g;
					}
				}
			}
		}
	}

	my $minheight = 0;
	my $front_image = display_image_box($product_ref, 'front', \$minheight);
	$front_image =~ s/ width="/ itemprop="image" width="/;

	# Take the last (biggest) image
	my $product_image_url;
	if ($front_image =~ /.*src="([^"]*\/products\/[^"]+)"/is) {
		$product_image_url = $1;
	}

	my $product_fields = '';
	foreach my $field (@fields) {
		# print STDERR "display_product() - field: $field - value: $product_ref->{$field}\n";
		$product_fields .= display_field($product_ref, $field);
	}

	$template_data_ref->{front_image_html} = $front_image;
	$template_data_ref->{product_fields} = $product_fields;

	# try to display ingredients in the local language if available

	my $ingredients_text = $product_ref->{ingredients_text};
	my $ingredients_text_lang = $product_ref->{ingredients_lc};

	if (defined $product_ref->{ingredients_text_with_allergens}) {
		$ingredients_text = $product_ref->{ingredients_text_with_allergens};
	}

	if (    (defined $product_ref->{"ingredients_text" . "_" . $lc})
		and ($product_ref->{"ingredients_text" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $lc};
		$ingredients_text_lang = $lc;
	}

	if (    (defined $product_ref->{"ingredients_text_with_allergens" . "_" . $lc})
		and ($product_ref->{"ingredients_text_with_allergens" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text_with_allergens" . "_" . $lc};
		$ingredients_text_lang = $lc;
	}

	if (not defined $ingredients_text) {
		$ingredients_text = "";
	}

	$ingredients_text =~ s/\n/<br>/g;

	# Indicate if we are displaying ingredients in another language than the language of the interface

	my $ingredients_text_lang_html = "";

	if (($ingredients_text ne "") and ($ingredients_text_lang ne $lc)) {
		$ingredients_text_lang_html
			= " (" . display_taxonomy_tag($lc, 'languages', $language_codes{$ingredients_text_lang}) . ")";
	}

	$template_data_ref->{ingredients_image} = display_image_box($product_ref, 'ingredients', \$minheight);
	$template_data_ref->{ingredients_text_lang} = $ingredients_text_lang;
	$template_data_ref->{ingredients_text} = $ingredients_text;

	if ($User{moderator} and ($ingredients_text !~ /^\s*$/)) {
		$template_data_ref->{User_moderator} = 'defined';

		my $ilc = $ingredients_text_lang;
		$template_data_ref->{ilc} = $ingredients_text_lang;

		$initjs .= <<JS

	var editableText;

	\$("#editingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();

		var divHtml = \$("#ingredients_list").html();
		var allergens = /(<span class="allergen">|<\\/span>)/g;
		divHtml = divHtml.replace(allergens, '_');

		var editableText = \$('<textarea id="ingredients_list" style="height:8rem" lang="$ilc" />');
		editableText.val(divHtml);
		\$("#ingredients_list").replaceWith(editableText);
		editableText.focus();

		\$("#editingredientsbuttondiv").hide();
		\$("#saveingredientsbuttondiv").show();

		\$(document).foundation('equalizer', 'reflow');

	});


	\$("#saveingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();

		\$('div[id="saveingredientsbuttondiv"]').hide();
		\$('div[id="saveingredientsbuttondiv_status"]').html('<img src="/images/misc/loading2.gif"> Saving ingredients_texts_$ilc');
		\$('div[id="saveingredientsbuttondiv_status"]').show();

		\$.post('/cgi/product_jqm_multilingual.pl',
			{code: "$code", ingredients_text_$ilc :  \$("#ingredients_list").val(), comment: "Updated ingredients_texts_$ilc" },
			function(data) {

				\$('div[id="saveingredientsbuttondiv_status"]').html('Saved ingredients_texts_$ilc');
				\$('div[id="saveingredientsbuttondiv"]').show();

				\$(document).foundation('equalizer', 'reflow');
			},
			'json'
		);

		\$(document).foundation('equalizer', 'reflow');

	});



	\$("#wipeingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		\$('div[id="wipeingredientsbuttondiv"]').html('<img src="/images/misc/loading2.gif"> Erasing ingredients_texts_$ilc');
		\$.post('/cgi/product_jqm_multilingual.pl',
			{code: "$code", ingredients_text_$ilc : "", comment: "Erased ingredients_texts_$ilc: too much bad data" },
			function(data) {

				\$('div[id="wipeingredientsbuttondiv"]').html("Erased ingredients_texts_$ilc");
				\$('div[id="ingredients_list"]').html("");

				\$(document).foundation('equalizer', 'reflow');
			},
			'json'
		);

		\$(document).foundation('equalizer', 'reflow');

	});
JS
			;

	}

	$template_data_ref->{display_ingredients_in_lang}
		= sprintf(lang("add_ingredients_in_language"), display_taxonomy_tag($lc, 'languages', $language_codes{$lc}));

	$template_data_ref->{display_field_allergens} = display_field($product_ref, 'allergens');

	$template_data_ref->{display_field_traces} = display_field($product_ref, 'traces');

	$template_data_ref->{display_ingredients_analysis} = display_ingredients_analysis($product_ref);

	$template_data_ref->{display_ingredients_analysis_details} = display_ingredients_analysis_details($product_ref);

	my $html_ingredients_classes = "";

	# to compute the number of columns displayed
	my $ingredients_classes_n = 0;

	foreach my $class (
		'additives', 'vitamins',
		'minerals', 'amino_acids',
		'nucleotides', 'other_nutritional_substances',
		'ingredients_from_palm_oil', 'ingredients_that_may_be_from_palm_oil'
		)
	{

		my $tagtype = $class;
		my $tagtype_field = $tagtype;
		# display the list of additives variants in the order that they were found, without the parents (no E450 for E450i)
		if (($class eq 'additives') and (exists $product_ref->{'additives_original_tags'})) {
			$tagtype_field = 'additives_original';
		}

		if (    (defined $product_ref->{$tagtype_field . '_tags'})
			and (scalar @{$product_ref->{$tagtype_field . '_tags'}} > 0))
		{

			$ingredients_classes_n++;

			$html_ingredients_classes
				.= "<div class=\"column_class\"><b>"
				. ucfirst(lang($class . "_p") . separator_before_colon($lc))
				. ":</b><br>";

			if (defined $tags_images{$lc}{$tagtype}{get_string_id_for_lang("no_language", $tagtype)}) {
				my $img = $tags_images{$lc}{$tagtype}{get_string_id_for_lang("no_language", $tagtype)};
				my $size = '';
				if ($img =~ /\.(\d+)x(\d+)/) {
					$size = " width=\"$1\" height=\"$2\"";
				}
				$html_ingredients_classes .= <<HTML
<img src="/images/lang/$lc/$tagtype/$img"$size/ style="display:inline">
HTML
					;
			}

			$html_ingredients_classes .= "<ul style=\"display:block;float:left;\">";
			foreach my $tagid (@{$product_ref->{$tagtype_field . '_tags'}}) {

				my $tag;
				my $link;

				# taxonomy field?
				if (defined $taxonomy_fields{$class}) {
					$tag = display_taxonomy_tag($lc, $class, $tagid);
					$link = canonicalize_taxonomy_tag_link($lc, $class, $tagid);
				}
				else {
					$tag = canonicalize_tag2($class, $tagid);
					$link = canonicalize_tag_link($class, $tagid);
				}

				my $info = '';
				my $more_info = '';

				if ($class eq 'additives') {

					my $canon_tagid = $tagid;
					$tagid =~ s/.*://;    # levels are defined only in old French list

					if (    (defined $properties{$tagtype})
						and (defined $properties{$tagtype}{$canon_tagid})
						and (defined $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"})
						and ($properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"} ne 'en:no'))
					{

						my $tagtype_field = "additives_efsa_evaluation_overexposure_risk";
						my $valueid = $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"};
						$valueid =~ s/^en://;

						# check if we have an icon
						if (exists $Lang{$tagtype_field . "_icon_alt_" . $valueid}{$lc}) {
							my $alt = $Lang{$tagtype_field . "_icon_alt_" . $valueid}{$lc};
							my $iconid = $tagtype_field . "_icon_" . $valueid;
							$iconid =~ s/_/-/g;
							$more_info = <<HTML
<a href="$link">
<img src="/images/misc/$iconid.svg" alt="$alt" width="45" height="45">
</a>
<a href="$link" class="additives_efsa_evaluation_overexposure_risk_$valueid">
$alt
</a>
HTML
								;
						}

					}
				}

				$html_ingredients_classes .= "<li><a href=\"" . $link . "\"$info>" . $tag . "</a>$more_info</li>\n";
			}
			$html_ingredients_classes .= "</ul></div>";
		}

	}

	$template_data_ref->{ingredients_classes_n} = $ingredients_classes_n;

	if ($ingredients_classes_n > 0) {

		my $column_class = "small-12 columns";

		if ($ingredients_classes_n == 2) {
			$column_class = "medium-6 columns";
		}
		elsif ($ingredients_classes_n == 3) {
			$column_class = "medium-6 large-4 columns";
		}
		elsif ($ingredients_classes_n == 4) {
			$column_class = "medium-6 large-3 columns";
		}
		elsif ($ingredients_classes_n >= 5) {
			$column_class = "medium-6 large-3 xlarge-2 columns";
		}

		$html_ingredients_classes =~ s/column_class/$column_class/g;
		$template_data_ref->{html_ingredients_classes} = $html_ingredients_classes;

	}

	# special ingredients tags

	if ((defined $ingredients_text) and ($ingredients_text !~ /^\s*$/s) and (defined $special_tags{ingredients})) {
		$template_data_ref->{special_ingredients_tags} = 'defined';

		my $special_html = "";

		foreach my $special_tag_ref (@{$special_tags{ingredients}}) {

			my $tagid = $special_tag_ref->{tagid};
			my $type = $special_tag_ref->{type};

			if (   (($type eq 'without') and (not has_tag($product_ref, "ingredients", $tagid)))
				or (($type eq 'with') and (has_tag($product_ref, "ingredients", $tagid))))
			{

				$special_html
					.= "<li class=\"${type}_${tagid}_$lc\">"
					. lang("search_" . $type) . " "
					. display_taxonomy_tag_link($lc, "ingredients", $tagid)
					. "</li>\n";
			}

		}

		$template_data_ref->{special_html} = $special_html;
	}

	# NOVA groups

	if (    (defined $options{product_type})
		and ($options{product_type} eq "food")
		and (exists $product_ref->{nova_group}))
	{
		$template_data_ref->{product_nova_group} = 'exists';
		my $group = $product_ref->{nova_group};

		my $display = display_taxonomy_tag($lc, "nova_groups", $product_ref->{nova_groups_tags}[0]);
		my $a_title = lang('nova_groups_info');

		$template_data_ref->{a_title} = $a_title;
		$template_data_ref->{group} = $group;
		$template_data_ref->{display} = $display;
	}

	# Do not display nutrition table for Open Beauty Facts

	if (not((defined $options{no_nutrition_table}) and ($options{no_nutrition_table}))) {

		$template_data_ref->{nutrition_table} = 'defined';

		# Display Nutri-Score and nutrient levels

		my $template_data_nutriscore_ref = data_to_display_nutriscore($product_ref);
		my $template_data_nutrient_levels_ref = data_to_display_nutrient_levels($product_ref);

		my $nutriscore_html = '';
		my $nutrient_levels_html = '';

		if (not $template_data_nutrient_levels_ref->{do_not_display}) {

			process_template('web/pages/product/includes/nutriscore.tt.html',
				$template_data_nutriscore_ref, \$nutriscore_html)
				|| return "template error: " . $tt->error();
			process_template(
				'web/pages/product/includes/nutrient_levels.tt.html',
				$template_data_nutrient_levels_ref,
				\$nutrient_levels_html
			) || return "template error: " . $tt->error();
		}

		$template_data_ref->{display_nutriscore} = $nutriscore_html;
		$template_data_ref->{display_nutrient_levels} = $nutrient_levels_html;

		$template_data_ref->{display_serving_size}
			= display_field($product_ref, "serving_size") . display_field($product_ref, "br");

		# Compare nutrition data with stats of the categories and display the nutrition table

		if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {
			$template_data_ref->{no_nutrition_data} = 'on';
		}

		my $comparisons_ref = compare_product_nutrition_facts_to_categories($product_ref, $cc, undef);

		$template_data_ref->{display_nutrition_table} = display_nutrition_table($product_ref, $comparisons_ref);
		$template_data_ref->{nutrition_image} = display_image_box($product_ref, 'nutrition', \$minheight);

		if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
			$template_data_ref->{has_tag} = 'categories-en:alcoholic-beverages';
		}
	}

	# Packaging

	$template_data_ref->{packaging_image} = display_image_box($product_ref, 'packaging', \$minheight);

	# try to display packaging in the local language if available

	my $packaging_text = $product_ref->{packaging_text};

	my $packaging_text_lang = $product_ref->{lc};

	if ((defined $product_ref->{"packaging_text" . "_" . $lc}) and ($product_ref->{"packaging_text" . "_" . $lc} ne ''))
	{
		$packaging_text = $product_ref->{"packaging_text" . "_" . $lc};
		$packaging_text_lang = $lc;
	}

	if (not defined $packaging_text) {
		$packaging_text = "";
	}

	$packaging_text =~ s/\n/<br>/g;

	$template_data_ref->{packaging_text} = $packaging_text;
	$template_data_ref->{packaging_text_lang} = $packaging_text_lang;

	# packagings data structure
	$template_data_ref->{packagings} = $product_ref->{packagings};

	# Forest footprint
	# 2020-12-07 - We currently display the forest footprint in France
	# and for moderators so that we can extend it to other countries
	if (($cc eq "fr") or ($User{moderator})) {
		# Forest footprint data structure
		$template_data_ref->{forest_footprint_data} = $product_ref->{forest_footprint_data};
	}

	# other fields

	my $other_fields = "";
	foreach my $field (@ProductOpener::Config::display_other_fields) {
		# print STDERR "display_product() - field: $field - value: $product_ref->{$field}\n";
		$other_fields .= display_field($product_ref, $field);
	}

	if ($other_fields ne "") {
		$template_data_ref->{other_fields} = $other_fields;
	}

	$template_data_ref->{admin} = $admin;

	# Platform for producers: data quality issues and improvements opportunities

	if ($server_options{producers_platform}) {

		$template_data_ref->{display_data_quality_issues_and_improvement_opportunities}
			= display_data_quality_issues_and_improvement_opportunities($product_ref);

	}

	# photos and data sources

	my @other_editors = ();

	foreach my $editor (@{$product_ref->{editors_tags}}) {
		next if ((defined $product_ref->{creator}) and ($editor eq $product_ref->{creator}));
		next if ((defined $product_ref->{last_editor}) and ($editor eq $product_ref->{last_editor}));
		push @other_editors, $editor;
	}

	my $other_editors = "";

	foreach my $editor (sort @other_editors) {
		$other_editors
			.= "<a href=\""
			. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $editor)) . "\">"
			. $editor
			. "</a>, ";
	}
	$other_editors =~ s/, $//;

	my $creator
		= "<a href=\""
		. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $product_ref->{creator})) . "\">"
		. $product_ref->{creator} . "</a>";
	my $last_editor
		= "<a href=\""
		. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $product_ref->{last_editor})) . "\">"
		. $product_ref->{last_editor} . "</a>";

	if ($other_editors ne "") {
		$other_editors = "<br>\n$Lang{also_edited_by}{$lang} ${other_editors}.";
	}

	my $checked = "";
	if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
		my $last_checked_date = display_date_tag($product_ref->{last_checked_t});
		my $last_checker
			= "<a href=\""
			. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $product_ref->{last_checker}))
			. "\">"
			. $product_ref->{last_checker} . "</a>";
		$checked = "<br/>\n$Lang{product_last_checked}{$lang} $last_checked_date $Lang{by}{$lang} $last_checker.";
	}

	$template_data_ref->{created_date} = display_date_tag($product_ref->{created_t});
	$template_data_ref->{creator} = $creator;
	$template_data_ref->{last_modified_date} = display_date_tag($product_ref->{last_modified_t});
	$template_data_ref->{last_editor} = $last_editor;
	$template_data_ref->{other_editors} = $other_editors;
	$template_data_ref->{checked} = $checked;

	if (defined $User_id) {
		$template_data_ref->{display_field_states} = display_field($product_ref, 'states');
	}

	$template_data_ref->{display_product_history} = display_product_history($code, $product_ref) if $User{moderator};

	# Twitter card

	# example:

	#<meta name="twitter:card" content="product">
	#<meta name="twitter:site" content="@iHeartRadio">
	#<meta name="twitter:creator" content="@iHeartRadio">
	#<meta name="twitter:title" content="24/7 Beatles — Celebrating 50 years of Beatlemania">
	#<meta name="twitter:image" content="http://radioedit.iheart.com/service/img/nop()/assets/images/05fbb21d-e5c6-4dfc-af2b-b1056e82a745.png">
	#<meta name="twitter:label1" content="Genre">
	#<meta name="twitter:data1" content="Classic Rock">
	#<meta name="twitter:label2" content="Location">
	#<meta name="twitter:data2" content="National">

	my $meta_product_image_url = "";
	if (defined $product_image_url) {
		$meta_product_image_url = <<HTML
<meta name="twitter:image" content="$product_image_url">
<meta property="og:image" content="$product_image_url">
HTML
			;
	}

	$header .= <<HTML
<meta name="twitter:card" content="product">
<meta name="twitter:site" content="@<twitter_account>">
<meta name="twitter:creator" content="@<twitter_account>">
<meta name="twitter:title" content="$title">
<meta name="twitter:description" content="$description">
HTML
		;

	if (defined $product_ref->{brands}) {
		# print only first brand if multiple exist.
		my @brands = split(',', $product_ref->{brands});
		$header .= <<HTML
<meta name="twitter:label1" content="$Lang{brands_s}{$lc}">
<meta name="twitter:data1" content="$brands[0]">
HTML
			;
	}

	# get most specific category (the last one)
	my $data2 = display_taxonomy_tag($lc, "categories", $product_ref->{categories_tags}[-1]);
	if ($data2) {
		$header .= <<HTML
<meta name="twitter:label2" content="$Lang{categories_s}{$lc}">
<meta name="twitter:data2" content="$data2">
HTML
			;
	}

	$header .= <<HTML
$meta_product_image_url

HTML
		;

	# Compute attributes and embed them as JSON
	# enable feature for moderators

	if ($request_ref->{user_preferences}) {

		# A result summary will be computed according to user preferences on the client side

		compute_attributes($product_ref, $lc, $cc, $attributes_options_ref);

		my $product_attribute_groups_json
			= decode_utf8(encode_json({"attribute_groups" => $product_ref->{"attribute_groups_" . $lc}}));
		my $preferences_text = lang("classify_products_according_to_your_preferences");

		$scripts .= <<JS
<script type="text/javascript">
var page_type = "product";
var preferences_text = "$preferences_text";
var product = $product_attribute_groups_json;
</script>

<script src="/js/product-preferences.js"></script>
<script src="/js/product-search.js"></script>
JS
			;

		$initjs .= <<JS
display_user_product_preferences("#preferences_selected", "#preferences_selection_form", function () { display_product_summary("#product_summary", product); });
display_product_summary("#product_summary", product);
JS
			;
	}

	my $html_display_product;
	process_template('web/pages/product/product_page.tt.html', $template_data_ref, \$html_display_product)
		|| ($html_display_product = "template error: " . $tt->error());
	$html .= $html_display_product;

	$request_ref->{content_ref} = \$html;
	$request_ref->{title} = $title;
	$request_ref->{description} = $description;
	$request_ref->{page_type} = "product";
	$request_ref->{page_format} = "banner";

	$log->trace("displayed product") if $log->is_trace();

	display_page($request_ref);

	return;
}

sub display_product_jqm ($request_ref) {    # jquerymobile

	my $code = normalize_code($request_ref->{code});
	my $product_id = product_id_for_owner($Owner_id, $code);
	local $log->context->{code} = $code;
	local $log->context->{product_id} = $product_id;

	my $html = '';
	my $title = undef;
	my $description = undef;

	# Check that the product exist, is published, is not deleted, and has not moved to a new url

	$log->info("displaying product jquery mobile") if $log->is_info();

	$title = $code;

	my $product_ref;

	my $rev = single_param("rev");
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision on jquery mobile") if $log->is_info();
		$product_ref = retrieve_product_rev($product_id, $rev);
	}
	else {
		$product_ref = retrieve_product($product_id);
	}

	if (not defined $product_ref) {
		return;
	}

	$title = $product_ref->{product_name};

	if (not $title) {
		$title = $code;
	}

	if (defined $rev) {
		$title .= " version $rev";
	}

	$description = $title . ' - ' . $product_ref->{brands} . ' - ' . $product_ref->{generic_name};
	$description =~ s/ - $//;
	$request_ref->{canon_url} = product_url($product_ref);

	my @fields
		= qw(generic_name quantity packaging br brands br categories br labels br origins br manufacturing_places br emb_codes purchase_places stores);

	if ($code =~ /^2000/) {    # internal code
	}
	else {
		$html .= "<p>" . lang("barcode") . separator_before_colon($lc) . ": $code</p>\n";
	}

	# Generate HTML for Nutri-Score and nutrient levels
	my $template_data_nutriscore_and_nutrient_levels_ref = data_to_display_nutriscore_and_nutrient_levels($product_ref);

	my $nutriscore_html = '';
	my $nutrient_levels_html = '';

	if (not $template_data_nutriscore_and_nutrient_levels_ref->{do_not_display}) {

		process_template(
			'web/pages/product/includes/nutriscore.tt.html',
			$template_data_nutriscore_and_nutrient_levels_ref,
			\$nutriscore_html
		) || return "template error: " . $tt->error();
		process_template(
			'web/pages/product/includes/nutrient_levels.tt.html',
			$template_data_nutriscore_and_nutrient_levels_ref,
			\$nutrient_levels_html
		) || return "template error: " . $tt->error();
	}

	if (
			($lc eq 'fr')
		and
		(has_tag($product_ref, "labels", "fr:produits-retires-du-marche-lors-du-scandale-lactalis-de-decembre-2017"))
		)
	{

		$html .= <<HTML
<div id="warning_lactalis_201712" style="display: block; background:#ffaa33;color:black;padding:1em;text-decoration:none;">
Ce produit fait partie d'une liste de produits retirés du marché, et a été étiqueté comme tel par un bénévole d'Open Food Facts.
<br><br>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
</div>
HTML
			;

	}
	elsif (
			($lc eq 'fr')
		and (has_tag($product_ref, "categories", "en:baby-milks"))
		and (
			has_one_of_the_tags_from_the_list(
				$product_ref,
				"brands",
				[
					"amilk", "babycare", "celia-ad", "celia-develop",
					"celia-expert", "celia-nutrition", "enfastar", "fbb",
					"fl", "frezylac", "gromore", "malyatko",
					"mamy", "milumel", "milumel", "neoangelac",
					"nophenyl", "novil", "ostricare", "pc",
					"picot", "sanutri"
				]
			)
		)
		)
	{

		$html .= <<HTML
<div id="warning_lactalis_201712" style="display: block; background:#ffcc33;color:black;padding:1em;text-decoration:none;">
Certains produits de cette marque font partie d'une liste de produits retirés du marché.
<br><br>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des produits et lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
</div>
HTML
			;

	}

	# Nutri-Score and nutrient levels

	$html .= $nutriscore_html;

	$html .= $nutrient_levels_html;

	# NOVA groups

	if ((exists $product_ref->{nova_group})) {
		my $group = $product_ref->{nova_group};

		my $display = display_taxonomy_tag($lc, "nova_groups", $product_ref->{nova_groups_tags}[0]);
		my $a_title = lang('nova_groups_info');

		$html .= <<HTML
<h4>$Lang{nova_groups_s}{$lc}
<a href="https://world.openfoodfacts.org/nova" title="${$a_title}">
@{[ display_icon('info') ]}</a>
</h4>


<a href="https://world.openfoodfacts.org/nova" title="${$a_title}"><img src="/images/misc/nova-group-$group.svg" alt="$display" style="margin-bottom:1rem;max-width:100%"></a><br>
$display
HTML
			;
	}

	my $minheight = 0;
	$product_ref->{jqm} = 1;
	my $html_image = display_image_box($product_ref, 'front', \$minheight);
	$html .= <<HTML
        <div data-role="deactivated-collapsible-set" data-theme="" data-content-theme="">
            <div data-role="deactivated-collapsible">
HTML
		;
	$html .= "<h2>" . lang("product_characteristics") . "</h2>
	<div style=\"min-height:${minheight}px;\">"
		. $html_image;

	foreach my $field (@fields) {
		# print STDERR "display_product() - field: $field - value: $product_ref->{$field}\n";
		$html .= display_field($product_ref, $field);
	}

	$html_image = display_image_box($product_ref, 'ingredients', \$minheight);

	# try to display ingredients in the local language

	my $ingredients_text = $product_ref->{ingredients_text};

	if (defined $product_ref->{ingredients_text_with_allergens}) {
		$ingredients_text = $product_ref->{ingredients_text_with_allergens};
	}

	if (    (defined $product_ref->{"ingredients_text" . "_" . $lc})
		and ($product_ref->{"ingredients_text" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $lc};
	}

	if (    (defined $product_ref->{"ingredients_text_with_allergens" . "_" . $lc})
		and ($product_ref->{"ingredients_text_with_allergens" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text_with_allergens" . "_" . $lc};
	}

	$ingredients_text =~ s/<span class="allergen">(.*?)<\/span>/<b>$1<\/b>/isg;

	$html .= "</div>";

	$html .= <<HTML
			</div>
		</div>
        <div data-role="deactivated-collapsible-set" data-theme="" data-content-theme="">
            <div data-role="deactivated-collapsible" data-collapsed="true">
HTML
		;

	$html .= "<h2>" . lang("ingredients") . "</h2>
	<div style=\"min-height:${minheight}px\">"
		. $html_image;

	$html .= "<p class=\"note\">&rarr; " . lang("ingredients_text_display_note") . "</p>";
	$html
		.= "<div id=\"ingredients_list\" ><span class=\"field\">"
		. lang("ingredients_text")
		. separator_before_colon($lc)
		. ":</span> $ingredients_text</div>";

	$html .= display_field($product_ref, 'allergens');

	$html .= display_field($product_ref, 'traces');

	my $class = 'additives';

	if ((defined $product_ref->{$class . '_tags'}) and (scalar @{$product_ref->{$class . '_tags'}} > 0)) {

		$html
			.= "<br><hr class=\"floatleft\"><div><b>" . lang("additives_p") . separator_before_colon($lc) . ":</b><br>";

		$html .= "<ul>";
		foreach my $tagid (@{$product_ref->{$class . '_tags'}}) {

			my $tag;
			my $link;

			# taxonomy field?
			if ($tagid =~ /:/) {
				$tag = display_taxonomy_tag($lc, $class, $tagid);
				$link = canonicalize_taxonomy_tag_link($lc, $class, $tagid);
			}
			else {
				$tag = canonicalize_tag2($class, $tagid);
				$link = canonicalize_tag_link($class, $tagid);
			}

			my $info = '';

			if ($class eq 'additives') {
				$tagid =~ s/.*://;    # levels are defined only in old French list

				if ($ingredients_classes{$class}{$tagid}{level} > 0) {
					$info
						= ' class="additives_'
						. $ingredients_classes{$class}{$tagid}{level}
						. '" title="'
						. $ingredients_classes{$class}{$tagid}{warning} . '" ';
				}
			}

			$html .= "<li><a href=\"" . $link . "\"$info>" . $tag . "</a></li>\n";
		}
		$html .= "</ul></div>";

	}

	# special ingredients tags

	if ((defined $ingredients_text) and ($ingredients_text !~ /^\s*$/s) and (defined $special_tags{ingredients})) {

		my $special_html = "";

		foreach my $special_tag_ref (@{$special_tags{ingredients}}) {

			my $tagid = $special_tag_ref->{tagid};
			my $type = $special_tag_ref->{type};

			if (   (($type eq 'without') and (not has_tag($product_ref, "ingredients", $tagid)))
				or (($type eq 'with') and (has_tag($product_ref, "ingredients", $tagid))))
			{

				$special_html
					.= "<li class=\"${type}_${tagid}_$lc\">"
					. lang("search_" . $type) . " "
					. display_taxonomy_tag_link($lc, "ingredients", $tagid)
					. "</li>\n";
			}

		}

		if ($special_html ne "") {

			$html
				.= "<br><hr class=\"floatleft\"><div><b>"
				. ucfirst(lang("ingredients_analysis") . separator_before_colon($lc))
				. ":</b><br>"
				. "<ul id=\"special_ingredients\">\n"
				. $special_html
				. "</ul>\n" . "<p>"
				. lang("ingredients_analysis_note")
				. "</p></div>\n";
		}

	}

	$html_image = display_image_box($product_ref, 'nutrition', \$minheight);

	$html .= "</div>";

	$html .= <<HTML
			</div>
		</div>
HTML
		;

	if (not((defined $options{no_nutrition_table}) and ($options{no_nutrition_table}))) {

		$html .= <<HTML
        <div data-role="deactivated-collapsible-set" data-theme="" data-content-theme="">
            <div data-role="deactivated-collapsible" data-collapsed="true">
HTML
			;

		$html .= "<h2>" . lang("nutrition_data") . "</h2>";

		# Nutri-Score and nutrient levels

		$html .= $nutriscore_html;

		$html .= $nutrient_levels_html;

		$html .= "<div style=\"min-height:${minheight}px\">" . $html_image;

		$html .= display_field($product_ref, "serving_size") . display_field($product_ref, "br");

		# Compare nutrition data with categories

		my @comparisons = ();

		if ($product_ref->{no_nutrition_data} eq 'on') {
			$html .= "<div class='panel callout'>$Lang{no_nutrition_data}{$lang}</div>";
		}

		$html .= display_nutrition_table($product_ref, \@comparisons);

		$html .= <<HTML
			</div>
		</div>
HTML
			;
	}

	my $created_date = display_date_tag($product_ref->{created_t});

	# Ask for photos if we do not have any, or if they are too old

	my $last_image = "";
	my $image_warning = "";

	if ((not defined($product_ref->{images})) or ((scalar keys %{$product_ref->{images}}) < 1)) {

		$image_warning = $Lang{product_has_no_photos}{$lang};

	}
	elsif ((defined $product_ref->{last_image_t}) and ($product_ref->{last_image_t} > 0)) {

		my $last_image_date = display_date($product_ref->{last_image_t});
		my $last_image_date_without_time = display_date_without_time($product_ref->{last_image_t});

		$last_image = "<br>" . "$Lang{last_image_added}{$lang} $last_image_date";

		# Was the last photo uploaded more than 6 months ago?

		if (($product_ref->{last_image_t} + 86400 * 30 * 6) < time()) {

			$image_warning = sprintf($Lang{product_has_old_photos}{$lang}, $last_image_date_without_time);

		}

	}

	if ($image_warning ne "") {

		$image_warning = <<HTML
<div id="image_warning" style="display: block; background:#ffcc33;color:black;padding:1em;text-decoration:none;">
$image_warning
</div>
HTML
			;

	}

	my $creator = $product_ref->{creator};

	# Remove links for iOS (issues with twitter / facebook badges loading in separate windows..)
	$html =~ s/<a ([^>]*)href="([^"]+)"([^>]*)>/<span $1$3>/g
		;    # replace with a span to keep class for color of additives etc.
	$html =~ s/<\/a>/<\/span>/g;
	$html =~ s/<span >/<span>/g;
	$html =~ s/<span  /<span /g;

	$html .= <<HTML

<p>
$Lang{product_added}{$lang} $created_date $Lang{by}{$lang} $creator
$last_image
</p>


<div style="margin-bottom:20px;">

<p>$Lang{fixme_product}{$lang}</p>

$image_warning

<p>$Lang{app_you_can_add_pictures}{$lang}</p>

<button onclick="captureImage();" data-icon="off-camera">$Lang{image_front}{$lang}</button>
<div id="upload_image_result_front"></div>
<button onclick="captureImage();" data-icon="off-camera">$Lang{image_ingredients}{$lang}</button>
<div id="upload_image_result_ingredients"></div>
<button onclick="captureImage();" data-icon="off-camera">$Lang{image_nutrition}{$lang}</button>
<div id="upload_image_result_nutrition"></div>
<button onclick="captureImage();" data-icon="off-camera">$Lang{app_take_a_picture}{$lang}</button>
<div id="upload_image_result"></div>
<p>$Lang{app_take_a_picture_note}{$lang}</p>

</div>
HTML
		;

	$request_ref->{jqm_content} = $html;
	$request_ref->{title} = $title;
	$request_ref->{description} = $description;

	$log->trace("displayed product on jquery mobile") if $log->is_trace();

	return;
}

=head2 display_nutriscore_calculation_details( $nutriscore_data_ref )

Generates HTML code with information on how the Nutri-Score was computed for a particular product.

For each component of the Nutri-Score (energy, sugars etc.) it shows the input value,
the rounded value according to the Nutri-Score rules, and the corresponding points.

=cut

sub display_nutriscore_calculation_details ($nutriscore_data_ref) {

	my $beverage_view;

	if ($nutriscore_data_ref->{is_beverage}) {
		$beverage_view = lang("nutriscore_is_beverage");
	}
	else {
		$beverage_view = lang("nutriscore_is_not_beverage");
	}

	# Select message that explains the reason why the proteins points have been counted or not

	my $nutriscore_protein_info;
	if ($nutriscore_data_ref->{negative_points} < 11) {
		$nutriscore_protein_info = lang("nutriscore_proteins_negative_points_less_than_11");
	}
	elsif ((defined $nutriscore_data_ref->{is_cheese}) and ($nutriscore_data_ref->{is_cheese})) {
		$nutriscore_protein_info = lang("nutriscore_proteins_is_cheese");
	}
	elsif (
		(
				((defined $nutriscore_data_ref->{is_beverage}) and ($nutriscore_data_ref->{is_beverage}))
			and ($nutriscore_data_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils_points} == 10)
		)
		or (    ((not defined $nutriscore_data_ref->{is_beverage}) or (not $nutriscore_data_ref->{is_beverage}))
			and ($nutriscore_data_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils_points} == 5))
		)
	{

		$nutriscore_protein_info = lang("nutriscore_proteins_maximum_fruits_points");
	}
	else {
		$nutriscore_protein_info = lang("nutriscore_proteins_negative_points_greater_or_equal_to_11");
	}

	# Generate a data structure that we will pass to the template engine

	my $template_data_ref = {

		beverage_view => $beverage_view,
		is_fat => $nutriscore_data_ref->{is_fat},

		nutriscore_protein_info => $nutriscore_protein_info,

		score => $nutriscore_data_ref->{score},
		grade => uc($nutriscore_data_ref->{grade}),
		positive_points => $nutriscore_data_ref->{positive_points},
		negative_points => $nutriscore_data_ref->{negative_points},

		# Details of positive and negative points, filled dynamically below
		# as the nutrients and thresholds are different for some products (beverages and fats)
		points_groups => []
	};

	my %points_groups = (
		"positive" => ["proteins", "fiber", "fruits_vegetables_nuts_colza_walnut_olive_oils"],
		"negative" => ["energy", "sugars", "saturated_fat", "sodium"],
	);

	foreach my $type ("positive", "negative") {

		# Initiate a data structure for the points of the group

		my $points_group_ref = {
			type => $type,
			points => $nutriscore_data_ref->{$type . "_points"},
			nutrients => [],
		};

		# Add the nutrients for the group
		foreach my $nutrient (@{$points_groups{$type}}) {

			my $nutrient_threshold_id = $nutrient;

			if (    (defined $nutriscore_data_ref->{is_beverage})
				and ($nutriscore_data_ref->{is_beverage})
				and (defined $points_thresholds{$nutrient_threshold_id . "_beverages"}))
			{
				$nutrient_threshold_id .= "_beverages";
			}
			if (($nutriscore_data_ref->{is_fat}) and ($nutrient eq "saturated_fat")) {
				$nutrient = "saturated_fat_ratio";
				$nutrient_threshold_id = "saturated_fat_ratio";
			}
			push @{$points_group_ref->{nutrients}},
				{
				id => $nutrient,
				points => $nutriscore_data_ref->{$nutrient . "_points"},
				maximum => scalar(@{$points_thresholds{$nutrient_threshold_id}}),
				value => $nutriscore_data_ref->{$nutrient},
				rounded => $nutriscore_data_ref->{$nutrient . "_value"},
				};
		}

		push @{$template_data_ref->{points_groups}}, $points_group_ref;
	}

	# Nutrition Score Calculation Template

	my $html;
	process_template('web/pages/product/includes/nutriscore_details.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

=head2 data_to_display_nutrient_levels ( $product_ref )

Generates a data structure to display the nutrient levels (food traffic lights).

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_nutrient_levels ($product_ref) {

	my $result_data_ref = {};

	# Do not display traffic lights for baby foods
	if (has_tag($product_ref, "categories", "en:baby-foods")) {

		$result_data_ref->{do_not_display} = 1;
	}

	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, coffee, tea)
	# unless we have nutrition data for the prepared product

	my $prepared = "";

	foreach my $category_tag ("en:dried-products-to-be-rehydrated",
		"en:chocolate-powders", "en:dessert-mixes", "en:flavoured-syrups")
	{

		if (has_tag($product_ref, "categories", $category_tag)) {

			if ((defined $product_ref->{nutriments}{"energy_prepared_100g"})) {
				$prepared = '_prepared';
				last;
			}
			else {
				$result_data_ref->{do_not_display} = 1;
			}
		}
	}

	if (not $result_data_ref->{do_not_display}) {

		$result_data_ref->{nutrient_levels} = [];

		foreach my $nutrient_level_ref (@nutrient_levels) {
			my ($nid, $low, $high) = @{$nutrient_level_ref};

			if ((defined $product_ref->{nutrient_levels}) and (defined $product_ref->{nutrient_levels}{$nid})) {

				push @{$result_data_ref->{nutrient_levels}}, {
					nid => $nid,
					nutrient_level => $product_ref->{nutrient_levels}{$nid},
					nutrient_quantity_in_grams =>
						sprintf("%.2e", $product_ref->{nutriments}{$nid . $prepared . "_100g"}) + 0.0,
					nutrient_in_quantity => sprintf(
						lang("nutrient_in_quantity"),
						display_taxonomy_tag($lc, "nutrients", "zz:$nid"),
						lang($product_ref->{nutrient_levels}{$nid} . "_quantity")
					),
					# Needed for the current display on product page, can be removed once transitioned fully to knowledge panels
					nutrient_bold_in_quantity => sprintf(
						lang("nutrient_in_quantity"),
						"<b>" . display_taxonomy_tag($lc, "nutrients", "zz:$nid") . "</b>",
						lang($product_ref->{nutrient_levels}{$nid} . "_quantity")
					),
				};
			}
		}
	}

	return $result_data_ref;
}

=head2 data_to_display_nutriscore ( $product_ref )

Generates a data structure to display the Nutri-Score.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_nutriscore($) {

	my $product_ref = shift;

	my $result_data_ref = {};

	# Nutri-Score data

	my @nutriscore_warnings = ();

	if ((defined $product_ref->{nutrition_grade_fr}) and ($product_ref->{nutrition_grade_fr} =~ /^[abcde]$/)) {

		$result_data_ref->{nutriscore_grade} = $product_ref->{"nutrition_grade_fr"};

		# Do not display a warning for water
		if (not(has_tag($product_ref, "categories", "en:spring-waters"))) {

			# Warning for nutrients estimated from ingredients
			if ($product_ref->{nutrition_score_warning_nutriments_estimated}) {
				push @nutriscore_warnings, lang("nutrition_grade_fr_nutriments_estimated_warning");
			}

			# Warning for tea and herbal tea in bags: state that the Nutri-Score applies
			# only when reconstituted with water only (no milk, no sugar)
			if (
				   (has_tag($product_ref, "categories", "en:tea-bags"))
				or (has_tag($product_ref, "categories", "en:herbal-teas-in-tea-bags"))
				# many tea bags are only under "en:teas", but there are also many tea beverages under "en:teas"
				or ((has_tag($product_ref, "categories", "en:teas"))
					and not(has_tag($product_ref, "categories", "en:tea-based-beverages")))
				)
			{
				push @nutriscore_warnings, lang("nutrition_grade_fr_tea_bags_note");
			}

			# Combined message when we miss both fruits and fiber
			if (    ($product_ref->{nutrition_score_warning_no_fiber})
				and (defined $product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts})
				and ($product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts} == 1))
			{
				push @nutriscore_warnings, lang("nutrition_grade_fr_fiber_and_fruits_vegetables_nuts_warning");
			}
			elsif ($product_ref->{nutrition_score_warning_no_fiber}) {
				push @nutriscore_warnings, lang("nutrition_grade_fr_fiber_warning");
			}
			elsif ($product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts}) {
				push @nutriscore_warnings, lang("nutrition_grade_fr_no_fruits_vegetables_nuts_warning");
			}

			if ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate}) {
				push @nutriscore_warnings,
					sprintf(
					lang("nutrition_grade_fr_fruits_vegetables_nuts_estimate_warning"),
					$product_ref->{nutriments}{"fruits-vegetables-nuts-estimate_100g"}
					);
			}
			if ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category}) {
				push @nutriscore_warnings,
					sprintf(
					lang("nutrition_grade_fr_fruits_vegetables_nuts_from_category_warning"),
					display_taxonomy_tag(
						$lc, 'categories', $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category}
					),
					$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category_value}
					);
			}
			if ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients}) {
				push @nutriscore_warnings,
					sprintf(
					lang("nutrition_grade_fr_fruits_vegetables_nuts_estimate_from_ingredients_warning"),
					$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients_value}
					);
			}
		}
	}
	# The Nutri-Score is unknown
	else {

		# Category without Nutri-Score: baby food, alcoholic beverages etc.
		if (has_tag($product_ref, "misc", "en:nutriscore-not-applicable")) {
			push @nutriscore_warnings, lang("nutriscore_not_applicable");
			$result_data_ref->{nutriscore_grade} = "not-applicable";
			$result_data_ref->{nutriscore_unknown_reason} = "not_applicable";
			$result_data_ref->{nutriscore_unknown_reason_short} = f_lang(
				"f_attribute_nutriscore_not_applicable_description",
				{
					category => display_taxonomy_tag_name(
						$lc, "categories",
						deep_get($product_ref, qw/nutriscore_data nutriscore_not_applicable_for_category/)
					)
				}
			);
		}
		else {

			$result_data_ref->{nutriscore_grade} = "unknown";

			# Missing category?
			if (has_tag($product_ref, "misc", "en:nutriscore-missing-category")) {
				push @nutriscore_warnings, lang("nutriscore_missing_category");
				$result_data_ref->{nutriscore_unknown_reason} = "missing_category";
				$result_data_ref->{nutriscore_unknown_reason_short} = lang("nutriscore_missing_category_short");
			}

			# Missing nutrition facts?
			if (has_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data")) {
				push @nutriscore_warnings, lang("nutriscore_missing_nutrition_data");
				if (not has_tag($product_ref, "misc", "en:nutriscore-missing-category")) {
					$result_data_ref->{nutriscore_unknown_reason} = "missing_nutrition_data";
					$result_data_ref->{nutriscore_unknown_reason_short}
						= lang("nutriscore_missing_nutrition_data_short");
				}
				else {
					$result_data_ref->{nutriscore_unknown_reason} = "missing_category_and_nutrition_data";
					$result_data_ref->{nutriscore_unknown_reason_short}
						= lang("nutriscore_missing_category_and_nutrition_data_short");
				}
			}
		}
	}

	if (@nutriscore_warnings > 0) {
		$result_data_ref->{nutriscore_warnings} = \@nutriscore_warnings;
	}

	# Display the details of the computation of the Nutri-Score if we computed one
	if ((defined $product_ref->{nutriscore_grade}) and ($product_ref->{nutriscore_grade} =~ /^[a-e]$/)) {
		$result_data_ref->{nutriscore_details}
			= display_nutriscore_calculation_details($product_ref->{nutriscore_data});
	}

	return $result_data_ref;
}

sub add_product_nutriment_to_stats ($nutriments_ref, $nid, $value) {

	if ((defined $value) and ($value ne '')) {

		if (not defined $nutriments_ref->{"${nid}_n"}) {
			$nutriments_ref->{"${nid}_n"} = 0;
			$nutriments_ref->{"${nid}_s"} = 0;
			$nutriments_ref->{"${nid}_array"} = [];
		}

		$nutriments_ref->{"${nid}_n"}++;
		$nutriments_ref->{"${nid}_s"} += $value + 0.0;
		push @{$nutriments_ref->{"${nid}_array"}}, $value + 0.0;

	}
	return 1;
}

sub compute_stats_for_products ($stats_ref, $nutriments_ref, $count, $n, $min_products, $id) {

	#my $stats_ref        ->    where we will store the stats
	#my $nutriments_ref   ->    values for some nutriments
	#my $count            ->    total number of products (including products that have no values for the nutriments we are interested in)
	#my $n                ->    number of products with defined values for specified nutriments
	#my $min_products     ->    min number of products needed to compute stats
	#my $id               ->    id (e.g. category id)

	$stats_ref->{stats} = 1;
	$stats_ref->{nutriments} = {};
	$stats_ref->{id} = $id;
	$stats_ref->{count} = $count;
	$stats_ref->{n} = $n;

	foreach my $nid (keys %{$nutriments_ref}) {
		next if $nid !~ /_n$/;
		$nid = $`;

		next if ($nutriments_ref->{"${nid}_n"} < $min_products);

		# Compute the mean and standard deviation, without the bottom and top 5% (so that huge outliers
		# that are likely to be errors in the data do not completely overweight the mean and std)

		my @values = sort {$a <=> $b} @{$nutriments_ref->{"${nid}_array"}};
		my $nb_values = $#values + 1;
		my $kept_values = 0;
		my $sum_of_kept_values = 0;

		my $i = 0;
		foreach my $value (@values) {
			$i++;
			next if ($i <= $nb_values * 0.05);
			next if ($i >= $nb_values * 0.95);
			$kept_values++;
			$sum_of_kept_values += $value;
		}

		my $mean_for_kept_values = $sum_of_kept_values / $kept_values;

		$nutriments_ref->{"${nid}_mean"} = $mean_for_kept_values;

		my $sum_of_square_differences_for_kept_values = 0;
		$i = 0;
		foreach my $value (@values) {
			$i++;
			next if ($i <= $nb_values * 0.05);
			next if ($i >= $nb_values * 0.95);
			$sum_of_square_differences_for_kept_values
				+= ($value - $mean_for_kept_values) * ($value - $mean_for_kept_values);
		}
		my $std_for_kept_values = sqrt($sum_of_square_differences_for_kept_values / $kept_values);

		$nutriments_ref->{"${nid}_std"} = $std_for_kept_values;

		$stats_ref->{nutriments}{"${nid}_n"} = $nutriments_ref->{"${nid}_n"};
		$stats_ref->{nutriments}{"$nid"} = $nutriments_ref->{"${nid}_mean"};
		$stats_ref->{nutriments}{"${nid}_100g"} = sprintf("%.2e", $nutriments_ref->{"${nid}_mean"}) + 0.0;
		$stats_ref->{nutriments}{"${nid}_std"} = sprintf("%.2e", $nutriments_ref->{"${nid}_std"}) + 0.0;

		if ($nid =~ /^energy/) {
			$stats_ref->{nutriments}{"${nid}_100g"} = int($stats_ref->{nutriments}{"${nid}_100g"} + 0.5);
			$stats_ref->{nutriments}{"${nid}_std"} = int($stats_ref->{nutriments}{"${nid}_std"} + 0.5);
		}

		$stats_ref->{nutriments}{"${nid}_min"} = sprintf("%.2e", $values[0]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_max"} = sprintf("%.2e", $values[$nutriments_ref->{"${nid}_n"} - 1]) + 0.0;
		#$stats_ref->{nutriments}{"${nid}_5"} = $nutriments_ref->{"${nid}_array"}[int ( ($nutriments_ref->{"${nid}_n"} - 1) * 0.05) ];
		#$stats_ref->{nutriments}{"${nid}_95"} = $nutriments_ref->{"${nid}_array"}[int ( ($nutriments_ref->{"${nid}_n"}) * 0.95) ];
		$stats_ref->{nutriments}{"${nid}_10"}
			= sprintf("%.2e", $values[int(($nutriments_ref->{"${nid}_n"} - 1) * 0.10)]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_90"}
			= sprintf("%.2e", $values[int(($nutriments_ref->{"${nid}_n"}) * 0.90)]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_50"}
			= sprintf("%.2e", $values[int(($nutriments_ref->{"${nid}_n"}) * 0.50)]) + 0.0;

		#print STDERR "-> lc: lc -category $tagid - count: $count - n: nutriments: " . $nn . "$n \n";
		#print "categories stats - cc: $cc - n: $n- values for category $id: " . join(", ", @values) . "\n";
		#print "tagid: $id - nid: $nid - 100g: " .  $stats_ref->{nutriments}{"${nid}_100g"}  . " min: " . $stats_ref->{nutriments}{"${nid}_min"} . " - max: " . $stats_ref->{nutriments}{"${nid}_max"} .
		#	"mean: " . $stats_ref->{nutriments}{"${nid}_mean"} . " - median: " . $stats_ref->{nutriments}{"${nid}_50"} . "\n";

	}

	return;
}

=head2 compare_product_nutrition_facts_to_categories ($product_ref, $target_cc, $max_number_of_categories)

Compares a product nutrition facts to average nutrition facts of each of its categories.

=head3 Arguments

=head4 Product reference $product_ref

=head4 Target country code $target_cc

=head4 Max number of categories $max_number_of_categories

If defined, we will limit the number of categories returned, and keep the most specific categories.

=head3 Return values

Reference to a comparisons data structure that can be passed to the data_to_display_nutrition_table() function.

=cut

sub compare_product_nutrition_facts_to_categories ($product_ref, $target_cc, $max_number_of_categories) {

	my @comparisons = ();

	if (
		(
			not(    (defined $product_ref->{not_comparable_nutrition_data})
				and ($product_ref->{not_comparable_nutrition_data}))
		)
		and (defined $product_ref->{categories_tags})
		and (scalar @{$product_ref->{categories_tags}} > 0)
		)
	{

		my $categories_nutriments_ref = $categories_nutriments_per_country{$target_cc};

		if (defined $categories_nutriments_ref) {

			foreach my $cid (@{$product_ref->{categories_tags}}) {

				if (    (defined $categories_nutriments_ref->{$cid})
					and (defined $categories_nutriments_ref->{$cid}{stats}))
				{

					push @comparisons,
						{
						id => $cid,
						name => display_taxonomy_tag($lc, 'categories', $cid),
						link => canonicalize_taxonomy_tag_link($lc, 'categories', $cid),
						nutriments => compare_nutriments($product_ref, $categories_nutriments_ref->{$cid}),
						count => $categories_nutriments_ref->{$cid}{count},
						n => $categories_nutriments_ref->{$cid}{n},
						};
				}
			}

			if ($#comparisons > -1) {
				@comparisons = sort {$a->{count} <=> $b->{count}} @comparisons;
				$comparisons[0]{show} = 1;
			}

			# Limit the number of categories returned
			if (defined $max_number_of_categories) {
				while (@comparisons > $max_number_of_categories) {
					pop @comparisons;
				}
			}
		}
	}

	return \@comparisons;
}

=head2 data_to_display_nutrition_table ( $product_ref, $comparisons_ref )

Generates a data structure to display a nutrition table.

The nutrition table can be the nutrition table of a product, or of a category (stats for the categories).

In the case of a product, extra columns can be added to compare the product nutrition facts to the average for its categories.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head4 Comparisons reference $product_ref

Reference to an array with nutrition facts for 1 or more categories.

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_nutrition_table ($product_ref, $comparisons_ref) {

	# This function populates a data structure that is used by the template to display the nutrition facts table
	my $template_data_ref = {

		nutrition_table => {
			id => "nutrition",
			header => {
				name => lang('nutrition_data_table'),
				columns => [],
			},
			rows => [],
		},
	};

	# List of columns
	my @cols = ();

	# Data for each column
	my %columns = ();

	# We can have data for the product as sold, and/or prepared
	my @displayed_product_types = ();
	my %displayed_product_types = ();

	if ((not defined $product_ref->{nutrition_data}) or ($product_ref->{nutrition_data})) {
		# by default, old products did not have a checkbox, display the nutrition data entry column for the product as sold
		push @displayed_product_types, "";
		$displayed_product_types{as_sold} = 1;
	}
	if ((defined $product_ref->{nutrition_data_prepared}) and ($product_ref->{nutrition_data_prepared} eq 'on')) {
		push @displayed_product_types, "prepared_";
		$displayed_product_types{prepared} = 1;
	}

	foreach my $product_type (@displayed_product_types) {

		my $nutrition_data_per = "nutrition_data" . "_" . $product_type . "per";

		my $col_name = lang("product_as_sold");
		if ($product_type eq 'prepared_') {
			$col_name = lang("prepared_product");
		}

		$columns{$product_type . "100g"} = {
			scope => "product",
			product_type => $product_type,
			per => "100g",
			name => $col_name . "<br>" . lang("nutrition_data_per_100g"),
			short_name => "100g",
		};
		$columns{$product_type . "serving"} = {
			scope => "product",
			product_type => $product_type,
			per => "serving",
			name => $col_name . "<br>" . lang("nutrition_data_per_serving"),
			short_name => lang("nutrition_data_per_serving"),
		};

		if ((defined $product_ref->{serving_size}) and ($product_ref->{serving_size} ne '')) {
			$columns{$product_type . "serving"}{name} .= ' (' . $product_ref->{serving_size} . ')';
		}

		if (not defined $product_ref->{$nutrition_data_per}) {
			$product_ref->{$nutrition_data_per} = '100g';
		}

		if ($product_ref->{$nutrition_data_per} eq 'serving') {

			if ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} > 0)) {
				if (($product_type eq "") and ($displayed_product_types{prepared})) {
					# do not display non prepared by portion if we have data for the prepared product
					# -> the portion size is for the prepared product
					push @cols, $product_type . '100g';
				}
				else {
					push @cols, ($product_type . '100g', $product_type . 'serving');
				}
			}
			else {
				push @cols, $product_type . 'serving';
			}
		}
		else {
			if ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} > 0)) {
				if (($product_type eq "") and ($displayed_product_types{prepared})) {
					# do not display non prepared by portion if we have data for the prepared product
					# -> the portion size is for the prepared product
					push @cols, $product_type . '100g';
				}
				else {
					push @cols, ($product_type . '100g', $product_type . 'serving');
				}
			}
			else {
				push @cols, $product_type . '100g';
			}
		}
	}

	# Comparisons with other products, categories, recommended daily values etc.

	if ((defined $comparisons_ref) and (scalar @{$comparisons_ref} > 0)) {

		# Add a comparisons array to the template data structure

		$template_data_ref->{comparisons} = [];

		my $i = 0;

		foreach my $comparison_ref (@{$comparisons_ref}) {

			my $col_id = "compare_" . $i;

			push @cols, $col_id;

			$columns{$col_id} = {
				"scope" => "comparisons",
				"name" => lang("compared_to") . lang("sep") . ": " . $comparison_ref->{name},
				"class" => $col_id,
			};

			$log->debug("displaying nutrition table comparison column",
				{colid => $col_id, id => $comparison_ref->{id}, name => $comparison_ref->{name}})
				if $log->is_debug();

			my $checked = 0;
			if (defined $comparison_ref->{show}) {
				$checked = 1;
			}
			else {
				$styles .= <<CSS
.$col_id { display:none }
CSS
					;
			}

			my $checked_html = "";
			if ($checked) {
				$checked_html = ' checked="checked"';
			}

			push @{$template_data_ref->{comparisons}},
				{
				col_id => $col_id,
				checked => $checked,
				name => $comparison_ref->{name},
				link => $comparison_ref->{link},
				count => $comparison_ref->{count},
				};

			$i++;
		}
	}

	# Stats for categories

	if (defined $product_ref->{stats}) {

		foreach my $col_id ('std', 'min', '10', '50', '90', 'max') {
			push @cols, $col_id;
			$columns{$col_id} = {
				"scope" => "categories",
				"name" => lang("nutrition_data_per_" . $col_id),
				"class" => "stats",
			};
		}

		if ($product_ref->{id} ne 'search') {

			# Show checkbox to display/hide stats for the category

			$template_data_ref->{category_stats} = 1;
		}
	}

	# Data for the nutrition table header

	foreach my $col_id (@cols) {

		$columns{$col_id}{col_id} = $col_id;
		push(@{$template_data_ref->{nutrition_table}{header}{columns}}, $columns{$col_id});

	}

	# Data for the nutrition table body

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if (($nid =~ /_/) and ($nid !~ /_prepared$/));

		$nid =~ s/_prepared$//;

		if (    (not exists_taxonomy_tag("nutrients", "zz:$nid"))
			and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid}))
		{
			push @unknown_nutriments, $nid;
			$seen_unknown_nutriments{$nid} = 1;
		}
	}

	# Display estimate of fruits, vegetables, nuts from the analysis of the ingredients list
	my @nutriments = ();
	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments) {
		push @nutriments, $nutriment;
		if (($nutriment eq "fruits-vegetables-nuts-estimate-")) {
			push @nutriments, "fruits-vegetables-nuts-estimate-from-ingredients-";
		}
	}

	my $decf = get_decimal_formatter($lc);
	my $perf = get_percent_formatter($lc, 0);

	foreach my $nutriment (@nutriments) {

		next if $nutriment =~ /^\#/;
		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		next if $nid eq 'sodium';

		# Skip "energy-kcal" and "energy-kj" as we will display "energy" which has both
		next if (($nid eq "energy-kcal") or ($nid eq "energy-kj"));

		# Determine if the nutrient should be shown
		my $shown = 0;

		# Check if we have a value for the nutrient
		my $is_nutrient_with_value = (
			((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne ''))
				or ((defined $product_ref->{nutriments}{$nid . "_100g"})
				and ($product_ref->{nutriments}{$nid . "_100g"} ne ''))
				or ((defined $product_ref->{nutriments}{$nid . "_prepared"})
				and ($product_ref->{nutriments}{$nid . "_prepared"} ne ''))
				or ((defined $product_ref->{nutriments}{$nid . "_modifier"})
				and ($product_ref->{nutriments}{$nid . "_modifier"} eq '-'))
				or ((defined $product_ref->{nutriments}{$nid . "_prepared_modifier"})
				and ($product_ref->{nutriments}{$nid . "_prepared_modifier"} eq '-'))
		);

		# Show rows that are not optional (id with a trailing -), or for which we have a value
		if (($nutriment !~ /-$/) or $is_nutrient_with_value) {
			$shown = 1;
		}

		# Hide rows that are not important when we don't have a value
		if ((($nutriment !~ /^!/) or ($product_ref->{id} eq 'search'))
			and not($is_nutrient_with_value))
		{
			$shown = 0;
		}

		# Show the UK nutrition score only if the country is matching
		# Always show the FR nutrition score (Nutri-Score)

		if ($nid =~ /^nutrition-score-(.*)$/) {
			# Always show the FR score and Nutri-Score
			if (($cc ne $1) and (not($1 eq 'fr'))) {
				$shown = 0;
			}

			# 2021-12: now not displaying the Nutrition scores and Nutri-Score in nutrition facts table (experimental)
			$shown = 0;
		}

		if ($shown) {

			# Level of the nutrient: 0 for main nutrients, 1 for sub-nutrients, 2 for sub-sub-nutrients
			my $level = 0;

			if ($nutriment =~ /^!?-/) {
				$level = 1;
				if ($nutriment =~ /^!?--/) {
					$level = 2;
				}
			}

			# Name of the nutrient

			my $name;
			my $unit = "g";

			if (exists_taxonomy_tag("nutrients", "zz:$nid")) {
				$name = display_taxonomy_tag($lc, "nutrients", "zz:$nid");
				$unit = get_property("nutrients", "zz:$nid", "unit:en") // 'g';
			}
			else {
				if (defined $product_ref->{nutriments}{$nid . "_label"}) {
					$name = $product_ref->{nutriments}{$nid . "_label"};
				}
				if (defined $product_ref->{nutriments}{$nid . "_unit"}) {
					$unit = $product_ref->{nutriments}{$nid . "_unit"};
				}
			}
			my @columns;
			my @extra_row_columns;

			my $extra_row = 0;    # Some rows will trigger an extra row (e.g. Salt adds Sodium)

			foreach my $col_id (@cols) {

				my $values;    # Value for row
				my $values2;    # Value for extra row (e.g. after the row for salt, we add an extra row for sodium)
				my $col_class = $columns{$col_id}{class};
				my $percent;
				my $percent_numeric_value;

				my $rdfa = '';    # RDFA property for row
				my $rdfa2 = '';    # RDFA property for extra row

				my $col_type;

				if ($col_id =~ /compare_(.*)/) {    #comparisons

					$col_type = "comparison";

					my $comparison_ref = $comparisons_ref->[$1];

					my $value = "";
					if (defined $comparison_ref->{nutriments}{$nid . "_100g"}) {
						# energy-kcal is already in kcal
						if ($nid eq 'energy-kcal') {
							$value = $comparison_ref->{nutriments}{$nid . "_100g"};
						}
						else {
							$value = $decf->format(g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, $unit));
						}
					}
					# too small values are converted to e notation: 7.18e-05
					if (($value . ' ') =~ /e/) {
						# use %f (outputs extras 0 in the general case)
						$value = sprintf("%f", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, $unit));
					}

					# 0.045 g	0.0449 g

					$values = "$value $unit";
					if (   (not defined $comparison_ref->{nutriments}{$nid . "_100g"})
						or ($comparison_ref->{nutriments}{$nid . "_100g"} eq ''))
					{
						$values = '?';
					}
					elsif (($nid eq "energy") or ($nid eq "energy-from-fat")) {
						# Use the actual value in kcal if we have it
						my $value_in_kcal;
						if (defined $comparison_ref->{nutriments}{$nid . "-kcal" . "_100g"}) {
							$value_in_kcal = $comparison_ref->{nutriments}{$nid . "-kcal" . "_100g"};
						}
						# Otherwise convert the value in kj
						else {
							$value_in_kcal = g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, 'kcal');
						}
						$values .= "<br>(" . sprintf("%d", $value_in_kcal) . ' kcal)';
					}

					$percent = $comparison_ref->{nutriments}{"${nid}_100g_%"};
					if ((defined $percent) and ($percent ne '')) {

						$percent_numeric_value = $percent;
						$percent = $perf->format($percent / 100.0);
						# issue 2273 -  minus signs are rendered with different characters in different locales, e.g. Finnish
						# so just test positivity of numeric value
						if ($percent_numeric_value > 0) {
							$percent = "+" . $percent;
						}
						# If percent is close to 0, just put "-"
						if (sprintf("%.0f", $percent_numeric_value) eq "0") {
							$percent = "-";
						}
					}
					else {
						$percent = undef;
					}

					if ($nid eq 'sodium') {
						if (   (not defined $comparison_ref->{nutriments}{$nid . "_100g"})
							or ($comparison_ref->{nutriments}{$nid . "_100g"} eq ''))
						{
							$values2 = '?';
						}
						else {
							$values2
								= ($decf->format(g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"} * 2.5, $unit)))
								. " "
								. $unit;
						}
					}
					elsif ($nid eq 'salt') {
						if (   (not defined $comparison_ref->{nutriments}{$nid . "_100g"})
							or ($comparison_ref->{nutriments}{$nid . "_100g"} eq ''))
						{
							$values2 = '?';
						}
						else {
							$values2
								= ($decf->format(g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"} / 2.5, $unit)))
								. " "
								. $unit;
						}
					}
					elsif ($nid eq 'nutrition-score-fr') {
						# We need to know the category in order to select the right thresholds for the nutrition grades
						# as it depends on whether it is food or drink

						# if it is a category stats, the category id is the id field
						if (    (not defined $product_ref->{categories_tags})
							and (defined $product_ref->{id})
							and ($product_ref->{id} =~ /^en:/))
						{
							$product_ref->{categories} = $product_ref->{id};
							compute_field_tags($product_ref, "en", "categories");
						}

						if (defined $product_ref->{categories_tags}) {

							my $nutriscore_grade = compute_nutriscore_grade(
								$product_ref->{nutriments}{$nid . "_100g"},
								is_beverage_for_nutrition_score($product_ref),
								is_water_for_nutrition_score($product_ref)
							);

							$values2 = uc($nutriscore_grade);
						}
					}
				}
				else {
					$col_type = "normal";
					my $value_unit = "";

					# Nutriscore: per serving = per 100g
					if (($nid =~ /(nutrition-score(-\w\w)?)/)) {
						# same Nutri-Score for 100g / serving and prepared / as sold
						$product_ref->{nutriments}{$nid . "_" . $col_id} = $product_ref->{nutriments}{$1 . "_100g"};
					}

					# We need to know if the column corresponds to a prepared value, in order to be able to retrieve the right modifier
					my $prepared = '';
					if ($col_id =~ /prepared/) {
						$prepared = "_prepared";
					}

					if (   (not defined $product_ref->{nutriments}{$nid . "_" . $col_id})
						or ($product_ref->{nutriments}{$nid . "_" . $col_id} eq ''))
					{
						if (    (defined $product_ref->{nutriments}{$nid . $prepared . "_modifier"})
							and ($product_ref->{nutriments}{$nid . $prepared . "_modifier"} eq '-'))
						{
							# The nutrient is not indicated on the package, display a minus sign
							$value_unit = '-';
						}
						else {
							$value_unit = '?';
						}
					}
					else {

						# this is the actual value on the package, not a computed average. do not try to round to 2 decimals.
						my $value;

						# energy-kcal is already in kcal
						if ($nid eq 'energy-kcal') {
							$value = $product_ref->{nutriments}{$nid . "_" . $col_id};
						}
						else {
							$value = $decf->format(g_to_unit($product_ref->{nutriments}{$nid . "_" . $col_id}, $unit));
						}

						# too small values are converted to e notation: 7.18e-05
						if (($value . ' ') =~ /e/) {
							# use %f (outputs extras 0 in the general case)
							$value = sprintf("%f", g_to_unit($product_ref->{nutriments}{$nid . "_" . $col_id}, $unit));
						}

						$value_unit = "$value $unit";

						if (defined $product_ref->{nutriments}{$nid . $prepared . "_modifier"}) {
							$value_unit
								= $product_ref->{nutriments}{$nid . $prepared . "_modifier"} . " " . $value_unit;
						}

						if (($nid eq "energy") or ($nid eq "energy-from-fat")) {
							# Use the actual value in kcal if we have it
							my $value_in_kcal;
							if (defined $product_ref->{nutriments}{$nid . "-kcal" . "_" . $col_id}) {
								$value_in_kcal = $product_ref->{nutriments}{$nid . "-kcal" . "_" . $col_id};
							}
							# Otherwise convert the value in kj
							else {
								$value_in_kcal = g_to_unit($product_ref->{nutriments}{$nid . "_" . $col_id}, 'kcal');
							}
							$value_unit .= "<br>(" . sprintf("%d", $value_in_kcal) . ' kcal)';
						}
					}

					if ($nid eq 'sodium') {
						my $salt;
						if (defined $product_ref->{nutriments}{$nid . "_" . $col_id}) {
							$salt = $product_ref->{nutriments}{$nid . "_" . $col_id} * 2.5;
						}
						if (exists $product_ref->{nutriments}{"salt" . "_" . $col_id}) {
							$salt = $product_ref->{nutriments}{"salt" . "_" . $col_id};
						}
						if (defined $salt) {
							$salt = $decf->format(g_to_unit($salt, $unit));
							if ($col_id eq '100g') {
								$rdfa2 = "property=\"food:saltEquivalentPer100g\" content=\"$salt\"";
							}
							$salt .= " " . $unit;
						}
						else {
							$salt = "?";
						}
						$values2 = $salt;
					}
					elsif ($nid eq 'salt') {
						my $sodium;
						if (defined $product_ref->{nutriments}{$nid . "_" . $col_id}) {
							$sodium = $product_ref->{nutriments}{$nid . "_" . $col_id} / 2.5;
						}
						if (exists $product_ref->{nutriments}{"sodium" . "_" . $col_id}) {
							$sodium = $product_ref->{nutriments}{"sodium" . "_" . $col_id};
						}
						if (defined $sodium) {
							$sodium = $decf->format(g_to_unit($sodium, $unit));
							if ($col_id eq '100g') {
								$rdfa2 = "property=\"food:sodiumEquivalentPer100g\" content=\"$sodium\"";
							}
							$sodium .= " " . $unit;
						}
						else {
							$sodium = "?";
						}
						$values2 = $sodium;
					}
					elsif ($nid eq 'nutrition-score-fr') {
						# We need to know the category in order to select the right thresholds for the nutrition grades
						# as it depends on whether it is food or drink

						# if it is a category stats, the category id is the id field
						if (    (not defined $product_ref->{categories_tags})
							and (defined $product_ref->{id})
							and ($product_ref->{id} =~ /^en:/))
						{
							$product_ref->{categories} = $product_ref->{id};
							compute_field_tags($product_ref, "en", "categories");
						}

						if (defined $product_ref->{categories_tags}) {

							if ($col_id ne "std") {

								my $nutriscore_grade = compute_nutriscore_grade(
									$product_ref->{nutriments}{$nid . "_" . $col_id},
									is_beverage_for_nutrition_score($product_ref),
									is_water_for_nutrition_score($product_ref)
								);

								$values2 = uc($nutriscore_grade);
							}
						}
					}
					elsif ($col_id eq $product_ref->{nutrition_data_per}) {
						# % DV ?
						if (    (defined $product_ref->{nutriments}{$nid . "_value"})
							and (defined $product_ref->{nutriments}{$nid . "_unit"})
							and ($product_ref->{nutriments}{$nid . "_unit"} eq '% DV'))
						{
							$value_unit
								.= ' ('
								. $product_ref->{nutriments}{$nid . "_value"} . ' '
								. $product_ref->{nutriments}{$nid . "_unit"} . ')';
						}
					}

					if (($col_id eq '100g') and (defined $product_ref->{nutriments}{$nid . "_" . $col_id})) {
						my $property = $nid;
						$property =~ s/-([a-z])/ucfirst($1)/eg;
						$property .= "Per100g";
						$rdfa = " property=\"food:$property\" content=\""
							. $product_ref->{nutriments}{$nid . "_" . $col_id} . "\"";
					}

					$values = $value_unit;
				}

				my $cell_data_ref = {
					value => $values,
					rdfa => $rdfa,
					class => $col_class,
					percent => $percent,
					type => $col_type,
				};

				# Add evaluation
				if (defined $percent_numeric_value) {

					my $nutrient_evaluation = get_property("nutrients", "zz:$nid", "evaluation:en")
						;    # Whether the nutrient is considered good or not

					# Determine if the value of this nutrient compared to other products is good or not

					if (defined $nutrient_evaluation) {

						if (   (($nutrient_evaluation eq "good") and ($percent_numeric_value >= 10))
							or (($nutrient_evaluation eq "bad") and ($percent_numeric_value <= -10)))
						{
							$cell_data_ref->{evaluation} = "good";
						}
						elsif ((($nutrient_evaluation eq "bad") and ($percent_numeric_value >= 10))
							or (($nutrient_evaluation eq "good") and ($percent_numeric_value <= -10)))
						{
							$cell_data_ref->{evaluation} = "bad";
						}
					}
				}

				push(@columns, $cell_data_ref);

				push(
					@extra_row_columns,
					{
						value => $values2,
						rdfa => $rdfa2,
						class => $col_class,
						percent => $percent,
						type => $col_type,
					}
				);

				if (defined $values2) {
					$extra_row = 1;
				}
			}

			# Add the row data to the template
			push @{$template_data_ref->{nutrition_table}{rows}},
				{
				nid => $nid,
				level => $level,
				name => $name,
				columns => \@columns,
				};

			# Add an extra row for specific nutrients
			# 2021-12: There may not be a lot of value to display an extra sodium or salt row,
			# tentatively disabling it. Keeping code in place in case we want to re-enable it under some conditions.
			if (0 and (defined $extra_row)) {
				if ($nid eq 'sodium') {

					push @{$template_data_ref->{nutrition_table}{rows}},
						{
						name => lang("salt_equivalent"),
						nid => "salt_equivalent",
						level => 1,
						columns => \@extra_row_columns,
						};
				}
				elsif ($nid eq 'salt') {

					push @{$template_data_ref->{nutrition_table}{rows}},
						{
						name => display_taxonomy_tag($lc, "nutrients", "zz:sodium"),
						nid => "sodium",
						level => 1,
						columns => \@extra_row_columns,
						};
				}
				elsif ($nid eq 'nutrition-score-fr') {

					push @{$template_data_ref->{nutrition_table}{rows}},
						{
						name => "Nutri-Score",
						nid => "nutriscore",
						level => 1,
						columns => \@extra_row_columns,
						};
				}
			}
		}
	}

	return $template_data_ref;
}

=head2 display_nutrition_table ( $product_ref, $comparisons_ref )

Generates HTML to display a nutrition table.

Use  data produced by data_to_display_nutrition_table

=head3 Arguments

=head4 Product reference $product_ref

=head4 Comparisons reference $product_ref

Reference to an array with nutrition facts for 1 or more categories.

=head3 Return values

HTML for the nutrition table.

=cut

sub display_nutrition_table ($product_ref, $comparisons_ref) {

	my $html = '';

	my $template_data_ref = data_to_display_nutrition_table($product_ref, $comparisons_ref);

	process_template('web/pages/product/includes/nutrition_facts_table.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

=head2 display_preferences_api ( $target_lc )

Return a JSON structure with all available preference values for attributes.

This is used by clients that ask for user preferences to personalize
filtering and ranking based on product attributes.

=head3 Arguments

=head4 request object reference $request_ref

=head4 language code $target_lc

Sets the desired language for the user facing strings.

=cut

sub display_preferences_api ($request_ref, $target_lc) {

	if (not defined $target_lc) {
		$target_lc = $lc;
	}

	$request_ref->{structured_response} = [];

	foreach my $preference ("not_important", "important", "very_important", "mandatory") {

		my $preference_ref = {
			id => $preference,
			name => lang("preference_" . $preference),
		};

		if ($preference eq "important") {
			$preference_ref->{factor} = 1;
		}
		elsif ($preference eq "very_important") {
			$preference_ref->{factor} = 2;
		}
		elsif ($preference eq "mandatory") {
			$preference_ref->{factor} = 4;
			$preference_ref->{minimum_match} = 20;
		}

		push @{$request_ref->{structured_response}}, $preference_ref;
	}

	display_structured_response($request_ref);

	return;
}

=head2 display_attribute_groups_api ( $request_ref, $target_lc )

Return a JSON structure with all available attribute groups and attributes,
with strings (names, descriptions etc.) in a specific language,
and return them in an array of attribute groups.

This is used in particular for clients of the API to know which
preferences they can ask users for, and then use for personalized
filtering and ranking.

=head3 Arguments

=head4 request object reference $request_ref

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=cut

sub display_attribute_groups_api ($request_ref, $target_lc) {

	if (not defined $target_lc) {
		$target_lc = $lc;
	}

	my $attribute_groups_ref = list_attributes($target_lc);

	# Add default preferences
	if (defined $options{attribute_default_preferences}) {
		foreach my $attribute_group_ref (@$attribute_groups_ref) {
			foreach my $attribute_ref (@{$attribute_group_ref->{attributes}}) {
				if (defined $options{attribute_default_preferences}{$attribute_ref->{id}}) {
					$attribute_ref->{default} = $options{attribute_default_preferences}{$attribute_ref->{id}};
				}
			}
		}
	}

	$request_ref->{structured_response} = $attribute_groups_ref;

	display_structured_response($request_ref);

	return;
}

=head2 display_taxonomy_api ( $request_ref )

Generate an extract of a taxonomy for specific tags, fields and languages,
and return it as a JSON object.

Accessed through the /api/v2/taxonomy API

e.g. https://world.openfoodfacts.org/api/v2/taxonomy?type=labels&tags=en:organic,en:fair-trade&fields=name,description,children&include_children=1&lc=en,fr

=head3 Arguments

=head4 request object reference $request_ref

=cut

sub display_taxonomy_api ($request_ref) {

	my $tagtype = single_param('tagtype');
	my $tags = single_param('tags');
	my @tags = split(/,/, $tags);

	my $options_ref = {};

	foreach my $field (qw(fields include_children include_parents include_root_entries)) {
		if (defined single_param($field)) {
			$options_ref->{$field} = single_param($field);
		}
	}

	my $taxonomy_ref = generate_tags_taxonomy_extract($tagtype, \@tags, $options_ref, \@lcs);

	$request_ref->{structured_response} = $taxonomy_ref;

	display_structured_response($request_ref);

	return;
}

sub display_product_api ($request_ref) {

	# Is a sample product requested?
	if ((defined $request_ref->{code}) and ($request_ref->{code} eq "example")) {

		$request_ref->{code}
			= $options{"sample_product_code_country_${cc}_language_${lc}"}
			|| $options{"sample_product_code_country_${cc}"}
			|| $options{"sample_product_code_language_${lc}"}
			|| $options{"sample_product_code"}
			|| "";
	}

	my $code = normalize_code($request_ref->{code});
	my $product_id = product_id_for_owner($Owner_id, $code);

	# Check that the product exist, is published, is not deleted, and has not moved to a new url

	$log->debug("display_product_api", {code => $code, params => {CGI::Vars()}}) if $log->is_debug();

	my %response = ();

	$response{code} = $code;

	my $product_ref;

	my $rev = single_param("rev");
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision") if $log->is_info();
		$product_ref = retrieve_product_rev($product_id, $rev);
	}
	else {
		$product_ref = retrieve_product($product_id);
	}

	if ($code !~ /^\d{4,24}$/) {

		$log->info("invalid code", {code => $code, original_code => $request_ref->{code}}) if $log->is_info();
		$response{status} = 0;
		$response{status_verbose} = 'no code or invalid code';
	}
	elsif ((not defined $product_ref) or (not defined $product_ref->{code})) {
		if ($request_ref->{api_version} >= 1) {
			$request_ref->{status_code} = 404;
		}
		$response{status} = 0;
		$response{status_verbose} = 'product not found';
		if (single_param("jqm")) {
			$response{jqm} = <<HTML
$Lang{app_please_take_pictures}{$lang}
<button onclick="captureImage();" data-icon="off-camera">$Lang{app_take_a_picture}{$lang}</button>
<div id="upload_image_result"></div>
<p>$Lang{app_take_a_picture_note}{$lang}</p>
HTML
				;
			if ($request_ref->{api_version} >= 0.1) {

				my @app_fields = qw(product_name brands quantity);

				my $html = <<HTML
<form id="product_fields" action="javascript:void(0);">
<div data-role="fieldcontain" class="ui-hide-label" style="border-bottom-width: 0;">
HTML
					;
				foreach my $field (@app_fields) {

					# placeholder in value
					my $value = $Lang{$field}{$lang};

					$html .= <<HTML
<label for="$field">$Lang{$field}{$lang}</label>
<input type="text" name="$field" id="$field" value="" placeholder="$value">
HTML
						;
				}

				$html .= <<HTML
</div>
<div id="save_button">
<input type="submit" id="save" name="save" value="$Lang{save}{$lang}">
</div>
<div id="saving" style="display:none">
<img src="loading2.gif" style="margin-right:10px"> $Lang{saving}{$lang}
</div>
<div id="saved" style="display:none">
$Lang{saved}{$lang}
</div>
<div id="not_saved" style="display:none">
$Lang{not_saved}{$lang}
</div>
</form>
HTML
					;
				$response{jqm} .= $html;

			}
		}
	}
	else {
		$response{status} = 1;
		$response{status_verbose} = 'product found';

		add_images_urls_to_product($product_ref, $lc);

		$response{product} = $product_ref;

		# If the request specified a value for the fields parameter, return only the fields listed

		my $customized_product_ref
			= customize_response_for_product($request_ref, $product_ref, single_param('fields') || 'all');

		# 2019-05-10: the OFF Android app expects the _serving fields to always be present, even with a "" value
		# the "" values have been removed
		# -> temporarily add back the _serving "" values
		if ((user_agent =~ /Official Android App/) or (user_agent =~ /okhttp/)) {
			if (defined $customized_product_ref->{nutriments}) {
				foreach my $nid (keys %{$customized_product_ref->{nutriments}}) {
					next if ($nid =~ /_/);
					if (    (defined $customized_product_ref->{nutriments}{$nid . "_100g"})
						and (not defined $customized_product_ref->{nutriments}{$nid . "_serving"}))
					{
						$customized_product_ref->{nutriments}{$nid . "_serving"} = "";
					}
					if (    (defined $customized_product_ref->{nutriments}{$nid . "_serving"})
						and (not defined $customized_product_ref->{nutriments}{$nid . "_100g"}))
					{
						$customized_product_ref->{nutriments}{$nid . "_100g"} = "";
					}
				}
			}
		}

		$response{product} = $customized_product_ref;

		# Disable nested ingredients in ingredients field (bug #2883)

		# 2021-02-25: we now store only nested ingredients, flatten them if the API is <= 1

		if ($request_ref->{api_version} <= 1) {

			if (defined $product_ref->{ingredients}) {

				flatten_sub_ingredients($product_ref);

				foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {
					# Delete sub-ingredients, keep only flattened ingredients
					exists $ingredient_ref->{ingredients} and delete $ingredient_ref->{ingredients};
				}
			}
		}

		# Return blame information
		if (single_param("blame")) {
			my $path = product_path_from_id($product_id);
			my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
			if (not defined $changes_ref) {
				$changes_ref = [];
			}
			$response{blame} = {};
			compute_product_history_and_completeness($data_root, $product_ref, $changes_ref, $response{blame});
		}

		if (single_param("jqm")) {
			# return a jquerymobile page for the product

			display_product_jqm($request_ref);
			$response{jqm} = $request_ref->{jqm_content};
			$response{jqm} =~ s/(href|src)=("\/)/$1="https:\/\/$cc.${server_domain}\//g;
			$response{title} = $request_ref->{title};
		}
	}

	$request_ref->{structured_response} = \%response;

	display_structured_response($request_ref);

	return;
}

sub display_rev_info ($product_ref, $rev) {

	my $code = $product_ref->{code};

	my $path = product_path($product_ref);
	my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
	if (not defined $changes_ref) {
		return '';
	}

	my $change_ref = $changes_ref->[$rev - 1];

	my $date = display_date_tag($change_ref->{t});
	my $userid = get_change_userid_or_uuid($change_ref);
	my $user = display_tag_link('editors', $userid);
	my $previous_link = qw{};
	my $product_url = product_url($product_ref);
	if ($rev > 1) {
		$previous_link = $product_url . '?rev=' . ($rev - 1);
	}

	my $next_link = qw{};
	if ($rev < scalar @{$changes_ref}) {
		$next_link = $product_url . '?rev=' . ($rev + 1);
	}

	my $comment = _format_comment($change_ref->{comment});

	my $template_data_ref = {
		lang => \&lang,
		rev_number => $rev,
		date => $date,
		user => $user,
		comment => $comment,
		previous_link => $previous_link,
		current_link => $product_url,
		next_link => $next_link,
	};

	my $html;
	process_template('web/pages/product/includes/display_rev_info.tt.html', $template_data_ref, \$html)
		|| return 'template error: ' . $tt->error();
	return $html;

}

sub display_product_history ($code, $product_ref) {

	if ($product_ref->{rev} <= 0) {
		return;
	}

	my $path = product_path($product_ref);
	my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
	if (not defined $changes_ref) {
		$changes_ref = [];
	}

	my $current_rev = $product_ref->{rev};
	my @revisions = ();

	foreach my $change_ref (reverse @{$changes_ref}) {

		my $userid = get_change_userid_or_uuid($change_ref);
		my $comment = _format_comment($change_ref->{comment});

		my $change_rev = $change_ref->{rev};

		if (not defined $change_rev) {
			$change_rev = $current_rev;
		}

		$current_rev--;

		push @revisions,
			{
			number => $change_rev,
			date => display_date_tag($change_ref->{t}),
			userid => $userid,
			diffs => compute_changes_diff_text($change_ref),
			comment => $comment
			};

	}

	my $template_data_ref = {
		lang => \&lang,
		display_editor_link => sub ($uid) {
			return display_tag_link('editors', $uid);
		},
		this_product_url => product_url($product_ref),
		revisions => \@revisions
	};

	my $html;
	process_template('web/pages/product/includes/edit_history.tt.html', $template_data_ref, \$html)
		|| return 'template error: ' . $tt->error();
	return $html;

}

sub display_structured_response ($request_ref) {
	# directly serve structured data from $request_ref->{structured_response}

	$log->debug(
		"Displaying structured response",
		{
			json => single_param("json"),
			jsonp => single_param("jsonp"),
			xml => single_param("xml"),
			jqm => single_param("jqm"),
			rss => scalar $request_ref->{rss}
		}
	) if $log->is_debug();

	if (single_param("xml")) {

		# my $xs = XML::Simple->new(NoAttr => 1, NumericEscape => 2);
		my $xs = XML::Simple->new(NumericEscape => 2);

		# without NumericEscape => 2, the output should be UTF-8, but is in fact completely garbled
		# e.g. <categories>Frais,Produits laitiers,Desserts,Yaourts,Yaourts aux fruits,Yaourts sucrurl>http://static.openfoodfacts.net/images/products/317/657/216/8015/front.15.400.jpg</image_url>

		# https://github.com/openfoodfacts/openfoodfacts-server/issues/463
		# remove the languages field which has keys like "en:english"
		# keys with the : character break the XML export

		# Remove some select fields from products before rendering them.
		# Note: use "state" to avoid re-initializing the array. This can be seen as a premature optimisation
		# here but this new perl feature can be used at other places to encapsulate large lists while avoiding
		# inefficiencies from reinitialization.
		my @product_fields_to_delete = ("languages", "category_properties", "categories_properties");

		remove_fields($request_ref->{structured_response}{product}, \@product_fields_to_delete);

		if (defined $request_ref->{structured_response}{products}) {
			foreach my $product_ref (@{$request_ref->{structured_response}{products}}) {
				remove_fields($product_ref, \@product_fields_to_delete);
			}
		}

		my $xml
			= "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
			. $xs->XMLout($request_ref->{structured_response});  # noattr -> force nested elements instead of attributes

		my $status_code = $request_ref->{status_code} || "200";
		write_cors_headers();
		print header(
			-status => $status_code,
			-type => 'text/xml',
			-charset => 'utf-8',
		) . $xml;

	}
	elsif ($request_ref->{rss}) {
		display_structured_response_opensearch_rss($request_ref);
	}
	else {
		# my $data =  encode_json($request_ref->{structured_response});
		# Sort keys of the JSON output
		my $json = JSON::PP->new->allow_nonref->canonical;
		my $data = $json->utf8->encode($request_ref->{structured_response});

		my $jsonp = undef;

		if (defined single_param('jsonp')) {
			$jsonp = single_param('jsonp');
		}
		elsif (defined single_param('callback')) {
			$jsonp = single_param('callback');
		}

		my $status_code = $request_ref->{status_code} || 200;

		if (defined $jsonp) {
			$jsonp =~ s/[^a-zA-Z0-9_]//g;
			write_cors_headers();
			print header(
				-status => $status_code,
				-type => 'text/javascript',
				-charset => 'utf-8',
				)
				. $jsonp . "("
				. $data . ");";
		}
		else {
			$log->warning("XXXXXXXXXXXXXXXXXXXXXX");
			write_cors_headers();
			$log->warning("YYYYYYYYYYYYYYYY");
			print header(
				-status => $status_code,
				-type => 'application/json',
				-charset => 'utf-8',
			) . $data;
		}
	}

	my $r = Apache2::RequestUtil->request();
	$r->rflush;
	$r->status(200);

	exit();
}

sub display_structured_response_opensearch_rss ($request_ref) {

	my $xs = XML::Simple->new(NumericEscape => 2);

	my $short_name = lang("site_name");
	my $long_name = $short_name;
	if ($cc eq 'world') {
		$long_name .= " " . uc($lc);
	}
	else {
		$long_name .= " " . uc($cc) . "/" . uc($lc);
	}

	$long_name = $xs->escape_value(encode_utf8($long_name));
	$short_name = $xs->escape_value(encode_utf8($short_name));
	my $query_link = $xs->escape_value(encode_utf8($formatted_subdomain . $request_ref->{current_link} . "&rss=1"));
	my $description = $xs->escape_value(encode_utf8(lang("search_description_opensearch")));

	my $search_terms = $xs->escape_value(encode_utf8(decode utf8 => single_param('search_terms')));
	my $count = $xs->escape_value($request_ref->{structured_response}{count});
	my $skip = $xs->escape_value($request_ref->{structured_response}{skip});
	my $page_size = $xs->escape_value($request_ref->{structured_response}{page_size});
	my $page = $xs->escape_value($request_ref->{structured_response}{page});

	my $xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
 <rss version="2.0"
      xmlns:opensearch="https://a9.com/-/spec/opensearch/1.1/"
      xmlns:atom="https://www.w3.org/2005/Atom">
   <channel>
     <title>$long_name</title>
     <link>$query_link</link>
     <description>$description</description>
     <opensearch:totalResults>$count</opensearch:totalResults>
     <opensearch:startIndex>$skip</opensearch:startIndex>
     <opensearch:itemsPerPage>${page_size}</opensearch:itemsPerPage>
     <atom:link rel="search" type="application/opensearchdescription+xml" href="$formatted_subdomain/cgi/opensearch.pl"/>
     <opensearch:Query role="request" searchTerms="${search_terms}" startPage="$page" />
XML
		;

	if (defined $request_ref->{structured_response}{products}) {
		foreach my $product_ref (@{$request_ref->{structured_response}{products}}) {
			my $item_title = product_name_brand_quantity($product_ref);
			$item_title = $product_ref->{code} unless $item_title;
			my $item_description = $xs->escape_value(encode_utf8(sprintf(lang("product_description"), $item_title)));
			$item_title = $xs->escape_value(encode_utf8($item_title));
			my $item_link = $xs->escape_value(encode_utf8($formatted_subdomain . product_url($product_ref)));

			$xml .= <<XML
     <item>
       <title>$item_title</title>
       <link>$item_link</link>
       <description>$item_description</description>
     </item>
XML
				;
		}
	}

	$xml .= <<XML
   </channel>
 </rss>
XML
		;

	write_cors_headers();
	print header(-type => 'application/rss+xml', -charset => 'utf-8') . $xml;

	return;
}

sub display_recent_changes ($request_ref, $query_ref, $limit, $page) {

	add_params_to_query($request_ref, $query_ref);

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	if (defined $limit) {
	}
	elsif (defined $request_ref->{page_size}) {
		$limit = $request_ref->{page_size};
	}
	else {
		$limit = $page_size;
	}

	my $skip = 0;
	if (defined $page) {
		$skip = ($page - 1) * $limit;
	}
	elsif (defined $request_ref->{page}) {
		$page = $request_ref->{page};
		$skip = ($page - 1) * $limit;
	}
	else {
		$page = 1;
	}

	# support for returning structured results in json / xml etc.

	$request_ref->{structured_response} = {
		page => $page,
		page_size => $limit,
		skip => $skip,
		changes => [],
	};

	my $sort_ref = Tie::IxHash->new();
	$sort_ref->Push('$natural' => -1);

	$log->debug("Counting MongoDB documents for query", {query => $query_ref}) if $log->is_debug();
	my $count = execute_query(
		sub {
			return get_recent_changes_collection()->count_documents($query_ref);
		}
	);
	$log->info("MongoDB count query ok", {error => $@, count => $count}) if $log->is_info();

	$log->debug("Executing MongoDB query", {query => $query_ref}) if $log->is_debug();
	my $cursor = execute_query(
		sub {
			return get_recent_changes_collection()->query($query_ref)->sort($sort_ref)->limit($limit)->skip($skip);
		}
	);
	$log->info("MongoDB query ok", {error => $@}) if $log->is_info();

	my $html = '';
	my $last_change_ref = undef;
	my @cumulate_changes = ();
	my $template_data_ref_changes = {};
	my @changes;

	while (my $change_ref = $cursor->next) {
		# Conversion for JSON, because the $change_ref cannot be passed to encode_json.
		my $change_hash = {
			code => $change_ref->{code},
			countries_tags => $change_ref->{countries_tags},
			userid => $change_ref->{userid},
			ip => $change_ref->{ip},
			t => $change_ref->{t},
			comment => $change_ref->{comment},
			rev => $change_ref->{rev},
			diffs => $change_ref->{diffs}
		};

		my $changes_ref = {};

		# security: Do not expose IP addresses to non-admin or anonymous users.
		delete $change_hash->{ip} unless $admin;

		push @{$request_ref->{structured_response}{changes}}, $change_hash;
		my $diffs = compute_changes_diff_text($change_ref);
		$change_hash->{diffs_text} = $diffs;

		$changes_ref->{cumulate_changes} = @cumulate_changes;
		if (    defined $last_change_ref
			and $last_change_ref->{code} == $change_ref->{code}
			and $change_ref->{userid} == $last_change_ref->{userid}
			and $change_ref->{userid} ne 'kiliweb')
		{

			push @cumulate_changes, $change_ref;
			next;

		}
		elsif (@cumulate_changes > 0) {

			my @cumulate_changes_display;

			foreach (@cumulate_changes) {
				push(
					@cumulate_changes_display,
					{
						display_change => display_change($_, compute_changes_diff_text($_)),
					}
				);
			}

			$changes_ref->{cumulate_changes_display} = \@cumulate_changes_display;
			@cumulate_changes = ();

		}

		$changes_ref->{display_change} = display_change($change_ref, $diffs);
		push(@changes, $changes_ref);

		$last_change_ref = $change_ref;
	}

	$template_data_ref_changes->{changes} = \@changes;
	$template_data_ref_changes->{display_pagination} = display_pagination($request_ref, $count, $limit, $page);
	process_template('web/common/includes/display_recent_changes.tt.html', $template_data_ref_changes, \$html)
		|| ($html .= 'template error: ' . $tt->error());

	${$request_ref->{content_ref}} .= $html;
	$request_ref->{title} = lang("recent_changes");
	$request_ref->{page_type} = "recent_changes";
	display_page($request_ref);

	return;
}

sub display_change ($change_ref, $diffs) {

	my $date = display_date_tag($change_ref->{t});
	my $user = "";
	if (defined $change_ref->{userid}) {
		$user
			= "<a href=\""
			. canonicalize_tag_link("users", get_string_id_for_lang("no_language", $change_ref->{userid})) . "\">"
			. $change_ref->{userid} . "</a>";
	}

	my $comment = _format_comment($change_ref->{comment});

	my $change_rev = $change_ref->{rev};

	# Display diffs
	# [Image upload - add: 1, 2 - delete 2], [Image selection - add: front], [Nutriments... ]

	my $product_url = product_url($change_ref->{code});

	return
		  "<li><a href=\"$product_url\">"
		. $change_ref->{code}
		. "</a>; $date - $user ($comment) [$diffs] - <a href=\""
		. $product_url
		. "?rev=$change_rev\">"
		. lang("view")
		. "</a></li>\n";
}

=head2 display_icon ( $icon )

Displays icons (e.g., the camera icon "Picture with barcode", the graph and maps button, etc)

=cut

our %icons_cache = ();

sub display_icon ($icon) {

	my $svg = $icons_cache{$icon};

	if (not(defined $svg)) {
		my $file = "$www_root/images/icons/dist/$icon.svg";
		$svg = do {
			local $/ = undef;
			open my $fh, "<", $file
				or die "could not open $file: $!";
			<$fh>;
		};

		$icons_cache{$icon} = $svg;
	}

	return $svg;

}

=head2 display_nested_list_of_ingredients ( $ingredients_ref, $ingredients_text_ref, $ingredients_list_ref )

Recursive function to display how the ingredients were analyzed.
This function calls itself to display sub-ingredients of ingredients.

=head3 Parameters

=head4 $ingredients_ref (input)

Reference to the product's ingredients array or the ingredients array of an ingredient.

=head4 $ingredients_text_ref (output)

Reference to a list of ingredients in text format that we will reconstruct from the ingredients array.

=head4 $ingredients_list_ref (output)

Reference to an HTML list of ingredients in ordered nested list format that corresponds to the ingredients array.

=cut

sub display_nested_list_of_ingredients ($ingredients_ref, $ingredients_text_ref, $ingredients_list_ref) {

	${$ingredients_list_ref} .= "<ol id=\"ordered_ingredients_list\">\n";

	my $i = 0;

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		$i++;

		($i > 1) and ${$ingredients_text_ref} .= ", ";

		my $ingredients_exists = exists_taxonomy_tag("ingredients", $ingredient_ref->{id});
		my $class = '';
		if (not $ingredients_exists) {
			$class = ' class="text_info unknown_ingredient"';
		}

		${$ingredients_text_ref} .= "<span$class>" . $ingredient_ref->{text} . "</span>";

		if (defined $ingredient_ref->{percent}) {
			${$ingredients_text_ref} .= " " . $ingredient_ref->{percent} . "%";
		}

		${$ingredients_list_ref}
			.= "<li>" . "<span$class>" . $ingredient_ref->{text} . "</span>" . " -> " . $ingredient_ref->{id};

		foreach my $property (qw(origin labels vegan vegetarian from_palm_oil percent_min percent percent_max)) {
			if (defined $ingredient_ref->{$property}) {
				${$ingredients_list_ref} .= " - " . $property . ":&nbsp;" . $ingredient_ref->{$property};
			}
		}

		if (defined $ingredient_ref->{ingredients}) {
			${$ingredients_text_ref} .= " (";
			display_nested_list_of_ingredients($ingredient_ref->{ingredients},
				$ingredients_text_ref, $ingredients_list_ref);
			${$ingredients_text_ref} .= ")";
		}

		${$ingredients_list_ref} .= "</li>\n";
	}

	${$ingredients_list_ref} .= "</ol>\n";

	return;
}

=head2 display_list_of_specific_ingredients ( $product_ref )

Generate HTML to display how the specific ingredients (e.g. mentions like "Total milk content: 90%")
were analyzed.

=head3 Parameters

=head4 $product_ref

=head3 Return value

Empty string if no specific ingredients were detected, or HTML describing the specific ingredients.

=cut

sub display_list_of_specific_ingredients ($product_ref) {

	if (not defined $product_ref->{specific_ingredients}) {
		return "";
	}

	my $html = "<ul id=\"specific_ingredients_list\">\n";

	foreach my $ingredient_ref (@{$product_ref->{specific_ingredients}}) {

		my $ingredients_exists = exists_taxonomy_tag("ingredients", $ingredient_ref->{id});
		my $class = '';
		if (not $ingredients_exists) {
			$class = ' class="unknown_ingredient"';
		}

		$html
			.= "<li>"
			. $ingredient_ref->{text} . "<br>"
			. "<span$class>"
			. $ingredient_ref->{ingredient}
			. "</span>" . " -> "
			. $ingredient_ref->{id};

		foreach my $property (qw(origin labels vegan vegetarian from_palm_oil percent_min percent percent_max)) {
			if (defined $ingredient_ref->{$property}) {
				$html .= " - " . $property . ":&nbsp;" . $ingredient_ref->{$property};
			}
		}

		$html .= "</li>\n";
	}

	$html .= "</ul>\n";

	return $html;
}

=head2 data_to_display_ingredients_analysis_details ( $product_ref )

Generates a data structure to display the details of ingredients analysis.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_ingredients_analysis_details ($product_ref) {

	# Do not display ingredients analysis details when we don't have ingredients

	if (   (not defined $product_ref->{ingredients})
		or (scalar @{$product_ref->{ingredients}} == 0))
	{
		return;
	}

	my $result_data_ref = {};

	my $ingredients_text_lc = $product_ref->{ingredients_lc};
	my $ingredients_text = "$ingredients_text_lc: ";
	my $ingredients_list = "";

	display_nested_list_of_ingredients($product_ref->{ingredients}, \$ingredients_text, \$ingredients_list);

	my $specific_ingredients = display_list_of_specific_ingredients($product_ref);

	if (($ingredients_text . $specific_ingredients) =~ /unknown_ingredient/) {
		$result_data_ref->{unknown_ingredients} = 1;
	}

	$result_data_ref->{ingredients_text} = $ingredients_text;
	$result_data_ref->{ingredients_list} = $ingredients_list;
	$result_data_ref->{specific_ingredients} = $specific_ingredients;

	return $result_data_ref;
}

=head2 display_ingredients_analysis_details ( $product_ref )

Generates HTML code with information on how the ingredient list was parsed and mapped to the ingredients taxonomy.

=cut

sub display_ingredients_analysis_details ($product_ref) {

	my $html = "";

	my $template_data_ref = data_to_display_ingredients_analysis_details($product_ref);

	if (defined $template_data_ref) {
		process_template('web/pages/product/includes/ingredients_analysis_details.tt.html', $template_data_ref, \$html)
			|| return "template error: " . $tt->error();
	}

	return $html;
}

=head2 data_to_display_ingredients_analysis ( $product_ref )

Generates a data structure to display the results of ingredients analysis.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_ingredients_analysis ($product_ref) {

	my $result_data_ref;

	# Populate the data templates needed to display the Nutri-Score and nutrient levels

	if (defined $product_ref->{ingredients_analysis_tags}) {

		$result_data_ref = {ingredients_analysis_tags => [],};

		foreach my $ingredients_analysis_tag (@{$product_ref->{ingredients_analysis_tags}}) {

			my $evaluation;
			my $icon = "";
			# $ingredients_analysis_tag is a tag like "en:palm-oil-free", "en:vegan-status-unknown", or "en:non-vegetarian"
			# we will derive from it the associated property e.g. "palm_oil", "vegan", "vegetarian"
			# and the tag corresponding to unknown status for the property e.g. "en:palm-oil-content-unknown", "en:vegan-status-unknown"
			# so that we can display unknown ingredients for the property even if the status is different than unknown
			my $property;
			my $property_unknown_tag;

			if ($ingredients_analysis_tag =~ /palm/) {

				# Set property and icon
				$property = "palm_oil_free";
				$property_unknown_tag = "en:palm-oil-content-unknown";
				$icon = "palm-oil";

				# Evaluation
				if ($ingredients_analysis_tag =~ /-free$/) {
					$evaluation = 'good';
				}
				elsif ($ingredients_analysis_tag =~ /unknown/) {
					$evaluation = 'unknown';
				}
				elsif ($ingredients_analysis_tag =~ /^en:may-/) {
					$evaluation = 'average';
				}
				else {
					$evaluation = 'bad';
				}
			}
			else {

				# Set property (e.g. vegan for the tag vegan or non-vegan) and icon
				if ($ingredients_analysis_tag =~ /vegan/) {
					$property = "vegan";
					$icon = "leaf";
				}
				elsif ($ingredients_analysis_tag =~ /vegetarian/) {
					$property = "vegetarian";
					$icon = "vegetarian";
				}
				$property_unknown_tag = "en:" . $property . "-status-unknown";

				# Evaluation
				if ($ingredients_analysis_tag =~ /^en:non-/) {
					$evaluation = 'bad';
				}
				elsif ($ingredients_analysis_tag =~ /^en:maybe-/) {
					$evaluation = 'average';
				}
				elsif ($ingredients_analysis_tag =~ /unknown/) {
					$evaluation = 'unknown';
				}
				else {
					$evaluation = 'good';
				}
			}

			# Generate the translation string id for the list of ingredients we will display
			my $ingredients_title_id;
			if ($evaluation eq "unknown") {
				$ingredients_title_id = "unrecognized_ingredients";
			}
			else {
				# convert analysis tag to a translation string id
				# eg. en:non-vegetarian property to non_vegetarian_ingredients translation string id
				$ingredients_title_id = lc($ingredients_analysis_tag) . "_ingredients";
				$ingredients_title_id =~ s/^en://;
				$ingredients_title_id =~ s/-/_/g;
			}

			push @{$result_data_ref->{ingredients_analysis_tags}},
				{
				tag => $ingredients_analysis_tag,
				property => $property,
				property_unknown_tag => $property_unknown_tag,
				evaluation => $evaluation,
				icon => $icon,
				title => display_taxonomy_tag($lc, "ingredients_analysis", $ingredients_analysis_tag),
				ingredients_title_id => $ingredients_title_id,
				};
		}
	}

	return $result_data_ref;
}

=head2 display_ingredients_analysis ( $product_ref )

Generates HTML code with icons that show if the product is vegetarian, vegan and without palm oil.

=cut

sub display_ingredients_analysis ($product_ref) {

	# Ingredient analysis

	my $html = "";

	my $template_data_ref = data_to_display_ingredients_analysis($product_ref);

	if (defined $template_data_ref) {
		process_template('web/pages/product/includes/ingredients_analysis.tt.html', $template_data_ref, \$html)
			|| return "template error: " . $tt->error();
	}

	return $html;
}

sub _format_comment ($comment) {

	$comment = lang($comment) if $comment eq 'product_created';

	$comment =~ s/^Modification :\s+//;
	if ($comment eq 'Modification :') {
		$comment = q{};
	}

	$comment =~ s/new image \d+( -)?//;

	return $comment;
}

=head2 display_ecoscore_calculation_details( $cc, $ecoscore_data_ref )

Generates HTML code with information on how the Eco-score was computed for a particular product.

=head3 Parameters

=head4 country code $cc

=head4 ecoscore data $ecoscore_data_ref

=cut

sub display_ecoscore_calculation_details ($ecoscore_cc, $ecoscore_data_ref) {

	# Generate a data structure that we will pass to the template engine

	my $template_data_ref = dclone($ecoscore_data_ref);

	# Eco-score Calculation Template

	my $html;
	process_template('web/pages/product/includes/ecoscore_details.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

=head2 display_ecoscore_calculation_details_simple_html( $ecoscore_cc, $ecoscore_data_ref )

Generates simple HTML code (to display in a mobile app) with information on how the Eco-score was computed for a particular product.

=cut

sub display_ecoscore_calculation_details_simple_html ($ecoscore_cc, $ecoscore_data_ref) {

	# Generate a data structure that we will pass to the template engine

	my $template_data_ref = dclone($ecoscore_data_ref);

	# Eco-score Calculation Template

	my $html;
	process_template('web/pages/product/includes/ecoscore_details_simple_html.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

=head2 search_and_analyze_recipes ($request_ref, $query_ref)

Analyze the distribution of selected parent ingredients in the searched products

=cut

sub search_and_analyze_recipes ($request_ref, $query_ref) {

	add_params_to_query($request_ref, $query_ref);

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	my $cursor;

	$log->info("retrieving products from MongoDB to analyze their recipes") if $log->is_info();

	if ($admin) {
		$log->debug("Executing MongoDB query", {query => $query_ref}) if $log->is_debug();
	}

	# Limit the fields we retrieve from MongoDB
	my $fields_ref = {
		lc => 1,
		code => 1,
		product_name => 1,
		brands => 1,
		quantity => 1,
		"product_name_$lc" => 1,
		ingredients => 1,
		ingredients_percent_analysis => 1,
		ingredients_text => 1,
	};

	# For the producer platform, we also need the owner
	if ((defined $server_options{private_products}) and ($server_options{private_products})) {
		$fields_ref->{owner} = 1;
	}

	eval {
		$cursor = execute_query(
			sub {
				return get_products_collection(get_products_collection_request_parameters($request_ref))
					->query($query_ref)->fields($fields_ref);
			}
		);
	};
	if ($@) {
		$log->warn("MongoDB error", {error => $@}) if $log->is_warn();
	}
	else {
		$log->info("MongoDB query ok", {error => $@}) if $log->is_info();
	}

	$log->info("retrieved products from MongoDB to analyze their recipes") if $log->is_info();

	my @products = $cursor->all;
	my $count = @products;

	my $html = '';

	if ($count < 0) {
		$html .= "<p>" . lang("error_database") . "</p>";
	}
	elsif ($count == 0) {
		$html .= "<p>" . lang("no_products") . "</p>";
	}

	$html .= search_permalink($request_ref);

	if ($count <= 0) {
		return $html;
	}

	if ($count > 0) {

		my $uncanonicalized_parent_ingredients = single_param('parent_ingredients');

		# Canonicalize the parent ingredients
		my $parent_ingredients_ref = [];
		foreach my $parent (split(/,/, $uncanonicalized_parent_ingredients)) {
			push @{$parent_ingredients_ref}, canonicalize_taxonomy_tag($lc, "ingredients", $parent);
		}

		my $recipes_ref = [];

		my $debug = "";

		foreach my $product_ref (@products) {
			my $recipe_ref = compute_product_recipe($product_ref, $parent_ingredients_ref);

			add_product_recipe_to_set($recipes_ref, $product_ref, $recipe_ref);

			if (single_param("debug")) {
				$debug
					.= "product: "
					. JSON::PP->new->utf8->canonical->encode($product_ref)
					. "<br><br>\n\n"
					. "recipe: "
					. JSON::PP->new->utf8->canonical->encode($recipe_ref)
					. "<br><br><br>\n\n\n";
			}
		}

		my $analysis_ref = analyze_recipes($recipes_ref, $parent_ingredients_ref);

		my $template_data_ref = {
			analysis => $analysis_ref,
			recipes => $recipes_ref,
			debug => $debug,
		};

		process_template('web/pages/recipes/recipes.tt.html', $template_data_ref, \$html)
			or $html = "template error: " . $tt->error();

	}

	return $html;
}

=head2 display_properties( $cc, $ecoscore_data_ref )

Load the Folksonomy Engine properties script

=cut

sub display_properties ($request_ref) {

	my $html;
	process_template('web/common/includes/folksonomy_script.tt.html', {}, \$html)
		|| return "template error: " . $tt->error();

	$request_ref->{content_ref} = \$html;
	$request_ref->{page_type} = "properties";

	display_page($request_ref);
	return;
}

=head2 data_to_display_image ( $product_ref, $imagetype, $target_lc )

Generates a data structure to display a product image.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head4 Image type $image_type: one of [front|ingredients|nutrition|packaging]

=head4 Language code $target_lc

=head3 Return values

- Reference to a data structure with needed data to display.
- undef if no image is available for the requested image type

=cut

sub data_to_display_image ($product_ref, $imagetype, $target_lc) {

	my $image_ref;

	# first try the requested language
	my @img_lcs = ($target_lc);

	# next try the main language of the product
	if ($product_ref->{lc} ne $target_lc) {
		push @img_lcs, $product_ref->{lc};
	}

	foreach my $img_lc (@img_lcs) {

		my $id = $imagetype . "_" . $img_lc;

		if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})) {

			my $path = product_path($product_ref);
			my $rev = $product_ref->{images}{$id}{rev};
			my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $Lang{$imagetype . '_alt'}{$lang};
			if ($img_lc ne $target_lc) {
				$alt .= ' - ' . $img_lc;
			}

			$image_ref = {
				type => $imagetype,
				lc => $img_lc,
				alt => $alt,
				sizes => {},
				id => $id,
			};

			foreach my $size ($thumb_size, $small_size, $display_size, "full") {
				if (defined $product_ref->{images}{$id}{sizes}{$size}) {
					$image_ref->{sizes}{$size} = {
						url => "$images_subdomain/images/products/$path/$id.$rev.$size.jpg",
						width => $product_ref->{images}{$id}{sizes}{$size}{w},
						height => $product_ref->{images}{$id}{sizes}{$size}{h},
					};
				}
			}

			last;
		}
	}

	return $image_ref;
}

=head2 generate_select2_options_for_taxonomy ($target_lc, $tagtype)

Generates an array of taxonomy entries in a specific language, to be used as options
in a select2 input.

See https://select2.org/data-sources/arrays

=head3 Arguments

=head4 Language code $target_lc

=head4 Taxonomy $tagtype

=head3 Return values

- Reference to an array of options

=cut

sub generate_select2_options_for_taxonomy ($target_lc, $tagtype) {

	my @entries = ();

	# all tags can be retrieved from the $translations_to hash
	foreach my $canon_tagid (keys %{$translations_to{$tagtype}}) {
		# just_synonyms are not real entries
		next if defined $just_synonyms{$tagtype}{$canon_tagid};

		push @entries, display_taxonomy_tag($target_lc, $tagtype, $canon_tagid);
	}

	my @options = ();

	foreach my $entry (sort @entries) {
		push @options,
			{
			id => $entry,
			text => $entry,
			};
	}

	return \@options;
}

sub generate_select2_options_for_taxonomy_to_json ($target_lc, $tagtype) {

	return decode_utf8(
		JSON::PP->new->utf8->canonical->encode(generate_select2_options_for_taxonomy($target_lc, $tagtype)));
}

1;
