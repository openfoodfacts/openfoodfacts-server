# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

package ProductOpener::Display;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&init
					&analyze_request
					
					&remove_tags
					&remove_tags_and_quote
					&remove_tags_except_links
					&xml_escape
					&display_form
					&display_date
					&display_date_tag
					&get_packager_code_coordinates
					
					&display_structured_response
					&display_new					
					&display_text
					&display_points
					&display_mission
					&display_tag
					&display_error
					&gen_feeds
					
					&add_product_nutriment_to_stats
					&compute_stats_for_products
					&display_nutrition_table
					&display_product
					&display_product_api
					&display_product_history
					&search_and_display_products
					&search_and_export_products
					&search_and_graph_products
					&search_and_map_products
					&display_recent_changes
					
					@search_series
					
					$admin
					$memd
					$default_request_ref
					
					$connection
					$database
					$products_collection
					$emb_codes_collection
					$recent_changes_collection
					
					$scripts
					$initjs
					$styles
					$header
					$bodyabout

					$original_subdomain
					$subdomain
					$test
					$lc
					$cc
					$country
					
					$nutriment_table
					
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Cache qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Missions qw/:all/;
use ProductOpener::MissionsConfig qw/:all/;
use ProductOpener::URL qw/:all/;

use Cache::Memcached::Fast;
use Text::Unaccent;
use Encode;
use URI::Escape::XS;
use CGI qw/:cgi :form escapeHTML/;
use HTML::Entities;
use DateTime;
use DateTime::Format::Mail;
use DateTime::Format::CLDR;
use DateTime::Locale;
use experimental 'smartmatch';
use MongoDB;
use Tie::IxHash;
use JSON::PP;
use XML::Simple;
use Storable qw(freeze);
use Digest::MD5 qw(md5_hex);

use Log::Any '$log', default_adapter => 'Stderr';

use Apache2::RequestRec ();
use Apache2::Const ();


# Initialize exported variables

$memd = new Cache::Memcached::Fast {
	'servers' => [ "127.0.0.1:11211" ],
	'utf8' => 1,
};

$connection = MongoDB->connect($mongodb_host);
$database = $connection->get_database($mongodb);
$products_collection = $database->get_collection('products');
$emb_codes_collection = $database->get_collection('emb_codes');
$recent_changes_collection = $database->get_collection('recent_changes');

if (defined $options{other_servers}) {

	foreach my $server (keys %{$options{other_servers}}) {
		$options{other_servers}{$server}{database} = $connection->get_database($options{other_servers}{$server}{mongodb});
		$options{other_servers}{$server}{products_collection} = $options{other_servers}{$server}{database}->get_collection('products');
	}
}


$default_request_ref = {
page=>1,
};


# Initialize internal variables
# - using my $variable; is causing problems with mod_perl, it looks
# like inside subroutines below, they retain the first value they were
# called with. (but no "$variable will not stay shared" warning).
# Converting them to global variables.
# - better solution: create a class?

use vars qw(
);

