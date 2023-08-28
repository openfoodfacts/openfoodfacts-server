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
		&analyze_request
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Store qw/:all/;

use Encode;
use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Log::Any qw($log);

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

sub analyze_request ($request_ref) {

	# TODO: this function uses the global $lc
	# we should replace it with $request_ref->{lc}
	# Ideally, we should remove completely the global $lc
	# and then in this function we can have
	# my $lc = $resquest_ref->{lc}

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

	# Decode the escaped characters in the query string
	$request_ref->{query_string} = decode("utf8", URI::Escape::XS::decodeURIComponent($request_ref->{query_string}));

	$log->debug("analyzing query_string, step 3 - components UTF8 decoded",
		{query_string => $request_ref->{query_string}})
		if $log->is_debug();

	$request_ref->{page} = 1;

	# some sites like FB can add query parameters, remove all of them
	# make sure that all query parameters of interest have already been consumed above

	$request_ref->{query_string} =~ s/(\&|\?).*//;

	$log->debug("analyzing query_string, step 4 - removed all query parameters",
		{query_string => $request_ref->{query_string}})
		if $log->is_debug();

	# if the query request json or xml, either through the json=1 parameter or a .json extension
	# set the $request_ref->{api} field
	if ((defined single_param('json')) or (defined single_param('jsonp')) or (defined single_param('xml'))) {
		$request_ref->{api} = 'v0';
	}

	# Split query string by "/" to know where it points
	my @components = split(/\//, $request_ref->{query_string});

	# Root, ex: https://world.openfoodfacts.org/
	if ($#components < 0) {
		$request_ref->{text} = 'index';
		$request_ref->{current_link} = '';
	}
	# Root + page number, ex: https://world.openfoodfacts.org/2
	elsif (($#components == 0) and ($components[-1] =~ /^\d+$/)) {
		$request_ref->{page} = pop @components;
		$request_ref->{current_link} = '';
		$request_ref->{text} = 'index';
	}

	# Api access
	# /api/v0/product/[code]
	# /api/v0/search
	elsif ($components[0] eq 'api') {

		# Set version, method, action and code
		$request_ref->{api} = $components[1];
		if ($request_ref->{api} =~ /v(.*)/) {
			$request_ref->{api_version} = $1;
		}
		else {
			$request_ref->{api_version} = 0;
		}

		$request_ref->{api_action} = $components[2];

		# Also support "products" in order not to break apps that were using it
		if ($request_ref->{api_action} eq 'products') {
			$request_ref->{api_action} = 'product';
		}

		# If the api_action is different than "search", check if it is the local path for "product"
		# so that urls like https://fr.openfoodfacts.org/api/v3/produit/4324232423 work (produit instead of product)
		# this is so that we can quickly add /api/v3/ to get the API

		if (    ($request_ref->{api_action} ne 'search')
			and ($request_ref->{api_action} eq $tag_type_singular{products}{$lc}))
		{
			$request_ref->{api_action} = 'product';
		}

		# some API actions have an associated object
		if ($request_ref->{api_action} eq "product") {    # /api/v3/product/[code]
			param("code", $components[3]);
			$request_ref->{code} = $components[3];
		}
		elsif ($request_ref->{api_action} eq "tag") {    # /api/v3/[tagtype]/[tagid]
			param("tagtype", $components[3]);
			$request_ref->{tagtype} = $components[3];
			param("tagid", $components[4]);
			$request_ref->{tagid} = $components[4];
		}

		$request_ref->{api_method} = $request_ref->{method};

		# If return format is not xml or jqm or jsonp, default to json
		if (    (not defined single_param("xml"))
			and (not defined single_param("jqm"))
			and (not defined single_param("jsonp")))
		{
			param("json", 1);
		}

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
	}

	# /search search endpoint, parameters will be parsed by CGI.pm param()
	elsif ($components[0] eq "search") {
		$request_ref->{search} = 1;
	}

	# /taxonomy API endpoint
	# e.g. /api/v2/taxonomy?type=categories&tags=en:fruits,en:vegetables&fields=name,description,parents,children,vegan:en,inherited:vegetarian:en&lc=en,fr&include_children=1
	elsif ($components[0] eq "taxonomy") {
		$request_ref->{taxonomy} = 1;
	}

	# Folksonomy engine properties endpoint
	elsif (($components[0] eq "properties") or ($components[0] eq "property")) {
		$request_ref->{properties} = 1;
	}

	# /products endpoint (e.g. /products/8024884500403+3263855093192 )
	# assign the codes to the code parameter
	elsif ($components[0] eq "products") {
		$request_ref->{search} = 1;
		param("code", $components[1]);
	}

	# Renamed text?
	elsif ((defined $options{redirect_texts}) and (defined $options{redirect_texts}{$lang . "/" . $components[0]})) {
		$request_ref->{redirect} = $formatted_subdomain . "/" . $options{redirect_texts}{$lang . "/" . $components[0]};
		$log->info("renamed text, redirecting", {textid => $components[0], redirect => $request_ref->{redirect}})
			if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	# First check if the request is for a text
	elsif ( (defined $texts{$components[0]})
		and ((defined $texts{$components[0]}{$lang}) or (defined $texts{$components[0]}{en}))
		and (not defined $components[1]))
	{
		$request_ref->{text} = $components[0];
		$request_ref->{canon_rel_url} = "/" . $components[0];
	}

	# Product specified as en:product?
	elsif (_component_is_singular_tag_in_specific_lc($components[0], 'products')) {
		# check the product code looks like a number
		if ($components[1] =~ /^\d/) {
			$request_ref->{redirect}
				= $formatted_subdomain . '/' . $tag_type_singular{products}{$lc} . '/' . $components[1];
		}
		else {
			$request_ref->{status_code} = 404;
			$request_ref->{error_message} = lang("error_invalid_address");
		}
	}

	# Product?
	# try language from $lc, and English, so that /product/ always work
	elsif (($components[0] eq $tag_type_singular{products}{$lc})
		or ($components[0] eq $tag_type_singular{products}{en}))
	{

		# Check if the product code is a number, else show 404
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
			$request_ref->{status_code} = 404;
			$request_ref->{error_message} = lang("error_invalid_address");
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

	# https://github.com/openfoodfacts/openfoodfacts-server/issues/4140
	elsif ((scalar(@components) == 2) and ($components[0] eq '.well-known') and ($components[1] eq 'change-password')) {
		$request_ref->{redirect} = $formatted_subdomain . '/cgi/change_password.pl';
		$log->info('well-known password change page - redirecting', {redirect => $request_ref->{redirect}})
			if $log->is_info();
		redirect_to_url($request_ref, 307, $request_ref->{redirect});
	}

	elsif ($#components == -1) {
		# Main site
	}

	# Known tag type?
	else {

		$request_ref->{canon_rel_url} = '';
		my $canon_rel_url_suffix = '';

		#check if last field is number
		if (($#components >= 1) and ($components[-1] =~ /^\d+$/)) {
			#if first field or third field is tags (plural) then last field is page number
			if (   defined $tag_type_from_plural{$lc}{$components[0]}
				or defined $tag_type_from_plural{"en"}{$components[0]}
				or defined $tag_type_from_plural{$lc}{$components[2]}
				or defined $tag_type_from_plural{"en"}{$components[2]})
			{
				$request_ref->{page} = pop @components;
				$log->debug("get page number", {$request_ref->{page}}) if $log->is_debug();
			}
		}
		# list of tags? (plural of tagtype must be the last field)

		$log->debug("checking last component",
			{last_component => $components[-1], is_plural => $tag_type_from_plural{$lc}{$components[-1]}})
			if $log->is_debug();

		# list of (categories) tags with stats for a nutriment
		if (    ($#components == 1)
			and (defined $tag_type_from_plural{$lc}{$components[0]})
			and ($tag_type_from_plural{$lc}{$components[0]} eq "categories")
			and (defined $nutriments_labels{$lc}{$components[1]}))
		{

			$request_ref->{groupby_tagtype} = $tag_type_from_plural{$lc}{$components[0]};
			$request_ref->{stats_nid} = $nutriments_labels{$lc}{$components[1]};
			$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
			$canon_rel_url_suffix .= "/" . $components[1];
			pop @components;
			pop @components;
			$log->debug("request looks like a list of tags - categories with nutrients",
				{groupby => $request_ref->{groupby_tagtype}, stats_nid => $request_ref->{stats_nid}})
				if $log->is_debug();
		}

		if (defined $tag_type_from_plural{$lc}{$components[-1]}) {

			$request_ref->{groupby_tagtype} = $tag_type_from_plural{$lc}{pop @components};
			$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
			$log->debug("request looks like a list of tags", {groupby => $request_ref->{groupby_tagtype}, lc => $lc})
				if $log->is_debug();
		}
		# also try English tagtype
		elsif (defined $tag_type_from_plural{"en"}{$components[-1]}) {

			$request_ref->{groupby_tagtype} = $tag_type_from_plural{"en"}{pop @components};
			# use $lc for canon url
			$canon_rel_url_suffix .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
			$log->debug("request looks like a list of tags", {groupby => $request_ref->{groupby_tagtype}, lc => "en"})
				if $log->is_debug();
		}

		if (
			($#components >= 0)
			and (  (defined $tag_type_from_singular{$lc}{$components[0]})
				or (defined $tag_type_from_singular{"en"}{$components[0]}))
			)
		{

			$log->debug("request looks like a singular tag", {lc => $lc, tagid => $components[0]}) if $log->is_debug();

			# If the first component is a valid singular tag type, use it as the tag type
			if (defined $tag_type_from_singular{$lc}{$components[0]}) {
				$request_ref->{tagtype} = $tag_type_from_singular{$lc}{shift @components};
			}
			# Otherwise, use "en" as the default language and try again
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
				# If the tag type is a valid taxonomy field, try to canonicalize the tag ID
				if (defined $taxonomy_fields{$tagtype}) {
					my $parsed_tag = canonicalize_taxonomy_tag_linkeddata($tagtype, $request_ref->{tag});
					if (not $parsed_tag) {
						$parsed_tag = canonicalize_taxonomy_tag_weblink($tagtype, $request_ref->{tag});
					}

					if ($parsed_tag) {
						$request_ref->{tagid} = $parsed_tag;
					}
					else {
						if ($request_ref->{tag} !~ /^(\w\w):/) {
							$request_ref->{tag} = $lc . ":" . $request_ref->{tag};
						}

						$request_ref->{tagid} = get_taxonomyid($lc, $request_ref->{tag});
					}
				}
				else {
					# Use "no_language" normalization
					$request_ref->{tagid} = get_string_id_for_lang("no_language", $request_ref->{tag});
				}
			}

			$request_ref->{canon_rel_url}
				.= "/" . $tag_type_singular{$tagtype}{$lc} . "/" . $request_ref->{tag_prefix} . $request_ref->{tagid};

			# 2nd tag?

			if (
				($#components >= 0)
				and (  (defined $tag_type_from_singular{$lc}{$components[0]})
					or (defined $tag_type_from_singular{"en"}{$components[0]}))
				)
			{

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
						my $parsed_tag2 = canonicalize_taxonomy_tag_linkeddata($tagtype, $request_ref->{tag2});
						if (not $parsed_tag2) {
							$parsed_tag2 = canonicalize_taxonomy_tag_weblink($tagtype, $request_ref->{tag2});
						}

						if ($parsed_tag2) {
							$request_ref->{tagid2} = $parsed_tag2;
						}
						else {
							if ($request_ref->{tag2} !~ /^(\w\w):/) {
								$request_ref->{tag2} = $lc . ":" . $request_ref->{tag2};
							}

							$request_ref->{tagid2} = get_taxonomyid($lc, $request_ref->{tag2});
						}
					}
					else {
						# Use "no_language" normalization
						$request_ref->{tagid2} = get_string_id_for_lang("no_language", $request_ref->{tag2});
					}
				}

				$request_ref->{canon_rel_url}
					.= "/"
					. $tag_type_singular{$tagtype}{$lc} . "/"
					. $request_ref->{tag2_prefix}
					. $request_ref->{tagid2};
			}

			if ((defined $components[0]) and ($components[0] eq 'points')) {
				$request_ref->{points} = 1;
				$request_ref->{canon_rel_url} .= "/points";
			}

		}
		elsif ((defined $components[0]) and ($components[0] eq 'points')) {
			$request_ref->{points} = 1;
			$request_ref->{canon_rel_url} .= "/points";
		}
		elsif (not defined $request_ref->{groupby_tagtype}) {
			$log->warn("invalid address, confused by number of components left", {left_components => $#components})
				if $log->is_warn();
			$request_ref->{status_code} = 404;
			$request_ref->{error_message} = lang("error_invalid_address");
		}

		# We have a component left
		if ($#components >= 0) {
			# The last component can be a page number
			if ($components[-1] =~ /^\d+$/) {
				$request_ref->{page} = pop @components;
			}
			else {
				# We have a component left, but we don't know what it is
				$request_ref->{status_code} = 404;
				$request_ref->{error_message} = lang("error_invalid_address");
				return;
			}
		}

		$request_ref->{canon_rel_url} .= $canon_rel_url_suffix;
	}

	# Index page on producers platform
	if (    (defined $request_ref->{text})
		and ($request_ref->{text} eq "index")
		and (defined $server_options{private_products})
		and ($server_options{private_products}))
	{
		$request_ref->{text} = 'index-pro';
	}

	# Return noindex empty HTML page for web crawlers that crawl specific facet pages
	if (is_no_index_page($request_ref)) {
		# $request_ref->{no_index} is set to 0 by default in init_request()
		$request_ref->{no_index} = 1;
	}

	$log->debug("request analyzed", {lc => $lc, lang => $lang, request_ref => $request_ref}) if $log->is_debug();

	return 1;
}

=head2 is_no_index_page ($request_ref)

Return 1 if the page should not be indexed by web crawlers based on analyzed request, 0 otherwise.

=cut

sub is_no_index_page ($request_ref) {
	return scalar(
		($request_ref->{is_crawl_bot} == 1) and (
			# if is_denied_crawl_bot == 1, we don't accept any request from this bot
			($request_ref->{is_denied_crawl_bot} == 1)
			# All list of tags pages should be non-indexable
			or (defined $request_ref->{groupby_tagtype})
			or (
				(
					defined $request_ref->{tagtype} and (
						# Only allow indexation of a selected number of facets
						# Ingredients were left out because of the number of possible ingredients (1.2M)
						(not exists($ProductOpener::Display::index_tag_types_set{$request_ref->{tagtype}}))
						# Don't index facet pages with page number > 1 (we want only 1 index page per facet value)
						or ($request_ref->{page} >= 2)
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

	my $match = $tag_type_singular{$tag}{$component_lc};
	if ((defined $match) and ($match eq $component)) {
		return 1;
	}
	else {
		return 0;
	}
}

1;