sub init()
{
	$log->context->{request} = generate_token(16);

	$styles = '';
	$scripts = '';
	$initjs = '';
	$header = '';
	$bodyabout = '';
	$admin = 0;
	#if ((remote_addr() eq '82.226.239.239') and (user_agent() =~ /Firefox/i)) {
	#	$admin = 1;
	#}
	
	my $r = shift;
	
	$cc = 'world';
	$lc = 'en';
	$country = 'en:world';
	
	if (not defined $r) {
		$r = Apache2::RequestUtil->request();
	}
	
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
	# Note: cc and lc can be overriden by query parameters
	# (especially for the API so that we can use only one subdomain : api.openfoodfacts.org)

	my $hostname = $r->hostname;
	$subdomain = lc($hostname);
	
	local $log->context->{hostname} = $hostname;
	local $log->context->{ip} = remote_addr();
	local $log->context->{query_string} = $ENV{QUERY_STRING};

	$test = 0;
	if ($subdomain =~ /\.test\./) {
		$subdomain =~ s/\.test\./\./;
		$test = 1;
	}
	
	$subdomain =~ s/\..*//;
	
	$original_subdomain = $subdomain;	# $subdomain can be changed if there are cc and/or lc overrides
	
	
	$log->debug("initializing request", { subdomain => $subdomain }) if $log->is_debug();

	if ($subdomain eq 'world') {
		($cc, $country, $lc) = ('world','en:world','en');
	}
	elsif (defined $country_codes{$subdomain}) {
		local $log->context->{subdomain_format} = 1;

		$cc = $subdomain;
		$country = $country_codes{$cc};
		$lc = $country_languages{$cc}[0]; # first official language
		
		$log->debug("subdomain matches known country code", { subdomain => $subdomain, lc => $lc, cc => $cc, country => $country }) if $log->is_debug();
		
		if (not exists $Langs{$lc}) {
			$log->debug("current lc does not exist, falling back to lc = en", { subdomain => $subdomain, lc => $lc, cc => $cc, country => $country }) if $log->is_debug();
			$lc = 'en';
		}
		
	}
	elsif ($subdomain =~ /(.*?)-(.*)/) {
		local $log->context->{subdomain_format} = 2;
		$log->debug("subdomain in cc-lc format - checking values", { subdomain => $subdomain, lc => $lc, cc => $cc, country => $country }) if $log->is_debug();

		if (defined $country_codes{$1}) {
			$cc = $1;
			$country = $country_codes{$cc};
			$lc = $country_languages{$cc}[0]; # first official language
			if (defined $language_codes{$2}) {
				$lc = $2;		
				$lc =~ s/-/_/; # pt-pt -> pt_pt
			}
			
			$log->debug("subdomain matches known country code", { subdomain => $subdomain, lc => $lc, cc => $cc, country => $country }) if $log->is_debug();
		}
	}
	elsif (defined $country_names{$subdomain}) {
		local $log->context->{subdomain_format} = 3;
		($cc, $country, $lc) = @{$country_names{$subdomain}};
		
		$log->debug("subdomain matches known country name", { subdomain => $subdomain, lc => $lc, cc => $cc, country => $country }) if $log->is_debug();
	}
	elsif ($ENV{QUERY_STRING} !~ /(cgi|api)\//) {
		# redirect
		my $worlddom = format_subdomain('world');
		my $redirect = "$worlddom/" . $ENV{QUERY_STRING};
		$log->info("request could not be matched to a known format, redirecting", { subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect }) if $log->is_info();
		$r->headers_out->set(Location => $redirect);
		$r->status(301);  
		return 301;
	}
	

	$lc =~ s/_.*//;     # PT_PT doest not work yet: categories
	
	if ((not defined $lc) or (($lc !~ /^\w\w(_|-)\w\w$/) and (length($lc) != 2) )) {
		$log->debug("replacing unknown lc with en",  { lc => $lc }) if $log->debug();
		$lc = 'en';
	}
	
	$lang = $lc;
	
	# If the language is equal to the first language of the country, but we are on a different subdomain, redirect to the main country subdomain. (fr-fr => fr)
	if ((defined $lc) and (defined $cc) and (defined $country_languages{$cc}[0]) and ($country_languages{$cc}[0] eq $lc) and ($subdomain ne $cc) and ($subdomain !~ /^(ssl-)?api/) and ($r->method() eq 'GET') and ($ENV{QUERY_STRING} !~ /(cgi|api)\//)) {
		# redirect
		my $ccdom = format_subdomain($cc);
		my $redirect = "$ccdom/" . $ENV{QUERY_STRING};
		$log->info("lc is equal to first lc of the country, redirecting to countries main domain", { subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect }) if $log->is_info();
		$r->headers_out->set(Location => $redirect);
		$r->status(301);
		return 301;
	}
	
	
	# Allow cc and lc overrides as query parameters
	# do not redirect to the corresponding subdomain
	my $cc_lc_overrides = 0;
	if ((defined param('cc')) and ((defined $country_codes{param('cc')}) or (param('cc') eq 'world')) ) {
		$cc = param('cc');
		$country = $country_codes{$cc};
		$cc_lc_overrides = 1;
		$log->debug("cc override from request parameter", { cc => $cc }) if $log->is_debug();
	}
	if ((defined param('lc')) and (defined $language_codes{param('lc')})) {
		$lc = param('lc');
		$lang = $lc;
		$cc_lc_overrides = 1;
		$log->debug("lc override from request parameter", { lc => $lc }) if $log->is_debug();
	}	
	# change the subdomain if we have overrides so that links to product pages are properly constructed
	if ($cc_lc_overrides) {
		$subdomain = $cc;
		if (not ((defined $country_languages{$cc}[0]) and ($lc eq $country_languages{$cc}[0]))) {
			$subdomain .= "-" . $lc;
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
	
	$log->debug("URI parsed for additional information", { subdomain => $subdomain, original_subdomain => $original_subdomain, lc => $lc, lang => $lang, cc => $cc, country => $country }) if $log->is_debug();

	my $error = ProductOpener::Users::init_user();
	if ($error) {
		if (not param('jqm')) { # API
			display_error($error, undef);
		}
	}
	
	if ((%admins) and (defined $User_id) and (exists $admins{$User_id})) {
		$admin = 1;
	}
	
	if (defined $User_id) {
		$styles .= <<CSS
.hide-when-logged-in { display:none}
CSS
;
	}
	else {
		$styles .= <<CSS
.show-when-logged-in { display:none}
CSS
;
	}
}

# component was specified as en:product, fr:produit etc.
sub _component_is_singular_tag_in_specific_lc($$) {
	my ($component, $tag) = @_;

	my $component_lc;
	if ($component =~ /^(\w\w):/) {
		$component_lc = $1;
		$component = $';
	}
	else {
		return 0;
	}

	my $match = $tag_type_singular{$tag}{$component_lc};
	if ((defined $match) and ($match eq $component)) {
		return 1;
	}
	else {
		return 0;
	}
}

sub analyze_request($)
{
	my $request_ref = shift;
	
	$log->debug("analyzing query_string, step 0 - unmodified", { query_string => $request_ref->{query_string} } ) if $log->is_debug();
	
	# https://world.openfoodfacts.org/?utm_content=bufferbd4aa&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer
	# https://world.openfoodfacts.org/?ref=producthunt
	
	if ($request_ref->{query_string} =~ /(\&|\?)(utm_|ref=)/) {
		$request_ref->{query_string} = $`;
	}
	
	# cc and lc query overrides have already been consumed by init(), remove them
	# so that they do not interfere with the query string analysis after
	$request_ref->{query_string} =~ s/(\&|\?)(cc|lc)=([^&]*)//g;
		
	$log->debug("analyzing query_string, step 1 - utm, cc, and lc removed", { query_string => $request_ref->{query_string} } ) if $log->is_debug();
	
	# Process API parameters: fields, formats, revision
	
	# API calls may request JSON, JSONP or XML by appending .json, .jsonp or .xml at the end of the query string
	# .jqm returns results in HTML specifically formated for the OFF mobile app (which uses jquerymobile)
	# for calls to /cgi/ actions (e.g. search.pl), the format can also be indicated with a parameter &json=1 &jsonp=1 &xml=1 &jqm=1
	# (or ?json=1 if it's the first parameter)
	
	# first check parameters in the query string

	foreach my $parameter ('fields', 'rev', 'json', 'jsonp', 'jqm','xml') {
	
		if ($request_ref->{query_string} =~ /(\&|\?)$parameter=([^\&]+)/) {
			$request_ref->{query_string} =~ s/(\&|\?)$parameter=([^\&]+)//;
			$request_ref->{$parameter} = $2;
			$log->debug("parameter was set from query string", { parameter => $parameter, value => $request_ref->{$parameter} }) if $log->is_debug();
		}	
	}	
	
	# then check suffixes .json etc.
	
	foreach my $parameter ('json', 'jsonp', 'jqm','xml') {
	
		if ($request_ref->{query_string} =~ /\.$parameter$/) {
			$request_ref->{query_string} =~ s/\.$parameter$//;
			$request_ref->{$parameter} = 1;
			$log->debug("parameter was set from extension in URL path", { parameter => $parameter, value => $request_ref->{$parameter} }) if $log->is_debug();
		}
	}	
	
	$log->debug("analyzing query_string, step 2 - fields, rev, json, jsonp, jqm, and xml removed", { query_string => $request_ref->{query_string} } ) if $log->is_debug();
	
	$request_ref->{query_string} =~ s/^\///;
	$request_ref->{query_string} = decode("utf8",URI::Escape::XS::decodeURIComponent($request_ref->{query_string}));
	
	$log->debug("analyzing query_string, step 3 - components UTF8 decoded", { query_string => $request_ref->{query_string} } ) if $log->is_debug();
	
	$request_ref->{page} = 1;
	
	my @components = split(/\//, $request_ref->{query_string});
	
	# Root
	if ($#components < 0) {
		$request_ref->{text} = 'index';
		$request_ref->{current_link} = '';
	}
	# Root + page number
	elsif (($#components == 0) and ($components[$#components] =~ /^\d+$/)) {
		$request_ref->{page} = pop @components;
		$request_ref->{current_link} = '';
		$request_ref->{text} = 'index';
	}
	
	# api
	elsif ($components[0] eq 'api') {
	
		$request_ref->{api} = $components[1]; # version
		if ($request_ref->{api} =~ /v(.*)/) {
			$request_ref->{api_version} = $1;
		}
		$request_ref->{api_method} = $components[2];
		$request_ref->{code} = $components[3];
		
		 # if return format is not xml or jqm or jsonp, default to json
		 if ((not exists $request_ref->{xml}) and (not exists $request_ref->{jqm}) and (not exists $request_ref->{jsonp})) {
			$request_ref->{json} = 1;
		 }
		
		$log->debug("request looks like an API request", { api => $request_ref->{api}, api_version => $request_ref->{api_version}, api_method => $request_ref->{api_method}, code => $request_ref->{code}, jqm => $request_ref->{jqm}, json => $request_ref->{json}, xml => $request_ref->{xml} } ) if $log->is_debug();
	}	

	# or a list
	elsif (0 and (-e ("$data_root/lists/" . $components[0] . ".$cc.$lc.html") ) and (not defined $components[1]))  {
		$request_ref->{text} = $components[0];
		$request_ref->{list} = $components[0];
		$request_ref->{canon_rel_url} = "/" . $components[0];
	}
	# First check if the request is for a text
	elsif ((defined $texts{$components[0]}) and ((defined $texts{$components[0]}{$lang}) or (defined $texts{$components[0]}{en}))and (not defined $components[1]))  {
		$request_ref->{text} = $components[0];
		$request_ref->{canon_rel_url} = "/" . $components[0];
	}
	# Product specified as en:product?
	elsif (_component_is_singular_tag_in_specific_lc($components[0], 'products')) {
		# check the product code looks like a number
		if ($components[1] =~ /^\d/) {
			$request_ref->{redirect} = format_subdomain($subdomain) . '/' . $tag_type_singular{products}{$lc} . '/' . $components[1];;
		}
		else {
			display_error(lang("error_invalid_address"), 404);
		}
	}
	# Product?
	# try language from $lc, and English, so that /product/ always work
	elsif (($components[0] eq $tag_type_singular{products}{$lc}) or ($components[0] eq $tag_type_singular{products}{en})) {
		# check the product code looks like a number
		if ($components[1] =~ /^\d/) {
			$request_ref->{product} = 1;
			$request_ref->{code} = $components[1];
			if (defined $components[2]) {
				$request_ref->{titleid} = $components[2];
			}
			else {
				$request_ref->{titleid} = '';
			}
		}
		else {
			display_error(lang("error_invalid_address"), 404);
		}
	}
	
	# Graph of the products?
	# $data_root/lang/$lang/texts/products_stats_$cc.html
	#elsif (($components[0] eq $tag_type_plural{products}{$lc}) and (not defined $components[1])) {
	#	$request_ref->{text} = "products_stats_$cc";
	#	$request_ref->{canon_rel_url} = "/" . $components[0];
	#}	
	# -> done through a text transclusion in /lang/fr/produits.html etc.
	
	
	# Mission?
	elsif ($components[0] eq $tag_type_singular{missions}{$lc}) {
		$request_ref->{mission} = 1;
		$request_ref->{missionid} = $components[1];
	}	
	
	elsif ($#components == -1) {
		# Main site
	}
	
	# Known tag type?
	else {
	
		$request_ref->{canon_rel_url} = '';
		my $canon_rel_url_suffix = '';
	
		# list of tags? (plural of tagtype must be the last field)
		
		$log->debug("checking last component", { last_component => $components[$#components], is_plural => $tag_type_from_plural{$lc}{$components[$#components]} }) if $log->is_debug();
		
		# list of (categories) tags with stats for a nutriment 
		if (($#components == 1) and (defined $tag_type_from_plural{$lc}{$components[0]}) and ($tag_type_from_plural{$lc}{$components[0]} eq "categories")
			and (defined $nutriments_labels{$lc}{$components[1]})) {
			
			$request_ref->{groupby_tagtype} = $tag_type_from_plural{$lc}{$components[0]};
			$request_ref->{stats_nid} = $nutriments_labels{$lc}{$components[1]};
			$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
			$canon_rel_url_suffix .= "/" . $components[1];
			pop @components;
			pop @components;
			$log->debug("request looks like a list of tags - categories with nutrients", { groupby => $request_ref->{groupby_tagtype}, stats_nid => $request_ref->{stats_nid} }) if $log->is_debug();
		}
		
		if (defined $tag_type_from_plural{$lc}{$components[$#components]}) {
		
			$request_ref->{groupby_tagtype} = $tag_type_from_plural{$lc}{pop @components};
			$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
			$log->debug("request looks like a list of tags", { groupby => $request_ref->{groupby_tagtype}, lc => $lc }) if $log->is_debug();
		}
		# also try English tagtype
		elsif (defined $tag_type_from_plural{"en"}{$components[$#components]}) {
		
			$request_ref->{groupby_tagtype} = $tag_type_from_plural{"en"}{pop @components};
			# use $lc for canon url
			$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
			$log->debug("request looks like a list of tags", { groupby => $request_ref->{groupby_tagtype}, lc => "en" }) if $log->is_debug();
		}
	
		if (($#components >= 0) and ((defined $tag_type_from_singular{$lc}{$components[0]})
			or (defined $tag_type_from_singular{"en"}{$components[0]}))) {
		
			$log->debug("request looks like a singular tag", { lc => $lc, tagid => $components[0] }) if $log->is_debug();
			
			if (defined $tag_type_from_singular{$lc}{$components[0]}) {
				$request_ref->{tagtype} = $tag_type_from_singular{$lc}{shift @components};
			}
			else {
				$request_ref->{tagtype} = $tag_type_from_singular{"en"}{shift @components};
			}
			
			my $tagtype = $request_ref->{tagtype};
		
			if (($#components >= 0)) {
				$request_ref->{tag} = shift @components;
				
				# if there is a leading dash - before the tag, it indicates we want products without it
				if ($request_ref->{tag} =~ /^-/) {
					$request_ref->{tag_prefix} = "-";
					$request_ref->{tag} = $';
				}
				else {
					$request_ref->{tag_prefix} = "";
				}
				
				if (defined $taxonomy_fields{$tagtype}) {
					if ($request_ref->{tag} !~ /^(\w\w):/) {
						$request_ref->{tag} = $lc . ":" . $request_ref->{tag};
					}
				}
				$request_ref->{tagid} = get_taxonomyid($request_ref->{tag});
			}
			
			$request_ref->{canon_rel_url} .= "/" . $tag_type_singular{$tagtype}{$lc} . "/" . $request_ref->{tag_prefix} . $request_ref->{tagid}; 
			
			# 2nd tag?
			
			if (($#components >= 0) and ((defined $tag_type_from_singular{$lc}{$components[0]})
				or (defined $tag_type_from_singular{"en"}{$components[0]}))) {
			
				if (defined $tag_type_from_singular{$lc}{$components[0]}) {
					$request_ref->{tagtype2} = $tag_type_from_singular{$lc}{shift @components};
				}
				else {
					$request_ref->{tagtype2} = $tag_type_from_singular{"en"}{shift @components};
				}
				my $tagtype = $request_ref->{tagtype2};
			
				if (($#components >= 0)) {
					$request_ref->{tag2} = shift @components;
					
					# if there is a leading dash - before the tag, it indicates we want products without it
					if ($request_ref->{tag2} =~ /^-/) {
						$request_ref->{tag2_prefix} = "-";
						$request_ref->{tag2} = $';
					}
					else {
						$request_ref->{tag2_prefix} = "";
					}
				
					if (defined $taxonomy_fields{$tagtype}) {
						if ($request_ref->{tag2} !~ /^(\w\w):/) {
							$request_ref->{tag2} = $lc . ":" . $request_ref->{tag2};
						}
					}
					$request_ref->{tagid2} = get_taxonomyid($request_ref->{tag2});
				}
				
				$request_ref->{canon_rel_url} .= "/" . $tag_type_singular{$tagtype}{$lc} . "/" . $request_ref->{tag2_prefix} . $request_ref->{tagid2}; 
			}

			if ((defined $components[0]) and ($components[0] eq 'points')) {
				$request_ref->{points} = 1;
				$request_ref->{canon_rel_url} .= "/points"
			}
		
		}
		elsif ((defined $components[0]) and ($components[0] eq 'points')) {
				$request_ref->{points} = 1;
				$request_ref->{canon_rel_url} .= "/points"
		}
		elsif (not defined $request_ref->{groupby_tagtype}) {
			$log->warn("invalid address, confused by number of components left", { left_components => $#components }) if $log->is_warn();
			display_error(lang("error_invalid_address"), 404);
		}
		
		if (($#components >=0) and ($components[$#components] =~ /^\d+$/)) {
			$request_ref->{page} = pop @components;
		}
		
		$request_ref->{canon_rel_url} .= $canon_rel_url_suffix;
	}
	
	if ($log->is_debug()) {
		my $debug_log = "";
		foreach my $log_field (qw/text product tagtype tagid tagtype2 tagid2 groupby_tagtype points/) {
			if (defined $request_ref->{$log_field}) {
				$debug_log .= " - $log_field: $request_ref->{$log_field}";
			}
		}

		$log->debug("request analyzed", { lc => $lc, lang => $lang, log_fields => $debug_log });
	}
		
	return 1;
}



sub remove_tags_and_quote($) {

	my $s = shift;

	if (not defined $s) {
		$s = "";
	}

	# Remove tags
	$s =~ s/<(([^>]|\n)*)>//g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/"/&quot;/g;

	# Remove whitespace
	$s =~ s/^\s+|\s+$//g;

	return $s;
}

sub xml_escape($) {

	my $s = shift;

	# Remove tags
	$s =~ s/<(([^>]|\n)*)>//g;
	$s =~ s/\&/\&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/"/&quot;/g;

	# Remove whitespace
	$s =~ s/^\s+|\s+$//g;

	return $s;

}

sub remove_tags($) {

	my $s = shift;

	# Remove tags
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;

	return $s;
}


sub remove_tags_except_links($) {

	my $s = shift;

	# Transform links
	$s =~ s/<a href="?'?([^>"' ]+?)"?'?>([^>]+?)<\/a>/\[a href="$1"\]$2\[\/a\]/isg;
	
	$s = remove_tags($s);
	
	# Transform back links
	$s =~ s/\[a href="?'?([^>"' ]+?)"?'?\]([^\]]+?)\[\/a\]/\<a href="$1">$2<\/a>/isg;	

	return $s;
}


use URI::Find;

my $uri_finder = URI::Find->new(sub {
      my($uri, $orig_uri) = @_;
	  if ($uri =~ /\http/) {
		return qq|<a href="$uri">$orig_uri</a>|;
	  }
	  else {
		return $orig_uri;
	  }
});


sub display_form($) {

	my $s = shift;

	# Activate links

	$s =~ s/<a href="h/<a href="protectedh/g;
	
	$uri_finder->find(\$s);
	
	$s =~ s/<a href="protectedh/<a href="h/g;

	# Change line feeds to <br /> and <p>..</p>
	
	$s =~ s/\n(\n+)/<\/p>\n<p>/g;
	$s =~ s/\n/<br \/>\n/g;
	
	return "<p>$s</p>";
}

sub display_date($) {

	my $t = shift;

	if (defined $t) {
		my @codes = DateTime::Locale->codes;
		my $locale;
		if ( $lc ~~ @codes ) {
			$locale = DateTime::Locale->load($lc);
		}
		else {
			$locale = DateTime::Locale->load('en');
		}
	
		my $dt = DateTime->from_epoch(
			locale => $locale,
			time_zone => $reference_timezone,
			epoch => $t );
		my $formatter = DateTime::Format::CLDR->new(
		    pattern => $locale->datetime_format_long,
		    locale => $locale
		);
		$dt->set_formatter($formatter);
		return $dt;
	}
	else {
		return;
	}

}

sub display_date_without_time($) {

	my $t = shift;

	if (defined $t) {
		my @codes = DateTime::Locale->codes;
		my $locale;
		if ( $lc ~~ @codes ) {
			$locale = DateTime::Locale->load($lc);
		}
		else {
			$locale = DateTime::Locale->load('en');
		}
	
		my $dt = DateTime->from_epoch(
			locale => $locale,
			time_zone => $reference_timezone,
			epoch => $t );
		my $formatter = DateTime::Format::CLDR->new(
		    pattern => $locale->date_format_long,
		    locale => $locale
		);
		$dt->set_formatter($formatter);
		return $dt;
	}
	else {
		return;
	}

}

sub display_date_tag($) {

	my $t = shift;
	my $dt = display_date($t);
	if (defined $dt) {
		my $iso = $dt->iso8601;;
		return "<time datetime=\"$iso\">$dt</time>";
	}
	else {
		return;
	}

}

sub display_error($$)
{
	my $error_message = shift;
	my $status = shift;
	my $html = "<p>$error_message</p>";
	display_new( {
		title => lang('error'),
		content_ref => \$html,
		status => $status
	});
	exit();
}


sub display_text($)
{
	my $request_ref = shift;
	my $textid = $request_ref->{text};
		
	my $text_lang = $lang;

	# if a page does not exist in the local language, use the English version
	# e.g. Index, Discover, Contribute pages.
	if ((not defined $texts{$textid}{$text_lang}) and (defined $texts{$textid}{en})) {
		$text_lang = 'en';
	}
	
	my $file = "$data_root/lang/$text_lang/texts/" . $texts{$textid}{$text_lang} ;
	
	
	#list?
	if (-e "$data_root/lists/$textid.$cc.$lc.html") {
		$file = "$data_root/lists/$textid.$cc.$lc.html";
	}

	
	open(my $IN, "<:encoding(UTF-8)", $file);
	my $html = join('', (<$IN>));
	close ($IN);
	
	my $country_name = display_taxonomy_tag($lc,"countries",$country);
	
	$html =~ s/<cc>/$cc/g;
	$html =~ s/<country_name>/$country_name/g;
	
	my $title = undef;
	
	if (($textid eq 'index') or (defined $request_ref->{list})) {	
		$html =~ s/<\/h1>/ - $country_name<\/h1>/;
	}

	$log->info("displaying text from file", { cc => $cc, lc => $lc, lang => $lang, textid => $textid, textlang => $text_lang, file => $file }) if $log->is_info();
	
	# if page number is higher than 1, then keep only the h1 header
	# e.g. index page
	if ((defined $request_ref->{page}) and ($request_ref->{page} > 1)) {
		$html =~ s/<\/h1>.*//is;
		$html .= '</h1>';
	}
	
	my $replace_file = sub ($) {
		my $fileid = shift;
		($fileid =~ /\.\./) and return '';
		my $file = "$data_root/lang/$lc/$fileid";
		my $html = '';
		if (-e $file) {
			open (my $IN, "<:encoding(UTF-8)", "$file");
			$html .= join('', (<$IN>));
			close ($IN);
		}
		return $html;
	};
	
	my $replace_query = sub ($) {
	
		my $query = shift;
		my $query_ref = decode_json($query);
		my $sort_by = undef;
		if (defined $query_ref->{sort_by}) {
			$sort_by = $query_ref->{sort_by};
			delete $query_ref->{sort_by};
		}
		return search_and_display_products( {}, $query_ref, $sort_by, undef, undef );
	
	};
	
	
	if ($file !~ /index.foundation/) {
		$html =~ s/\[\[query:(.*?)\]\]/$replace_query->($1)/eg;
	}
	else {
		$html .= search_and_display_products( $request_ref, {}, "last_modified_t_complete_first", undef, undef);
	}
	
	$html =~ s/\[\[(.*?)\]\]/$replace_file->($1)/eg;
	
	
	if ($html =~ /<scripts>(.*)<\/scripts>/s) {
		$html = $` . $';
		$scripts .= $1;
	}
	
	if ($html =~ /<initjs>(.*)<\/initjs>/s) {
		$html = $` . $';
		$initjs .= $1;
	}		
	
	# wikipedia style links [url text] 
	$html =~ s/\[(http\S*?) ([^\]]+)\]/<a href="$1">$2<\/a>/g;
	
	
	if ($html =~ /<h1>(.*)<\/h1>/) {
		$title = $1;
		#$html =~ s/<h1>(.*)<\/h1>//;
	}

	# Generate a table of content
	
	if ($html =~ /<toc>/) {
	
		my $toc = '';
		my $text = $html;
		my $new_text = '';

		my $current_root_level = -1;
		my $current_level = -1;
		my $nb_headers = 0;

		while ($text =~ /<h(\d)([^<]*)>(.*?)<\/h(\d)>/si )
		{
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
			$header_id = get_fileid($header_id);
			$header_id =~ s/-/_/g;

			my $header_id_html = " id=\"$header_id\"";

			if ($h_attributes =~ /id="([^<]+)"/)
			{
				$header_id = $1;
				$header_id_html = '';
				}

			$new_text .= "<h$level${header_id_html}${h_attributes}>$header</h$level>";

			if ($current_root_level == -1)
			{
				$current_root_level = $level;
				$current_level = $level;
				}

				for (my $i = $current_level; $i < $level; $i++)
				{
					$toc .= "<ul>\n";
				}

				for (my $i = $level; $i < $current_level; $i++)
				{
					$toc .= "</ul>\n";
				}

			for ( ; $current_level < $current_root_level ; $current_root_level--)
			{
				$toc = "<ul>\n" . $toc;
				}

				$current_level = $level;
				
				$header =~ s/<br>//sig;

				$toc .= "<li><a href=\"#$header_id\">$header</a></li>\n" ;
		}

		for (my $i = $current_root_level; $i < $current_level; $i++)
		{
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
	
	if ($textid ne 'index') {
		$request_ref->{full_width} = 1;
	}
	
	display_new($request_ref);
	exit();
}



sub display_mission($)
{
	my $request_ref = shift;
	my $missionid = $request_ref->{missionid};

	open(my $IN, "<:encoding(UTF-8)", "$data_root/lang/$lang/missions/$missionid.html");
	my $html = join('', (<$IN>));
	my $title = undef;
	if ($html =~ /<h1>(.*)<\/h1>/) {
		$title = $1;
		#$html =~ s/<h1>(.*)<\/h1>//;
	}
	
	$request_ref->{title} = lang("mission_") . $title;	
	$request_ref->{content_ref} = \$html;
	$request_ref->{canon_url} = canonicalize_tag_link("missions", $missionid);
	
	display_new($request_ref);
	exit();
}




sub display_list_of_tags($$) {


	my $request_ref = shift;
	my $query_ref = shift;
	my $groupby_tagtype = $request_ref->{groupby_tagtype};
	
	if (defined $country) {
		if ($country ne 'en:world') {
			$query_ref->{countries_tags} = $country;
		}
		delete $query_ref->{lc};
	}
	
	# support for returning json / xml results
	
	$request_ref->{structured_response} = {
		tags => [],
	};	

	
	#if ($admin) 
	{
		$log->debug("MongoDB query built", { query => $query_ref }) if $log->is_debug();	
	}

	my $worlddom = format_subdomain('world');
	my $staticdom = format_subdomain('static');

	
#  db.products.aggregate( {$match : {"categories_tags" : "en:fruit-yogurts"}}, 
#		{ $unwind : "$countries_tags"}, { $group : { _id : "$countries_tags", "total" : {"$sum" : 1}}}, {$sort : { total : -1 }} );
# {
#  "result" : [
#   {
#    "_id" : "en:france",
#    "total" : 39
#   },
#   {
#    "_id" : "en:switzerland",
#    "total" : 2
#   },
#   {
#    "_id" : "en:reunion",
#    "total" : 1
#   },
#   {
#    "_id" : "fr:europe",
#    "total" : 1
#   }
#  ],
#  "ok" : 1
# }

#     my $result = $collection->aggregate([{"\$match" => {"b" => {"\$gte" => $number, "\$lt" => $number+1000}}}, {"\$group" => {"_id" => 0, "average" => {"\$avg" => "\$b"}, "count" => {"\$sum" => 1}}}]);

	
	# groupby_tagtype
	
	my $results;	
	my $count;
	
	my $aggregate_parameters = [
			{ "\$match" => $query_ref },
			{ "\$unwind" => ("\$" . $groupby_tagtype . "_tags")},
			{ "\$group" => { "_id" => ("\$" . $groupby_tagtype . "_tags"), "count" => { "\$sum" => 1 }}},
			{ "\$sort" => { "count" => -1 }}
			];
			
	if ($groupby_tagtype eq 'users') {
		$aggregate_parameters = [
			{ "\$match" => $query_ref },
			{ "\$group" => { "_id" => ("\$creator" ), "count" => { "\$sum" => 1 }}},
			{ "\$sort" => { "count" => -1 }}
			];
	}

	if (($groupby_tagtype eq 'nutrition_grades') or ($groupby_tagtype eq 'nova_groups') ){
		$aggregate_parameters = [
			{ "\$match" => $query_ref },
			{ "\$unwind" => ("\$" . $groupby_tagtype . "_tags")},
			{ "\$group" => { "_id" => ("\$" . $groupby_tagtype . "_tags"), "count" => { "\$sum" => 1 }}},
			{ "\$sort" => { "_id" => 1 }}
			];
	}	
	
	my $mongodb_query_ref = $aggregate_parameters;
	
	my $key = $server_domain . "/" . freeze($mongodb_query_ref);
	
	$log->debug("MongoDB aggregate query key", { key => $key }) if $log->is_debug();

	$key = md5_hex($key);
	
	$log->debug("MongoDB hashed aggregate query key", { key => $key }) if $log->is_debug();
	
	$results = $memd->get($key);	
	
	if ((not defined $results) or (ref($results) ne "ARRAY") or (not defined $results->[0])) {
	
		$results = undef;
	
		$log->debug("Did not find a value for aggregate MongoDB query key", { key => $key }) if $log->is_debug();
	
	
		eval {
			$log->debug("Executing MongoDB aggregate query", { query => $aggregate_parameters }) if $log->is_debug();
			$results = $products_collection->aggregate( $aggregate_parameters );
		};
		if ($@) {
			$log->warn("MongoDB error - retrying once", { error => $@ }) if $log->is_warn();
			# maybe $connection auto-reconnects but $database and $products_collection still reference the old connection?
			
			# opening new connection
			eval {
				$connection = MongoDB->connect($mongodb_host);
				$database = $connection->get_database($mongodb);
				$products_collection = $database->get_collection('products');
			};
			if ($@) {
				$log->error("MongoDB error - reconnecting failed", { error => $@ }) if $log->is_error();
				$count = -1;
			}
			else {		
				$log->info("MongoDB reconnect ok", { error => $@ }) if $log->is_info();
				eval {
					$log->debug("Executing MongoDB aggregate query", { query => $aggregate_parameters }) if $log->is_debug();
					$results = $products_collection->aggregate( $aggregate_parameters);
				};
				$log->debug("MongoDB query done", { error => $@ }) if $log->is_debug();
			}
		}
			
		$log->trace("aggregate query done") if $log->is_trace();
		
		if ($admin) {
			$log->debug("aggregate query results", { results => $results }) if $log->is_debug();	
		}	
		
		# the return value of aggregate has changed from version 0.702
		# and v1.4.5 of the perl MongoDB module
		if (defined $results) {
			$results = [$results->all];
				
			if (defined $results->[0]) {
				$log->debug("Setting value for aggregate MongoDB query key", { key => $key }) if $log->is_debug();

				$memd->set($key, $results, 3600) or $log->debug("Could not set value for MongoDB query key", { key => $key });
			}
		
		}
		else {
			$log->debug("No results for aggregate MongoDB query key", { key => $key }) if $log->is_debug();
		
		}
	}
	else {
		$log->debug("Found a value for aggregate MongoDB query key", { key => $key }) if $log->is_debug();
	}		
		
	
	my $html = '';
	my $html_pages = '';	
	
	my $countries_map_links = '';
	my $countries_map_names = '';
	my $countries_map_data = '';
	
	if ((not defined $results) or (ref($results) ne "ARRAY") or (not defined $results->[0])) {
	
		$log->debug("results for aggregate MongoDB query key", { "results" => $results}) if $log->is_debug();
		$html .= "<p>" . lang("no_products") . "</p>";
		$request_ref->{structured_response}{count} = 0;
	
	}
	else {
	
		if ((defined $request_ref->{current_link_query}) and (not defined $request_ref->{jqm})) {
	
			if ($country ne 'en:world') {
				$html .= "<p>&rarr; <a href=\"${worlddom}" . $request_ref->{current_link_query} . "&action=display\">" . lang('view_results_from_the_entire_world') . "</a></p>";
			}	
		
			$request_ref->{current_link_query_display} = $request_ref->{current_link_query};
			$html .= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">" . lang("search_link") . "</a><br />";
			$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
			$html .= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">" . lang("search_edit") . "</a><br />";
				
			

			if ((defined $request_ref->{current_link_query}) and (not defined $request_ref->{jqm}))  {
				$request_ref->{current_link_query_download} = $request_ref->{current_link_query};
				$request_ref->{current_link_query_download} .= "&download=on";
				$html .= "&rarr; <a href=\"$request_ref->{current_link_query_download}\">" . lang("search_download_results") . "</a><br />";
			}
		}
	
		my @tags = @{$results};
		my $tagtype = $groupby_tagtype;
		
		$request_ref->{structured_response}{count} = ($#tags + 1);
		
		$request_ref->{title} = sprintf(lang("list_of_x"), $Lang{$tagtype . "_p"}{$lang});
		
		if (-e "$data_root/lang/$lc/texts/" . get_fileid($Lang{$tagtype . "_p"}{$lang}) . ".list.html") {
			open (my $IN, q{<}, "$data_root/lang/$lc/texts/" . get_fileid($Lang{$tagtype . "_p"}{$lang}) . ".list.html");
			$html .= join("\n", (<$IN>));
			close $IN;
		}
		
		$html .= "<p>" . ($#tags + 1) . " ". $Lang{$tagtype . "_p"}{$lang} . ":</p>";
				
		my $th_nutriments = '';
		
		#if ($tagtype eq 'categories') {
		#	$th_nutriments = "<th>" . ucfirst($Lang{"products_with_nutriments"}{$lang}) . "</th>";
		#}
		
		my $categories_nutriments_ref;
		my @cols = ();
		
		if ($tagtype eq 'categories') {
			if (defined $request_ref->{stats_nid}) {
				$categories_nutriments_ref = retrieve("$data_root/index/categories_nutriments_per_country.$cc.sto");
				push @cols, '100g','std', 'min', '10', '50', '90', 'max';
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
		
		$html .= "<div style=\"max-width:600px;\"><table id=\"tagstable\">\n<thead><tr><th>" . ucfirst($Lang{$tagtype . "_s"}{$lang}) . "</th><th>" . ucfirst($Lang{"products"}{$lang}) . "</th>" . $th_nutriments . "</tr></thead>\n<tbody>\n";

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
				$main_link = canonicalize_taxonomy_tag_link($lc,$request_ref->{tagtype},$request_ref->{tagid}) ;
				$log->debug("main_link determined from the taxonomy tag", { main_link => $main_link }) if $log->is_debug();
			}
			else {
				$main_link = canonicalize_tag_link($request_ref->{tagtype}, $request_ref->{tagid});
				$log->debug("main_link determined from the canonical tag", { main_link => $main_link }) if $log->is_debug();
			}
			$nofollow = ' rel="nofollow"';
		}
		
		my %products = ();	# number of products by tag, used for histogram of nutrition grades colors
		
		foreach my $tagcount_ref (@tags) {
		
			my $tagid = $tagcount_ref->{_id};
			my $count = $tagcount_ref->{count};
			
			$products{$tagid} = $count;
			
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
			if ($tagtype eq 'categories') {
			
				if (defined $request_ref->{stats_nid}) {
				
					foreach my $col (@cols) {
						if ((defined $categories_nutriments_ref->{$tagid})) {
							$td_nutriments .= "<td>" . $categories_nutriments_ref->{$tagid}{nutriments}{$request_ref->{stats_nid} . '_' . $col} . "</td>";
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
					}
					else {
						$td_nutriments .= "<td style=\"text-align:center\">*</td>";
					}
				}
			}
			# show a * next to fields that do not exist in the taxonomy
			elsif (defined $taxonomy_fields{$tagtype}) {
				if (exists_taxonomy_tag($tagtype, $tagid)) {
					$td_nutriments .= "<td></td>";
				}
				else {
					$td_nutriments .= "<td style=\"text-align:center\">*</td>";
				}
			}
			

			if (defined $taxonomy_fields{$tagtype}) {
				$link = canonicalize_taxonomy_tag_link($lc, $tagtype, $tagid);
			}
			else {
				$link = canonicalize_tag_link($tagtype, $tagid);
			}
			
			my $info = '';
			my $cssclass = get_tag_css_class($lc, $tagtype, $tagid);

			my $extra_td = '';
			
			my $icid = $tagid;
			$icid =~ s/^(.*)://;	# additives
			
			my $risk_level;
			if ($tagtype eq 'additives') {
				# Take additive level from more complete FR list.
				$risk_level = $tags_levels{$lc}{$tagtype}{$icid} || $tags_levels{'fr'}{$tagtype}{$icid};

				if ($risk_level) {
					# $cssclass .= ' additives_' . $ingredients_classes{$tagtype}{$icid}{level} . ';
					# $info .= ' title="' . $ingredients_classes{$tagtype}{$icid}{warning} . '" ';
					my $risk_level_label = lang("risk_level_" . $risk_level);
					$risk_level_label =~ s/ /\&nbsp;/g;
					$extra_td = '<td class="level_' . $risk_level . '">' . $risk_level_label . '</td>';
				}
				else {
					#$extra_td = '<td class="additives_0">' . lang("risk_level_0") . '</td>';				
					$extra_td = '<td></td>';
				}
			}
			
			if ($risk_level) {
				$cssclass .= ' level_' . $risk_level;
			}
			
			my $product_link = $main_link . $link;
			
			$html .= "<tr><td>";
			
			my $display = '';
			my @sameAs = ();
			if ($tagtype eq 'nutrition_grades') {
				if ($tagid =~ /^a|b|c|d|e$/) {
					my $grade = $tagid;
					$display = "<img src=\"/images/misc/nutriscore-$grade.svg\" alt=\"$Lang{nutrition_grade_fr_alt}{$lc} " . uc($grade) . "\" style=\"margin-bottom:1rem;max-width:100%\" />" ;
				}
				else {
					$display = lang("unknown");
				}
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
				$display = display_taxonomy_tag($lc, $tagtype, $tagid);
				if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$tagid})) {
					foreach my $key (keys %weblink_templates) {
						next if not defined $properties{$tagtype}{$tagid}{$key};
						push @sameAs, sprintf($weblink_templates{$key}{href}, $properties{$tagtype}{$tagid}{$key});
					}
				}
			}
			else {
				$display = canonicalize_tag2($tagtype, $tagid);
			}

			$cssclass =~ s/^\s+|\s+$//g;
			$info .= ' class="' . $cssclass . '"';
			$html .= "<a href=\"$product_link\"$info$nofollow>" . $display . "</a>";
			$html .= "</td>\n<td style=\"text-align:right\">$products</td>" . $td_nutriments . $extra_td . "</tr>\n";
			
			my $tagentry = {
				id => $tagid,
				name => $display,
				url => format_subdomain($subdomain) . $product_link,
				products => $products + 0, # + 0 to make the value numeric
			};
			
			if (($#sameAs >= 0)) {
				$tagentry->{sameAs} = \@sameAs;
			}

			if (defined $tags_images{$lc}{$tagtype}{get_fileid($icid)}) {
				my $img = $tags_images{$lc}{$tagtype}{get_fileid($icid)};
				$tagentry->{image} = "$staticdom/images/lang/$lc/$tagtype/$img";
			}
			
			push @{$request_ref->{structured_response}{tags}}, $tagentry;
			
			# Maps for countries (and origins)
			
			if (($tagtype eq 'countries') or ($tagtype eq 'origins') or ($tagtype eq 'manufacturing_places') ) {
				my $region = $tagid;
				
				if (($tagtype eq 'origins') or ($tagtype eq 'manufacturing_places')) {
					# try to find a matching country
					$region =~ s/.*://;
					$region = canonicalize_taxonomy_tag($lc,'countries',$region);
					$display = display_taxonomy_tag($lc,$tagtype,$tagid);
					
				}
				
				if (exists($country_codes_reverse{$region})) {
					$region = uc($country_codes_reverse{$region});
					if ($region eq 'UK') {
						$region = 'GB';
					}
					$countries_map_links .=  '"' . $region . '": "' . $product_link . "\",\n";
					$countries_map_data .= '"' . $region . '": ' . $products . ",\n";		

					my $name = $display;
					$name =~ s/<(.*?)>//g;
					$countries_map_names .= '"' . $region . '": "' . $name . "\",\n";
				}
			}				
			

		}
		
		$html .= "</tbody></table></div>";
		
		
		# nutrition grades colors histogram
		
		if ($groupby_tagtype eq 'nutrition_grades') {
		
		my $categories = "'A','B','C','D','E','" . lang("unknown") . "'";
		my $series_data = '';
		foreach my $nutrition_grade ('a','b','c','d','e','unknown') {
			$series_data .= ($products{$nutrition_grade} + 0) . ',';
		}
		$series_data =~ s/,$//;
		
		my $y_title = lang("number_of_products");
		my $x_title = lang("nutrition_grades_p");

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
                text: '$Lang{data_source}{$lc}$sep: @{[ format_subdomain($subdomain) ]}'
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
                '#00ff00',
                '#ffff00',
                '#ff6600',
				'#ff0180',
				'#ff0000',
				'#808080'
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
		
		
		$html = <<HTML
<script src="/js/highcharts.4.0.4.js"></script>
<div id="container" style="height: 400px"></div>​
<p>&nbsp;</p>
HTML
	. $html;
		
		}
		
		
		# countries map?
		if ($countries_map_data ne '') {
		
			$countries_map_data =~ s/,\n?$//s;
			$initjs .= <<JS
var countries_map_data = {
$countries_map_data
};

var countries_map_links = {
$countries_map_links
};

var countries_map_names = {
$countries_map_names
};


\$('#world-map').vectorMap({
  map: 'world_mill_en',
  series: {
    regions: [{
      values: countries_map_data,
      scale: ['#C8EEFF', '#0071A4'],
      normalizeFunction: 'polynomial'
    }]
  },
  onRegionLabelShow: function(e, el, code){
	var label = el.html();
	label = countries_map_names[code];
	if (countries_map_data[code] > 0) {
		label = label + ' (' + countries_map_data[code] + ' $Lang{products}{$lc})';
	}
	el.html(label);
  },
  onRegionClick: function(e, code, region){
	if (countries_map_links[code]) {
		window.location.href = "@{[ format_subdomain($subdomain) ]}" + countries_map_links[code];
	}
  },
});

JS
;
			$scripts .= <<SCRIPTS
<script src="/js/jquery-jvectormap-1.2.2.min.js"></script>
<script src="/js/jquery-jvectormap-world-mill-en.js"></script>			
SCRIPTS
;

			$header .= <<HEADER
<link rel="stylesheet" media="all" href="/js/jquery-jvectormap-1.2.2.css"/>
HEADER
;			
			my $map_html .= <<HTML
  <div id="world-map" style="width: 600px; height: 400px"></div>
	
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
			$extra_column_searchable .= ', { "searchable": false }';
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
		{ "searchable": false } $extra_column_searchable
	]
});
JS
;

	$scripts .= <<SCRIPTS
<script src="/js/datatables.min.js"></script>
SCRIPTS
;

	$header .= <<HEADER
<link rel="stylesheet" href="/js/datatables.min.css" />
HEADER
;
		

	}
	
	# datatables clears both
	$request_ref->{full_width} = 1;

	return $html;
}



sub display_points_ranking($$) {

	my $tagtype = shift;	# users or countries
	my $tagid = shift;
	
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
		$points_ref = retrieve("$data_root/index/users_points.sto");
		$ambassadors_points_ref = retrieve("$data_root/index/ambassadors_users_points.sto");
	}
	else {
		$points_ref = retrieve("$data_root/index/countries_points.sto");
		$ambassadors_points_ref = retrieve("$data_root/index/ambassadors_countries_points.sto");	
	}

	$html .= "\n\n<table id=\"${tagtype}table\">\n";
	
	$html .= "<tr><th>" . ucfirst(lang($ranktype . "_p")) . "</th><th>Explorer rank</th><th>Explorer points</th><th>Ambassador rank</th><th>Ambassador points</th></tr>\n";
	
	my %ambassadors_ranks = ();
	
	my $i = 1;
	my $j = 1;
	my $current = -1;
	foreach my $key (sort { $ambassadors_points_ref->{$tagid}{$b} <=> $ambassadors_points_ref->{$tagid}{$a}} keys %{$ambassadors_points_ref->{$tagid}}) {
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
	
	foreach my $key (sort { $points_ref->{$tagid}{$b} <=> $points_ref->{$tagid}{$a}} keys %{$points_ref->{$tagid}}) {
		# ex-aequo: keep track of current high score
		if ($points_ref->{$tagid}{$key} != $current) {
			$j = $i;
			$current = $points_ref->{$tagid}{$key};
		}
		my $rank = $j;
		$i++;	
		
		my $display_key = $key;
		my $link = canonicalize_taxonomy_tag_link($lc,$ranktype,$key) . "/points";
		
		if ($ranktype eq "countries") {
			$display_key = display_taxonomy_tag($lc,"countries",$key);
			$link = format_subdomain($country_codes_reverse{$key}) . "/points";
		}
		
		$html .= "<tr><td><a href=\"$link\">$display_key</a></td><td>$rank</td><td>" . $points_ref->{$tagid}{$key} . "</td><td>" . $ambassadors_ranks{$key} . "</td><td>" . $ambassadors_points_ref->{$tagid}{$key} . "</td></tr>\n";
	
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
			$title = sprintf(lang("points_country"), display_taxonomy_tag($lc,$tagtype,$tagid), $n_explorers, $n_ambassadors);
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

sub display_points($) {

	my $request_ref = shift;
	
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
			$canon_tagid = canonicalize_taxonomy_tag($lc,$tagtype, $tagid); 
			$display_tag = display_taxonomy_tag($lc,$tagtype,$canon_tagid);
			$title = $display_tag; 
			$newtagid = get_taxonomyid($display_tag);
			$log->debug("displaying points for a taxonomy tag", { canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title }) if $log->is_debug();
			if ($newtagid !~ /^(\w\w):/) {
				$newtagid = $lc . ':' . $newtagid;
			}
			$newtagidpath = canonicalize_taxonomy_tag_link($lc,$tagtype, $newtagid);
			$request_ref->{current_link} = $newtagidpath;
			$request_ref->{world_current_link} =  canonicalize_taxonomy_tag_link('en',$tagtype, $canon_tagid);
		}
		else {
			$display_tag  = canonicalize_tag2($tagtype, $tagid);
			$newtagid = get_fileid($display_tag);
			if ($tagtype eq 'emb_codes') {
				$canon_tagid = $newtagid;
				$canon_tagid =~ s/-(eec|eg|ce)$/-ec/i;
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
			$log->debug("displaying points for a normal tag", { canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title }) if $log->is_debug();			
		}
	}
	
	$request_ref->{current_link} .= "/points";
	
	if ((defined $tagid) and ($newtagid ne $tagid) ) {
		$request_ref->{redirect} = $request_ref->{current_link};
		$log->info("newtagid does not equal the original tagid, redirecting", { newtagid => $newtagid, redirect => $request_ref->{redirect} }) if $log->is_info();
		return 301;
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
		$title = display_taxonomy_tag($lc,$tagtype,$tagid);
	}
	
	if (not defined $tagid) {
		$tagid = '_all_';
	}

	if (defined $tagtype) {
		$html .= display_points_ranking($tagtype, $tagid);
		$request_ref->{title} = "Open Food Hunt" . lang("title_separator") . lang("points_ranking") . lang("title_separator") . $title;
	}
	else {
		$html .= display_points_ranking("users", "_all_");
		$html .= display_points_ranking("countries", "_all_");
		$request_ref->{title} = "Open Food Hunt" . lang("title_separator") . lang("points_ranking_users_and_countries");
	}
	
	$request_ref->{content_ref} = \$html;
	

	$scripts .= <<SCRIPTS
<script src="/js/datatables.min.js"></script>
SCRIPTS
;

	$header .= <<HEADER
<link rel="stylesheet" href="/js/datatables.min.css" />
<meta property="og:image" content="https://world.openfoodfacts.org/images/misc/open-food-hunt-2015.1304x893.png"/>
HEADER
;	
			
	display_new($request_ref);

}




sub display_tag($) {

	my $request_ref = shift;
	
	my $html = '';
	
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

	if (defined $tagid) {
		if (defined $taxonomy_fields{$tagtype}) {
			$canon_tagid = canonicalize_taxonomy_tag($lc,$tagtype, $tagid); 
			$display_tag = display_taxonomy_tag($lc,$tagtype,$canon_tagid);
			$title = $display_tag; 
			$newtagid = get_taxonomyid($display_tag);
			$log->info("displaying taxonomy tag", { canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title }) if $log->is_info();
			if ($newtagid !~ /^(\w\w):/) {
				$newtagid = $lc . ':' . $newtagid;
			}
			$newtagidpath = canonicalize_taxonomy_tag_link($lc,$tagtype, $newtagid);
			$request_ref->{current_link} = $newtagidpath;
			$request_ref->{world_current_link} =  canonicalize_taxonomy_tag_link('en',$tagtype, $canon_tagid);
		}
		else {
			$display_tag  = canonicalize_tag2($tagtype, $tagid);
			$newtagid = get_fileid($display_tag);
			if ($tagtype eq 'emb_codes') {
				$canon_tagid = $newtagid;
				$canon_tagid =~ s/-(eec|eg|ce)$/-ec/i;
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
			$log->info("displaying normal tag", { canon_tagid => $canon_tagid, newtagid => $newtagid, title => $title }) if $log->is_info();
		}
		
		# add back leading dash when a tag is excluded
		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} ne '')) {
			my $prefix = $request_ref->{tag_prefix};
			$request_ref->{current_link} =~ s/^\/([^\/]+)$/\/$prefix$1/;
			$request_ref->{world_current_link} =~ s/^\/([^\/]+)$/\/$prefix$1/;
		}		
	}
	else {
		$log->warn("no tagid found") if $log->is_warn();
	}
	
	# 2nd tag?
	if (defined $tagid2) {
		if (defined $taxonomy_fields{$tagtype2}) {
			$canon_tagid2 = canonicalize_taxonomy_tag($lc,$tagtype2, $tagid2); 
			$display_tag2 = display_taxonomy_tag($lc,$tagtype2,$canon_tagid2);
			$title .= " / " . $display_tag2; 
			$newtagid2 = get_taxonomyid($display_tag2);		
			$log->info("2nd level tag is a taxonomy tag", { tagtype2 => $tagtype2, tagid2 => $tagid2, canon_tagid2 => $canon_tagid2, newtagid2 => $newtagid2, title => $title }) if $log->is_info();
			if ($newtagid2 !~ /^(\w\w):/) {
				$newtagid2 = $lc . ':' . $newtagid2;
			}
			$newtagid2path = canonicalize_taxonomy_tag_link($lc,$tagtype2, $newtagid2);
			$request_ref->{current_link} .= $newtagid2path;
			$request_ref->{world_current_link} .= canonicalize_taxonomy_tag_link('en',$tagtype2, $canon_tagid2);
		}
		else {
			$display_tag2 = canonicalize_tag2($tagtype2, $tagid2);
			$title .= " / " . $display_tag2;
			$newtagid2 = get_fileid($display_tag2);
			if ($tagtype2 eq 'emb_codes') {
				$canon_tagid2 = $newtagid2;
				$canon_tagid2 =~ s/-(eec|eg|ce)$/-ec/i;
			}				
			$newtagid2path = canonicalize_tag_link($tagtype2, $newtagid2);
			$request_ref->{current_link} .= $newtagid2path;
			my $current_lang = $lang;
			my $current_lc = $lc;
			$lang = 'en';
			$lc = 'en';
			$request_ref->{world_current_link} .= canonicalize_tag_link($tagtype2, $newtagid2);
			$lang = $current_lang;
			$lc = $current_lc;
		}
		
		# add back leading dash when a tag is excluded
		if ((defined $request_ref->{tag2_prefix}) and ($request_ref->{tag2_prefix} ne '')) {
			my $prefix = $request_ref->{tag2_prefix};
			$request_ref->{current_link} =~ s/^\/([^\/]+)$/\/$prefix$1/;
			$request_ref->{world_current_link} =~ s/^\/([^\/]+)$/\/$prefix$1/;
		}		
		
	}

	if (defined $request_ref->{groupby_tagtype}) {
		$request_ref->{world_current_link} .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{en};
	}
	
	if (((defined $newtagid) and ($newtagid ne $tagid)) or ((defined $newtagid2) and ($newtagid2 ne $tagid2))) {
		$request_ref->{redirect} = $request_ref->{current_link};
		# Re-add file suffix, so that the correct response format is kept. https://github.com/openfoodfacts/openfoodfacts-server/issues/894
		$request_ref->{redirect} .= '.json' if $request_ref->{json};
		$request_ref->{redirect} .= '.jsonp' if $request_ref->{jsonp};
		$request_ref->{redirect} .= '.xml' if $request_ref->{xml};
		$request_ref->{redirect} .= '.jqm' if $request_ref->{jqm};
		$log->info("one or more tagids mismatch, redirecting to correct url", { redirect => $request_ref->{redirect} }) if $log->is_info();
		return 301;
	}
	
	my $weblinks_html = '';
	my @map_layers = ();
	if ( ($tagtype ne 'additives')
		and (not defined $request_ref->{groupby_tagtype})) {
		my @weblinks = ();
		if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid})) {
			foreach my $key (keys %weblink_templates) {
				next if not defined $properties{$tagtype}{$canon_tagid}{$key};
				my $weblink = {
					text => $weblink_templates{$key}{text},
					href => sprintf($weblink_templates{$key}{href}, $properties{$tagtype}{$canon_tagid}{$key}),
					hreflang => $weblink_templates{$key}{hreflang},
				};
				$weblink->{title} = sprintf($weblink_templates{$key}{title}, $properties{$tagtype}{$canon_tagid}{$key}) if defined $weblink_templates{$key}{title},
				push @weblinks, $weblink;
			}

			if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid}{'wikidata:en'})) {
				push @map_layers, 'addWikidataObjectToMap("' . $properties{$tagtype}{$canon_tagid}{'wikidata:en'} . '")';
			}
		}

		if (($#weblinks >= 0)) {
			$weblinks_html .= '<div style="float:right;width:300px;margin-left:20px;margin-bottom:20px;padding:10px;border:1px solid #cbe7ff;background-color:#f0f8ff;"><h3>' . lang('tag_weblinks') . '</h3><ul>';
			foreach my $weblink (@weblinks) {
				$weblinks_html .= '<li><a href="' . encode_entities($weblink->{href}) . '" itemprop="sameAs"';
				$weblinks_html .= ' hreflang="' . encode_entities($weblink->{hreflang}) . '"' if defined $weblink->{hreflang};
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
	
	if (defined $tagtype) {
	
	# check if there is a template to display additional fields from the taxonomy
	
	if (exists $options{"display_tag_" . $tagtype}) {
	
		print STDERR "option display_tag_$tagtype\n";
	
		foreach my $field_orig (@{$options{"display_tag_" . $tagtype}}) {
		
			my $field = $field_orig;
			
			$log->debug("display_tag - field", { field => $field }) if $log->is_debug();
		
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
				$log->debug("display_tag - section title", { field => $field }) if $log->is_debug();
				next;
			}
			
			
			# Special processing
			
			if ($field eq 'efsa_evaluation_exposure_table') {
			
				$log->debug("display_tag - efsa_evaluation_exposure_table", { efsa_evaluation_overexposure_risk => $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en:"} }) if $log->is_debug();
			
				if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid})
					and (defined $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"})
					and ($properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"} ne 'en:no')) {
					
					$log->debug("display_tag - efsa_evaluation_exposure_table - yes", {  }) if $log->is_debug();
			
					my @groups = qw(infants toddlers children adolescents adults elderly);
					my @percentiles = qw(mean 95th);
					my @doses = qw(noael adi);
					my %doses = ();
					
					my %exposure = (mean => {}, '95th' => {});
					
					# in taxonomy:
					# efsa_evaluation_exposure_95th_greater_than_adi:en: en:adults, en:elderly, en:adolescents, en:children, en:toddlers, en:infants

					foreach my $dose (@doses) {
						foreach my $percentile (@percentiles) {
							my $exposure_property = "efsa_evaluation_exposure_" . $percentile . "_greater_than_" . $dose . ":en";
							if (defined $properties{$tagtype}{$canon_tagid}{$exposure_property}) {
								foreach my $groupid (split(/,/, $properties{$tagtype}{$canon_tagid}{$exposure_property})) {
									my $group = $groupid;
									$group =~ s/^\s*en://;
									$group =~ s/\s+$//;
									
									# NOAEL has priority over ADI
									if (not exists $exposure{$percentile}{$group}) {
										$exposure{$percentile}{$group} = $dose;
										$doses{$dose} = 1; # to display legend for the dose
										$log->debug("display_tag - exposure_table ", { group => $group, percentile => $percentile, dose => $dose }) if $log->is_debug();
									}
								}
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
					
						$table .= '<td style="background-color:black;color:white;">' . lang($group . "_age") . "</td>";					
					}					
			
					$table .= "</tr>\n";
								
					my %icons = (
						adi => 'moderate',
						noael => 'high',
					);
								
					foreach my $percentile (@percentiles) {
					
						$table .= "<tr><th>" . lang("exposure_title_" . $percentile) . "<br/>("
							. lang("exposure_description_" . $percentile) . ")</th>";
							
						foreach my $group (@groups) {
					
							$table .= "<td>";
							
							my $dose = $exposure{$percentile}{$group};

							if (not defined $dose ) {
								$table .= "&nbsp;";
							}
							else {
								$table .= '<img src="/images/misc/' . $icons{$dose} . '.svg" alt="'
									. lang("additives_efsa_evaluation_exposure_" . $percentile . "_greater_than_" . $dose) 
									. '" />';
							}							
							
							$table .= "</td>";
						}	
						
						$table .= "</tr>\n";
					}
			
					$table .= "</tbody>\n</table>\n</div>";
			
					$description .= $table;
					
					foreach my $dose (@doses) {
						if (exists $doses{$dose}) {
							$description .= "<p>" . '<img src="/images/misc/' . $icons{$dose} . '.svg" width="30" height="30" style="vertical-align:middle" alt="'
									. lang("additives_efsa_evaluation_exposure_greater_than_" . $dose) . '" /> <span>: '
									. lang("additives_efsa_evaluation_exposure_greater_than_" . $dose) . "</span></p>\n";
						}
					}
				}
				next;
			}
			
			
			my $fieldid = get_fileid($field);
			$fieldid =~ s/-/_/g;
			
			my %propertyid = ();
			
			
			# Check if we have properties in the interface language, otherwise use English
			
			
			if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid}) ) {
			
				$log->debug("display_tag - checking properties", { tagtype => $tagtype, canon_tagid => $canon_tagid, field => $field}) if $log->is_debug();
			
			
				foreach my $key ('property', 'description', 'abstract', 'url', 'date') {			
				
					my $suffix = "_" . $key;
					if ($key eq 'property') {
						$suffix = '';
					}
				
					if (defined $properties{$tagtype}{$canon_tagid}{$fieldid . $suffix . ":" . $lc})  {
						$propertyid{$key} = $fieldid . $suffix . ":" . $lc;
						$log->debug("display_tag - property key is defined for lc $lc", { tagtype => $tagtype, canon_tagid => $canon_tagid, field => $field, key => $key, propertyid => $propertyid{$key} }) if $log->is_debug();						
						}
					elsif (defined $properties{$tagtype}{$canon_tagid}{$fieldid . $suffix . ":" . "en"})  {
						$propertyid{$key} = $fieldid . $suffix .":" . "en";
						$log->debug("display_tag - property key is defined for en", { tagtype => $tagtype, canon_tagid => $canon_tagid, field => $field, key => $key, propertyid => $propertyid{$key} }) if $log->is_debug();						
					}
					else {
						$log->debug("display_tag - property key is not defined", { tagtype => $tagtype, canon_tagid => $canon_tagid, field => $field, key => $key, propertyid => $propertyid{$key} }) if $log->is_debug();
					}					
				}
			}
			
			$log->debug("display_tag", { tagtype => $tagtype, canon_tagid => $canon_tagid, field_orig => $field_orig, field => $field, propertyid => $propertyid{property}, array => $array }) if $log->is_debug();
	
			if ((defined $propertyid{property}) or (defined $propertyid{abstract})) {
			
				# abstract?
				
				if (defined $propertyid{abstract}) {
								
					my $site = $fieldid;
					
					$log->debug("display_tag - showing abstract", { site => $site }) if $log->is_debug();
				
					$description .= "<p>" . $properties{$tagtype}{$canon_tagid}{$propertyid{abstract}} ;
					
					if (defined $propertyid{url}) {
					
						my $lang_site = lang($site);
						if ((defined $lang_site) and ($lang_site ne "")) {
							$site = $lang_site;
						}
						$description .= ' - <a href="' . $properties{$tagtype}{$canon_tagid}{$propertyid{url}} . '">' . $site . '</a>';
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
			
				$log->debug("display_tag - title", { tagtype => $tagtype, title => $title }) if $log->is_debug();
			
				$description .= "<p>";
				
				if (defined $title) {
					$description .= "<b>" . $title . "</b>" . separator_before_colon($lc) . ": ";
				}
				
				my @values = ( $properties{$tagtype}{$canon_tagid}{$propertyid{property}} );
				
				if ($array) {
					@values = split(/,/, $properties{$tagtype}{$canon_tagid}{$propertyid{property}});
				}
				
				my $values_display = "";
					
				foreach my $value_orig (@values) {
				
					my $value = $value_orig; # make a copy so that we can modify it inside the foreach loop
					
					next if $value =~ /^\s*$/;
					
					$value =~ s/^\s+//;
					$value =~ s/\s+$//;
				
					my $property_tagtype = $fieldid;
					
					$property_tagtype =~ s/-/_/g;
					
					if (not exists $taxonomy_fields{$property_tagtype}) {
						# try with an additional s
						$property_tagtype .= "s";
					}
											
					$log->debug("display_tag", { property_tagtype => $property_tagtype, lc => $lc, value => $value }) if $log->is_debug();
					
					my $display = $value;
					
					if (exists $taxonomy_fields{$property_tagtype}) {
					
						$display = display_taxonomy_tag($lc, $property_tagtype, $value);
						
						$log->debug("display_tag - $property_tagtype is a taxonomy", { display => $display }) if $log->is_debug();
					
						if ((defined $properties{$property_tagtype}) and (defined $properties{$property_tagtype}{$value}) ) {
						
							# tooltip
						
							my $tooltip;
							
							if (defined $properties{$property_tagtype}{$value}{"description:$lc"})  {
								$tooltip = $properties{$property_tagtype}{$value}{"description:$lc"};
							}
							elsif (defined $properties{$property_tagtype}{$value}{"description:en"})  {
								$tooltip = $properties{$property_tagtype}{$value}{"description:en"}
							}
							
							if (defined $tooltip) {
								$display = '<span data-tooltip aria-haspopup="true" class="has-tip top" style="font-weight:normal" data-disable-hover="false" tabindex="2" title="'
								. $tooltip . '">' . $display . '</span>';
							}
							else {
								$log->debug("display_tag - no tooltip", { property_tagtype => $property_tagtype, value => $value }) if $log->is_debug();
							}
							
						}
						else {
							$log->debug("display_tag - no property found", { property_tagtype => $property_tagtype, value => $value }) if $log->is_debug();
						}
					}
					else {
						$log->debug("display_tag - not a taxonomy", { property_tagtype => $property_tagtype, value => $value }) if $log->is_debug();
						
						# Do we have a translation for the field?
						
						my $valueid = $value;
						$valueid =~ s/^en://;
						
						# check if the value translate to a field specific value
						
						if (exists $Lang{$tagtype_field . "_" . $valueid}{$lc}) {
							$display = $Lang{$tagtype_field . "_" . $valueid }{$lc};
						}
						
						# check if we have an icon
						if (exists $Lang{$tagtype_field . "_icon_alt_" . $valueid}{$lc}) {
							my $alt = $Lang{$tagtype_field . "_icon_alt_" . $valueid }{$lc};
							my $iconid = $tagtype_field . "_icon_" . $valueid;
							$iconid =~ s/_/-/g;
							$display = <<HTML
<div class="row">
<div class="small-2 large-1 columns">
<img src="/images/misc/$iconid.svg" alt="$alt" /> 
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
						
						$log->debug("display_tag - display value", { display => $display }) if $log->is_debug();
						
						# tooltip
						
						if (exists $Lang{$valueid . "_description"}{$lc}) {

							my $tooltip = $Lang{$valueid . "_description"}{$lc};
							
							$display = '<span data-tooltip aria-haspopup="true" class="has-tip top" data-disable-hover="false" tabindex="2" title="'
								. $tooltip . '">' . $display . '</span>';
							
						}
						else {
							$log->debug("display_tag - no description", { valueid => $valueid }) if $log->is_debug();
						}					

						# link
						
						if (exists $propertyid{url}) {
							$display = '<a href="' . $properties{$tagtype}{$canon_tagid}{$propertyid{url}} . '">'
									. $display . "</a>";
						}
						if (exists $Lang{$valueid . "_url"}{$lc}) {
							$display = '<a href="' . $Lang{$valueid . "_url"}{$lc} . '">'
									. $display . "</a>";
						}
						else {
							$log->debug("display_tag - no url", { valueid => $valueid }) if $log->is_debug();
						}
						
						# date
						
						if (exists $propertyid{date}) {
							$display .= " (" . $properties{$tagtype}{$canon_tagid}{$propertyid{date}} . ")";
						}	
						if (exists $Lang{$valueid . "_date"}{$lc}) {
							$display .= " (" . $Lang{$valueid . "_date"}{$lc} . ")";
						}						
						else {
							$log->debug("display_tag - no date", { valueid => $valueid }) if $log->is_debug();
						}
						
					}
								
					$values_display .=  $display . ", ";
				}
				$values_display =~ s/, $//;				
				
				$description .= $values_display . "</p>\n";
				
				# Display an optional description of the property
				
				if (exists $Lang{$tagtype_field . "_description"}{$lc}) {
					$description .= "<p>" . $Lang{$tagtype_field . "_description"}{$lc} . "</p>";
				}
				
			}
			else {
					$log->debug("display_tag - property not defined", { tagtype => $tagtype, property_id => $propertyid{property}, canon_tagid => $canon_tagid }) if $log->is_debug();
			}
	
		}
		
		# Remove titles without content
		
		$description =~ s/<h3>([^<]+)<\/h3>\s*(<h3>)/<h3>/isg;
		$description =~ s/<h3>([^<]+)<\/h3>\s*$//isg;
		
	
	}
	
	$description =~ s/<tag>/$title/g;
	
		
	if (defined $ingredients_classes{$tagtype}) {
		my $class = $tagtype;
		
		if ($class eq 'additives') {
			$icid =~ s/-.*//;
		}		
		if ($ingredients_classes{$class}{$icid}{other_names} =~ /,/) {
			$description .= "<p>" . lang("names") . separator_before_colon($lc) . ": " . $ingredients_classes{$class}{$icid}{other_names} . "</p>";
		}
		
		if ($ingredients_classes{$class}{$icid}{description} ne '') {
			$description .= "<p>" . $ingredients_classes{$class}{$icid}{description} . "</p>";
		}
		
		if ($ingredients_classes{$class}{$icid}{level} > 0) {
		
			my $warning = $ingredients_classes{$class}{$icid}{warning};
			$warning =~ s/(<br>|<br\/>|<br \/>|\n)/<\li>\n<li>/g;
			$warning = "<li>" . $warning . "</li>";
		
			if (defined $Lang{$class . '_' . $ingredients_classes{$class}{$icid}{level}}{$lang}) {
				$description .= "<p class=\"" . $class . '_' . $ingredients_classes{$class}{$icid}{level} . "\">"
					. $Lang{$class . '_' . $ingredients_classes{$class}{$icid}{level}}{$lang} . "</p>\n";
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
	
	
	if (($request_ref->{page} <= 1 ) and (defined $tags_texts{$lc}{$tagtype}{$icid})) {
		$description .= $tags_texts{$lc}{$tagtype}{$icid};
	}	
	
	my @markers = ();
	if ($tagtype eq 'emb_codes') {
	
		my $city_code = get_city_code($tagid);
		
		local $log->context->{city_code} = $city_code;
		$log->debug("city code for tag with emb_code type") if $log->debug();
		
		if (defined $emb_codes_cities{$city_code}) {
			$description .= "<p>" . lang("cities_s") . separator_before_colon($lc) . ": " . display_tag_link('cities', $emb_codes_cities{$city_code}) . "</p>";
		}
		
		$log->debug("checking if the canon_tagid is a packager code") if $log->is_debug();		
		if (exists $packager_codes{$canon_tagid}) {
			$log->debug("packager code found for the canon_tagid", { cc => $packager_codes{$canon_tagid}{cc} }) if $log->is_debug();
			
			# Generate a map if we have coordinates
			my ($lat, $lng) = get_packager_code_coordinates($canon_tagid);
			if ((defined $lat) and (defined $lng)) {
				my $geo = "$lat,$lng";
				push @markers, $geo;
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

			if ($packager_codes{$canon_tagid}{cc} eq 'uk') {
			
				my $district = '';
				my $local_authority = '';
				if ($packager_codes{$canon_tagid}{district} =~ /\w/) {
					$district = "District: $packager_codes{$canon_tagid}{district}<br/>";
				}
				if ($packager_codes{$canon_tagid}{local_authority} =~ /\w/) {
					$local_authority = "Local authority: $packager_codes{$canon_tagid}{local_authority}<br/>";
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
					my $img = "images/countries/uk/ratings/large/72ppi/" . lc($packager_codes{$canon_tagid}{fsa_rating_key}). ".jpg";
					if (-e "$www_root/$img") {
						$logo = <<HTML
<img src="/$img" alt="Rating" />
HTML
;
					}
					$description .= <<HTML
<div>
<a href="https://ratings.food.gov.uk/">Food Hygiene Rating</a> from the Food Standards Agency (FSA):
<p>
Business name: $packager_codes{$canon_tagid}{fsa_rating_business_name}<br/>
Business type: $packager_codes{$canon_tagid}{fsa_rating_business_type}<br/>
Address: $packager_codes{$canon_tagid}{fsa_rating_address}<br/>
Local authority: $packager_codes{$canon_tagid}{fsa_rating_local_authority}<br/>
Rating: $packager_codes{$canon_tagid}{fsa_rating_value}<br/>
Rating date: $packager_codes{$canon_tagid}{fsa_rating_date}<br/>
</p>
$logo
</div>
HTML
;
				}
			}	
		}
	}

	$description = <<HTML
<div class="row">

	<div id="tag_description" class="large-12 columns">
		$description
	</div>
	<div id="tag_map" class="large-9 columns" style="display: none;">
		<div id="container" style="height: 300px"></div>​
	</div>

</div>			

HTML
;

	if ((scalar @markers) > 0) {
		my $layer = '';
		foreach my $geo (@markers) {
			$layer .= "\nmarkers.push(L.marker([$geo]))\n";
		}

		$layer .= <<JS
runCallbackOnJson(function (map) {
	L.featureGroup(markers).addTo(map)
	fitBoundsToAllLayers(map)
})
JS
;
		push @map_layers, $layer;
	}

	if ((scalar @map_layers) > 0) {
		$header .= <<HTML		
	<link rel="stylesheet" href="/bower_components/leaflet/dist/leaflet.css">
	<script src="/bower_components/leaflet/dist/leaflet.js"></script>
	<script src="/bower_components/osmtogeojson/osmtogeojson.js"></script>
	<script src="/js/display-tag.js"></script>
HTML
;
		
		my $js = '';
		foreach my $layer (@map_layers) {
			$js .= $layer;
		}
		
		$js .= $request_ref->{map_options};
		
		$initjs .= $js;
	}

	if ($tagtype eq 'users') {
		my $user_ref = retrieve("$data_root/users/$tagid.sto");
		
		if ($admin) {
			$description .= "<p>" . $user_ref->{email} . "</p>";
		}
		
		if (defined $user_ref) {
			if ((defined $user_ref->{name}) and ($user_ref->{name} ne '')) {
				$title = $user_ref->{name} . " ($tagid)";
				$products_title = $user_ref->{name};
			}
			
			$description .= "<p>" . lang("contributor_since") . " " . display_date_tag($user_ref->{registered_t}) . "</p>";
			
			if ((defined $user_ref->{missions}) and ($request_ref->{page} <= 1 )) {
				my $missions = '';
				my $i = 0;
			
				foreach my $missionid (sort { $user_ref->{missions}{$b} <=> $user_ref->{missions}{$a}} keys %{$user_ref->{missions}}) {
					$missions .= "<li style=\"margin-bottom:10px;clear:left;\"><img src=\"/images/misc/gold-star-32.png\" alt=\"Star\" style=\"float:left;margin-top:-5px;margin-right:20px;\"/> <div>"
					. "<a href=\"" . canonicalize_tag_link("missions", $missionid) . "\" style=\"font-size:1.4em\">"
					. $Missions{$missionid}{name} . "</a></div></li>\n";
					$i++;
				}
				
				if ($i > 0) {
					$missions = "<h2>" . lang("missions") . "</h2>\n<p>"
					. $products_title . ' ' . sprintf(lang("completed_n_missions"), $i) . "</p>\n"
					. '<ul id="missions" style="list-style-type:none">' . "\n" . $missions . "</ul>";
					$missions =~ s/ 1 missions/ 1 mission/;
				}
				
				$description .= $missions;
			}		
		}
	}	
	
	if ($tagtype eq 'categories') {
	
		my $categories_nutriments_ref = retrieve("$data_root/index/categories_nutriments_per_country.$cc.sto");
	
		$log->debug("checking if this category has stored statistics", { cc => $cc, tagtype => $tagtype, tagid => $tagid }) if $log->is_debug();	
		if ((defined $categories_nutriments_ref) and (defined $categories_nutriments_ref->{$canon_tagid})
			and (defined $categories_nutriments_ref->{$canon_tagid}{stats})) {
			$log->debug("statistics found for the tag, addind stats to description", { cc => $cc, tagtype => $tagtype, tagid => $tagid }) if $log->is_debug();
	
			$description .= "<h2>" . lang("nutrition_data") . "</h2>"
				. "<p>"
				. sprintf(lang("nutrition_data_average"), $categories_nutriments_ref->{$canon_tagid}{n}, $display_tag,
				$categories_nutriments_ref->{$canon_tagid}{count}) . "</p>"
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
		$products_title .= lang("title_separator") . lang($tagtype2 . '_s') . separator_before_colon($lc) . ": " . $display_tag2;
	}
	
	if (not defined $request_ref->{groupby_tagtype}) {
		if (defined $tagid2) {
			$html .= "<p><a href=\"/" . $tag_type_plural{$tagtype}{$lc} . "\">" . ucfirst(lang($tagtype . '_p')) . "</a>" . separator_before_colon($lc)
				. ": <a href=\"$newtagidpath\">$display_tag</a>"		
				. "\n<br /><a href=\"/" . $tag_type_plural{$tagtype2}{$lc} . "\">" . ucfirst(lang($tagtype2 . '_p')) . "</a>" . separator_before_colon($lc)
				. ": <a href=\"$newtagid2path\">$display_tag2</a></p>";		
		}
		else {
			$html .= "<p><a href=\"/" . $tag_type_plural{$tagtype}{$lc} . "\">" . ucfirst(lang($tagtype . '_p')) . "</a>" . separator_before_colon($lc). ": $display_tag</p>";
			
			my $tag_html .= display_tags_hierarchy_taxonomy($lc, $tagtype, [$canon_tagid]);
			
			$tag_html =~ s/.*<\/a>(<br \/>)?//;	# remove link, keep only tag logo
			
			$html .= $tag_html;

			my $share = lang('share');
			$html .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;margin-left:10px;display:none;">
<a href="$request_ref->{canon_url}" class="button small icon" title="$title">
	<i class="fi-share"></i>
	<span class="show-for-large-up"> $share</span>
</a></div>
HTML
;

			$html .= $weblinks_html . display_parents_and_children($lc, $tagtype, $canon_tagid) . $description;
		}
		
		
	
		$html .= "<h2>" . $products_title . lang("title_separator") . display_taxonomy_tag($lc,"countries",$country) . "</h2>\n";
	}
	
	} # end of if (defined $tagtype)
	
	if ($country ne 'en:world') {
		my $worlddom = format_subdomain('world');
		if (defined $request_ref->{groupby_tagtype}) {
			$html .= "<p>&rarr; <a href=\"" . $worlddom . $request_ref->{world_current_link} . "\">" . lang('view_list_for_products_from_the_entire_world') . "</a></p>";			
		}
		else {
			$html .= "<p>&rarr; <a href=\"" . $worlddom . $request_ref->{world_current_link} . "\">" . lang('view_products_from_the_entire_world') . "</a></p>";
		}
	}

	my $query_ref = {};
	my $sort_by;
	if ($tagtype eq 'users') {
		$query_ref->{creator} = $tagid;
		$sort_by = 'last_modified_t';
	}
	elsif (defined $canon_tagid) {
		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} ne '')) {
			$query_ref->{ ($tagtype . "_tags")} = { "\$ne" => $canon_tagid };
		}
		else {
			$query_ref->{ ($tagtype . "_tags")} = $canon_tagid;
		}
		$sort_by = 'last_modified_t';		
	}
	elsif (defined $tagid) {
		if ((defined $request_ref->{tag_prefix}) and ($request_ref->{tag_prefix} ne '')) {
			$query_ref->{ ($tagtype . "_tags")} = { "\$ne" => $tagid };
		}
		else {
			$query_ref->{ ($tagtype . "_tags")} = $tagid;
		}
		$sort_by = 'last_modified_t';
	}
	
	# db.myCol.find({ mylist: { $ne: 'orange' } })

	
	# unknown ?
	if (($tagid eq get_fileid(lang("unknown"))) or ($tagid eq ($lc . ":" . get_fileid(lang("unknown"))))) {
		#$query_ref = { ($tagtype . "_tags") => "[]"};
		$query_ref = { "\$or" => [ { ($tagtype ) => undef}, { $tagtype => ""} ] };
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
		
		# 2 criteria on the same field?
		# we need to use the $and MongoDB syntax 
		
		if (defined $query_ref->{$field}) {
			my $and = [{ $field => $query_ref->{$field} }];
			push @$and, { $field => $value };
			delete $query_ref->{$field};
			$query_ref->{"\$and"} = $and;
		}	
		else {
			$query_ref->{$field} = $value;
		}
		
	}	
	
	
	
	if (defined $request_ref->{groupby_tagtype}) {
		${$request_ref->{content_ref}} .= $html . display_list_of_tags($request_ref, $query_ref);
		if ($products_title ne '') {
			$request_ref->{title} .= " " . lang("for") . " " . lcfirst($products_title);
		}
		$request_ref->{title} .= lang("title_separator") . display_taxonomy_tag($lc,"countries",$country);
	}
	else {
		if ((defined $request_ref->{page}) and ($request_ref->{page} > 1)) {
			$request_ref->{title} = $title . lang("title_separator") . sprintf(lang("page_x"), $request_ref->{page});
		}
		else {
			$request_ref->{title} = $title;
		}

		$html = "<div itemscope itemtype=\"https://schema.org/Thing\"><h1 itemprop=\"name\">" . $title ."</h1>" . $html . "</div>";
		${$request_ref->{content_ref}} .= $html . search_and_display_products($request_ref, $query_ref, $sort_by, undef, undef);
	}

	
	
	display_new($request_ref);

}




sub search_and_display_products($$$$$) {

	my $request_ref = shift;
	my $query_ref = shift;
	my $sort_by = shift;
	my $limit = shift;
	my $page = shift;
	

	
	if (defined $country) {
		if ($country ne 'en:world') {
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
				push @$and, { $field => $query_ref->{$field} };
				push @$and, { $field => $value };
				delete $query_ref->{$field};
				$query_ref->{"\$and"} = $and;
			}
		}
		
	}
	
	delete $query_ref->{lc};
	
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
	
	my $sort_ref = Tie::IxHash->new();
	
	if (defined $sort_by) {
	}
	elsif (defined $request_ref->{sort_by}) {
		$sort_by = $request_ref->{sort_by};
	}
		
	
	if (defined $sort_by) {
		my $order = 1;
		if ($sort_by =~ /^((.*)_t)_complete_first/) {
			#$sort_by = $1;
			#$sort_ref->Push(complete => -1);
			$sort_ref->Push(sortkey => -1);
			$order = -1;
		}		
		elsif ($sort_by =~ /_t/) {
			$order = -1;
			$sort_ref->Push($sort_by => $order);
		}
		elsif ($sort_by =~ /scans_n/) {
			$order = -1;
			$sort_ref->Push($sort_by => $order);		
		}
		else {
			$sort_ref->Push($sort_by => $order);
		}
	}
	

	my $cursor;
	my $count;
	
	my $mongodb_query_ref = [ lc => $lc, query => $query_ref, sort => $sort_ref, limit => $limit, skip => $skip ];
	
	my $key = $server_domain . "/" . freeze($mongodb_query_ref);
	
	$log->debug("MongoDB query key", { key => $key }) if $log->is_debug();
	
	$key = md5_hex($key);
	
	$log->debug("MongoDB hashed query key", { key => $key }) if $log->is_debug();
	
	$request_ref->{structured_response} = $memd->get($key);
	
	$log->debug("Retrieving value for MongoDB query key", { key => $key }) if $log->is_debug();
	
	if (not defined $request_ref->{structured_response}) {
	
		$log->debug("Did not find value for MongoDB query key", { key => $key }) if $log->is_debug();
		
		$request_ref->{structured_response} = {
			page => $page,
			page_size => $limit,
			skip => $skip,
			products => [],
		};	
		
		eval {
			if (($options{mongodb_supports_sample}) and (defined $request_ref->{sample_size})) {
				my $aggregate_parameters = [
					{ "\$match" => $query_ref },
					{ "\$sample" => { "size" => $request_ref->{sample_size} } }
				];
				$log->debug("Executing MongoDB query", { query => $aggregate_parameters }) if $log->is_debug();
				$cursor = $products_collection->aggregate($aggregate_parameters);
			}
			else {
				$log->debug("Executing MongoDB query", { query => $mongodb_query_ref }) if $log->is_debug();
				$cursor = $products_collection->query($query_ref)->sort($sort_ref)->limit($limit)->skip($skip);
				$count = $cursor->count() + 0;
				$log->info("MongoDB query ok", { error => $@, result_count => $count }) if $log->is_info();
			}
		};
		if ($@) {
			$log->warn("MongoDB error - retrying once", { error => $@ }) if $log->is_warn();
			# maybe $connection auto-reconnects but $database and $products_collection still reference the old connection?
			
			# opening new connection
			eval {
				$connection = MongoDB->connect($mongodb_host);
				$database = $connection->get_database($mongodb);
				$products_collection = $database->get_collection('products');
			};
			if ($@) {
				$log->error("MongoDB error - reconnecting failed", { error => $@ }) if $log->is_error();
				$count = -1;
			}
			else {		
				$log->info("MongoDB reconnect ok", { error => $@ }) if $log->is_info();
				if (($options{mongodb_supports_sample}) and (defined $request_ref->{sample_size})) {
					my $aggregate_parameters = [
						{ "\$match" => $query_ref },
						{ "\$sample" => { "size" => $request_ref->{sample_size} } }
					];
					$log->debug("Executing MongoDB query", { query => $aggregate_parameters }) if $log->is_debug();
					$cursor = $products_collection->aggregate($aggregate_parameters);
				}
				else {
					$log->debug("Executing MongoDB query", { query => $query_ref, sort => $sort_ref, limit => $limit, skip => $skip }) if $log->is_debug();
					$cursor = $products_collection->query($query_ref)->sort($sort_ref)->limit($limit)->skip($skip);
					$count = $cursor->count() + 0;
					$log->info("MongoDB query ok", { error => $@, result_count => $count }) if $log->is_info();

				}
				$log->debug("MongoDB query done", { error => $@ }) if $log->is_debug();
			}
		}
		
		while (my $product_ref = $cursor->next) {
			push @{$request_ref->{structured_response}{products}}, $product_ref;
		}
	
		$request_ref->{structured_response}{count} = $count + 0;
		
		$log->debug("Setting value for MongoDB query key", { key => $key }) if $log->is_debug();

		$memd->set($key, $request_ref->{structured_response}, 3600) or $log->debug("Could not set value for MongoDB query key", { key => $key });
		
	}
	else {
		$log->debug("Found a value for MongoDB query key", { key => $key }) if $log->is_debug();
	}
	
	
	
	$count = $request_ref->{structured_response}{count};
	
	if (defined $request_ref->{description}) {
		$request_ref->{description} =~ s/<nb_products>/$count/g;
	}
	
	my $html = '';
	my $html_pages = '';
	my $html_count = '';
	
	if (not defined $request_ref->{jqm_loadmore}) {
		if ($count < 0) {
			$html .= "<p>" . lang("error_database") . "</p>";	
		}
		elsif ($count == 0) {
			$html .= "<p>" . lang("no_products") . "</p>";
		}
		elsif ($count == 1) {
			$html_count .= lang("1_product");
		}
		elsif ($count > 1) {
			$html_count .= sprintf(lang("n_products"), $count) ;
		}
	}
	
	if ((defined $request_ref->{current_link_query}) and (not defined $request_ref->{jqm})) {
	
		if ($country ne 'en:world') {
			$html .= "<p>&rarr; <a href=\"" . format_subdomain('world') . $request_ref->{current_link_query} . "&action=display\">" . lang('view_results_from_the_entire_world') . "</a></p>";
		}	
	
		$request_ref->{current_link_query_display} = $request_ref->{current_link_query};
		$html .= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">" . lang("search_link") . "</a><br />";
		$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
		$html .= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">" . lang("search_edit") . "</a><br />";
			
		
	}
		
	if ($count > 0) {
	
		if ((defined $request_ref->{current_link_query}) and (not defined $request_ref->{jqm}))  {
			$request_ref->{current_link_query_download} = $request_ref->{current_link_query};
			$request_ref->{current_link_query_download} .= "&download=on";
			$html .= "&rarr; <a href=\"$request_ref->{current_link_query_download}\">" . lang("search_download_results") . "</a><br />";
		}
		
		if ($log->is_debug()) {
			my $debug_log = "search - count: $count";
			defined $request_ref->{search} and $debug_log .= " - request_ref->{search}: " . $request_ref->{search};
			defined $request_ref->{tagid2}  and $debug_log .= " - tagid2 " . $request_ref->{tagid2};
			$log->debug($debug_log);
		}
		
		if ((not defined $request_ref->{search}) and ($count >= 5) 	
			and (not defined $request_ref->{tagid2}) and (not defined $request_ref->{product_changes_saved})) {
			
			my @current_drilldown_fields = @ProductOpener::Config::drilldown_fields;
			if ($country eq 'en:world') {
				unshift (@current_drilldown_fields, "countries");
			}
			$html .= <<HTML
<ul class="button-group">
<li><div style="font-size:1.2rem;background-color:#eeeeee;padding:0.3rem 1rem;height:2.75rem;margin:0">$html_count</div></li>
<li>
<button href="#" data-dropdown="drop1" aria-controls="drop1" aria-expanded="false" class="button dropdown small">$Lang{explore_products_by}{$lc}</button>
<ul id="drop1" data-dropdown-content class="f-dropdown" aria-hidden="true">
HTML
;				
			foreach my $newtagtype (@current_drilldown_fields) {
			
				$html .= "<li ><a href=\"" . $request_ref->{current_link} . "/" . $tag_type_plural{$newtagtype}{$lc} . "\">"
					. ucfirst(lang($newtagtype . "_p")) . "</a></li>\n";
			}
			$html .= "</ul>\n</li>\n</ul>\n\n";
		
		
		}
		else {
			$html .= "<p>$html_count " . separator_before_colon($lc) . ":</p>";
		}
		
	
		if (defined $request_ref->{jqm}) {
			if (not defined $request_ref->{jqm_loadmore}) {
				$html .= '<ul data-role="listview" data-theme="c" id="search_results_list">';	
			}
		}
		else {		
			$html .= "<ul class=\"products\">\n";
		}
	
		for my $product_ref (@{$request_ref->{structured_response}{products}}) {
			my $img_url;
			my $img_w;
			my $img_h;
			
			my $code = $product_ref->{code};
			my $img = display_image_thumb($product_ref, 'front');
			


			my $product_name =  remove_tags_and_quote(product_name_brand_quantity($product_ref));
			
			# Prevent the quantity "750 g" to be split on two lines
			$product_name =~ s/(.*) (.*?)/$1\&nbsp;$2/;
			
			my $url = product_url($product_ref);
			$product_ref->{url} = format_subdomain($subdomain) . $url;
			
			add_images_urls_to_product($product_ref);
			
			
			if ($request_ref->{jqm}) {
				# <li><a href="#page_product?code=3365622026164">Sardines à l'huile</a></li>
				$html .= <<HTML
<li>
<a href="#page_product?code=$code" title="$product_name">
$img
$product_ref->{product_name}
</a>
</li>
HTML
;				
			}
			else  {
				if ($product_name eq '') {
					$product_name = $code;
				}
				
			# Display the brand if we don't have an image
			#if (($img eq '') and ($product_ref->{brands} ne '')) {
			#	$product_name .= ' - ' . $product_ref->{brands};
			#}				
				
				$html .= <<HTML
<li>
<a href="$url" title="$product_name">
<div>$img</div>
<span>${product_name}</span>
</a>
</li>
HTML
;
			}
			
			# remove some debug info
			delete $product_ref->{additives};
			delete $product_ref->{additives_prev};
			delete $product_ref->{additives_next};			
		}
	

		# If the request specified a value for the fields parameter, return only the fields listed
		if (defined $request_ref->{fields}) {
		
			my $compact_products = [];
		
			for my $product_ref (@{$request_ref->{structured_response}{products}}) {
		
				my $compact_product_ref = {};
				foreach my $field (split(/,/, $request_ref->{fields})) {
					if (defined $product_ref->{$field}) {
						$compact_product_ref->{$field} = $product_ref->{$field};
					}
				}
				push @$compact_products, $compact_product_ref;
			}
			
			$request_ref->{structured_response}{products} = $compact_products;
		}	
	
		
		# Pagination

		my $nb_pages = int (($count - 1) / $limit) + 1;
		
		my $current_link = $request_ref->{current_link};
		my $current_link_query = $request_ref->{current_link_query};		
		
		if ($request_ref->{jqm}) {
			$current_link_query .= "&jqm=1";
		}
		
		my $next_page_url;
		
		if ((($nb_pages > 1) and ((defined $current_link) or (defined $current_link_query))) and (not defined $request_ref->{product_changes_saved})) {
		
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

						if (defined $current_link) {
							
							$link = $current_link;
							if ($i > 1) {
								$link .= "/$i";
							}
							if ($link eq '') {
								$link  = "/";
							}
						}
						elsif (defined $current_link_query) {
							
							$link = $current_link_query . "&page=$i";
						}
										
						$html_pages .=  '<li><a href="' . $link . '">' . $i . '</a></li>';
						
						if ($i == $page - 1) {
							$prev = '<li><a href="' . $link . '" rel="prev">' . lang("previous") . '</a></li>';
						}
						elsif ($i == $page + 1) {
							$next = '<li><a href="' . $link . '" rel="next">' . lang("next") . '</a></li>';
							$next_page_url = $link;
						}
					}
				}
			}
			
			$html_pages =~ s/(<unavailable>)+/<li class="unavailable">&hellip;<\/li>/g;
			
			$html_pages = "\n<hr/>" . '<ul id="pages" class="pagination">'
			. "<li class=\"unavailable\">" . lang("pages") . "</li>" 
			. $prev . $html_pages . $next . "</ul>\n";
		}		
		
		# Close the list
		
		
		if (defined $request_ref->{jqm}) {
			if (defined $next_page_url) {
				my $loadmore = lang("loadmore");
				my $loadmore_domain = format_subdomain($subdomain);
				$html .= <<HTML
<li id="loadmore" style="text-align:center"><a href="${loadmore_domain}/${next_page_url}&jqm_loadmore=1" id="loadmorelink">$loadmore</a></li>
HTML
;
			}
			else {
				$html .= '<br/><br/>';	
			}
		}			
		
		if (not defined $request_ref->{jqm_loadmore}) {
			$html .= "</ul>\n";
		}
		
		if (not defined $request_ref->{jqm}) {
			$html .= $html_pages;
		}
		
		
	}	
	
	# if cc and/or lc have been overriden, change the relative paths to absolute paths using the new subdomain
	
	if ($subdomain ne $original_subdomain) {
		$log->debug("subdomain not equal to original_subdomain, converting relative paths to absolute paths", { subdomain => $subdomain, original_subdomain => $original_subdomain }) if $log->is_debug();
		my $formated_subdomain = format_subdomain($subdomain);
		$html =~ s/(href|src)=("\/)/$1="$formated_subdomain\//g;
	}

	return $html;
}





sub search_and_export_products($$$$$) {

	my $request_ref = shift;
	my $query_ref = shift;
	my $sort_by = shift;
	my $flatten = shift;
	my $flatten_ref = shift;

	if (defined $country) {
		if ($country ne 'en:world') {
			$query_ref->{countries_tags} = $country;
		}
		delete $query_ref->{lc};
	}
	
	delete $query_ref->{lc};
	
	my $sort_ref = Tie::IxHash->new();
	
	if (defined $sort_by) {
	}
	elsif (defined $request_ref->{sort_by}) {
		$sort_by = $request_ref->{sort_by};
	}
	
	if (defined $sort_by) {
		my $order = 1;
		if ($sort_by =~ /^((.*)_t)_complete_first/) {
			#$sort_by = $1;
			#$sort_ref->Push(complete => -1);
			$sort_ref->Push(sortkey => -1);
			$order = -1;
		}		
		elsif ($sort_by =~ /_t/) {
			$order = -1;
			$sort_ref->Push($sort_by => $order);
		}
		elsif ($sort_by =~ /scans_n/) {
			$order = -1;
			$sort_ref->Push($sort_by => $order);		
		}
		else {
			$sort_ref->Push($sort_by => $order);
		}
	}
	
	$sort_ref->Push(product_name => 1);
	$sort_ref->Push(generic_name => 1);
	
	$log->debug("Executing MongoDB query", { query => $query_ref, sort => $sort_ref }) if $log->is_debug();

	my $cursor;
	my $count;
	
	eval {
		$cursor = $products_collection->query($query_ref)->sort($sort_ref);
		$count = $cursor->count() + 0;
	};
	if ($@) {
		$log->warn("MongoDB error - retrying once", { error => $@ }) if $log->is_warn();
		# maybe $connection auto-reconnects but $database and $products_collection still reference the old connection?
		
		# opening new connection
		eval {
			$connection = MongoDB->connect($mongodb_host);
			$database = $connection->get_database($mongodb);
			$products_collection = $database->get_collection('products');
		};
		if ($@) {
			$log->error("MongoDB error - reconnecting failed", { error => $@ }) if $log->is_error();
			$count = -1;
		}
		else {		
			$log->info("MongoDB reconnect ok", { error => $@ }) if $log->is_info();
			$cursor = $products_collection->query($query_ref)->sort($sort_ref);
			$count = $cursor->count() + 0;
			$log->info("MongoDB query ok", { error => $@, result_count => $count }) if $log->is_info();
		}
	}
		
	$request_ref->{count} = $count + 0;
	
	my $html = '';
	
	if ($count < 0) {
		$html .= "<p>" . lang("error_database") . "</p>";	
	}
	elsif ($count == 0) {
		$html .= "<p>" . lang("no_products") . "</p>";
	}
	
	if (defined $request_ref->{current_link_query}) {
		$request_ref->{current_link_query_display} = $request_ref->{current_link_query};
		$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
		$html .= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">" . lang("search_edit") . "</a><br />";
	}
	
	if ($count <= 0) {
		# $request_ref->{content_html} = $html;
		return $html;
	}
	
	
	my $csv = '';
	
	if ($count > 0) {
		
		my $categories_nutriments_ref = retrieve("$data_root/index/categories_nutriments_per_country.$cc.sto");	
		
		# First pass needed if we flatten results
		my %flattened_tags = ();
		my %flattened_tags_sorted = ();
		foreach my $field (%$flatten_ref) {
			$flattened_tags{$field} = {};
		}
		
		if ($flatten) {
		
			while (my $product_ref = $cursor->next) {
			
				foreach my $field (%$flatten_ref) {
					if (defined $product_ref->{$field . '_tags'}) {
						foreach my $tag (@{$product_ref->{$field . '_tags'}}) {
							$flattened_tags{$field}{$tag} = 1;
						}
					}
				}
			}
			$cursor->reset;
			
			foreach my $field (%$flatten_ref) {
				$flattened_tags_sorted{$field} = [ sort keys %{$flattened_tags{$field}}];
			}
		}
		
		
		# Output header
		
		my %tags_fields = (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, manufacturing_places => 1, emb_codes=>1, cities=>1, allergens => 1, traces => 1, additives => 1, ingredients_from_palm_oil => 1, ingredients_that_may_be_from_palm_oil => 1);

		my @fields = qw (
code
creator
created_t
last_modified_t
product_name
generic_name
quantity
packaging
brands 
categories 
labels
origins
manufacturing_places
emb_codes
cities
purchase_places
stores
countries
ingredients_text
allergens
traces
serving_size
no_nutriments
additives_n
additives
ingredients_from_palm_oil_n
ingredients_from_palm_oil
ingredients_that_may_be_from_palm_oil_n
ingredients_that_may_be_from_palm_oil
pnns_groups_1
pnns_groups_2
);

		foreach my $field (@fields) {
		
			$csv .= $field . "\t";

		
			if ($field eq 'code') {
			
				$csv .= "url\t";
			
			}
		
			if (defined $tags_fields{$field}) {
				$csv .= $field . '_tags' . "\t";
			}
		
		}
		
		$csv .= "main_category\t";
		
		$csv .= "image_url\timage_small_url\t";	
		$csv .= "image_front_url\timage_front_small_url\t";	
		$csv .= "image_ingredients_url\timage_ingredients_small_url\t";	
		$csv .= "image_nutrition_url\timage_nutrition_small_url\t";	

		

		
		foreach (@{$nutriments_tables{$nutriment_table}}) {
		
			my $nid = $_;	# Copy instead of alias
		
			$nid =~/^#/ and next;
		
			$nid =~ s/!//g;
			$nid =~ s/^-//g;
			$nid =~ s/-$//g;
					
			$csv .= "${nid}_100g" . "\t";
		}	
		
		foreach my $field (%$flatten_ref) {
			foreach my $tagid (@{$flattened_tags_sorted{$field}}) {
				$csv .= "$field:$tagid\t";
			}
		}
	
		$csv =~ s/\t$/\n/;		
		
		
		while (my $product_ref = $cursor->next) {
			
			# Normal fields
			
			foreach my $field (@fields) {
		
				my $value = $product_ref->{$field};
				if (defined $value) {
					$value =~ s/(\r|\n|\t)/ /g;
					$csv .= $value;
				}

				$csv .= "\t";

				if ($field eq 'code') {
				
					$csv .= format_subdomain($cc) . product_url($product_ref->{code}) . "\t";
				
				}
			
				if (defined $tags_fields{$field}) {
					if (defined $product_ref->{$field . '_tags'}) {				
						$csv .= join(',', @{$product_ref->{$field . '_tags'}}) . "\t";
					}
					else {
						$csv .= "\t";
					}
				}			
			}
			
			# Try to get the "main" category: smallest category with at least 10 products with nutrition data
		
			my @comparisons = ();
			my %comparisons = ();
			
			my $main_cid = '';
			
			if ( (not ((defined $product_ref->{not_comparable_nutrition_data}) and ($product_ref->{not_comparable_nutrition_data})))
			and  (defined $product_ref->{categories_tags}) and (scalar @{$product_ref->{categories_tags}} > 0)) {
			
				$main_cid = $product_ref->{categories_tags}[0];
				
				
			
				foreach my $cid (@{$product_ref->{categories_tags}}) {
					if ((defined $categories_nutriments_ref->{$cid}) and (defined $categories_nutriments_ref->{$cid}{stats})) {
						push @comparisons, {
							id => $cid,
							name => display_taxonomy_tag($lc,'categories', $cid),
							link => canonicalize_taxonomy_tag_link($lc,'categories', $cid),
							nutriments => compare_nutriments($product_ref, $categories_nutriments_ref->{$cid}),
							count => $categories_nutriments_ref->{$cid}{count},
							n => $categories_nutriments_ref->{$cid}{n},
						};
						#print STDERR "compare category: cid: $cid - name " . display_taxonomy_tag($lc,'categories', $cid) . "\n"; 

					}
				}
				
				local $log->context->{main_cid_orig} = $main_cid;
				local $log->context->{comparisons} = $#comparisons;
				if ($#comparisons > -1) {
					@comparisons = sort { $a->{count} <=> $b->{count}} @comparisons;
					$comparisons[0]{show} = 1;
					$main_cid = $comparisons[0]{id};
				}
				
				local $log->context->{main_cid} = $main_cid;
				$log->debug("final main_cid determined") if $log->is_debug();
			}		
			
			if ($main_cid ne '') {
				$main_cid = canonicalize_tag2("categories",$main_cid);
			}
			
			$csv .= $main_cid . "\t";
			
			$product_ref->{main_category} = $main_cid;
			
			add_images_urls_to_product($product_ref);
			
			# image_url = image_front_url
			foreach my $id ('front', 'front','ingredients','nutrition') {
				
				$csv .= $product_ref->{"image_" . $id . "_url"} . "\t" . $product_ref->{"image_" . $id . "_small_url"} . "\t";
			}		
			
			
			# Nutriments
			
			foreach (@{$nutriments_tables{$nutriment_table}}) {
			
				my $nid = $_;	# Copy instead of alias

				$nid =~/^#/ and next;
			
				$nid =~ s/!//g;
				$nid =~ s/^-//g;
				$nid =~ s/-$//g;
						
				if (defined $product_ref->{nutriments}{"${nid}_100g"}) {
					$csv .= $product_ref->{nutriments}{"${nid}_100g"};
				}

				$csv .= "\t";
			}
			
			# Flattened tags
			
			foreach my $field (%$flatten_ref) {
				my %product_tags = ();
				foreach my $tagid (@{$product_ref->{$field . '_tags'}}) {
					$product_tags{$tagid} = 1;
				}
				foreach my $tagid (@{$flattened_tags_sorted{$field}}) {
					if (defined $product_tags{$tagid}) {
						$csv .= "1\t";
					}
					else {
						$csv .= "\t";
					}
				}
			}				
			
			$csv =~ s/\t$/\n/;
		
		}	
	}	

	return $csv;
}


sub escape_single_quote($) {
	my $s = shift;
	# some app escape single quotes already, so we have \' already
	if (not defined $s) {
		$s = '';
	}
	$s =~ s/\\'/'/g;	
	$s =~ s/'/\\'/g;
	$s =~ s/\n/ /g;
	return $s;
}


@search_series = (qw/organic fairtrade with_sweeteners default/);

my %search_series_colors = (
default => { r => 0, g => 0, b => 255},
organic => { r => 0, g => 212, b => 0},
fairtrade => { r => 255, g => 102, b => 0},
with_sweeteners => { r => 0, g => 204, b => 255},
);


my %nutrition_grades_colors  = (
a => { r => 0, g => 255, b => 0},
b => { r => 255, g => 255, b => 0},
c => { r => 255, g => 102, b => 0},
d => { r => 255, g => 1, b => 128},
e => { r => 255, g => 0, b => 0},
unknown => { r => 128, g=> 128, b=>128},
);




sub display_scatter_plot($$$) {
		
		my $graph_ref = shift;
		my $cursor = shift;
		my $count = shift;		
		
		my $html = '';
		
		my $x_allowDecimals = '';
		my $y_allowDecimals = '';
		my $x_title;
		my $y_title;
		my $x_unit = '';
		my $y_unit = '';  
		my $x_unit2 = '';
		my $y_unit2 = '';
		if ($graph_ref->{axis_x} eq 'additives_n') {
			$x_allowDecimals = "allowDecimals:false,\n";
			$x_title = escape_single_quote(lang("number_of_additives"));
		}
		elsif ($graph_ref->{axis_x} eq 'ingredients_n') {
			$x_allowDecimals = "allowDecimals:false,\n";
			$x_title = escape_single_quote(lang("ingredients_n_s"));
		}		
		else {
			$x_title = $Nutriments{$graph_ref->{axis_x}}{$lc};
			$x_unit = " (" . $Nutriments{$graph_ref->{axis_x}}{unit} . " " . lang("nutrition_data_per_100g") . ")";
			$x_unit =~ s/\&nbsp;/ /g;
			$x_unit2 = $Nutriments{$graph_ref->{axis_x}}{unit};
		}
		if ($graph_ref->{axis_y} eq 'additives_n') {
			$y_allowDecimals = "allowDecimals:false,\n";
			$y_title = escape_single_quote(lang("number_of_additives"));
		}
		elsif ($graph_ref->{axis_y} eq 'ingredients_n') {
			$y_allowDecimals = "allowDecimals:false,\n";
			$y_title = escape_single_quote(lang("ingredients_n_s"));
		}		
		else {
			$y_title = $Nutriments{$graph_ref->{axis_y}}{$lc};
			$y_unit = " (" . $Nutriments{$graph_ref->{axis_y}}{unit} . " " . lang("nutrition_data_per_100g") . ")";
			$y_unit =~ s/\&nbsp;/ /g;		
			$y_unit2 = $Nutriments{$graph_ref->{axis_y}}{unit};			
		}
		
		my %nutriments = ();
			
		my $i = 0;		
		
		my %series = ();
		my %series_n = ();
		
		while (my $product_ref = $cursor->next) {

			# Keep only products that have known values for both x and y
			
			if ((((($graph_ref->{axis_x} eq 'additives_n') or ($graph_ref->{axis_x} eq 'ingredients_n')) and (defined $product_ref->{$graph_ref->{axis_x}})) 
					or 
					(defined $product_ref->{nutriments}{$graph_ref->{axis_x} . "_100g"}) and ($product_ref->{nutriments}{$graph_ref->{axis_x} . "_100g"} ne ''))
				and (((($graph_ref->{axis_y} eq 'additives_n') or ($graph_ref->{axis_y} eq 'ingredients_n')) and (defined $product_ref->{$graph_ref->{axis_y}})) or 
					(defined $product_ref->{nutriments}{$graph_ref->{axis_y} . "_100g"}) and ($product_ref->{nutriments}{$graph_ref->{axis_y} . "_100g"} ne ''))) {
				
				my $url = format_subdomain($subdomain) . product_url($product_ref->{code});
				
				# Identify the series id
				my $seriesid = 0;
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
						$seriesid = 'unknown',
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
				
				defined $series{$seriesid} or $series{$seriesid} = '';

				# print STDERR "Display::search_and_graph_products: i: $i - axis_x: $graph_ref->{axis_x} - axis_y: $graph_ref->{axis_y}\n";
					
				my %data;
					
				foreach my $axis ('x', 'y') {
					my $nid = $graph_ref->{"axis_" . $axis};
					if (($nid eq 'additives_n') or ($nid eq 'ingredients_n')) {
						$data{$axis} = $product_ref->{$nid};
					}
					else {
						$data{$axis} = g_to_unit($product_ref->{nutriments}{"${nid}_100g"}, $Nutriments{$nid}{unit});
					}
									
					add_product_nutriment_to_stats(\%nutriments, $nid, $product_ref->{nutriments}{"${nid}_100g"});
				}
				$data{product_name} = $product_ref->{product_name};
				$data{url} = $url;
				$data{img} = display_image_thumb($product_ref, 'front');
				
				defined $series{$seriesid} or $series{$seriesid} = '';
				$series{$seriesid} .= JSON::PP->new->encode(\%data) . ',';
				defined $series_n{$seriesid} or $series_n{$seriesid} = 0;
				$series_n{$seriesid}++;
				$i++;
			}
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
		
			foreach my $nutrition_grade ('a','b','c','d','e','unknown') {
				my $title = uc($nutrition_grade);
				if ($nutrition_grade eq 'unknown') {
					$title = ucfirst(lang("unknown"));
				}
				my $r = $nutrition_grades_colors{$nutrition_grade}{r};
				my $g = $nutrition_grades_colors{$nutrition_grade}{g};
				my $b = $nutrition_grades_colors{$nutrition_grade}{b};
				my $seriesid = $nutrition_grade;
				$series_data .= <<JS				
{
	name: '$title : $series_n{$seriesid} $Lang{products_p}{$lc}',
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
				
				$log->debug("rendering series colour as JavaScript", { seriesid => $seriesid, matching_series => $matching_series, s => $s, remainingseriesid => $remainingseriesid, title => $title }) if $log->is_debug();

				$r = int ($r / $matching_series);
				$g = int ($g / $matching_series);
				$b = int ($b / $matching_series);
				
				$series_data .= <<JS
{
	name: '$title : $series_n{$seriesid} $Lang{products_p}{$lc}',
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
                text: '$Lang{data_source}{$lc}$sep: @{[ format_subdomain($subdomain) ]}'
            },
            xAxis: {
				$x_allowDecimals
				min:0,
                title: {
                    enabled: true,
                    text: '${x_title}${x_unit}'
                },
                startOnTick: true,
                endOnTick: true,
                showLastLabel: true
            },
            yAxis: {
				$y_allowDecimals
				min:0,
                title: {
                    text: '${y_title}${y_unit}'
                }
            },
            tooltip: {
				useHTML: true,
				followPointer : false,
				formatter: function() { 
                    return '<a href="' + this.point.url + '">' + this.point.product_name + '<br/>'
						+ this.point.img + '</a><br/>'
						+ '$Lang{nutrition_data_per_100g}{$lc} :'
						+ '<br />$x_title$sep: '+ this.x + ' $x_unit2'
						+ '<br />$y_title$sep: ' + this.y + ' $y_unit2';
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
					tooltip : { followPointer : false },
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
		
		$html .= <<HTML
<script src="/js/highcharts.4.0.4.js"></script>
<p>$count_string</p>
<div id="container" style="height: 400px"></div>​

HTML
;	

		# Display stats
		
		my $stats_ref = {};
		
		compute_stats_for_products($stats_ref, \%nutriments, $count, $i, 5, 'search');
		
		$html .= display_nutrition_table($stats_ref, undef);
		
		$html .= "<p>&nbsp;</p>";

		return $html;
		
}




sub display_histogram($$$) {
		
		my $graph_ref = shift;
		my $cursor = shift;
		my $count = shift;
		
		my $html = '';
		
		my $x_allowDecimals = '';
		my $y_allowDecimals = '';
		my $x_title;
		my $y_title;
		my $x_unit = '';
		my $y_unit = '';  
		my $x_unit2 = '';
		my $y_unit2 = '';
		if ($graph_ref->{axis_x} eq 'additives_n') {
			$x_allowDecimals = "allowDecimals:false,\n";
			$x_title = escape_single_quote(lang("number_of_additives"));
		}
		elsif ($graph_ref->{axis_x} eq 'ingredients_n') {
			$x_allowDecimals = "allowDecimals:false,\n";
			$x_title = escape_single_quote(lang("ingredients_n_s"));
		}		
		else {
			$x_title = $Nutriments{$graph_ref->{axis_x}}{$lc};
			$x_unit = " (" . $Nutriments{$graph_ref->{axis_x}}{unit} . " " . lang("nutrition_data_per_100g") . ")";
			$x_unit =~ s/\&nbsp;/ /g;
			$x_unit2 = $Nutriments{$graph_ref->{axis_x}}{unit};
		}

		$y_allowDecimals = "allowDecimals:false,\n";
		$y_title = escape_single_quote(lang("number_of_products"));
		
		my $nid = $graph_ref->{"axis_x"};
		
		my $i = 0;		
		
		my %series = ();
		my %series_n = ();
		my @all_values = ();
		
		my $min = 10000000000000;
		my $max = -10000000000000;
		
		while (my $product_ref = $cursor->next) {

			# Keep only products that have known values for x
			
			if ((((($graph_ref->{axis_x} eq 'additives_n') or ($graph_ref->{axis_x} eq 'ingredients_n')) and (defined $product_ref->{$graph_ref->{axis_x}})) or 
					(defined $product_ref->{nutriments}{$graph_ref->{axis_x} . "_100g"}) and ($product_ref->{nutriments}{$graph_ref->{axis_x} . "_100g"} ne ''))
					) {
								
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
				
				
				# print STDERR "Display::search_and_graph_products: i: $i - axis_x: $graph_ref->{axis_x} - axis_y: $graph_ref->{axis_y}\n";
					

				my $value = 0;
					

					if (($nid eq 'additives_n') or ($nid eq 'ingredients_n')) {
						$value = $product_ref->{$nid};
					}
					elsif ($nid =~ /^nutrition-score/) {
						$value = $product_ref->{nutriments}{"${nid}_100g"};
					}
					else {
						$value = g_to_unit($product_ref->{nutriments}{"${nid}_100g"}, $Nutriments{$nid}{unit});
					}
				
				if ($value < $min) {
					$min = $value;
				}
				if ($value > $max) {
					$max = $value;
				}
				
				push @all_values, $value;				
				
				defined $series{$seriesid} or $series{$seriesid} = [];
				push @{$series{$seriesid}}, $value;

				defined $series_n{$seriesid} or $series_n{$seriesid} = 0;
				$series_n{$seriesid}++;
				$i++;
			}
		}

		# define intervals
		
		$max += 0.0000000001;
		
		my @intervals = ();
		my $intervals = 10;
		my $interval = 1;
		if (defined param('intervals')) {
			$intervals = param('intervals');
			$intervals > 0 or $intervals = 10;
		}
		
		if ($i == 0) {
			return "";
		}
		elsif ($i == 1) {
			push @intervals, [$min, $max, "$min"];
		}
		else {
			if (($nid =~ /_n$/) or ($nid =~ /^nutrition-score/)) {
				$interval = 1;
				$intervals = 0;
				for (my $j = $min; $j <= $max ; $j++) {
					push @intervals, [$j, $j, $j + 0.0];
					$intervals++;
				}
			}
			else {
				$interval = ($max - $min) / 10;
				for (my $k = 0; $k < $intervals; $k++) {
					my $mink = $min + $k * $interval;
					my $maxk = $mink + $interval;
					push @intervals, [$mink, $maxk, '>' . (sprintf("%.2e", $mink) + 0.0) . ' <' . (sprintf("%.2e", $maxk) + 0.0)];
				}
			}
		}

		$log->debug("hisogram for all 'i' values", { i => $i, min => $min, max => $max }) if $log->is_debug();
		
		my %series_intervals = ();
		my $categories = '';
		
		for (my $k = 0; $k < $intervals; $k++) {
			$categories .= '"' . $intervals[$k][2] .  '", ';
		}
		$categories =~ s/,\s*$//;
		
		foreach my $seriesid (keys %series) {
			$series_intervals{$seriesid} = [];
			for (my $k = 0; $k < $intervals; $k++) {
				$series_intervals{$seriesid}[$k] = 0;
				$log->debug("computing histogram", { k => $k, min =>$intervals[$k][0], max => $intervals[$k][1] }) if $log->is_debug();
			}
			foreach my $value (@{$series{$seriesid}}) {
				for (my $k = 0; $k < $intervals; $k++) {
					if (($value >= $intervals[$k][0])
						and (($value < $intervals[$k][1])) or (($intervals[$k][1] == $intervals[$k][0])) and ($value == $intervals[$k][1])) {
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
			
			$log->debug("rendering series as JavaScript", { seriesid => $seriesid, matching_series => $matching_series, s => $s, remainingseriesid => $remainingseriesid, title => $title }) if $log->is_debug();

			$r = int ($r / $matching_series);
			$g = int ($g / $matching_series);
			$b = int ($b / $matching_series);
			
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
                text: '$Lang{data_source}{$lc}$sep: @{[ format_subdomain($subdomain) ]}'
            },
            xAxis: {
                title: {
                    enabled: true,
                    text: '${x_title}${x_unit}'
                },
				categories: [
					$categories
				]
            },
            yAxis: {
			
				$y_allowDecimals
				min:0,
                title: {
                    text: '${y_title}${y_unit}'
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
            headerFormat: '<b>${x_title} {point.key}</b><br/>${x_unit}<table>',
            pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
                '<td style="padding:0"><b>{point.y}</b></td></tr>',
            footerFormat: '</table>Total: <b>{point.total}</b>',
            shared: true,
            useHTML: true,
			formatter: function() {
            var points='<table class="tip"><caption>${x_title} ' + this.x + '</b><br/>${x_unit}</caption><tbody>';
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
		
		$html .= <<HTML
<script src="/js/highcharts.4.0.4.js"></script>
<p>$count_string</p>
<div id="container" style="height: 400px"></div>​
<p>&nbsp;</p>
HTML
;	

		return $html;
		
}









sub search_and_graph_products($$$) {

	my $request_ref = shift;
	my $query_ref = shift;
	my $graph_ref = shift;

	if (defined $country) {
		if ($country ne 'en:world') {
			$query_ref->{countries_tags} = $country;
		}
	}
	
	delete $query_ref->{lc};

	my $cursor;
	my $count;
	
	$log->info("retrieving products from MongoDB to display them in a graph", { count => $count }) if $log->is_info();

	if ($admin) {
		$log->debug("Executing MongoDB query", { query => $query_ref }) if $log->is_debug();
	}
	
	eval {
		$cursor = $products_collection->query($query_ref);
		$count = $cursor->count() + 0;
	};
	if ($@) {
		$log->warn("MongoDB error - retrying once", { error => $@ }) if $log->is_warn();
		# maybe $connection auto-reconnects but $database and $products_collection still reference the old connection?
		
		# opening new connection
		eval {
			$connection = MongoDB->connect($mongodb_host);
			$database = $connection->get_database($mongodb);
			$products_collection = $database->get_collection('products');
		};
		if ($@) {
			$log->error("MongoDB error - reconnecting failed", { error => $@ }) if $log->is_error();
			$count = -1;
		}
		else {		
			$log->info("MongoDB reconnect ok", { error => $@ }) if $log->is_info();
			$cursor = $products_collection->query($query_ref);
			$count = $cursor->count() + 0;
			$log->info("MongoDB query ok", { error => $@, result_count => $count }) if $log->is_info();
		}
	}
		
	$log->info("retrieved products from MongoDB to display them in a graph", { count => $count }) if $log->is_info();
		
	$request_ref->{count} = $count + 0;
	
	my $html = '';
	
	if ($count < 0) {
		$html .= "<p>" . lang("error_database") . "</p>";	
	}
	elsif ($count == 0) {
		$html .= "<p>" . lang("no_products") . "</p>";
	}
	
	if (defined $request_ref->{current_link_query}) {
		$request_ref->{current_link_query_display} = $request_ref->{current_link_query};
		$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
		$html .= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">" . lang("search_edit") . "</a><br />";
	}
	
	if ($count <= 0) {
		# $request_ref->{content_html} = $html;
		$log->warn("could not retrieve enough products for a graph", { count => $count }) if $log->is_warn();
		return $html;
	}
		
	if ($count > 0) {
	

		$graph_ref->{graph_title} = escape_single_quote($graph_ref->{graph_title});
		
		# 1 axis: histogram / bar chart
		# 2 axis: scatter plot
		
		if ($graph_ref->{axis_y} eq 'products_n') {
			$html .= display_histogram($graph_ref, $cursor, $count);
		}
		else {
			$html .= display_scatter_plot($graph_ref, $cursor, $count);		
		}
		
		

		if (defined $request_ref->{current_link_query}) {
			$request_ref->{current_link_query_display} = $request_ref->{current_link_query};
			$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
			$html .= "&rarr; <a href=\"$request_ref->{current_link_query}\">" . lang("search_graph_link") . "</a><br />";
		}
		
		$html .= "<p>" . lang("search_graph_warning") . "</p>";
		
		$html .= lang("search_graph_blog");
	}
	

	return $html;
}


sub get_packager_code_coordinates($) {

	my $emb_code = shift;
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



sub search_and_map_products($$$) {

	my $request_ref = shift;
	my $query_ref = shift;
	my $graph_ref = shift;

	if (defined $country) {
		if ($country ne 'en:world') {
			$query_ref->{countries_tags} = $country;
		}
		
	}
	
	delete $query_ref->{lc};
	
	my $cursor;
	my $count;
	
	$log->info("retrieving products from MongoDB to display them in a map", { count => $count }) if $log->is_info();
	
	eval {
		$cursor = $products_collection->query($query_ref);
		$count = $cursor->count() + 0;
	};
	if ($@) {
		$log->warn("MongoDB error - retrying once", { error => $@ }) if $log->is_warn();
		# maybe $connection auto-reconnects but $database and $products_collection still reference the old connection?
		
		# opening new connection
		eval {
			$connection = MongoDB->connect($mongodb_host);
			$database = $connection->get_database($mongodb);
			$products_collection = $database->get_collection('products');
		};
		if ($@) {
			$log->error("MongoDB error - reconnecting failed", { error => $@ }) if $log->is_error();
			$count = -1;
		}
		else {		
			$log->info("MongoDB reconnect ok", { error => $@ }) if $log->is_info();
			$cursor = $products_collection->query($query_ref);
			$count = $cursor->count() + 0;
			$log->info("MongoDB query ok", { error => $@, result_count => $count }) if $log->is_info();
		}
	}
		
	$log->info("retrieved products from MongoDB to display them in a map", { count => $count }) if $log->is_info();
		
	$request_ref->{count} = $count + 0;
	
	my $html = '';
	
	if ($count < 0) {
		$html .= "<p>" . lang("error_database") . "</p>";	
	}
	elsif ($count == 0) {
		$html .= "<p>" . lang("no_products") . "</p>";
	}
	
	if (defined $request_ref->{current_link_query}) {
		$request_ref->{current_link_query_display} = $request_ref->{current_link_query};
		$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
		$html .= "&rarr; <a href=\"$request_ref->{current_link_query_display}&action=display\">" . lang("search_edit") . "</a><br />";
	}
	
	if ($count <= 0) {
		# $request_ref->{content_html} = $html;
		$log->warn("could not retrieve enough products for a map", { count => $count }) if $log->is_warn();
		return $html;
	}
		
	if ($count > 0) {
	
		my $js_example = <<JS
		
 var markers = new L.MarkerClusterGroup();
markers.addLayer(new L.Marker(getRandomLatLng(map)));
... Add more layers ...
map.addLayer(markers);
		
		
var markers = new L.MarkerClusterGroup({ spiderfyOnMaxZoom: false, showCoverageOnHover: false, zoomToBoundsOnClick: false });

singleMarkerMode: If set to true, overrides the icon for all added markers to make them appear as a 1 size cluster
{ singleMarkerMode: true}

addLayers and removeLayers are bulk methods for adding and removing markers and should be favoured over the single versions when doing bulk addition/removal of markers. Each takes an array of markers


		
JS
;

		$graph_ref->{graph_title} = escape_single_quote($graph_ref->{graph_title});
		

		
		my $matching_products = 0;	
		my $places = 0;		
		my $emb_codes = 0;
		my $products = 0;
		
		my %seen = ();
		my $data = '';
		
		while (my $product_ref = $cursor->next) {

			# Keep only products that have known values for both x and y
			
			if (1) {
				
				my $url = format_subdomain($cc) . product_url($product_ref->{code});
				
					
				my $data_start = '{';
				
				
				my $manufacturing_places =  escape_single_quote($product_ref->{"manufacturing_places"});
				$manufacturing_places =~ s/,( )?/, /g;
				if ($manufacturing_places ne '') {
					$manufacturing_places = ucfirst(lang("manufacturing_places_p")) . separator_before_colon($lc) . ": " . $manufacturing_places . "<br/>";
				}	
				
				
				my $origins =  escape_single_quote($product_ref->{origins});
				$origins =~ s/,( )?/, /g;
				if ($origins ne '') {
					$origins = ucfirst(lang("origins_p")) . separator_before_colon($lc) . ": " . $origins . "<br/>";;
				}				
				
				$origins = $manufacturing_places . $origins;
					
				$data_start .= " product_name:'" . escape_single_quote($product_ref->{product_name}) . "', brands:'" . escape_single_quote($product_ref->{brands}) . "', url: '" . $url . "', img:'"
					. escape_single_quote(display_image_thumb($product_ref, 'front')) . "', origins:'" . $origins . "'";	
				

				
				# Loop on cities: multiple emb codes can be on one product
				
				my $field = 'emb_codes';
				if (defined $product_ref->{"emb_codes_tags" }) {
				
					my %current_seen = (); # only one product when there are multiple city codes for the same city
					
					foreach my $emb_code (@{$product_ref->{"emb_codes_tags"}}) {
					
						my ($lat, $lng) = get_packager_code_coordinates($emb_code);	
						
						if ((defined $lat) and ($lat ne '') and (defined $lng) and ($lng ne '')) {
							my $geo = "$lat,$lng";
							if (not defined $current_seen{$geo}) {
						
								$current_seen{$geo} = 1;
								$data .= $data_start . ', geo:[' . $geo . "]},\n";
								$emb_codes++;
								if (not defined $seen{$geo}) {
									$seen{$geo} = 1;
									$places++;
								}
							}						
						}

					}
					if (scalar keys %current_seen > 0) {
						$products++;
					}
				}					
				
				$matching_products++;
			}
		}	

		$log->debug("rendering map for matching products", { count => $count, matching_products => $matching_products, products => $products, emb_codes => $emb_codes }) if $log->is_debug();
		
		# Points to display?

		if ($emb_codes > 0) {

			$header .= <<HTML		
<link rel="stylesheet" href="/bower_components/leaflet/dist/leaflet.css">
<script src="/bower_components/leaflet/dist/leaflet.js"></script>
<link rel="stylesheet" href="/bower_components/leaflet.markercluster/dist/MarkerCluster.css" />
<link rel="stylesheet" href="/bower_components/leaflet.markercluster/dist/MarkerCluster.Default.css" />
<script src="/bower_components/leaflet.markercluster/dist/leaflet.markercluster.js"></script>
HTML
;


# 18/07/2016 -> mapquest removed free access to their tiles without registration
#L.tileLayer('http://otile{s}.mqcdn.com/tiles/1.0.0/map/{z}/{x}/{y}.jpeg', {
#	attribution: 'Tiles Courtesy of <a href="http://www.mapquest.com/">MapQuest</a> &mdash; Map data &copy; <a href="https://openstreetmap.org">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>',
#	subdomains: '1234',
#    maxZoom: 18
#}).addTo(map);			

		

			my $js = <<JS
var pointers = [ 
				$data
			];

var map = L.map('container', {maxZoom:12});	
		
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
	maxZoom: 19,
	attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
}).addTo(map);			


var markers = new L.MarkerClusterGroup({singleMarkerMode: true});

var length = pointers.length,
    pointer = null;
	
var layers = [];
	
for (var i = 0; i < length; i++) {
  pointer = pointers[i];
  var marker = new L.marker(pointer.geo);
  marker.bindPopup('<a href="' + pointer.url + '">' + pointer.product_name + '</a><br/>' + pointer.brands  + "<br/>" + '<a href="' + pointer.url + '">' + pointer.img + '</a><br/>' + pointer.origins);
  layers.push(marker); 
}

markers.addLayers(layers);

map.addLayer(markers);
map.fitBounds(markers.getBounds());
$request_ref->{map_options}
JS
;		
			$initjs .= $js;
		
			my $count_string = sprintf(lang("map_count"), $count, $products);
		
			$html .= <<HTML
<p>$count_string</p>
<div id="container" style="height: 600px"></div>​
<p>&nbsp;</p>
HTML
;	

		}

		if (defined $request_ref->{current_link_query}) {
			$request_ref->{current_link_query_display} = $request_ref->{current_link_query};
			$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
			$html .= "&rarr; <a href=\"$request_ref->{current_link_query}\">" . lang("search_map_link") . "</a><br />";
		}
		
		$html .= "<p>" . lang("search_map_warning") . "</p>";
		
		$html .= lang("search_map_blog");
	}
	
	
	


	return $html;
}



sub display_login_register($)
{
	my $blocks_ref = shift;
	
	if (not defined $User_id) {
	
		my $content = <<HTML
<p>$Lang{login_to_add_and_edit_products}{$lc}</p>

<form method="post" action="/cgi/session.pl">
<div class="row">
<div class="small-12 columns">
	<label>$Lang{login_username_email}{$lc}
		<input type="text" name="user_id" autocomplete="username" />
	</label>
</div>
<div class="small-12 columns">
	<label>$Lang{password}{$lc}
		<input type="password" name="password" autocomplete="current-password" />
	</label>
</div>
<div class="small-12 columns">
	<label>
		<input type="checkbox" name="remember_me" value="on" />
		$Lang{remember_me}{$lc}
	</label>
</div>
</div>
<input type="submit" name=".submit" value="$Lang{login_register_title}{$lc}" class="button small" />
</form>
<p>$Lang{login_not_registered_yet}{$lc}
<a href="/cgi/user.pl">$Lang{login_create_your_account}{$lc}</a></p>

HTML
;
	
		push @$blocks_ref, {
			'title'=>lang("login_register_title"),
			'content'=>$content,
		};
	}
}

sub display_my_block($)
{
	my $blocks_ref = shift;
	
	
	if (defined $User_id) {
		
		my $links = '<ul class="side-nav" style="padding-top:0">';
		$links .= "<li><a href=\"" . canonicalize_tag_link("users", get_fileid($User_id)) . "\">" . lang("products_you_edited") . "</a></li>";
		$links .= "<li><a href=\"" . canonicalize_tag_link("users", get_fileid($User_id)) . canonicalize_taxonomy_tag_link($lc,"states", "en:to-be-completed") . "\">" . lang("incomplete_products_you_added") . "</a></li>";  
		$links .= "</ul>";
		
		my $content = '';
		
		
		if (defined $Facebook_id) {
			$content = lang("connected_with_facebook") . <<HTML
<fb:login-button autologoutlink="true" perms="email"></fb:login-button>
$links
HTML
;
		}
		else {
			my $signout = lang("signout");
			$content = sprintf(lang("you_are_connected_as_x"), $User_id) . <<HTML
<ul class="button-group">
<li>
	<form method="post" action="/cgi/session.pl">
	<input type="hidden" name="length" value="logout" />
	<input type="submit" name=".submit" value="$signout" class="button small" />
	</form>
</li>
<li>
	<a href="/cgi/user.pl?userid=$User_id&type=edit" class="button small" title="$Lang{edit_settings}{$lc}" style="padding-left:1rem;padding-right:1rem"><i class="fi-widget"></i></a>
</li>
</ul>
$links
HTML
;		
		}
	
		push @$blocks_ref, {
			'title'=> lang("hello") . ' ' . $User{name},
			'content'=>$content,
			'id'=>'my_block',
		};	
	}
	
}




sub display_on_the_blog($)
{
	my $blocks_ref = shift;
	if (open (my $IN, "<:encoding(UTF-8)", "$data_root/lang/$lang/texts/blog-foundation.html")) {
	
		my $html = join('', (<$IN>));
		push @$blocks_ref, {
				'title'=>lang("on_the_blog_title"),
				'content'=>lang("on_the_blog_content") . '<ul class="side-nav">' . $html . '</ul>',
				'id'=>'on_the_blog',
		};	
		close $IN;
	}
}



sub display_top_block($)
{
	my $blocks_ref = shift;
	
	if (defined $Lang{top_content}{$lang}) {
		unshift @$blocks_ref, {
			'title'=>lang("top_title"),
			'content'=>lang("top_content"),
		};
	}
}


sub display_bottom_block($)
{
	my $blocks_ref = shift;
	
	if (defined $Lang{bottom_content}{$lang}) {
	
		my $html = lang("bottom_content");
		
		push @$blocks_ref, {
			'title'=>lang("bottom_title"),
			'content'=> $html,
		};
	}
}


sub display_blocks($)
{
	my $request_ref = shift;
	my $blocks_ref = $request_ref->{blocks_ref};
	
	my $html = '';
	
	foreach my $block_ref (@$blocks_ref) {
		$html .= "
<div class=\"block\">
<h3 class=\"block_title\">$block_ref->{title}</h3>
<div class=\"block_content\">
$block_ref->{content}
</div>
</div>
";
		if ((defined $block_ref->{id}) and ($block_ref->{id} eq 'my_block')) {
			$html .= "<!-- end off canvas blocks for small screens -->\n";
		}

	}
	
	# Remove empty titles
	$html =~ s/<div class=\"block_title\"><\/div>//g;
	
	return $html;
}



sub display_new($) {

	my $request_ref = shift;
	
	# If the client is requesting json, jsonp, xml or jqm, 
	# and if we have a response in structure format,
	# do not generate an HTML response and serve the structured data
	
	if (($request_ref->{json} or $request_ref->{jsonp} or $request_ref->{xml} or $request_ref->{jqm} or $request_ref->{rss})
		and (exists $request_ref->{structured_response})) {
	
		display_structured_response($request_ref);
		return;
	}
	
	
	not $request_ref->{blocks_ref} and $request_ref->{blocks_ref} = [];
	

	my $title = $request_ref->{title};
	my $description = $request_ref->{description};
	my $content_ref = $request_ref->{content_ref};
	my $blocks_ref = $request_ref->{blocks_ref};
	
	
	my $meta_description = '';
	
	my $content_header = '';	
	
	$log->debug("displaying page", { title => $title }) if $log->is_debug();
	
	my $object_ref;
	my $type;
	my $id;

	
	$log->debug("displaying blocks") if $log->is_debug();
	
	display_login_register($blocks_ref);
		
	display_my_block($blocks_ref);
	
	display_product_search_or_add($blocks_ref);
	
	display_on_the_blog($blocks_ref);
	
	#display_top_block($blocks_ref);
	display_bottom_block($blocks_ref);
	
	my $site = "<a href=\"/\">" . lang("site_name") . "</a>";
	
	$$content_ref =~ s/<SITE>/$site/g;

	$title =~ s/<SITE>/$site/g;
	
	$title =~ s/<([^>]*)>//g;	

	my $h1_title= '';
	
	if (($$content_ref !~ /<h1/) and (defined $title)) {
		$h1_title = "<h1>$title</h1>";
	}

	my $textid = undef;
	if ((defined $description) and ($description =~ /^textid:/)) {
		$textid = $';
		$description = undef;
	}
	if ($$content_ref =~ /\<p id="description"\>(.*?)\<\/p\>/s) {
		$description = $1;
	}
	
	if (defined $description) {
		$description =~ s/<([^>]*)>//g;
		$description =~ s/"/'/g;
		$meta_description = "<meta name=\"description\" content=\"$description\" />";
	}
	

	
	my $canon_title = '';
	if (defined $title) {
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
	my $canon_url = format_subdomain($subdomain);

	if (defined $request_ref->{canon_url}) {
		if ($request_ref->{canon_url} =~ /^http:/) {
			$canon_url = $request_ref->{canon_url};
		}
		else {
			$canon_url .= $request_ref->{canon_url};
		}
	}
	elsif (defined $request_ref->{canon_rel_url}) {
		$canon_url .= $request_ref->{canon_rel_url};
	}
	elsif (defined $request_ref->{current_link_query}) {
		$canon_url .= $request_ref->{current_link_query};
	}
	elsif (defined $request_ref->{url}) {
		$canon_url = $request_ref->{url};
	}
	
	# More images?
	
	my $og_images = '';
	my $og_images2 = '<meta property="og:image" content="' . lang("og_image_url") . '"/>';
	my $more_images = 0;
	
	# <img id="og_image" src="https://recettes.de/images/misc/recettes-de-cuisine-logo.gif" width="150" height="200" /> 
	if ($$content_ref =~ /<img id="og_image" src="([^"]+)"/) {
		my $img_url = $1;
		$img_url =~ s/\.200\.jpg/\.400\.jpg/;
		if ($img_url !~ /^http:/) {
			$img_url = format_subdomain($lc) . $img_url;
		}
		$og_images .= '<meta property="og:image" content="' . $img_url . '"/>' . "\n";
		if ($img_url !~ /misc/) {
			$og_images2 = '';
		}
	}
	

	
	my $main_margin_right = "margin-right:301px;";
	if ((defined $request_ref->{full_width}) and ($request_ref->{full_width} == 1)) {
		$main_margin_right = '';
	}
	
	my $og_type = 'food';
	if (defined $request_ref->{og_type}) {
		$og_type = $request_ref->{og_type};
	}
	
# <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
# <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/jquery-ui.min.js"></script>
# <link rel="stylesheet" href="https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/themes/ui-lightness/jquery-ui.css" />


#<script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.3/jquery.min.js"></script>
#<script src="//ajax.googleapis.com/ajax/libs/jqueryui/1.9.2/jquery-ui.min.js"></script>
#<link rel="stylesheet" href="https://ajax.googleapis.com/ajax/libs/jqueryui/1.9.2/themes/ui-lightness/jquery-ui.css" />
	
	my $html = <<HTML
<!doctype html>
<html class="no-js" lang="$lang">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="stylesheet" href="/css/dist/app.css" />
    <script src="/bower_components/foundation/js/vendor/modernizr.js"></script>
	
<title>$title</title>

$meta_description
	
<script src="/bower_components/foundation/js/vendor/jquery.js"></script>
<script type="text/javascript" src="/bower_components/jquery-ui/jquery-ui.min.js"></script>
<link rel="stylesheet" href="/bower_components/jquery-ui/themes/base/jquery-ui.min.css" />

<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/select2/4.0.3/css/select2.min.css" integrity="sha384-HIipfSYbpCkh5/1V87AWAeR5SUrNiewznrUrtNz1ux4uneLhsAKzv/0FnMbj3m6g" crossorigin="anonymous">
<link rel="search" href="@{[ format_subdomain($subdomain) ]}/cgi/opensearch.pl" type="application/opensearchdescription+xml" title="$Lang{site_name}{$lang}" />

<script>
\$(function() {
\$("#select_country").select2({
	placeholder: "$Lang{select_country}{$lang}",
    allowClear: true
	}
	).on("select2:select", function(e) {
	var subdomain =  e.params.data.id;
	if (! subdomain) {
		subdomain = 'world';
	}
	window.location.href = "https://" + subdomain + ".${server_domain}";
}).on("select2:unselect", function(e) {

	window.location.href = "https://world.${server_domain}";
})
;
<initjs>
});
</script>

$header

<meta property="fb:app_id" content="219331381518041" />
<meta property="og:type" content="$og_type"/>
<meta property="og:title" content="$canon_title"/>
<meta property="og:url" content="$canon_url"/>
$og_images
$og_images2
<meta property="og:description" content="$canon_description"/>

$options{favicons}


<style type="text/css" media="all">

hr.floatclear {
background: none;
border: 0;
clear: both;
display: block;
float: none;
font-size: 0;
margin: 0;
padding: 0;
overflow: hidden;
visibility: hidden;
width: 0;
height: 0;
}

hr.floatleft {
background: none;
border: 0;
clear: left;
display: block;
float: none;
font-size: 0;
margin: 0;
padding: 0;
overflow: hidden;
visibility: hidden;
width: 0;
height: 0;
}

hr.floatright {
background: none;
border: 0;
clear: right;
display: block;
float: none;
font-size: 0;
margin: 0;
padding: 0;
overflow: hidden;
visibility: hidden;
width: 0;
height: 0;
}



.data_table label, .data_table input { display: inline}
.data_table input, .data_table select { font-size: 1em }
.nutriment_label  { text-align: left; width: 300px; }
.nutriment_value { text-align: right }
.nutriment_subx { font-size: 0.9em;}
.data_table .nutriment_sub .nutriment_label { padding-left:20px;}
input.nutriment_value { width:5rem; height:2.3125rem;}
select.nutriment_unit { width:4rem; margin-bottom:0;}
thead, tbody { margin:0px; padding:0px; }


.data_table { margin-top:20px; padding:0px; vertical-align:middle; border-collapse:collapse}
.data_table td, .data_table th { margin:0px; padding:0.2rem; padding-left:0.5rem;}
.data_table .nutriment_head { background-color: #8888ff; color: white; }
.data_table .nutriment_main { border-top:3px solid white; background-color: #ddddff;}
.data_table .nutriment_sub, .data_table .nutriment_sub td { border-top: 1px solid #ddddff; background-color: #eeeeff; }
.ui-autocomplete li { font-size: 1em;}
#nutriment_carbon-footprint_tr { background-color:#ddffdd }

ul.products {
	list-style:none;
	padding: 0;
	margin: 0;	
}

.products li {
	text-align:center;
	display:block;
	float:left;
}

.products a {
	display:block;
	width:120px;;
	height:167px;
	padding:10px;
	margin:10px;
	overflow:hidden;	
}

.products div {
	width:120px;
	height:100px;
	line-height:100px;
	text-align:center;
	padding:0px;
	margin:0px;
	display: table-cell;
	vertical-align:middle;
}



.products a:hover {
	background:#f4f4f4;
}

.products img {
	vertical-align:middle;
}

#pages {
	margin-top:1.5rem;
}

a { text-decoration: none;}
a, a:visited, a:hover { color: blue;}

a:hover { text-decoration: underline; }

a.button {
	color:white;
}

a.button:hover {
	text-decoration:none;
}

.level_3, a.level_3, a:visited.level_3, a:hover.level_3 {
	color:red;
}

.level_2, a.level_2, a:visited.level_2, a:hover.level_2 {
	color:darkorange;
}

.level_1, a.level_1, a:visited.level_1, a:hover.level_1 {
	color:green;
}


<!-- foundation styles -->

.row{
  &.full-width{
    max-width: 100% !important;
    .row{
      margin: 0 auto;
      max-width: 62.5rem;
      background: inherit;
    }  
  }
}

.select2-container--default .select2-selection--single {
border-radius:0;
font-size: 0.875rem;
  position: relative;
  height: 1.75rem;
  top: 0.53125rem;
  width:10rem;
}

.left-small {
  border-right:0;
}

.tab-bar-section.middle {
  right:0;
}

#aside_column {
	padding:1rem;
}

.side-nav li a:not(.button) {
  margin: 0 -1rem;
  padding: 0.4375rem 1rem;
  color:blue;
}

.side-nav li a:not(.button):hover, .side-nav li a:not(.button):focus {
	color:blue;
}


\@media only screen and (max-width: 64em) {
a.button.icon {
font-size:1rem;
width:2rem;
height:2rem;
padding:0.5rem;
}
}

.products {
line-height:1.2;
}

#sharebuttons li { text-align:center; max-width:100px; }

#footer > div {
	padding:1rem;
}

.dark {
	color:#f0f0f0;
}

.dark h4 {
	color:white;
}

.dark a, .dark a:hover, .dark a:visited {
	color:white;
}

\@media only screen and (max-width: 40em) {
#footer h4 {
	font-size:1.125rem;
}
}

.top-bar-section .has-dropdown>a:after {
  border-color: transparent transparent transparent rgba(0,0,0,0.4);
}


\@media only screen and (min-width: 40.063em) {
.top-bar-section .has-dropdown>a:after {
  border-color: rgba(0,0,0,0.4) transparent transparent transparent;
}
.top-bar-section ul li {
  background: inherit;
}
#select_country_li {padding-left:0;}
}

#main_column {
	padding-bottom:2rem;
}

.example { font-size: 0.8em; color:green; }
.note { font-size: 0.8em; }
.example, .note { margin-top:4px;margin-bottom:0px;margin-left:4px; }

.tag.user_defined { font-style: italic; }

HTML
;

	$html .= lang("css");
	
	$html .= <<HTML

$styles



</style>

$google_analytics
	
</head>
<body$bodyabout>


<nav class="top-bar" data-topbar role="navigation" id="top-bar">
	<ul class="title-area">
		<li class="name">
			<h2><a href="/" style="font-size:1rem;">$Lang{site_name}{$lang}</a></h2>
		</li>
		<!-- Remove the class "menu-icon" to get rid of menu icon. Take out "Menu" to just have icon alone -->
		<li class="toggle-topbar menu-icon"><a href="#"><span>Menu</span></a></li>
	</ul>

	<section class="top-bar-section">


	<!-- Left Nav Section -->	



HTML
;


# <label for="select_country">$Lang{select_country}{$lang}</label><br/>
	
	my $select_country_options = lang("select_country_options");
	$select_country_options =~ s/value="$cc"/value="$cc" selected/;
	if ($cc eq 'world') {
		$select_country_options =~ s/<option value="world"(.*?)<\/option>//;
	}
	
	$html .= <<HTML
	<ul class="left">
		<li class="has-form has-dropdown" id="select_country_li">
<select id="select_country" style="width:100%">
<option></option>
HTML
.
$select_country_options
.
<<HTML
</select>
		</li>
		
HTML
;

	
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
				$langs .= "<li><a href=\"" . format_subdomain($osubdomain) . "/\">$Langs{$olc}</a></li>"
			}
		}
	}
	

	if ($langs =~ /<a/) {
		$html .= <<HTML

      <li class="has-dropdown">
		$selected_lang
        <ul class="dropdown">			
			$langs
        </ul>
      </li>
		
HTML
;
	}	
	
	$html .= <<HTML
	</ul>	
HTML
;



	
	my $blocks = display_blocks($request_ref);
	my $aside_blocks = $blocks;
	
	my $aside_initjs = $initjs;
	
	# keep only the login block for off canvas
	$aside_blocks =~ s/<!-- end off canvas blocks for small screens -->(.*)//s;
	
	$aside_initjs =~ s/(.*)\/\/ start off canvas blocks for small screens//s;
	$aside_initjs =~ s/\/\/ end off canvas blocks for small screens(.*)//s;
	
	# change ids of the add product image upload form
	$aside_blocks =~ s/block_side/block_aside/g;
	
	$aside_initjs =~ s/block_side/block_aside/g;
	
	$initjs .= $aside_initjs;
	
	# Join us on Slack <a href="http://slack.openfoodfacts.org">Slack</a>:
	my $join_us_on_slack = sprintf($Lang{footer_join_us_on}{$lc}, '<a href="https://slack-ssl-openfoodfacts.herokuapp.com/">Slack</a>');
	
	my $twitter_account = lang("twitter_account");
	if (defined $Lang{twitter_account_by_country}{$cc}) {
		$twitter_account = $Lang{twitter_account_by_country}{$cc};
	}
	
	my $facebook_page = lang("facebook_page");
	
	my $torso_color = "white";
	if (defined $User_id) {
		$torso_color = "#ffe681";
	}
	
	my $search_terms = '';
	if (defined param('search_terms')) {
		$search_terms = remove_tags_and_quote(decode utf8=>param('search_terms'))
	}
		
	$html .= <<HTML

	
	<!-- Right Nav Section -->
	<ul class="right">
		<li class="show-for-large-up">
			<form action="/cgi/search.pl">
			<div class="row collapse ">

					<div class="small-8 columns">
						<input type="text" placeholder="$Lang{search_a_product_placeholder}{$lang}" name="search_terms" value="${search_terms}" />
						<input name="search_simple" value="1" type="hidden" />
						<input name="action" value="process" type="hidden" />
					</div>
					<div class="small-4 columns">
						 <button type="submit" title="$Lang{search}{$lang}"><i class="fi-magnifying-glass"></i></button>
					</div>

			</div>
			</form>	
		</li>
		
		<li class="show-for-large-up"><a href="/cgi/search.pl" title="$Lang{advanced_search}{$lang}"><i class="fi-plus"></i></a></li>
		
		<li class="show-for-large-up"><a href="/cgi/search.pl?graph=1" title="$Lang{graphs_and_maps}{$lang}"><i class="fi-graph-bar"></i></a></li>
		
		<li class="show-for-large-up divider"></li>
	
		<li><a href="$Lang{menu_discover_link}{$lang}">$Lang{menu_discover}{$lang}</a></li>
		<li><a href="$Lang{menu_contribute_link}{$lang}">$Lang{menu_contribute}{$lang}</a></li>

	</ul>	
	
	</section>
	

</nav>


<nav class="tab-bar show-for-small-only">

  <div class="left-small" style="padding-top:4px;">
    <a href="#idOfLeftMenu" role="button" aria-controls="idOfLeftMenu" aria-expanded="false" class="left-off-canvas-toggle button postfix">
	<i class="fi-torso" style="color:$torso_color;font-size:1.8rem"></i></a>
  </div>
  <div class="middle tab-bar-section" style="padding-top:4px;">
			<form action="/cgi/search.pl">
			<div class="row collapse ">

					<div class="small-8 columns">
						<input type="text" placeholder="$Lang{search_a_product_placeholder}{$lc}" name="search_terms">
						<input name="search_simple" value="1" type="hidden" />
						<input name="action" value="process" type="hidden" />						
					</div>
					<div class="small-2 columns">
						 <button type="submit" class="button postfix"><i class="fi-magnifying-glass"></i></button>
					</div>
					
					<div class="small-2 columns">
							<a href="/cgi/search.pl" title="$Lang{advanced_search}{$lang}"><i class="fi-magnifying-glass"></i> <i class="fi-plus"></i></a>
					</div>


			</div>
			</form>	  
  </div>
 </nav>

 
 
 
<div class="off-canvas-wrap" data-offcanvas>
  <div class="inner-wrap">


    <!-- Off Canvas Menu -->
    <aside class="left-off-canvas-menu">
        <!-- whatever you want goes here -->
		<div id="aside_column">

	$aside_blocks
		
		</div>
    </aside>


  <!-- close the off-canvas menu -->
  <a class="exit-off-canvas"></a>

  
<!-- main row - comment used to remove left column and center content on some pages -->  
<div class="row full-width" style="max-width: 100% !important;" data-equalizer>
	<div class="xxlarge-1 xlarge-2 large-3 medium-4 columns hide-for-small" style="background-color:#fafafa;padding-top:1rem;" data-equalizer-watch>
		<div class="sidebar">
		
<div style="text-align:center">
<a href="/"><img id="logo" src="/images/misc/$Lang{logo}{$lang}" srcset="/images/misc/$Lang{logo2x}{$lang} 2x" width="178" height="150" alt="$Lang{site_name}{$lang}" style="margin-bottom:0.5rem"/></a>
</div>

<p>$Lang{tagline}{$lc}</p>


			<form action="/cgi/search.pl" class="hide-for-large-up">
			<div class="row collapse">

					<div class="small-9 columns">
						<input type="text" placeholder="$Lang{search_a_product_placeholder}{$lc}" name="search_terms">
						<input name="search_simple" value="1" type="hidden" />
						<input name="action" value="process" type="hidden" />
					</div>
					<div class="small-2 columns">
						 <button type="submit" class="button postfix"><i class="fi-magnifying-glass"></i></button>
					</div>
					
					<div class="small-1 columns">
						<label class="right inline">
							<a href="/cgi/search.pl" title="$Lang{advanced_search}{$lang}"><i class="fi-plus"></i></a>
						</label>
					</div>
			

			</div>
			</form>		


$blocks
	
		</div> <!-- sidebar -->
	</div> <!-- left column -->
		
	
	<div id="main_column" class="xxlarge-11 xlarge-10 large-9 medium-8 columns" style="padding-top:1rem" data-equalizer-watch>

<!-- main column content - comment used to remove left column and center content on some pages -->  
	
$h1_title

$$content_ref

	</div> <!-- main content column -->
</div> <!-- row -->

	</div> <!-- inner wrap -->
</div> <!-- off-content wrap -->


<!-- footer -->

<div id="footer" class="row full-width collapse" style="max-width: 100% !important;" data-equalizer>

	<div class="small-12 medium-6 large-3 columns" style="border-top:10px solid #ff0000" data-equalizer-watch>
		<h4>Open Food Facts</h4>
		<p>$Lang{footer_tagline}{$lc}</p>
		<ul>
			<li><a href="$Lang{footer_legal_link}{$lc}">$Lang{footer_legal}{$lc}</a></li>
			<li><a href="$Lang{footer_terms_link}{$lc}">$Lang{footer_terms}{$lc}</a></li>
			<li><a href="$Lang{footer_data_link}{$lc}">$Lang{footer_data}{$lc}</a></li>
			<li><a href="$Lang{donate_link}{$lc}">$Lang{donate}{$lc}</a></li>
		</ul>
	</div>
	
	<div class="small-12 medium-6 large-3 columns" style="border-top:10px solid #ffcc00" data-equalizer-watch>
		<h4>$Lang{footer_install_the_app}{$lc}</h4>

<div style="float:left;width:160px;height:70px;">
<a href="$Lang{ios_app_link}{$lc}">
$Lang{ios_app_badge}{$lc}</a>
</div>

<div style="float:left;width:160px;height:70px;">
<a href="$Lang{android_app_link}{$lc}">
$Lang{android_app_badge}{$lc}
</a></div>

<div style="float:left;width:160px;height:70px;">
<a href="$Lang{windows_phone_app_link}{$lc}">
$Lang{windows_phone_app_badge}{$lc}
</a></div>

<div style="float:left;width:160px;height:70px;">
<a href="$Lang{android_apk_app_link}{$lc}">
$Lang{android_apk_app_badge}{$lc}
</a></div>
		
	</div>
	
	<div class="small-12 medium-6 large-3 columns" style="border-top:10px solid #00d400" data-equalizer-watch>
		<h4>$Lang{footer_discover_the_project}{$lc}</h4>
		<ul>
			<li><a href="$Lang{footer_who_we_are_link}{$lc}">$Lang{footer_who_we_are}{$lc}</a></li>
			<li><a href="$Lang{footer_faq_link}{$lc}">$Lang{footer_faq}{$lc}</a></li>
			<li><a href="$Lang{footer_blog_link}{$lc}">$Lang{footer_blog}{$lc}</a></li>
			<li><a href="$Lang{footer_press_link}{$lc}">$Lang{footer_press}{$lc}</a></li>
			<li><a href="$Lang{footer_wiki_link}{$lc}">$Lang{footer_wiki}{$lc}</a></li>
			<li><a href="$Lang{footer_translators_link}{$lc}">$Lang{footer_translators}{$lc}</a></li>
			<li><a href="$Lang{footer_partners_link}{$lc}">$Lang{footer_partners}{$lc}</a></li>
		</ul>
	</div>
	
	<div class="small-12 medium-6 large-3 columns" style="border-top:10px solid #0066ff" data-equalizer-watch>
		<h4>$Lang{footer_join_the_community}{$lc}</h4>

<div>
<a href="$Lang{footer_code_of_conduct_link}{$lc}">$Lang{footer_code_of_conduct}{$lc}</a><br/><br/>

$join_us_on_slack <script async defer src="https://slack-ssl-openfoodfacts.herokuapp.com/slackin.js"></script>
<br/>
$Lang{footer_and_the_facebook_group}{$lc}
</div>

<div>
$Lang{footer_follow_us}{$lc}

<ul class="small-block-grid-3" id="sharebuttons">
	<li>
		<a href="https://twitter.com/share" class="twitter-share-button" data-lang="$lc" data-via="$Lang{twitter_account}{$lang}" data-url="@{[ format_subdomain($subdomain) ]}" data-count="vertical">Tweeter</a>
	</li>
	<li><fb:like href="@{[ format_subdomain($subdomain) ]}" layout="box_count"></fb:like></li>
	<li><div class="g-plusone" data-size="tall" data-count="true" data-href="@{[ format_subdomain($subdomain) ]}"></div></li>
</ul>

</div>
	
	</div>
</div>



<div id="fb-root"></div>

    <script type="text/javascript">
      window.fbAsyncInit = function() {
        FB.init({appId: '219331381518041', status: true, cookie: true,
                 xfbml: true});
     };
	 
      (function() {
        var e = document.createElement('script');
        e.type = 'text/javascript';
        e.src = document.location.protocol +
          '//connect.facebook.net/$Lang{facebook_locale}{$lang}/all.js';
        e.async = true;
        document.getElementById('fb-root').appendChild(e);
      }());
	  

    </script>	

<script type="text/javascript">
  window.___gcfg = {
    lang: '$Lang{facebook_locale}{$lang}'
  };
  (function() {
    var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;
    po.src = 'https://apis.google.com/js/plusone.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);
  })();
</script>

<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0];if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src="https://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");</script>	

<script src="/bower_components/foundation/js/foundation.min.js"></script>
<script src="/bower_components/foundation/js/vendor/jquery.cookie.js"></script>

<script async defer src="/bower_components/ManUp.js/manup.min.js"></script>

<script src="https://cdnjs.cloudflare.com/ajax/libs/select2/4.0.3/js/select2.min.js" integrity="sha384-222hzbb8Z8ZKe6pzP18nTSltQM3PdcAwxWKzGOKOIF+Y3bROr5n9zdQ8yTRHgQkQ" crossorigin="anonymous"></script>

$scripts

<script>
	\$(document).foundation(  { equalizer : {
    // Specify if Equalizer should make elements equal height once they become stacked.
    equalize_on_stack: true
	},
    accordion: {
      callback : function (accordion) {
        \$(document).foundation('equalizer', 'reflow');
      }
    }	
  });
</script>

<script>
  'use strict';

  function doWebShare(e) {
    e.preventDefault();
    if (!window.isSecureContext || navigator.share === undefined) {
      console.error('Error: Unsupported feature: navigator.share');
        return;
      }

      var title = this.title;
      var url = this.href;
      navigator.share({title: title, url: url})
        .then(() => console.info('Successfully sent share'),
              error => console.error('Error sharing: ' + error));
  }

  function onLoad() {
    var buttons = document.getElementsByClassName('share_button');
    var shareAvailable = window.isSecureContext && navigator.share !== undefined;
    [].forEach.call(buttons, function(button) {
      if (shareAvailable) {
          button.style.display = 'block';
          [].forEach.call(button.getElementsByTagName('a'), function(a) {
            a.addEventListener('click', doWebShare);
          });
        } else {
          button.style.display = 'none';
        }
    });
  }

  window.addEventListener('load', onLoad);
</script>

<script type="application/ld+json">
{
	"\@context" : "https://schema.org",
	"\@type" : "WebSite",
	"name" : "$Lang{site_name}{$lc}",
	"url" : "@{[ format_subdomain($subdomain) ]}",
	"potentialAction": {
		"\@type": "SearchAction",
		"target": "@{[ format_subdomain($subdomain) ]}/cgi/search.pl?search_terms=?{search_term_string}",
		"query-input": "required name=search_term_string"
	}	
}
</script>

<script type="application/ld+json">
{
	"\@context": "https://schema.org/",
	"\@type": "Organization",
	"url": "@{[ format_subdomain($subdomain) ]}",
	"logo": "/images/misc/$Lang{logo}{$lang}",
	"name": "$Lang{site_name}{$lc}",
	"sameAs" : [ "$facebook_page", "https://twitter.com/$twitter_account"] 
}
</script>

</body>
</html>
HTML
;
	
	
	# disable equalizer
	# e.g. for product edit form, pages that load iframes (twitter embeds etc.)
	if ($html =~ /<!-- disable_equalizer -->/) {

		$html =~ s/data-equalizer(-watch)?//g;
	}
	
	# no side column?
	# e.g. in Discover and Contribute page
	
	if ($html =~ /<!-- no side column -->/) {
	
		my $new_main_row_column = <<HTML
<div class="row">
	<div class="large-12 columns" style="padding-top:1rem">
HTML
;

		$html =~ s/<!-- main row -(.*)<!-- main column content(.*?)-->/$new_main_row_column/s;
	
	}
	
	# Twitter account
	$html =~ s/<twitter_account>/$twitter_account/g;
	

	# Use static subdomain for images, js etc.
	my $static = format_subdomain('static');
	$html =~ s/(?<![a-z0-9-])(?:https?:\/\/[a-z0-9-]+\.$server_domain)?\/(images|js|foundation|bower_components)\//$static\/$1\//g;
	# (?<![a-z0-9-]) -> negative look behind to make sure we are not matching /images in another path.
	# e.g. https://apis.google.com/js/plusone.js or //cdnjs.cloudflare.com/ajax/libs/select2/4.0.0-rc.2/images/select2.min.js

	# init javascript code
	
	$html =~ s/<initjs>/$initjs/;

	if ((defined param('length')) and (param('length') eq 'logout')) {
		my $test = '';
		if ($data_root =~ /-test/) {
			$test = "-test";
		}
		my $session = {} ;
		my $cookie2 = cookie (-name=>'session', -expires=>'-1d',-value=>$session, domain=>".$lc$test.$server_domain", -path=>'/') ;
		print header (-cookie=>[$cookie, $cookie2], -expires=>'-1d', -charset=>'UTF-8');
	}
	elsif (defined $cookie) {
		print header (-cookie=>[$cookie], -expires=>'-1d', -charset=>'UTF-8');
	}
	else {
		print header ( -expires=>'-1d', -charset=>'UTF-8');
	}

	my $status = $request_ref->{status};
	if (defined $status) {
		print header ( -status => $status );
	}
	
	binmode(STDOUT, ":encoding(UTF-8)");
	print $html;
	
	$log->debug("display done", { lc => $lc, lang => $lang, mongodb => $mongodb, data_root => $data_root }) if $log->is_debug();
}


sub display_product_search_or_add($)
{
	my $blocks_ref = shift;
	
	my $title = lang("add_product");
	
	my $or = $Lang{or}{$lc};
	$or =~ s/( |\&nbsp;)?://;
	
	my $html = '';
	
	$html .= start_multipart_form(-action=>"/cgi/product.pl") ;

	$html .= display_search_image_form("block_side");
	
	$html .= <<HTML

      <div class="row collapse">	  
        <div class="small-9 columns">
          <input type="text" name="code" placeholder="$or $Lang{barcode}{$lc}">
        </div>
        <div class="small-3 columns">
           <input type="submit" value="$Lang{add}{$lc}" class="button postfix" />
        </div>
      </div>
	  
	  <input type="submit" value="$Lang{no_barcode}{$lc}" class="button tiny" />
</form>
HTML
;
	

	
		
	unshift @$blocks_ref, {
			'title'=>$title,
			'content'=>$html,
	};	

}



sub display_image_box($$$) {

	my $product_ref = shift;
	my $id = shift;
	my $minheight_ref = shift;
	
	# print STDERR "display_image_box : $id\n";
	
	my $img = display_image($product_ref, $id, $small_size);
	if ($img ne '') {
	
		if ($id eq 'front') {
		
			$img =~ s/<img/<img id="og_image"/;
		
		}
	
		$img = <<HTML
<div id="image_box_$id" class="image_box" itemprop="image" itemscope itemtype="https://schema.org/ImageObject">
$img
</div>			
HTML
;

		if ($img =~ /height="(\d+)"/) {
			$$minheight_ref = $1 + 22;
		}
		
		# Unselect button for admins
		if ($admin) {
		
			my $code = $product_ref->{code};
			
			my $idlc = $id;
			
			# <img src="/images/products/$path/$id.$rev.$size.jpg" 
			
			if ($img =~ /src="([^"]*)\/([^\.]+)\./) {
				$idlc = $2;
			}
					
		
			my $html = <<HTML
<div class="button_div unselectbuttondiv_$idlc"><button class="unselectbutton_$idlc" class="small button" type="button">Unselect image</button></div>
HTML
;

			my $filename = '';
			my $size = 'full';
			if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$idlc})
				and (defined $product_ref->{images}{$idlc}{sizes}) and (defined $product_ref->{images}{$idlc}{sizes}{$size})) {
				$filename = $idlc . '.' . $product_ref->{images}{$idlc}{rev} ;
			}

			my $path = product_path($product_ref->{code});
			if (-e "$www_root/images/products/$path/$filename.full.jpg.google_cloud_vision.json") {
				$html .= <<HTML
<a href="/images/products/$path/$filename.full.jpg.google_cloud_vision.json" class="button tiny">Cloud Vision</a>
HTML
;
			}

			if (-e "$www_root/images/products/$path/$filename.full.json") {
				$html .= <<HTML
<a href="/images/products/$path/$filename.full.json" class="button tiny">OCR</a>
HTML
;
			}
			
			$img .= $html;
			
			$initjs .= <<JS
	\$(".unselectbutton_$idlc").click({imagefield:"$idlc"},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		\$('div.unselectbuttondiv_$idlc').html('<img src="/images/misc/loading2.gif" /> Unselecting image');
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

# itemprop="description"
my %itemprops = (
"generic_name"=>"description",
"brands"=>"brand",
);

sub display_field($$) {

	my $product_ref = shift;
	my $field = shift;

	my $html = '';

	if ($field eq 'br') {
		$html .= '<hr class="floatleft">' . "\n";
		return $html;
	}

	my $value = $product_ref->{$field};
	
	# fields in %language_fields can have different values by language
	
	if (defined $language_fields{$field}) {
		if ((defined $product_ref->{$field . "_" . $lc}) and ($product_ref->{$field . "_" . $lc} ne '')) {
			$value = $product_ref->{$field . "_" . $lc};
		}
	}

	if (defined $taxonomy_fields{$field}) {
		$value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
	}	
	elsif (defined $hierarchy_fields{$field}) {
		$value = display_tags_hierarchy($field, $product_ref->{$field . "_hierarchy"});
	}
	elsif (defined $tags_fields{$field}) {
		$value = display_tags_list($field, $value);
	}

	
	if ($value ne '') {
		if (($field eq 'link') and ($value =~ /^http/)) {
			my $link = $value;
			$link =~ s/"|<|>|'//g;
			my $link2 = $link;
			$link2 =~ s/^(.{40}).*$/$1\.\.\./;
			$value = "<a href=\"$link\">$link2</a>";
		}
		my $itemprop = '';
		if (defined $itemprops{$field}) {
			$itemprop = " itemprop=\"$itemprops{$field}\"";
			if ($value =~ /<a /) {
				$value =~ s/<a /<a$itemprop /g;
			}
			else {
				$value = "<span$itemprop>$value</span>";
			}
		}
		my $lang_field = lang($field);
		if ($lang_field eq '') {
			$lang_field = ucfirst(lang($field . "_p"));
		}
		$html .= '<p><span class="field">' . $lang_field . separator_before_colon($lc) . ":</span> $value</p>";
		
		if ($field eq 'brands') {
			my $brand = $value;
			# Keep the first one
			$brand =~ s/,(.*)//;
			$brand =~ s/<([^>]+)>//g;
			$product_ref->{brand} = $brand;
		}		
		
		if ($field eq 'categories') {
			my $category = $value;
			# Keep the last one
			$category =~ s/.*,( )?//;
			$category =~ s/<([^>]+)>//g;
			$product_ref->{category} = $category;
		}
	}
	return $html;
}


sub display_product($)
{
	my $request_ref = shift;

	my $request_code = $request_ref->{code};
	my $code = normalize_code($request_code);
	local $log->context->{code} = $code;

	my $html = '';
	my $blocks_ref = [];
	my $title = undef;
	my $description = "";
	
	$scripts .= <<HTML
HTML
;
	$initjs .= <<JS
JS
;
	
	$styles .= <<CSS	

.image_box {
	text-align:center;
	margin-bottom:2rem;
}

.field_div {
	display:inline;
	float:left;
	margin-right:30px;
	margin-top:10px;
	margin-bottom:10px;
}

.field {
	font-weight:bold;
}

.allergen {
	font-weight:bold;
}


CSS
;
	
	# Check that the product exist, is published, is not deleted, and has not moved to a new url
	
	$log->info("displaying product", { request_code => $request_code }) if $log->is_info();
	
	$title = $code;
	
	my $product_ref;
	
	my $rev = $request_ref->{rev};
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision") if $log->is_info();
		$product_ref = retrieve_product_rev($code, $rev);
		$header .= '<meta name="robots" content="noindex,follow">';
	}
	else {
		$product_ref = retrieve_product($code);
	}
	
	if (not defined $product_ref) {
		display_error(sprintf(lang("no_product_for_barcode"), $code), 404);
	}
	
	$title = product_name_brand_quantity($product_ref);
	my $titleid = get_fileid(product_name_brand($product_ref));
	
	if (not $title) {
		$title = $code;
	}

	if (defined $rev) {
		$title .= " version $rev";
	}
	
	$description = sprintf(lang("product_description"), $title);
	
	$request_ref->{canon_url} = product_url($product_ref);
	
	# Old UPC-12 in url? Redirect to EAN-13 url
	if ($request_code ne $code) {
		$request_ref->{redirect} = $request_ref->{canon_url};
		$log->info("301 redirecting user because request_code does not match code", { redirect => $request_ref->{redirect}, lc => $lc, request_code => $code }) if $log->is_info();
		return 301;
	}
	
	# Check that the titleid is the right one
	
	if ((not defined $rev) and	(
			(($titleid ne '') and ((not defined $request_ref->{titleid}) or ($request_ref->{titleid} ne $titleid))) or
			(($titleid eq '') and ((defined $request_ref->{titleid}) and ($request_ref->{titleid} ne ''))) )) {
		$request_ref->{redirect} = $request_ref->{canon_url};
		$log->info("301 redirecting user because titleid is incorrect", { redirect => $request_ref->{redirect}, lc => $lc, product_lc => $product_ref->{lc}, titleid => $titleid, request_titleid => $request_ref->{titleid} }) if $log->is_info();
		return 301;
	}

	if ($request_ref->{product_changes_saved}) {
		my $text = lang('product_changes_saved');
		$html .= <<HTML
<div data-alert class="alert-box info">
<span>$text</span>
 <a href="#" class="close">&times;</a>
</div>
HTML
;
		my $query_ref = {};
		$query_ref->{ ("states_tags") } = "en:to-be-completed";
		
		my $search_result = search_and_display_products($request_ref, $query_ref, undef, undef, undef);
		if ($request_ref->{structured_response}{count} > 0) {
			$html .= $search_result . '<hr/>';
		}
	}
	
	my $share = lang('share');
	$html .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;display:none;">
<a href="$request_ref->{canon_url}" class="button small icon" title="$title">
	<i class="fi-share"></i>
	<span class="show-for-large-up"> $share</span>
</a></div>
<div class="edit_button right" style="float:right;margin-top:-10px;">
<a href="/cgi/product.pl?type=edit&code=$code" class="button small icon">
	<i class="fi-pencil"></i>
	<span class="show-for-large-up"> $Lang{edit_product_page}{$lc}</span>
</a></div>
HTML
;
	
	if ($admin) {
		$html .= <<HTML
<div class="delete_button right" style="float:right;margin-top:-10px;margin-right:10px;">
<a href="/cgi/product.pl?type=delete&code=$code" class="button small icon">
	<i class="fi-trash"></i>
	<span class="show-for-large-up"> $Lang{delete_product_page}{$lc}</span>
</a></div>
HTML
;
	}	
	

	
	# my @fields = qw(generic_name quantity packaging br brands br categories br labels origins br manufacturing_places br emb_codes link purchase_places stores countries);
	my @fields = @ProductOpener::Config::display_fields;
	
	$bodyabout = " about=\"" . product_url($product_ref) . "\" typeof=\"food:foodProduct\"";
	
#<div itemscope itemtype="http://schema.org/Product">
#  <span itemprop="name">Kenmore White 17" Microwave</span>
#  <img src="kenmore-microwave-17in.jpg" alt='Kenmore 17" Microwave' />
#  <div itemprop="aggregateRating"
#    itemscope itemtype="http://schema.org/AggregateRating">
#   Rated <span itemprop="ratingValue">3.5</span>/5
#   based on <span itemprop="reviewCount">11</span> customer reviews
#  </div>	

	$html .= '<div itemscope itemtype="https://schema.org/Product">' . "\n";
	
	$html .= "<h1 property=\"food:name\" itemprop=\"name\">$title</h1>";	
	
	if ($code =~ /^2000/) { # internal code
	}
	else {
		# Also display UPC code if the EAN starts with 0
		my $html_upc = "";
		if (length($code) == 13) {
			$html_upc .= "(EAN / EAN-13)";
			if ($code =~ /^0/) {
				$html_upc .= " " . $' . " (UPC / UPC-A)";
			}
		}
		$html .= "<p>" . lang("barcode") . separator_before_colon($lc) . ": <span property=\"food:code\" itemprop=\"gtin13\" style=\"speak-as:digits;\">$code</span> $html_upc</p>
<div property=\"gr:hasEAN_UCC-13\" content=\"$code\" datatype=\"xsd:string\"></div>\n";
	}
	

	if (not has_tag($product_ref, "states", "en:complete")) {
	
		$html .= <<HTML
<div data-alert class="alert-box info" id="warning_not_complete" style="display: block;">
$Lang{warning_not_complete}{$lc}
<a href="#" class="close">&times;</a>
</span></div>
HTML
;
	}		
	
	
	if (($lc eq 'fr') and (has_tag($product_ref, "labels","fr:produits-retires-du-marche-lors-du-scandale-lactalis-de-decembre-2017"))) {
		
		$html .= <<HTML
<div data-alert class="alert-box warn" id="warning_lactalis_201712" style="display: block; background:#ffaa33;color:black;">
Ce produit fait partie d'une liste de produits retirés du marché, et a été étiqueté comme tel par un bénévole d'Open Food Facts.
<br/><br/>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
<a href="#" class="close">&times;</a>
</span></div>
HTML
;		
		
	}
	elsif (($lc eq 'fr') and (has_tag($product_ref, "categories","en:baby-milks")) and (
		
		has_tag($product_ref, "brands", "amilk") or
		has_tag($product_ref, "brands", "babycare") or
		has_tag($product_ref, "brands", "celia") or
		has_tag($product_ref, "brands", "celia-ad") or
		has_tag($product_ref, "brands", "celia-develop") or
		has_tag($product_ref, "brands", "celia-expert") or
		has_tag($product_ref, "brands", "celia-nutrition") or
		has_tag($product_ref, "brands", "enfastar") or
		has_tag($product_ref, "brands", "fbb") or
		has_tag($product_ref, "brands", "fl") or
		has_tag($product_ref, "brands", "frezylac") or	
		has_tag($product_ref, "brands", "gromore") or
		has_tag($product_ref, "brands", "malyatko") or
		has_tag($product_ref, "brands", "mamy") or
		has_tag($product_ref, "brands", "milumel") or
		has_tag($product_ref, "brands", "neoangelac") or
		has_tag($product_ref, "brands", "neoangelac") or
		has_tag($product_ref, "brands", "nophenyl") or
		has_tag($product_ref, "brands", "novil") or
		has_tag($product_ref, "brands", "ostricare") or
		has_tag($product_ref, "brands", "pc") or
		has_tag($product_ref, "brands", "picot") or
		has_tag($product_ref, "brands", "sanutri")
		
	
	)
	
		
		
	) {
		
		$html .= <<HTML
<div data-alert class="alert-box warn" id="warning_lactalis_201712" style="display: block; background:#ffcc33;color:black;">
Certains produits de cette marque font partie d'une liste de produits retirés du marché.
<br/><br/>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des produits et lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
<a href="#" class="close">&times;</a>
</span></div>
HTML
;		
		
	}
	
	
	
	# photos and data sources

	my $html_manufacturer_source = ""; # Displayed at the top of the product page
	my $html_sources = "";	# 	Displayed at the bottom of the product page
	
	if (defined $product_ref->{sources}) {
		# FIXME : currently just a quick workaround to display openfood attribution

#			push @{$product_ref->{sources}}, {
#				id => "openfood-ch",
#				url => "https://www.openfood.ch/en/products/$openfood_id",
#				import_t => time(),
#				fields => \@modified_fields,
#				images => \@images_ids,	
#			};

		my %unique_sources = ();
	
		foreach my $source_ref (@{$product_ref->{sources}}) {
			$unique_sources{$source_ref->{id}} = $source_ref;
		}
		foreach my $source_id (sort keys %unique_sources) {
			my $source_ref = $unique_sources{$source_id};
			my $lang_source = $source_ref->{id};
			$lang_source =~ s/-/_/g;
			$html_sources .= "<p>" . lang("sources_" . $lang_source ) . "</p>";
			if (defined $source_ref->{url}) {
				$html_sources .= "<p><a href=\"" . $source_ref->{url} . "\">" . lang("sources_" . $lang_source . "_product_page" ) . "</a></p>";
			}
			
			if ((defined $source_ref->{manufacturer}) and ($source_ref->{manufacturer} == 1)) {
				$html_manufacturer_source = "<p>" . sprintf(lang("sources_manufacturer"), "<a href=\"" . $source_ref->{url} . "\">" . $source_ref->{name} . "</a>") . "</p>";
			}
		}
	}	
	
	$html .= $html_manufacturer_source;
	
	my $minheight = 0;
	my $html_image = display_image_box($product_ref, 'front', \$minheight);
	$html_image =~ s/ width="/ itemprop="image" width="/;
	
	# Take the last (biggest) image
	my $product_image_url;
	if ($html_image =~ /.*src="([^"]+)"/is) {
		$product_image_url = $1;
	}
	
	
	my $html_fields = '';
	foreach my $field (@fields) {
		# print STDERR "display_product() - field: $field - value: $product_ref->{$field}\n";
		$html_fields .= display_field($product_ref, $field);
	}	

	$html .= <<HTML
<h2>$Lang{product_characteristics}{$lc}</h2>
<div class="row">
<div class="hide-for-large-up medium-12 columns">$html_image</div>
<div class="medium-12 large-8 xlarge-8 xxlarge-8 columns">
$html_fields
</div>
<div class="show-for-large-up large-4 xlarge-4 xxlarge-4 columns" style="padding-left:0">$html_image</div>
</div>
HTML
;

	
	$html_image = display_image_box($product_ref, 'ingredients', \$minheight);	
	
	# try to display ingredients in the local language if available
	
	my $ingredients_text = $product_ref->{ingredients_text};
	my $ingredients_text_lang = $product_ref->{lc};
	
	if (defined $product_ref->{ingredients_text_with_allergens}) {
		$ingredients_text = $product_ref->{ingredients_text_with_allergens};
	}	
	
	if ((defined $product_ref->{"ingredients_text" . "_" . $lc}) and ($product_ref->{"ingredients_text" . "_" . $lc} ne '')) {
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $lc};
		$ingredients_text_lang = $lc;
	}
	
	if ((defined $product_ref->{"ingredients_text_with_allergens" . "_" . $lc}) and ($product_ref->{"ingredients_text_with_allergens" . "_" . $lc} ne '')) {
		$ingredients_text = $product_ref->{"ingredients_text_with_allergens" . "_" . $lc};
		$ingredients_text_lang = $lc;
	}
		
	
	
		$html .= <<HTML
<h2>$Lang{ingredients}{$lc}</h2>
<div class="row">
<div class="hide-for-large-up medium-12 columns">$html_image</div>
<div class="medium-12 large-8 xlarge-8 xxlarge-8 columns">
HTML
;
	
		
	$html .= "<p class=\"note\">&rarr; " . lang("ingredients_text_display_note") . "</p>";
	$html .= "<div><span class=\"field\">" . lang("ingredients_text") . separator_before_colon($lc) . ":</span>";
	if ($lc ne $ingredients_text_lang) {
		$html .= " <div id=\"ingredients_list\" property=\"food:ingredientListAsText\" lang=\"$ingredients_text_lang\">$ingredients_text</div>";
	}
	else {
		$html .= " <div id=\"ingredients_list\" property=\"food:ingredientListAsText\">$ingredients_text</div>";
	}
	$html .= "</div>";
	
	if ($admin and ($ingredients_text !~ /^\s*$/)) {
	
			my $ilc = $ingredients_text_lang;
	
	
			$html .= <<HTML
			
<div class="button_div" id="editingredientsbuttondiv"><button id="editingredients" class="small button" type="button">Edit ingredients ($ilc)</div>
<div class="button_div" id="saveingredientsbuttondiv_status" style="display:none"></div>
<div class="button_div" id="saveingredientsbuttondiv" style="display:none"><button id="saveingredients" class="small button" type="button">Save ingredients ($ilc)</div>

			
<div class="button_div" id="wipeingredientsbuttondiv"><button id="wipeingredients" class="small button" type="button">Ingredients ($ilc) are completely bogus, erase them.</button></div>
HTML
;			
						
			$initjs .= <<JS
			
	var editableText;

    \$("#editingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();
		
    var divHtml = \$("#ingredients_list").html();
	var allergens = /(<span class="allergen">|<\\/span>)/g;
	divHtml = divHtml.replace(allergens, '_');
	
    var editableText = \$('<textarea id="ingredients_list" style="height:8rem"/>');
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
		\$('div[id="saveingredientsbuttondiv_status"]').html('<img src="/images/misc/loading2.gif" /> Saving ingredients_texts_$ilc');
		\$('div[id="saveingredientsbuttondiv_status"]').show();

		\$.post('/cgi/product_jqm_multilingual.pl',
				{code: "$code", ingredients_text_$ilc :  \$("#ingredients_list").val(), comment: "Updated ingredients_texts_$ilc" }, function(data) {
				
				\$('div[id="saveingredientsbuttondiv_status"]').html('Saved ingredients_texts_$ilc');
						\$('div[id="saveingredientsbuttondiv"]').show();

		
			\$(document).foundation('equalizer', 'reflow');
		}, 'json');  
		
		\$(document).foundation('equalizer', 'reflow');
		
	});		
	
	
			
	\$("#wipeingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		\$('div[id="wipeingredientsbuttondiv"]').html('<img src="/images/misc/loading2.gif" /> Erasing ingredients_texts_$ilc');
		\$.post('/cgi/product_jqm_multilingual.pl',
				{code: "$code", ingredients_text_$ilc : "", comment: "Erased ingredients_texts_$ilc: too much bad data" }, function(data) {
				

				\$('div[id="wipeingredientsbuttondiv"]').html("Erased ingredients_texts_$ilc");
				\$('div[id="ingredients_list"]').html("");

			\$(document).foundation('equalizer', 'reflow');
		}, 'json');
		
		\$(document).foundation('equalizer', 'reflow');
		
	});				
JS
;	
	
	}

	$html .= display_field($product_ref, 'allergens');
	
	$html .= display_field($product_ref, 'traces');
	
	
	my $html_ingredients_classes = "";
	
	# to compute the number of columns displayed
	my $html_ingredients_classes_n = 0;

	foreach my $class ('additives', 'vitamins', 'minerals', 'amino_acids', 'nucleotides', 'other_nutritional_substances', 'ingredients_from_palm_oil', 'ingredients_that_may_be_from_palm_oil') {
	
		my $tagtype = $class;
		my $tagtype_field = $tagtype;
		# display the list of additives variants in the order that they were found, without the parents (no E450 for E450i)
		if (($class eq 'additives') and (exists $product_ref->{'additives_original_tags'})) {
			$tagtype_field = 'additives_original';
		}
	
		if ((defined $product_ref->{$tagtype_field . '_tags'}) and (scalar @{$product_ref->{$tagtype_field . '_tags'}} > 0)) {

			$html_ingredients_classes_n++;
			
			$html_ingredients_classes .= "<div class=\"column_class\"><b>" . ucfirst( lang($class . "_p") . separator_before_colon($lc)) . ":</b><br />";
			
			if (defined $tags_images{$lc}{$tagtype}{get_fileid($tagtype)}) {
				my $img = $tags_images{$lc}{$tagtype}{get_fileid($tagtype)};
				my $size = '';
				if ($img =~ /\.(\d+)x(\d+)/) {
					$size = " width=\"$1\" height=\"$2\"";
				}
				$html_ingredients_classes .= <<HTML
<img src="/images/lang/$lc/$tagtype/$img"$size/ style="display:inline"> 
HTML
;
			}
			
			if ($tagtype eq 'additives') {
			
				$styles .= <<CSS
a.additives_efsa_evaluation_overexposure_risk_high { color:red }
a.additives_efsa_evaluation_overexposure_risk_moderate { color:#ff6600 }
CSS
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
					$tagid =~ s/.*://; # levels are defined only in old French list

					if ($ingredients_classes{$class}{$tagid}{level} > 0) {
						$info = ' class="additives_' . $ingredients_classes{$class}{$tagid}{level} . '" title="' . $ingredients_classes{$class}{$tagid}{warning} . '" ';
					}
					
					if ((defined $properties{$tagtype}) and (defined $properties{$tagtype}{$canon_tagid})
						and (defined $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"})
						and ($properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"} ne 'en:no')) {
						
						my $tagtype_field = "additives_efsa_evaluation_overexposure_risk";
						my $valueid = $properties{$tagtype}{$canon_tagid}{"efsa_evaluation_overexposure_risk:en"};
						$valueid =~ s/^en://;
						
						# check if we have an icon
						if (exists $Lang{$tagtype_field . "_icon_alt_" . $valueid}{$lc}) {
							my $alt = $Lang{$tagtype_field . "_icon_alt_" . $valueid }{$lc};
							my $iconid = $tagtype_field . "_icon_" . $valueid;
							$iconid =~ s/_/-/g;
							$more_info = <<HTML
<a href="$link">						
<img src="/images/misc/$iconid.svg" alt="$alt" width="45" height="45" /> 
</a>
<a href="$link" class="additives_efsa_evaluation_overexposure_risk_$valueid">
$alt
</a>
HTML
;
						}						
						
					}						
				}			
				
				if ((defined $tags_levels{$lc}{$tagtype}) and (defined $tags_levels{$lc}{$tagtype}{$tagid})) {
					$info = ' class="level_' . $tags_levels{$lc}{$tagtype}{$tagid} . '" ';
				}

		
				$html_ingredients_classes .= "<li><a href=\"" . $link . "\"$info>" . $tag . "</a>$more_info</li>\n";
			}
			$html_ingredients_classes .= "</ul></div>";
		}
	
	}
	
	if ($html_ingredients_classes_n > 0) {
	
		my $column_class = "small-12 columns";
	
		if ($html_ingredients_classes_n == 2) {
			$column_class = "medium-6 columns";
		}
		elsif ($html_ingredients_classes_n == 3) {
			$column_class = "medium-6 large-4 columns";
		}		
		elsif ($html_ingredients_classes_n == 4) {
			$column_class = "medium-6 large-3 columns";
		}
		elsif ($html_ingredients_classes_n >= 5) {
			$column_class = "medium-6 large-3 xlarge-2 columns";
		}			
	
		$html_ingredients_classes =~ s/column_class/$column_class/g;
	
		$html .= <<HTML

<div class="row">

$html_ingredients_classes

</div>
	
HTML
;
	}
	
	
	# special ingredients tags
	
	if ((defined $ingredients_text) and ($ingredients_text !~ /^\s*$/s) and (defined $special_tags{ingredients})) {
	
		my $special_html = "";
	
		foreach my $special_tag_ref (@{$special_tags{ingredients}}) {
		
			my $tagid = $special_tag_ref->{tagid};
			my $type = $special_tag_ref->{type};
			
			if (  (($type eq 'without') and (not has_tag($product_ref, "ingredients", $tagid)))
			or (($type eq 'with') and (has_tag($product_ref, "ingredients", $tagid)))) {
				
				$special_html .= "<li class=\"${type}_${tagid}_$lc\">" . lang("search_" . $type) . " " . display_taxonomy_tag_link($lc, "ingredients", $tagid) . "</li>\n";
			}
		
		}
		
		if ($special_html ne "") {
		
			$html  .= "<br/><hr class=\"floatleft\"><div><b>" . ucfirst( lang("ingredients_analysis") . separator_before_colon($lc)) . ":</b><br />"
			. "<ul id=\"special_ingredients\">\n" . $special_html . "</ul>\n"
			. "<p>" . lang("ingredients_analysis_note") . "</p></div>\n";
		}
	
	}
	
	
	# NOVA groups
	
	if (($lc eq 'fr') and (exists $product_ref->{nova_group})) {
		my $group = $product_ref->{nova_group};
			
# <a href="https://fr.openfoodfacts.org/score-nutritionnel-france" title="$Lang{nutrition_grade_fr_formula}{$lc}">
# <i class="fi-info"></i></a>

		my $display = display_taxonomy_tag($lc, "nova_groups", $product_ref->{nova_groups_tags}[0]);
		
		$html .= <<HTML
<h4>$Lang{nova_groups_s}{$lc}
<a href="https://fr.openfoodfacts.org/classification-nova-pour-la-transformation-des-aliments" title="Classification NOVA des aliments transformés">
<i class="fi-info"></i></a>
</h4>


<a href="https://fr.openfoodfacts.org/classification-nova-pour-la-transformation-des-aliments" title="Classification NOVA des aliments transformés"><img src="/images/misc/nova-group-$group.svg" alt="$display" style="margin-bottom:1rem;max-width:100%" /></a><br/>
$display
HTML
;
	}	
	
	
	$html .= <<HTML
</div>
<div class="show-for-large-up large-4 xlarge-4 xxlarge-4 columns" style="padding-left:0">$html_image</div>
</div>
HTML
;

	# Do not display nutrition table for Open Beauty Facts
	
	if (not ((defined $options{no_nutrition_table}) and ($options{no_nutrition_table}))) {

	
	$html_image = display_image_box($product_ref, 'nutrition', \$minheight);	

	
	$html .= <<HTML
<h2>$Lang{nutrition_data}{$lc}</h2>
<div class="row">
<div class="hide-for-large-up medium-12 columns">$html_image</div>
<div class="medium-12 large-8 xlarge-8 xxlarge-8 columns">
HTML
;


	$html .= display_nutrient_levels($product_ref);

	
	$html .= display_field($product_ref, "serving_size") . display_field($product_ref, "br") ;
	
	# Compare nutrition data with categories
	
	my @comparisons = ();
	
	if ( (not ((defined $product_ref->{not_comparable_nutrition_data}) and ($product_ref->{not_comparable_nutrition_data})))
			and  (defined $product_ref->{categories_tags}) and (scalar @{$product_ref->{categories_tags}} > 0)) {
	
		my $categories_nutriments_ref = retrieve("$data_root/index/categories_nutriments_per_country.$cc.sto");	
		
		if (defined $categories_nutriments_ref) {

			foreach my $cid (@{$product_ref->{categories_tags}}) {
				if ((defined $categories_nutriments_ref->{$cid}) and (defined $categories_nutriments_ref->{$cid}{stats})) {
					push @comparisons, {
						id => $cid,
						name => display_taxonomy_tag($lc,'categories', $cid),
						link => canonicalize_taxonomy_tag_link($lc,'categories', $cid),
						nutriments => compare_nutriments($product_ref, $categories_nutriments_ref->{$cid}),
						count => $categories_nutriments_ref->{$cid}{count},
						n => $categories_nutriments_ref->{$cid}{n},
					};
				}
			}		
			
			if ($#comparisons > -1) {
				@comparisons = sort { $a->{count} <=> $b->{count}} @comparisons;
				$comparisons[0]{show} = 1;
			}
		}
	
	}
	
	
	if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {
		$html .= "<p>$Lang{no_nutrition_data}{$lang}</p>";
	}
	
	
	$html .= display_nutrition_table($product_ref, \@comparisons);
	
	$html .= <<HTML
</div>
<div class="show-for-large-up large-4 xlarge-4 xxlarge-4 columns" style="padding-left:0">$html_image</div>
</div>
HTML
;	
	
	}
	
	# photos and data sources

	
	$html .= $html_sources;
	
	
	my $created_date = display_date_tag($product_ref->{created_t});
	my $last_modified_date = display_date_tag($product_ref->{last_modified_t});
	
	my @other_editors = ();
	
	foreach my $editor (@{$product_ref->{editors_tags}}) {
		next if $editor eq $product_ref->{creator};
		next if $editor eq $product_ref->{last_editor};
		push @other_editors, $editor;
	}
	
	my $other_editors = "";
	
	foreach my $editor (sort @other_editors) {
		$other_editors .= "<a href=\"" . canonicalize_tag_link("users", get_fileid($editor)) . "\">" . $editor . "</a>, ";
	}
	$other_editors =~ s/, $//;
	
	my $creator = "<a href=\"" . canonicalize_tag_link("users", get_fileid($product_ref->{creator})) . "\">" . $product_ref->{creator} . "</a>";
	my $last_editor = "<a href=\"" . canonicalize_tag_link("users", get_fileid($product_ref->{last_editor})) . "\">" . $product_ref->{last_editor} . "</a>";
	
	if ($other_editors ne "") {
		$other_editors = "<br>\n$Lang{also_edited_by}{$lang} ${other_editors}.";
	}

	$html .= <<HTML
	
<p>$Lang{product_added}{$lang} $created_date $Lang{by}{$lang} $creator.<br/>
$Lang{product_last_edited}{$lang} $last_modified_date $Lang{by}{$lang} $last_editor.
$other_editors
</p>
	
<div class="alert-box info">
$Lang{fixme_product}{$lc}
</div>

</div>

HTML
;

	if (defined $User_id) {
		$html .= display_field($product_ref, 'states');
	}

	$html .= display_product_history($code, $product_ref) if $admin;

	$html .= <<HTML
<div class="edit_button right" style="float:right;margin-top:-10px;">
<a href="/cgi/product.pl?type=edit&code=$code" class="button small">
	<i class="fi-pencil"></i>
	$Lang{edit_product_page}{$lc}
</a></div>
HTML
;

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

	
	$header .= <<HTML
<meta name="twitter:card" content="product">
<meta name="twitter:site" content="@<twitter_account>">
<meta name="twitter:creator" content="@<twitter_account>">
<meta name="twitter:title" content="$title">
<meta name="twitter:description" content="$description">
<meta name="twitter:image" content="$product_image_url">
<meta name="twitter:label1" content="$Lang{brands_s}{$lc}">
<meta name="twitter:data1" content="$product_ref->{brand}">
<meta name="twitter:label2" content="$Lang{categories_s}{$lc}">
<meta name="twitter:data2" content="$product_ref->{category}">

<meta property="og:image" content="$product_image_url">
HTML
;

	$request_ref->{content_ref} = \$html;
	$request_ref->{title} = $title;
	$request_ref->{description} = $description;
	$request_ref->{blocks_ref} = $blocks_ref;
	
	$log->trace("displayed product") if $log->is_trace();
	
	display_new($request_ref);	
}


sub display_product_jqm ($) # jquerymobile
{
	my $request_ref = shift;

	my $code = normalize_code($request_ref->{code});
	local $log->context->{code} = $code;
	
	
	my $html = '';
	my $title = undef;
	my $description = undef;
	

	
	# Check that the product exist, is published, is not deleted, and has not moved to a new url
	
	$log->info("displaying product jquery mobile") if $log->is_info();
	
	$title = $code;
	
	my $product_ref;
	
	my $rev = $request_ref->{rev};
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision on jquery mobile") if $log->is_info();
		$product_ref = retrieve_product_rev($code, $rev);
	}
	else {
		$product_ref = retrieve_product($code);
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
	
	$description = $title . ' - ' .  $product_ref->{brands} . ' - ' .  $product_ref->{generic_name};
	$description =~ s/ - $//;
	$request_ref->{canon_url} = product_url($product_ref);
	
	
	my @fields = qw(generic_name quantity packaging br brands br categories br labels br origins br manufacturing_places br emb_codes purchase_places stores);

	

	
	$html .= "<h1>$product_ref->{product_name}</h1>";	
	
	if ($code =~ /^2000/) { # internal code
	}
	else {
		$html .= "<p>" . lang("barcode") . separator_before_colon($lc) . ": $code</p>\n";
	}
	
	
	if (($lc eq 'fr') and (has_tag($product_ref, "labels","fr:produits-retires-du-marche-lors-du-scandale-lactalis-de-decembre-2017"))) {
		
		$html .= <<HTML
<div id="warning_lactalis_201712" style="display: block; background:#ffaa33;color:black;padding:1em;text-decoration:none;">
Ce produit fait partie d'une liste de produits retirés du marché, et a été étiqueté comme tel par un bénévole d'Open Food Facts.
<br/><br/>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
</div>
HTML
;		
		
	}
	elsif (($lc eq 'fr') and (has_tag($product_ref, "categories","en:baby-milks")) and (
		
		has_tag($product_ref, "brands", "amilk") or
		has_tag($product_ref, "brands", "babycare") or
		has_tag($product_ref, "brands", "celia") or
		has_tag($product_ref, "brands", "celia-ad") or
		has_tag($product_ref, "brands", "celia-develop") or
		has_tag($product_ref, "brands", "celia-expert") or
		has_tag($product_ref, "brands", "celia-nutrition") or
		has_tag($product_ref, "brands", "enfastar") or
		has_tag($product_ref, "brands", "fbb") or
		has_tag($product_ref, "brands", "fl") or
		has_tag($product_ref, "brands", "frezylac") or	
		has_tag($product_ref, "brands", "gromore") or
		has_tag($product_ref, "brands", "malyatko") or
		has_tag($product_ref, "brands", "mamy") or
		has_tag($product_ref, "brands", "milumel") or
		has_tag($product_ref, "brands", "neoangelac") or
		has_tag($product_ref, "brands", "neoangelac") or
		has_tag($product_ref, "brands", "nophenyl") or
		has_tag($product_ref, "brands", "novil") or
		has_tag($product_ref, "brands", "ostricare") or
		has_tag($product_ref, "brands", "pc") or
		has_tag($product_ref, "brands", "picot") or
		has_tag($product_ref, "brands", "sanutri")
		
	
	)
	
		
		
	) {
		
		$html .= <<HTML
<div id="warning_lactalis_201712" style="display: block; background:#ffcc33;color:black;padding:1em;text-decoration:none;">
Certains produits de cette marque font partie d'une liste de produits retirés du marché.
<br/><br/>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des produits et lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
</div>
HTML
;		
		
	}	
	
	
	$html .= display_nutrient_levels($product_ref);
	
	
	# NOVA groups
	
	if (($lc eq 'fr') and (exists $product_ref->{nova_group})) {
		my $group = $product_ref->{nova_group};
			
# <a href="https://fr.openfoodfacts.org/score-nutritionnel-france" title="$Lang{nutrition_grade_fr_formula}{$lc}">
# <i class="fi-info"></i></a>

		my $display = display_taxonomy_tag($lc, "nova_groups", $product_ref->{nova_groups_tags}[0]);
		
		$html .= <<HTML
<h4>$Lang{nova_groups_s}{$lc}
<a href="https://world.openfoodfacts.org/nova-groups-for-food-processing" title="NOVA groups for food processing">
<i class="fi-info"></i></a>
</h4>


<a href="https://world.openfoodfacts.org/nova-groups-for-food-processing" title="NOVA groups for food processing"><img src="/images/misc/nova-group-$group.svg" alt="$display" style="margin-bottom:1rem;max-width:100%" /></a><br/>
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
	
	if ((defined $product_ref->{"ingredients_text" . "_" . $lc}) and ($product_ref->{"ingredients_text" . "_" . $lc} ne '')) {
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $lc};
	}
	
	if ((defined $product_ref->{"ingredients_text_with_allergens" . "_" . $lc}) and ($product_ref->{"ingredients_text_with_allergens" . "_" . $lc} ne '')) {
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
	$html .= "<div id=\"ingredients_list\" ><span class=\"field\">" . lang("ingredients_text") . separator_before_colon($lc) . ":</span> $ingredients_text</div>";
	
	$html .= display_field($product_ref, 'allergens');
	
	$html .= display_field($product_ref, 'traces');
	

	my $class = 'additives';
	
	if ((defined $product_ref->{$class . '_tags'}) and (scalar @{$product_ref->{$class . '_tags'}} > 0)) {

		$html .= "<br/><hr class=\"floatleft\"><div><b>" . lang("additives_p") . separator_before_colon($lc) . ":</b><br />";		
		
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
				$tagid =~ s/.*://; # levels are defined only in old French list

				if ($ingredients_classes{$class}{$tagid}{level} > 0) {
					$info = ' class="additives_' . $ingredients_classes{$class}{$tagid}{level} . '" title="' . $ingredients_classes{$class}{$tagid}{warning} . '" ';
				}
				
				my $tagtype = $class;
				if ((defined $tags_levels{$lc}{$tagtype}) and (defined $tags_levels{$lc}{$tagtype}{$tagid})) {
					$info = ' class="level_' . $tags_levels{$lc}{$tagtype}{$tagid} . '" ';
					my %colors = ( 3 => 'red', 2 => 'darkorange', 1 => 'green' );
					if ($tags_levels{$lc}{$tagtype}{$tagid} > 0) {
						$info .= ' style="color:' . $colors{$tags_levels{$lc}{$tagtype}{$tagid} + 0} . '" ';
					}
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
			
			if (  (($type eq 'without') and (not has_tag($product_ref, "ingredients", $tagid)))
			or (($type eq 'with') and (has_tag($product_ref, "ingredients", $tagid)))) {
				
				$special_html .= "<li class=\"${type}_${tagid}_$lc\">" . lang("search_" . $type) . " " . display_taxonomy_tag_link($lc, "ingredients", $tagid) . "</li>\n";
			}
		
		}
		
		if ($special_html ne "") {
		
			$html  .= "<br/><hr class=\"floatleft\"><div><b>" . ucfirst( lang("ingredients_analysis") . separator_before_colon($lc)) . ":</b><br />"
			. "<ul id=\"special_ingredients\">\n" . $special_html . "</ul>\n"
			. "<p>" . lang("ingredients_analysis_note") . "</p></div>\n";
		}
	
	}	
	
		
	
	$html_image = display_image_box($product_ref, 'nutrition', \$minheight);	
	
	$html .= "</div>";
	
	$html .= <<HTML
			</div>
		</div>
HTML
;

	if (not ((defined $options{no_nutrition_table}) and ($options{no_nutrition_table}))) {

		
	$html .= <<HTML	
        <div data-role="deactivated-collapsible-set" data-theme="" data-content-theme="">
            <div data-role="deactivated-collapsible" data-collapsed="true">	
HTML
;	
	
	$html .= "<h2>" . lang("nutrition_data") . "</h2>";
	
	
	$html .= display_nutrient_levels($product_ref);
	
	$html .= "<div style=\"min-height:${minheight}px\">"
	. $html_image;
		
	$html .= display_field($product_ref, "serving_size") . display_field($product_ref, "br") ;
	
	# Compare nutrition data with categories
	
	my @comparisons = ();	
	
	if ($product_ref->{no_nutrition_data} eq 'on') {
		$html .= "<p>$Lang{no_nutrition_data}{$lang}</p>";
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
	
	if ((not defined ($product_ref->{images})) or ((scalar keys %{$product_ref->{images}}) < 1)) {
	
		$image_warning = $Lang{product_has_no_photos}{$lang};
	
	}	
	elsif ((defined $product_ref->{last_image_t}) and ($product_ref->{last_image_t} > 0)) {
	
		my $last_image_date = display_date($product_ref->{last_image_t});
		my $last_image_date_without_time = display_date_without_time($product_ref->{last_image_t});
		
		$last_image = "<br/>" . "$Lang{last_image_added}{$lang} $last_image_date";
		
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
	

	
	my $creator =  $product_ref->{creator} ;
	
	# Remove links for iOS (issues with twitter / facebook badges loading in separate windows..)
	$html =~ s/<a ([^>]*)href="([^"]+)"([^>]*)>/<span $1$3>/g;	# replace with a span to keep class for color of additives etc.
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

}


sub display_nutrient_levels($) {

	my $product_ref = shift;
	
	my $html = '';
	
	# Do not display nutriscore and traffic lights for some categories of products
	# do not compute a score for baby foods
	if (has_tag($product_ref, "categories", "en:baby-foods")) {

			return "";
	}	
	
	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, coffee, tea)
	# unless we have nutrition data for the prepared product
	
	my $prepared = '';
	if (has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated")) {
	
			if ((defined $product_ref->{nutriments}{"energy_prepared_100g"})) {
				$prepared = '_prepared';
			}
			else {
				return "";
			}
	}

	
	
	# do not compute a score for coffee, tea etc.
	if (	(has_tag($product_ref, "categories", "en:alcoholic-beverages")) 
		or	(has_tag($product_ref, "categories", "en:coffees"))
		or	(has_tag($product_ref, "categories", "en:teas"))
		or	(has_tag($product_ref, "categories", "en:teas"))
		or	(has_tag($product_ref, "categories", "fr:levure"))
		or	(has_tag($product_ref, "categories", "fr:levures"))
		) {

			return "";
	}	
	
	my $html_nutrition_grade = '';
	my $html_nutrient_levels = '';
		
	if ((exists $product_ref->{"nutrition_grade_fr"})) {
		my $grade = $product_ref->{"nutrition_grade_fr"};
		my $uc_grade = uc($grade);
		
		my $warning = '';
		if ((defined $product_ref->{nutrition_score_warning_no_fiber}) and ($product_ref->{nutrition_score_warning_no_fiber} == 1)) {
			$warning .= "<p>" . lang("nutrition_grade_fr_fiber_warning") . "</p>";
		}
		if ((defined $product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts})
				and ($product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts} == 1)) {
			$warning .= "<p>" . lang("nutrition_grade_fr_no_fruits_vegetables_nuts_warning") . "</p>";
		}
		if ((defined $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate})
				and ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate} == 1)) {
			$warning .= "<p>" . sprintf(lang("nutrition_grade_fr_fruits_vegetables_nuts_estimate_warning"),
								$product_ref->{nutriments}{"fruits-vegetables-nuts-estimate_100g"}) . "</p>";
		}
		if ((defined $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category})
				and ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category} ne '')) {
			$warning .= "<p>" . sprintf(lang("nutrition_grade_fr_fruits_vegetables_nuts_from_category_warning"),
								display_taxonomy_tag($lc,'categories',$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category}),
								$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category_value}) . "</p>";
		}		

		
		$html_nutrition_grade .= <<HTML
<h4>$Lang{nutrition_grade_fr_title}{$lc}
<a href="https://fr.openfoodfacts.org/score-nutritionnel-france" title="$Lang{nutrition_grade_fr_formula}{$lc}">
<i class="fi-info"></i></a>
</h4>
<a href="https://fr.openfoodfacts.org/score-nutritionnel-france" title="$Lang{nutrition_grade_fr_formula}{$lc}"><img src="/images/misc/nutriscore-$grade.svg" alt="$Lang{nutrition_grade_fr_alt}{$lc} $uc_grade" style="margin-bottom:1rem;max-width:100%" /></a><br/>
$warning
HTML
;
	}
		
	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @$nutrient_level_ref;
		
		if ((defined $product_ref->{nutrient_levels}) and (defined $product_ref->{nutrient_levels}{$nid})) {
		
			$html_nutrient_levels .= '<img src="/images/misc/' . $product_ref->{nutrient_levels}{$nid} . '.svg" width="30" height="30" style="vertical-align:middle;margin-right:15px;margin-bottom:4px;" alt="'
				. lang($product_ref->{nutrient_levels}{$nid} . "_quantity") . '" />' . (sprintf("%.2e", $product_ref->{nutriments}{$nid . $prepared . "_100g"}) + 0.0) . " g "
				. sprintf(lang("nutrient_in_quantity"), "<b>" . $Nutriments{$nid}{$lc} . "</b>", lang($product_ref->{nutrient_levels}{$nid} . "_quantity")). "<br />";
		
		}
	}
	if ($html_nutrient_levels ne '') {
		$html_nutrient_levels = <<HTML
<h4>$Lang{nutrient_levels_info}{$lc}
<a href="$Lang{nutrient_levels_link}{$lc}" title="$Lang{nutrient_levels_info}{$lc}"><i class="fi-info"></i></a>
</h4>
$html_nutrient_levels
HTML
;
	}
	
	# 2 columns?
	if (($html_nutrition_grade ne '') and ($html_nutrient_levels ne '')) {
		$html = <<HTML
<div class="row">
	<div class="small-12 xlarge-6 columns">
		$html_nutrition_grade
	</div>
	<div class="small-12 xlarge-6 columns">
		$html_nutrient_levels
	</div>
</div>	
HTML
;
	}
	else {
		$html = $html_nutrition_grade . $html_nutrient_levels;
	}

		
	return $html;
}




sub add_product_nutriment_to_stats($$$) {

	my $nutriments_ref = shift;
	my $nid = shift;
	my $value = shift;
	
	if ($value =~ /nan/i) {
	
		return -1;
	}
	elsif ($value ne '') {
					
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


sub compute_stats_for_products($$$$$$) {

	my $stats_ref = shift;	# where we will store the stats
	my $nutriments_ref = shift;	# values for some nutriments
	my $count = shift;	# total number of products (including products that have no values for the nutriments we are interested in)
	my $n = shift;	# number of products with defined values for specified nutriments
	my $min_products = shift; # min number of products needed to compute stats	
	my $id = shift;	# id (e.g. category id)


	$stats_ref->{stats} = 1;
	$stats_ref->{nutriments} = {};
	$stats_ref->{id} = $id;
	$stats_ref->{count} = $count;
	$stats_ref->{n} = $n;	
	

	foreach my $nid (keys %{$nutriments_ref}) {
		next if $nid !~ /_n$/;
		$nid = $`;
		
		next if ($nutriments_ref->{"${nid}_n"} < $min_products);
		
		$nutriments_ref->{"${nid}_mean"} = $nutriments_ref->{"${nid}_s"} / $nutriments_ref->{"${nid}_n"};
		
		my $std = 0;
		foreach my $value (@{$nutriments_ref->{"${nid}_array"}}) {
			$std += ($value - $nutriments_ref->{"${nid}_mean"}) * ($value - $nutriments_ref->{"${nid}_mean"});
		}
		$std = sqrt($std / $nutriments_ref->{"${nid}_n"});
		
		$nutriments_ref->{"${nid}_std"} = $std;
		
		my @values = sort { $a <=> $b } @{$nutriments_ref->{"${nid}_array"}};
		
		$stats_ref->{nutriments}{"${nid}_n"} = $nutriments_ref->{"${nid}_n"};
		$stats_ref->{nutriments}{"$nid"} = $nutriments_ref->{"${nid}_mean"};
		$stats_ref->{nutriments}{"${nid}_100g"} = sprintf("%.2e", $nutriments_ref->{"${nid}_mean"}) + 0.0;
		$stats_ref->{nutriments}{"${nid}_std"} =  sprintf("%.2e", $nutriments_ref->{"${nid}_std"}) + 0.0;

		if ($nid =~ /^energy/) {
			$stats_ref->{nutriments}{"${nid}_100g"} = int ($stats_ref->{nutriments}{"${nid}_100g"} + 0.5);
			$stats_ref->{nutriments}{"${nid}_std"} = int ($stats_ref->{nutriments}{"${nid}_std"} + 0.5);
		}				
		
		$stats_ref->{nutriments}{"${nid}_min"} = sprintf("%.2e",$values[0]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_max"} = sprintf("%.2e",$values[$nutriments_ref->{"${nid}_n"} - 1]) + 0.0;
		#$stats_ref->{nutriments}{"${nid}_5"} = $nutriments_ref->{"${nid}_array"}[int ( ($nutriments_ref->{"${nid}_n"} - 1) * 0.05) ];
		#$stats_ref->{nutriments}{"${nid}_95"} = $nutriments_ref->{"${nid}_array"}[int ( ($nutriments_ref->{"${nid}_n"}) * 0.95) ];
		$stats_ref->{nutriments}{"${nid}_10"} = sprintf("%.2e", $values[int ( ($nutriments_ref->{"${nid}_n"} - 1) * 0.10) ]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_90"} = sprintf("%.2e", $values[int ( ($nutriments_ref->{"${nid}_n"}) * 0.90) ]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_50"} = sprintf("%.2e", $values[int ( ($nutriments_ref->{"${nid}_n"}) * 0.50) ]) + 0.0;
		
		#print STDERR "-> lc: lc -category $tagid - count: $count - n: nutriments: " . $nn . "$n \n";
		#print "categories stats - cc: $cc - n: $n- values for category $id: " . join(", ", @values) . "\n";
		#print "tagid: $id - nid: $nid - 100g: " .  $stats_ref->{nutriments}{"${nid}_100g"}  . " min: " . $stats_ref->{nutriments}{"${nid}_min"} . " - max: " . $stats_ref->{nutriments}{"${nid}_max"} . 
		#	"mean: " . $stats_ref->{nutriments}{"${nid}_mean"} . " - median: " . $stats_ref->{nutriments}{"${nid}_50"} . "\n";
		
	}							

}


sub display_nutrition_table($$) {

	my $product_ref = shift;
	my $comparisons_ref = shift;
	
	my $html = '';
	
	my @cols;
	
	
	my %col_name = (
	);
	
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
		
		my $col_name = $Lang{product_as_sold}{$lang};
		if ($product_type eq 'prepared_') {
			$col_name = $Lang{prepared_product}{$lang};
		}
		$col_name{$product_type . "100g"} = $col_name . "<br/>" . $Lang{nutrition_data_per_100g}{$lang};
		$col_name{$product_type . "serving"} = $col_name . "<br/>" . $Lang{nutrition_data_per_serving}{$lang};
		if ((defined $product_ref->{serving_size}) and ($product_ref->{serving_size} ne '')) {
			$col_name{$product_type . "serving"} .= ' (' . $product_ref->{serving_size} . ')';
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
	
	my %col_class = (
		std => 'stats',
		min => 'stats',
		'10' => 'stats',
		'50' => 'stats',
		'90' => 'stats',
		'max' => 'stats',
	);

	
	# Comparisons with other products, categories, recommended daily values etc.
	
	if ((defined $comparisons_ref) and (scalar @$comparisons_ref > 0)) {
	
		$html .= "<p>" . lang("nutrition_data_comparison_with_categories") . "</p>";


		
		my $i = 0;
		
		foreach my $comparison_ref (@$comparisons_ref) {
		
			my $colid = "compare_" . $i;
		
			push @cols, $colid;
			$col_class{$colid} = $colid;
			$col_name{$colid} =  sprintf(lang("nutrition_data_compare_with_category"), $comparison_ref->{name});
			$col_name{$colid} =  $comparison_ref->{name};
			
			$log->debug("displaying nutrition table comparison column", { colid => $colid, id => $comparison_ref->{id}, name => $comparison_ref->{name} }) if $log->is_debug();
		
			my $checked = 0;
			if (defined $comparison_ref->{show}) {
				$checked = 1;
			}
			else {
				$styles .= <<CSS
.$colid { display:none }
CSS
;
			}
			
			my $checked_html = "";
			if ($checked) {
				$checked_html = ' checked="checked"';
			}
			
			$html .= <<HTML
<label style="display:inline;font-size:1rem;"><input type="checkbox" name="$colid" value="on" $checked_html id="$colid" class="show_comparison" /> $comparison_ref->{name}</label>		
HTML
;
			if (defined $comparison_ref->{count}) {
				$html .= " <a href=\"$comparison_ref->{link}\">(" . $comparison_ref->{count} . " " . lang("products") . ")</a>";
			}
			$html .= "<br>";
			
			$i++;
		}
		
		$html .= <<HTML
<br />		
<input type="radio" id="nutrition_data_compare_percent" value="compare_percent" name="nutrition_data_compare_type" checked />
<label for="nutrition_data_compare_percent">$Lang{nutrition_data_compare_percent}{$lang}</label>
<input type="radio" id="nutrition_data_compare_value" value="compare_value" name="nutrition_data_compare_type" />
<label for="nutrition_data_compare_value">$Lang{nutrition_data_compare_value}{$lang}</label>

HTML
;

		$html .= "<p class=\"note\">&rarr; " . lang("nutrition_data_comparison_with_categories_note") . "</p>";		
		
		# \$( ".show_comparison" ).button();

		
		$initjs .= <<JS

\$('input:radio[name=nutrition_data_compare_type]').change(function () {
		
	if (\$('input:radio[name=nutrition_data_compare_type]:checked').val() == 'compare_value') {
		\$(".compare_percent").hide();
		\$(".compare_value").show();
	}
	else {
		\$(".compare_value").hide();
		\$(".compare_percent").show();	
	}

}
);

\$(".show_comparison").change(function () {
	if (\$(this).prop('checked')) {
		\$("." + \$(this).attr("id")).show();		
	}
	else {
		\$("." + \$(this).attr("id")).hide();		
	}
}
);

JS
;
	
	}
	
	# Stats for categories
	
	if (defined $product_ref->{stats}) {
	
		foreach my $col ('std', 'min', '10', '50', '90', 'max') {
			push @cols, $col; 
			$col_name{$col} = lang("nutrition_data_per_$col");
		}
		
		if ($product_ref->{id} ne 'search') {
		
			$html .= "<div><input id=\"show_stats\" type=\"checkbox\" /><label for=\"show_stats\">"
			. lang("show_category_stats")
			. '<span class="show-for-xlarge-up">'
			. separator_before_colon($lc) . ": " . lang("show_category_stats_details") . "</span></label>" . "</div>";
		
			$initjs .= <<JS
		
if (\$.cookie('show_stats') == '1') {
	\$('#show_stats').prop('checked',true);
}		
else {
	\$('#show_stats').prop('checked',false);
}

if (\$('#show_stats').prop('checked')) {
	\$(".stats").show();
}
else {
	\$(".stats").hide();
}

\$("#show_stats").change(function () {
	if (\$('#show_stats').prop('checked')) {
		\$.cookie('show_stats', '1', { expires: 365 });
		\$(".stats").show();		
	}
	else {
		\$.cookie('show_stats', null);
		\$(".stats").hide();		
	}
}
);

JS
;
	
		}
	}
	
	my $empty_cols = '';
	my $html2 = '';
	
	$html .= <<HTML
<table id="nutrition_data_table" class="data_table">
<thead class="nutriment_header">
<tr><th>
HTML
. lang("nutrition_data_table") . <<HTML
</th>
HTML
;

	foreach my $col (@cols) {
		my $col_class = '';
		if (defined $col_class{$col}) {
			$col_class = ' ' . $col_class{$col} ;
		}
		my $col_name = $col_name{$col};
		
		$html .= '<th class="nutriment_value' . ${col_class} . ' ' . $col . '">' . $col_name . '</th>';
		$empty_cols .= "<td></td>";
	}

	$html .= <<HTML
</tr>
</thead>
<tbody>
HTML
;

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {
	
		next if (($nid =~ /_/) and ($nid !~ /_prepared$/)) ;
		
		$nid =~ s/_prepared$//;
		
		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid})) {
			push @unknown_nutriments, $nid;
			$seen_unknown_nutriments{$nid} = 1;
		}
	}
	
	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments) {
		
		next if $nutriment =~ /^\#/;
		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;
		
		next if $nid eq 'sodium';
		
		my $class = 'main';
		my $prefix = '';
		
		my $shown = 0;
		
		if  (($nutriment !~ /-$/)
			or ((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne ''))
			or ((defined $product_ref->{nutriments}{$nid . "_prepared"}) and ($product_ref->{nutriments}{$nid . "_prepared"} ne ''))
			or ($nid eq 'new_0') or ($nid eq 'new_1')) {
			$shown = 1;
		}
		
		# Only show important nutriments if the value is not known
		# Only show known values for search graph results
		if ((($nutriment !~ /^!/) or ($product_ref->{id} eq 'search')) 
			and not (((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne ''))
					or ((defined $product_ref->{nutriments}{$nid . "_prepared"}) and ($product_ref->{nutriments}{$nid . "_prepared"} ne '')))) {
			$shown = 0;
		}
			
		if (($shown) and ($nutriment =~ /^-/)) {
			$class = 'sub';
			$prefix = lang("nutrition_data_table_sub") . " ";
			if ($nutriment =~ /^--/) {
				$prefix = "&nbsp; " . $prefix;
			}			
		}
		
		my $label = '';
		
		# display nutrition score only when the country is matching
		
		if ($nid =~ /^nutrition-score-(.*)$/) {
			# Always show the FR score and Nutri-Score
			if (($cc ne $1) and (not ($1 eq 'fr'))) {
				$shown = 0;
			}
			else {
				my $labelid = get_fileid($Nutriments{$nid}{$lang});
				$label = <<HTML
<td class="nutriment_label"><a href="/$labelid" title="$product_ref->{nutrition_score_debug}">${prefix}$Nutriments{$nid}{$lang}</a></td>
HTML
;			
			}
		}
		
		elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{$lang})) {
			$label = <<HTML
<td class="nutriment_label">${prefix}$Nutriments{$nid}{$lang}</td>
HTML
;
		}
		elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{en})) {
			$label = <<HTML
<td class="nutriment_label">${prefix}$Nutriments{$nid}{en}</td>
HTML
;
		}		
		elsif (defined $product_ref->{nutriments}{$nid . "_label"}) {
			my $label_value = $product_ref->{nutriments}{$nid . "_label"};
			$label = <<HTML
<td class="nutriment_label">$label_value</td>
HTML
;
		}
		
		my $unit = 'g';

		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit})) {
			$unit = $Nutriments{$nid}{unit};

		}
		elsif ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_unit"})) {
			$unit = $product_ref->{nutriments}{$nid . "_unit"};
		}
			
		my $values = '';
		
		my $values2 = '';
		
		
		foreach my $col (@cols) {
		
			my $col_class = '';
			if (defined $col_class{$col}) {
				$col_class = ' ' . $col_class{$col} ;
			}
			
			if ($col =~ /compare_(.*)/) {	#comparisons
			
				my $comparison_ref = $comparisons_ref->[$1];

				my $value = "";
				if (defined $comparison_ref->{nutriments}{$nid . "_100g"}) {
					$value = sprintf("%.2e", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, $unit)) + 0.0;
				}
				# too small values are converted to e notation: 7.18e-05
				if (($value . ' ') =~ /e/) {
					# use %f (outputs extras 0 in the general case)
					$value = sprintf("%f", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, $unit));
				}
				
				# 0.045 g	0.0449 g
				
				my $value_unit = "$value $unit";
				if ((not defined $comparison_ref->{nutriments}{$nid . "_100g"}) or ($comparison_ref->{nutriments}{$nid . "_100g"} eq '')) {
					$value_unit = '?';
				}
				elsif ($nid =~ /^energy/) {
					$value_unit .= "<br/>(" . sprintf("%d", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, 'kcal')) . ' kcal)';
				}
				
				my $percent = $comparison_ref->{nutriments}{"${nid}_100g_%"};
				if ((defined $percent) and ($percent ne '')) {
					$percent = sprintf("%.0f", $percent);
					if ($percent > 0) {
						$percent = "+" . $percent;
					}
					$value_unit = '<span class="compare_percent">' . $percent . '%</span><span class="compare_value" style="display:none">' . $value_unit . '</span>';
				}
				
				$values .= "<td class=\"nutriment_value${col_class}\">$value_unit</td>";
				
				if ($nid eq 'sodium') {
					if ((not defined $comparison_ref->{nutriments}{$nid . "_100g"}) or ($comparison_ref->{nutriments}{$nid . "_100g"} eq '')) {
						$values2 .= "<td class=\"nutriment_value${col_class}\">?</td>";
					}
					else {
						$values2 .= "<td class=\"nutriment_value${col_class}\">"
						. '<span class="compare_percent">' . $percent . '%</span>'
						. '<span class="compare_value" style="display:none">' . (sprintf("%.2e", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"} * 2.54, $unit)) + 0.0) . " " . $unit . '</span>' . "</td>";
					}
				}
				if ($nid eq 'salt') {
					if ((not defined $comparison_ref->{nutriments}{$nid . "_100g"}) or ($comparison_ref->{nutriments}{$nid . "_100g"} eq '')) {
						$values2 .= "<td class=\"nutriment_value${col_class}\">?</td>";
					}
					else {
						$values2 .= "<td class=\"nutriment_value${col_class}\">"
						. '<span class="compare_percent">' . $percent . '%</span>'
						. '<span class="compare_value" style="display:none">' . (sprintf("%.2e", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"} / 2.54, $unit)) + 0.0) . " " . $unit . '</span>' . "</td>";
					}
				}				
				
				if ($nid eq 'nutrition-score-fr') {
					# We need to know the category in order to select the right thresholds for the nutrition grades
					# as it depends on whether it is food or drink
					
					# if it is a category stats, the category id is the id field
					if ((not defined $product_ref->{categories_tags})
						and (defined $product_ref->{id}) 
						and ($product_ref->{id} =~ /^en:/) 
							) {
						$product_ref->{categories} = $product_ref->{id};
						compute_field_tags($product_ref, "categories");
					}
					
					if (defined $product_ref->{categories_tags}) {
					
						$values2 .= "<td class=\"nutriment_value${col_class}\">"
							. uc (compute_nutrition_grade($product_ref, $comparison_ref->{nutriments}{$nid . "_100g"}))
							. "</td>";
					}
				}
				
			}
			else {
			
				my $value_unit = "";
				my $rdfa = '';
				
				# Nutriscore: per serving = per 100g
				if (($nid =~ /nutrition-score/) and ($col eq "serving")) {
					$product_ref->{nutriments}{$nid . "_$col"} = $product_ref->{nutriments}{$nid . "_100g"};
				}
				
				if ((not defined $product_ref->{nutriments}{$nid . "_$col"}) or ($product_ref->{nutriments}{$nid . "_$col"} eq '')) {
					$value_unit = '?';
				}
				else {

					# this is the actual value on the package, not a computed average. do not try to round to 2 decimals.
					my $value = g_to_unit($product_ref->{nutriments}{$nid . "_$col"}, $unit);
				
					# too small values are converted to e notation: 7.18e-05
					if (($value . ' ') =~ /e/) {
						# use %f (outputs extras 0 in the general case)
						$value = sprintf("%f", g_to_unit($product_ref->{nutriments}{$nid . "_$col"}, $unit));
					}
					
					$value_unit = "$value $unit";
					
					if (defined $product_ref->{nutriments}{$nid . "_modifier"}) {
						$value_unit = $product_ref->{nutriments}{$nid . "_modifier"} . " " . $value_unit;
					}
					
					if ($nid =~ /^energy/) {
						$value_unit .= "<br/>(" . g_to_unit($product_ref->{nutriments}{$nid . "_$col"}, 'kcal') . ' kcal)';
					}
					elsif ($nid eq 'sodium') {
						my $salt = $product_ref->{nutriments}{$nid . "_$col"} * 2.54;
						if (exists $product_ref->{nutriments}{"salt" . "_$col"}) {
							$salt = $product_ref->{nutriments}{"salt" . "_$col"};
						}
						$salt = sprintf("%.2e", g_to_unit($salt, $unit)) + 0.0;
						my $property = '';
						if ($col eq '100g') {
							$property = "property=\"food:saltEquivalentPer100g\" content=\"$salt\"";
						}
						$values2 .= "<td class=\"nutriment_value${col_class}\" $property>" . $salt . " " . $unit . "</td>";
					}
					elsif ($nid eq 'salt') {
						my $sodium = $product_ref->{nutriments}{$nid . "_$col"} / 2.54;
						if (exists $product_ref->{nutriments}{"sodium". "_$col"}) {
							$sodium = $product_ref->{nutriments}{"sodium". "_$col"};
						}
						$sodium = sprintf("%.2e", g_to_unit($sodium, $unit)) + 0.0;
						my $property = '';
						if ($col eq '100g') {
							$property = "property=\"food:sodiumEquivalentPer100g\" content=\"$sodium\"";
						}
						$values2 .= "<td class=\"nutriment_value${col_class}\" $property>" . $sodium . " " . $unit . "</td>";
					}				
					elsif ($nid eq 'nutrition-score-fr') {
						# We need to know the category in order to select the right thresholds for the nutrition grades
						# as it depends on whether it is food or drink
						
						# if it is a category stats, the category id is the id field
						if ((not defined $product_ref->{categories_tags})
							and (defined $product_ref->{id}) 
							and ($product_ref->{id} =~ /^en:/) 
								) {
							$product_ref->{categories} = $product_ref->{id};
							compute_field_tags($product_ref, "categories");
						}
						
						if (defined $product_ref->{categories_tags}) {
						
							if ($col eq "std") {
								$values2 .= "<td class=\"nutriment_value${col_class}\"></td>";
							}
							else {
								$values2 .= "<td class=\"nutriment_value${col_class}\">"
								. uc (compute_nutrition_grade($product_ref, $product_ref->{nutriments}{$nid . "_$col"}))
								. "</td>";
							}
						}
					}					
					elsif ($col eq $product_ref->{nutrition_data_per}) {
						# % DV ?
						if ((defined $product_ref->{nutriments}{$nid . "_value"}) and (defined $product_ref->{nutriments}{$nid . "_unit"}) and ($product_ref->{nutriments}{$nid . "_unit"} eq '% DV')) {
							$value_unit .= ' (' . $product_ref->{nutriments}{$nid . "_value"} . ' ' . $product_ref->{nutriments}{$nid . "_unit"} . ')';
						}
					}					
					
					if ($col eq '100g') {
						my $property = $nid;
						$property =~ s/-([a-z])/ucfirst($1)/eg;
						$property .= "Per100g";
						$rdfa = " property=\"food:$property\" content=\"" . $product_ref->{nutriments}{$nid . "_$col"} . "\"";
					}
				}
				
				$values .= "<td class=\"nutriment_value${col_class}\"$rdfa>$value_unit</td>";
			}
		}

		
		my $input = <<HTML
<tr id="nutriment_${nid}_tr" class="nutriment_$class">
$label
$values
</tr>
HTML
;

		if (($nid eq 'sodium') and ($values2 ne '')) {
			$input .= <<HTML
<tr id="nutriment_salt_equivalent_tr" class="nutriment_sub">
<td class="nutriment_label">
HTML
. lang("salt_equivalent") . <<HTML
</td>
$values2
</tr>			
HTML
;
		}
		
		if (($nid eq 'salt') and ($values2 ne '')) {
			$input .= <<HTML
<tr id="nutriment_sodium_tr" class="nutriment_sub">
<td class="nutriment_label">
HTML
. $Nutriments{sodium}{$lang} . <<HTML
</td>
$values2
</tr>			
HTML
;
		}		
		
		if (($nid eq 'nutrition-score-fr') and ($values2 ne '')) {
			$input .= <<HTML
<tr id="nutriment_nutriscore_tr" class="nutriment_sub">
<td class="nutriment_label">
HTML
. "Nutri-Score" . <<HTML
</td>
$values2
</tr>			
HTML
;
		}		
		
		
		#print STDERR "nutrition_table - nid: $nid - shown: $shown \n";

		if (not $shown) {
		}
		elsif ($nid eq 'carbon-footprint') {
		
			$html2 .= <<HTML
<tr id="ecological_footprint"><td style="padding-top:10px;font-weight:bold;">$Lang{ecological_data_table}{$lang}</td>$empty_cols</tr>
HTML
			. $input;
		
		}
		else  {
			$html .= $input;
		}
	
	}
	
	$html .= <<HTML
$html2
</tbody>	
</table>
HTML
;	
	
	return $html;

}



sub display_product_api($)
{
	my $request_ref = shift;

	my $code = normalize_code($request_ref->{code});
	
	# Check that the product exist, is published, is not deleted, and has not moved to a new url
	
	$log->info("displaying product api", { code => $code }) if $log->is_info();

	my %response = ();
	
	$response{code} = $code;
	
	my $product_ref = retrieve_product($code);
	
	if ((not defined $product_ref) or (not defined $product_ref->{code})) {
		$response{status} = 0;
		$response{status_verbose} = 'product not found';
		if ($request_ref->{jqm}) {
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
<input type="text" name="$field" id="$field" value="" placeholder="$value" />
HTML
;	
				}
					
				$html .= <<HTML
</div>
<div id="save_button">
<input type="submit" id="save" name="save" value="$Lang{save}{$lang}" />
</div>
<div id="saving" style="display:none">
<img src="loading2.gif" style="margin-right:10px" /> $Lang{saving}{$lang}
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
		
		add_images_urls_to_product($product_ref);
		
		$response{product} = $product_ref;
		
		# If the request specified a value for the fields parameter, return only the fields listed
		if (defined $request_ref->{fields}) {
			my $compact_product_ref = {};
			foreach my $field (split(/,/, $request_ref->{fields})) {
				if (defined $product_ref->{$field}) {
					$compact_product_ref->{$field} = $product_ref->{$field};
				}
			}
			$response{product} = $compact_product_ref;
		}		
		
		
		if ($request_ref->{jqm}) {
			# return a jquerymobile page for the product
			
			display_product_jqm($request_ref);
			$response{jqm} = $request_ref->{jqm_content};
			$response{jqm} =~ s/(href|src)=("\/)/$1="https:\/\/$cc.${server_domain}\//g;
			$response{title} = $request_ref->{title};
			
		}
	}
	
	$request_ref->{structured_response} = \%response;
	
	display_structured_response($request_ref);
}

sub display_product_history($$) {

	my $code = shift;
	my $product_ref = shift;

	my $html = '';
	if ($product_ref->{rev} > 0) {
	
		my $path = product_path($code);
		my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
		if (not defined $changes_ref) {
			$changes_ref = [];
		}
		
		$html .= "<h2>" . lang("history") . "</h2>\n<ul>\n";
		
		my $current_rev = $product_ref->{rev};
		
		foreach my $change_ref (reverse @{$changes_ref}) {
		
			my $date = display_date_tag($change_ref->{t});	
			my $user = "";
			if (defined $change_ref->{userid}) {
				$user = "<a href=\"" . canonicalize_tag_link("users", get_fileid($change_ref->{userid})) . "\">" . $change_ref->{userid} . "</a>";
			}
			
			my $comment = $change_ref->{comment};
			$comment = lang($comment) if $comment eq 'product_created';
			
			$comment =~ s/^Modification :\s+//;
			if ($comment eq 'Modification :') {
				$comment = '';
			}
			$comment =~ s/\new image \d+( -)?//;
			
			if ($comment ne '') {
				$comment = "- $comment";
			}
			
			my $change_rev = $change_ref->{rev};
			
			if (not defined $change_rev) {
				$change_rev = $current_rev;
			}
			$current_rev--;
			
			# Display diffs
			# [Image upload - add: 1, 2 - delete 2], [Image selection - add: front], [Nutriments... ]
			
			my $diffs = compute_changes_diff_text($change_ref);
			$html .= "<li>$date - $user $diffs $comment - <a href=\"" . product_url($product_ref) . "?rev=$change_rev\">" . lang("view") . "</a></li>\n";
		
		}
		
		$html .= "</ul>\n";
	}

	return $html;

}

sub add_images_urls_to_product($) {

	my $product_ref = shift;
	
	my $staticdom = format_subdomain('static');
	my $path = product_path($product_ref->{code});
	
	foreach my $imagetype ('front','ingredients','nutrition') {
	
		my $size = $display_size;
		
		my $display_lc = $lc;
		
		# first try the requested language
		my @display_ids = ($imagetype . "_" . $display_lc);
		
		# next try the main language of the product
		if ($product_ref->{lc} ne $display_lc) {
			push @display_ids, $imagetype . "_" . $product_ref->{lc};
		}
		
		# last try the field without a language (for old products without updated images)
		push @display_ids, $imagetype;
			
		foreach my $id (@display_ids) {
	
			if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
				and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {

				$product_ref->{"image_" . $imagetype . "_url"} = "$staticdom/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $display_size . '.jpg';
				$product_ref->{"image_" . $imagetype . "_small_url"} = "$staticdom/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $small_size . '.jpg';
				$product_ref->{"image_" . $imagetype . "_thumb_url"} = "$staticdom/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $thumb_size . '.jpg';
				
				if ($imagetype eq 'front') {
					$product_ref->{image_url} = $product_ref->{"image_" . $imagetype . "_url"};
					$product_ref->{image_small_url} = $product_ref->{"image_" . $imagetype . "_small_url"};
					$product_ref->{image_thumb_url} = $product_ref->{"image_" . $imagetype . "_thumb_url"};
				}
				
				last;
			}
		}
		
		if (defined $product_ref->{languages_codes}) {
			foreach my $key (keys %{$product_ref->{languages_codes}}) {
				my $id = $imagetype . '_' . $key;
				if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
					and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
					
					$product_ref->{selected_images}{$imagetype}{display}{$key} = "$staticdom/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $display_size . '.jpg';
					$product_ref->{selected_images}{$imagetype}{small}{$key} = "$staticdom/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $small_size . '.jpg';
					$product_ref->{selected_images}{$imagetype}{thumb}{$key} = "$staticdom/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $thumb_size . '.jpg';
				}
			}
		}
	}
}



sub display_structured_response($)
{
	# directly serve structured data from $request_ref->{structured_response}

	my $request_ref = shift;
	
	
	$log->debug("Displaying structured response", { json => $request_ref->{json}, jsonp => $request_ref->{jsonp}, xml => $request_ref->{xml}, jqm => $request_ref->{jqm}, rss => $request_ref->{rss} }) if $log->is_debug();
	if ($request_ref->{xml}) {
	
		# my $xs = XML::Simple->new(NoAttr => 1, NumericEscape => 2);
		my $xs = XML::Simple->new(NumericEscape => 2);
		
		# without NumericEscape => 2, the output should be UTF-8, but is in fact completely garbled
		# e.g. <categories>Frais,Produits laitiers,Desserts,Yaourts,Yaourts aux fruits,Yaourts sucrurl>http://static.openfoodfacts.net/images/products/317/657/216/8015/front.15.400.jpg</image_url>
	
	
		# https://github.com/openfoodfacts/openfoodfacts-server/issues/463
		# remove the languages field which has keys like "en:english"
		
		if (defined $request_ref->{structured_response}{product}) {
		delete $request_ref->{structured_response}{product}{languages};
		}
		
		if (defined $request_ref->{structured_response}{products}) {
			foreach my $product_ref (@{$request_ref->{structured_response}{products}}) {
				delete $product_ref->{languages};
			}
		}
		
	
		my $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
		. $xs->XMLout($request_ref->{structured_response}); 	# noattr -> force nested elements instead of attributes
        
		print header( -type => 'text/xml', -charset => 'utf-8', -access_control_allow_origin => '*' ) . $xml;

	}
	elsif ($request_ref->{rss}) {
		display_structured_response_opensearch_rss($request_ref);
	}
	else {
		my $data =  encode_json($request_ref->{structured_response});
		
		my $jsonp = undef;
		
		if (defined param('jsonp')) {
			$jsonp = param('jsonp');
		}
		elsif (defined param('callback')) {
			$jsonp = param('callback');
		}
		
		$jsonp =~ s/[^a-zA-Z0-9_]//g;
		
		if (defined $jsonp) {
			print header( -type => 'text/javascript', -charset => 'utf-8', -access_control_allow_origin => '*' ) . $jsonp . "(" . $data . ");" ;
		}
		else {
			print header( -type => 'application/json', -charset => 'utf-8', -access_control_allow_origin => '*' ) . $data;
		}
	}
	
	exit();
}

sub display_structured_response_opensearch_rss {
	my ($request_ref) = @_;
	
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
	my $dom = format_subdomain($subdomain);
	my $query_link = $xs->escape_value(encode_utf8($dom . $request_ref->{current_link_query} . "&rss=1"));
	my $description = $xs->escape_value(encode_utf8(lang("search_description_opensearch")));

	my $search_terms = $xs->escape_value(encode_utf8(decode utf8=>param('search_terms')));
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
     <atom:link rel="search" type="application/opensearchdescription+xml" href="$dom/cgi/opensearch.pl"/>
     <opensearch:Query role="request" searchTerms="${search_terms}" startPage="$page" />
XML
;

	if (defined $request_ref->{structured_response}{products}) {
		foreach my $product_ref (@{$request_ref->{structured_response}{products}}) {
			my $item_title = product_name_brand_quantity($product_ref);
			$item_title = $product_ref->{code} unless $item_title;
			my $item_description = $xs->escape_value(encode_utf8(sprintf(lang("product_description"), $item_title)));
			$item_title = $xs->escape_value(encode_utf8($item_title));
			my $item_link = $xs->escape_value(encode_utf8($dom . product_url($product_ref)));
			
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
	
	print header( -type => 'application/rss+xml', -charset => 'utf-8', -access_control_allow_origin => '*' ) . $xml;

}

sub display_recent_changes {

	my ($request_ref, $query_ref, $limit, $page) = @_;

	if ((defined $country) and ($country ne 'en:world')) {
		$query_ref->{countries_tags} = $country;
	}
	
	delete $query_ref->{lc};

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

	$log->debug("Executing MongoDB query", { query => $query_ref }) if $log->is_debug();
	my $cursor = $recent_changes_collection->query($query_ref)->sort($sort_ref)->limit($limit)->skip($skip);
	my $count = $cursor->count() + 0;
	$log->info("MongoDB query ok", { error => $@, result_count => $count }) if $log->is_info();

	if ($@) {
		$log->warn("MongoDB error - retrying once", { error => $@ }) if $log->is_warn();
		
		# opening new connection
		eval {
			$connection = MongoDB->connect($mongodb_host);
			$database = $connection->get_database($mongodb);
			$recent_changes_collection = $database->get_collection('recent_changes');
		};
		if ($@) {
			$log->error("MongoDB error - reconnecting failed", { error => $@ }) if $log->is_error();
			$count = -1;
		}
		else {		
			$log->info("MongoDB reconnect ok", { error => $@ }) if $log->is_info();
			$log->debug("Executing MongoDB query", { query => $query_ref }) if $log->is_debug();
			$cursor = $recent_changes_collection->query($query_ref)->sort($sort_ref)->limit($limit)->skip($skip);
			$count = $cursor->count() + 0;
			$log->info("MongoDB query ok", { error => $@, result_count => $count }) if $log->is_info();
		}
	}
	
	my $html .= "<ul>\n";
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

		delete $change_hash->{ip} unless $admin; # security: Do not expose IP addresses to non-admin or anonymous users.

		push @{$request_ref->{structured_response}{changes}}, $change_hash;

		my $date = display_date_tag($change_ref->{t});	
		my $user = "";
		if (defined $change_ref->{userid}) {
			$user = "<a href=\"" . canonicalize_tag_link("users", get_fileid($change_ref->{userid})) . "\">" . $change_ref->{userid} . "</a>";
		}
		
		my $comment = $change_ref->{comment};
		$comment = lang($comment) if $comment eq 'product_created';
		
		$comment =~ s/^Modification :\s+//;
		if ($comment eq 'Modification :') {
			$comment = '';
		}
		$comment =~ s/\new image \d+( -)?//;
		
		if ($comment ne '') {
			$comment = "- $comment";
		}
		
		my $change_rev = $change_ref->{rev};

		# Display diffs
		# [Image upload - add: 1, 2 - delete 2], [Image selection - add: front], [Nutriments... ]
		
		my $diffs = compute_changes_diff_text($change_ref);
		$change_hash->{diffs_text} = $diffs;
		
		my $product_url = product_url($change_ref->{code});
		$html .= "<li><a href=\"" . $product_url . "\">" . $change_ref->{code} . "</a> $date - $user $diffs $comment - <a href=\"" . $product_url . "?rev=$change_rev\">" . lang("view") . "</a></li>\n";

	}

	$html .= "</ul>";
	${$request_ref->{content_ref}} .= $html;
	$request_ref->{title} = lang("recent_changes");
	display_new($request_ref);

}

1;
