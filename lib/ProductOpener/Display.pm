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
		%index_tag_types_set

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

		&display_no_index_page_and_exit
		&display_robots_txt_and_exit
		&display_page
		&display_text
		&display_stats
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
		&display_taxonomy_api
		&map_of_products

		&display_ingredients_analysis_details
		&display_ingredients_analysis
		&display_possible_improvement_description
		&display_properties

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

		$admin

		$scripts
		$initjs
		$styles
		$header

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



		$show_ecoscore
		$attributes_options_ref
		$knowledge_panels_options_ref

		&display_nutriscore_calculation_details
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;


=begin GLOBAL VARS MOVED TO OTHER MODULES

	%file_timestamps => $app->{file_timestamp}{$filename}


=cut




use ProductOpener::HTTP qw(write_cors_headers);
use ProductOpener::Store qw(get_string_id_for_lang retrieve);
use ProductOpener::Config qw(:all);
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Tags qw(:all);
use ProductOpener::Users qw(:all);
use ProductOpener::Index qw(%texts);
use ProductOpener::Lang qw(:all);
use ProductOpener::Images qw(display_image display_image_thumb);
use ProductOpener::Food qw(:all);
use ProductOpener::Ingredients qw(flatten_sub_ingredients);
use ProductOpener::Products qw(:all);
use ProductOpener::Missions qw(:all);
use ProductOpener::MissionsConfig qw(:all);
use ProductOpener::URL qw(format_subdomain);
use ProductOpener::Data
	qw(execute_aggregate_tags_query execute_count_tags_query execute_query get_products_collection get_recent_changes_collection);
use ProductOpener::Text
	qw(escape_char escape_single_quote_and_newlines get_decimal_formatter get_percent_formatter remove_tags_and_quote);
use ProductOpener::Nutriscore qw(%points_thresholds compute_nutriscore_grade);
use ProductOpener::Ecoscore qw(localize_ecoscore);
use ProductOpener::Attributes qw(compute_attributes list_attributes);
use ProductOpener::KnowledgePanels qw(create_knowledge_panels initialize_knowledge_panels_options);
use ProductOpener::KnowledgePanelsTags qw(create_tag_knowledge_panels);
use ProductOpener::Orgs qw(is_user_in_org_group retrieve_org);
use ProductOpener::Web
	qw(display_data_quality_issues_and_improvement_opportunities display_field display_knowledge_panel);
use ProductOpener::Recipes qw(add_product_recipe_to_set analyze_recipes compute_product_recipe);
use ProductOpener::PackagerCodes
	qw($ec_code_regexp %geocode_addresses %packager_codes init_geocode_addresses init_packager_codes);
use ProductOpener::Export qw(export_csv);
use ProductOpener::API qw(add_error customize_response_for_product process_api_request);
use ProductOpener::Units qw/g_to_unit/;
use ProductOpener::Cache qw/$max_memcached_object_size $memd generate_cache_key/;
use ProductOpener::Permissions qw/has_permission/;

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
use Data::DeepAccess qw(deep_get deep_set);
use Log::Log4perl;
use LWP::UserAgent;

use Log::Any '$log', default_adapter => 'Stderr';

# special logger to make it easy to measure memcached hit and miss rates
our $mongodb_log = Log::Log4perl->get_logger('mongodb');
$mongodb_log->info("start") if $mongodb_log->is_info();



my $bodyabout;



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

sub init_request ($request_ref = {}) { # compatibility layer for old clients
	use ProductOpener::Request;
	return ProductOpener::Request->new($request_ref, $log);
}


sub single_param ($param_name) {
	warn "PO::Display::single_param() .. deprecated, use \$self->req->param(..)";

	use ProductOpener::Request;
	return 	ProductOpener::Request::single_param($param_name);
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
		foreach my $l ('en', $request_ref->{lc}) {
			my $tag_value_singular = $tag_type_singular{$type}{$l};
			my $tag_value_plural = $tag_type_plural{$type}{$l};
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

	if ($textid =~ /open-food-facts-mobile-app|application-mobile-open-food-facts/) {
		# we want the mobile app landing page to be included in a <div class="row">
		# so we display it under the `banner` page format, which is the page format
		# used on product pages, with a colored banner on top
		$request_ref->{page_format} = "banner";
	}

	my $text_lc = $request_ref->{lc};

	# if a page does not exist in the local language, use the English version
	# e.g. Index, Discover, Contribute pages.
	if ((not defined $texts{$textid}{$text_lc}) and (defined $texts{$textid}{en})) {
		$text_lc = 'en';
	}

	my $file = "$BASE_DIRS{LANG}/$text_lc/texts/" . $texts{$textid}{$text_lc};

	display_text_content($request_ref, $textid, $text_lc, $file);
	return;
}

sub display_stats ($request_ref) {
	my $textid = $request_ref->{text};
	my $stats_dir = "$BASE_DIRS{PUBLIC_DATA}/products_stats/" . $request_ref->{lc};
	my $file = "$stats_dir/products_stats_$cc.html";
	display_text_content($request_ref, $textid, $request_ref->{lc}, $file);
	return;
}

sub display_text_content ($request_ref, $textid, $text_lc, $file) {

	$request_ref->{page_type} = "text";

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
		{cc => $cc, lc => $lc, textid => $textid, text_lc => $text_lc, file => $file})
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
		my $text_dir = "$BASE_DIRS{LANG}/$lc/texts/";
		if ($fileid =~ /products_stats_/) {
			# special location as this is generated
			$text_dir = "$BASE_DIRS{PUBLIC_DATA}/products_stats/$lc/";
		}
		my $file = "$text_dir/$fileid";
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

	open(my $IN, "<:encoding(UTF-8)", "$BASE_DIRS{PUBLIC_DATA}/missions/" . $request_ref->{lc} . "/$missionid.html");
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

sub generate_query_cache_key ($name, $context_ref, $request_ref) {
	# Generates a cache key taking the obsolete parameter into account
	if (scalar request_param($request_ref, "obsolete")) {
		$name .= '_obsolete';
	}
	return generate_cache_key($name, $context_ref);
}

sub query_list_of_tags ($request_ref, $query_ref) {

	add_params_to_query($request_ref, $query_ref);

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

	# by default sort tags by descending product count
	my $default_sort_by = "count";

	# except for scores where we sort alphabetically (A to E, and 1 to 4)
	if (($groupby_tagtype =~ /^nutriscore|nutrition_grades|ecoscore|nova_groups/)) {
		$default_sort_by = "tag";
	}

	# allow sorting by tagname
	my $sort_by = request_param($request_ref, "sort_by") // $default_sort_by;
	my $sort_ref;

	if ($sort_by eq "tag") {
		$sort_ref = {"_id" => 1};
	}
	else {
		$sort_ref = {"count" => -1};
		$sort_by = "count";
	}

	# groupby_tagtype
	my $group_field_name = $groupby_tagtype . "_tags";
	my @unwind_req = ({"\$unwind" => ("\$" . $group_field_name)},);
	# specific case
	if ($groupby_tagtype eq 'users') {
		$group_field_name = "creator";
		@unwind_req = ();
	}

	my $aggregate_count_parameters = [
		{"\$match" => $query_ref},
		@unwind_req,
		{"\$group" => {"_id" => ("\$" . $group_field_name)}},
		{"\$count" => ($group_field_name)}
	];

	my $aggregate_parameters = [
		{"\$match" => $query_ref},
		@unwind_req,
		{"\$group" => {"_id" => ("\$" . $group_field_name), "count" => {"\$sum" => 1}}},
		{"\$sort" => $sort_ref},
		{"\$skip" => $skip},
		{"\$limit" => $limit}
	];

	#get cache results for aggregate query
	my $key = generate_query_cache_key("aggregate", $aggregate_parameters, $request_ref);
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
		my $key_count = generate_query_cache_key("aggregate_count", $aggregate_count_parameters, $request_ref);
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
				$request_ref->{structured_response}{count} = $count_results->{$group_field_name};

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

	return ($results, $sort_by);
}

sub display_list_of_tags ($request_ref, $query_ref) {

	my ($results, $sort_by) = query_list_of_tags($request_ref, $query_ref);
	my $request_lc = $request_ref->{lc};

	# Column that will be sorted by using JS
	my $sort_order = '[[ 1, "desc" ]]';
	if ($sort_by eq "tag") {
		$sort_order = '[[ 0, "asc" ]]';
	}

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

		my $tagtype_p = lang_in_other_lc($request_lc, $tagtype . "_p");

		$request_ref->{title} = sprintf(lang_in_other_lc($request_lc, "list_of_x"), $tagtype_p);

		my $text_for_tagtype_file
			= "$BASE_DIRS{LANG}/$request_lc/texts/" . get_string_id_for_lang("no_language", $tagtype_p) . ".list.html";

		if (-e $text_for_tagtype_file) {
			open(my $IN, q{<}, $text_for_tagtype_file);
			$html .= join("\n", (<$IN>));
			close $IN;
		}

		foreach (my $line = 1; (defined $Lang{$tagtype . "_facet_description_" . $line}); $line++) {
			$html .= "<p>" . lang_in_other_lc($request_lc, $tagtype . "_facet_description_" . $line) . "</p>";
		}

		$html
			.= "<p>"
			. $request_ref->{structured_response}{count} . " "
			. $tagtype_p
			. separator_before_colon($lc) . ":</p>";

		my $th_nutriments = '';

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
			. ucfirst(lang_in_other_lc($request_lc, $tagtype . "_s"))
			. "</th><th>"
			. ucfirst(lang_in_other_lc($request_lc, "products")) . "</th>"
			. $th_nutriments
			. "</tr></thead>\n<tbody>\n";

		# To get the root link, we remove the facet name from the current link
		my $main_link = $request_ref->{current_link};
		$main_link =~ s/\/[^\/]+$//;    # Remove the last / and everything after ir
		my $nofollow = '';
		if (defined $request_ref->{tagid}) {
			$nofollow = ' rel="nofollow"';
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

		# display_percent parameter: display the percentage of products for each tag
		# This is useful only for tags that have unique values like Nutri-Score and Eco-Score
		my $display_percent = single_param("display_percent");
		foreach my $tagcount_ref (@tags) {
			my $count = $tagcount_ref->{count};
			$stats{all_tags}++;
			$stats{all_tags_products} += $count;
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

			my $tag_link = $main_link . $link;

G			$html .= "<tr><td>";

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
					= "<img src=\"/images/attributes/dist/nutriscore-$tagid.svg\" alt=\"$Lang{nutrition_grade_fr_alt}{$lc} "
					. $grade
					. "\" title=\"$Lang{nutrition_grade_fr_alt}{$lc} "
					. $grade
					. "\" style=\"max-height:80px;\"> "
					. $grade;
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
					= "<img src=\"/images/attributes/dist/ecoscore-$tagid.svg\" alt=\"$Lang{ecoscore}{$lc} "
					. $grade
					. "\" title=\"$Lang{ecoscore}{$lc} "
					. $grade
					. "\" style=\"max-height:80px;\"> "
					. $grade;
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

			# Display the percent of products for each tag
			my $percent = '';
			if (($display_percent) and ($stats{all_tags})) {
				$percent = ' (' . sprintf("%2.2f", $products / $stats{all_tags_products} * 100) . '%)';
			}

			$css_class =~ s/^\s+|\s+$//g;
			$info .= ' class="' . $css_class . '"';
			$html .= "<a href=\"$tag_link\"$info$nofollow>" . $display . "</a>";
			$html
				.= "</td>\n<td style=\"text-align:right\"><a href=\"$tag_link\"$info$nofollow>${products}${percent}</a></td>"
				. $td_nutriments
				. $extra_td
				. "</tr>\n";

			my $tagentry = {
				id => $tagid,
				name => $display,
				url => $formatted_subdomain . $tag_link,
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
						$countries_map_links->{$region} = $tag_link;
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
		$log->info("PAGINATION: BEFORE\n");
		if (    $request_ref->{structured_response}{count} >= $tags_page_size
			and not(defined single_param("stats"))
			and not(defined single_param("filter")))
		{
			$log->info("PAGINATION: CALLING\n");
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

		my $tagstable_search = lang_in_other_lc($request_lc, "tagstable_search");
		my $tagstable_filtered = lang_in_other_lc($request_lc, "tagstable_filtered");

		my $extra_column_searchable = "";
		if (defined $taxonomy_fields{$tagtype}) {
			$extra_column_searchable .= ', {"searchable": false}';
		}

		$initjs .= <<JS
oTable = \$('#tagstable').DataTable({
	language: {
		search: "$tagstable_search",
		info: "_TOTAL_ $tagtype_p",
		infoFiltered: " - $tagstable_filtered",
	},
	paging: false,
	order: $sort_order,
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

	my ($results, $sort_by) = query_list_of_tags($request_ref, $query_ref);
	my $request_lc = $request_ref->{lc};
	my $tagtype = $request_ref->{groupby_tagtype};
	my $tagtype_p = lang_in_other_lc($request_lc, $tagtype . "_p");

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

		$request_ref->{structured_response}{count} = ($#tags + 1);

		$request_ref->{title} = sprintf(lang("list_of_x"), $tagtype_p);

		# Display the message in English until we have translated the translate_taxonomy_to message in many languages,
		# to avoid mixing local words with English words

		$template_data_ref_tags_translate->{tagtype_s} = ucfirst(lang_in_other_lc($request_lc, $tagtype . "_s"));
		$template_data_ref_tags_translate->{translate_taxonomy} = sprintf(
			lang_in_other_lc("en", "translate_taxonomy_to"),
			lang_in_other_lc("en", $tagtype . "_p"),
			$Languages{$lc}{en}
		);

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
			. $tagtype_p . " ("
			. lang("translated")
			. " : $translated, "
			. lang("to_be_translated")
			. " : $to_be_translated)";

		$template_data_ref_tags_translate->{tagcounts} = \@tagcounts;
		$template_data_ref_tags_translate->{tagtype} = $tagtype;
		$template_data_ref_tags_translate->{counts} = $counts;

		$log->debug("going through all tags - done", {}) if $log->is_debug();

		my $tagstable_search = lang_in_other_lc($request_lc, "tagstable_search");
		my $tagstable_filtered = lang_in_other_lc($request_lc, "tagstable_filtered");

		$initjs .= <<JS
oTable = \$('#tagstable').DataTable({
	language: {
		search: "$tagstable_search",
		info: "_TOTAL_ $tagtype_p",
		infoFiltered: " - $tagstable_filtered",
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
		$points_ref = retrieve("$BASE_DIRS{PRIVATE_DATA}/index/users_points.sto");
		$ambassadors_points_ref = retrieve("$BASE_DIRS{PRIVATE_DATA}/index/ambassadors_users_points.sto");
	}
	else {
		$points_ref = retrieve("$BASE_DIRS{PRIVATE_DATA}/index/countries_points.sto");
		$ambassadors_points_ref = retrieve("$BASE_DIRS{PRIVATE_DATA}/index/ambassadors_countries_points.sto");
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

	my $tagtype_p = lang_in_other_lc($lc, $ranktype . "_p");
	my $tagstable_search = lang_in_other_lc($lc, "tagstable_search");
	my $tagstable_filtered = lang_in_other_lc($lc, "tagstable_filtered");

	$initjs .= <<JS
${tagtype}Table = \$('#${tagtype}table').DataTable({
	language: {
		search: "$tagstable_search",
		info: "_TOTAL_ $tagtype_p",
		infoFiltered: " - $tagstable_filtered"
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
	my $new_tagid;
	my $new_tagid_path;
	my $canon_tagid = undef;

	local $log->context->{tagtype} = $tagtype;
	local $log->context->{tagid} = $tagid;

	$log->info("displaying points") if $log->is_info();

	if (defined $tagid) {
		if (defined $taxonomy_fields{$tagtype}) {
			$canon_tagid = canonicalize_taxonomy_tag($lc, $tagtype, $tagid);
			$display_tag = display_taxonomy_tag($lc, $tagtype, $canon_tagid);
			$title = $display_tag;
			$new_tagid = get_taxonomyid($lc, $display_tag);
			$log->debug("displaying points for a taxonomy tag",
				{canon_tagid => $canon_tagid, new_tagid => $new_tagid, title => $title})
				if $log->is_debug();
			if ($new_tagid !~ /^(\w\w):/) {
				$new_tagid = $lc . ':' . $new_tagid;
			}
			$new_tagid_path = canonicalize_taxonomy_tag_link($lc, $tagtype, $new_tagid);
			$request_ref->{current_link} = $new_tagid_path;
			$request_ref->{world_current_link} = canonicalize_taxonomy_tag_link($lc, $tagtype, $canon_tagid);
		}
		else {
			$display_tag = canonicalize_tag2($tagtype, $tagid);
			$new_tagid = get_string_id_for_lang($lc, $display_tag);
			$display_tag = display_tag_name($tagtype, $display_tag);
			if ($tagtype eq 'emb_codes') {
				$canon_tagid = $new_tagid;
				$canon_tagid =~ s/-($ec_code_regexp)$/-ec/ie;
			}
			$title = $display_tag;
			$new_tagid_path = canonicalize_tag_link($tagtype, $new_tagid);
			$request_ref->{current_link} = $new_tagid_path;
			my $current_lc = $lc;
			$lc = 'en';
			$request_ref->{world_current_link} = canonicalize_tag_link($tagtype, $new_tagid);
			$lc = $current_lc;
			$log->debug("displaying points for a normal tag",
				{canon_tagid => $canon_tagid, new_tagid => $new_tagid, title => $title})
				if $log->is_debug();
		}
	}

	$request_ref->{current_link} .= "/points";

	if ((defined $tagid) and ($new_tagid ne $tagid)) {
		$request_ref->{redirect} = $formatted_subdomain . $request_ref->{current_link};
		$log->info(
			"new_tagid does not equal the original tagid, redirecting",
			{new_tagid => $new_tagid, redirect => $request_ref->{redirect}}
		) if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	my $description = '';

	if ($tagtype eq 'users') {
		my $user_ref = retrieve_user($tagid);
		if (defined $user_ref) {
			if ((defined $user_ref->{name}) and ($user_ref->{name} ne '')) {
				$title = $user_ref->{name} . " ($tagid)";
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

=head2 canonicalize_request_tags_and_redirect_to_canonical_url ($request_ref)

This function goes through the tags filters from the request and canonicalizes them.
If the requested tags are not canonical, we will redirect to the canonical URL.

=cut

sub canonicalize_request_tags_and_redirect_to_canonical_url ($request_ref) {

	$request_ref->{current_link} = '';
	$request_ref->{world_current_link} = '';

	my $header_meta_noindex = 0;    # Will be set if one of the tags is related to a user
	my $redirect_to_canonical_url = 0;    # Will be set if one of the tags is not canonical

	# Go through the tags filters from the request

	foreach my $tag_ref (@{$request_ref->{tags}}) {

		# the tag name requested in url (in $lc language)
		my $tagid = $tag_ref->{tagid};
		my $tagtype = $tag_ref->{tagtype};
		# in URLs, tags can be prefixed with a - (e.g /label/-organic)
		# to indicate we want to match products without that tag
		my $tag_prefix = $tag_ref->{tag_prefix};
		# The tag name displayed in the page (in $lc language)
		my $display_tag;
		# canonical tag corresponding to tagid
		my $canon_tagid;
		# normalized tagid, in the $lc language
		my $new_tagid;
		my $new_tagid_path;

		if (defined $taxonomy_fields{$tagtype}) {
			$canon_tagid = canonicalize_taxonomy_tag($lc, $tagtype, $tagid);
			$display_tag = display_taxonomy_tag($lc, $tagtype, $canon_tagid);
			$new_tagid = get_taxonomyid($lc, $display_tag);
			$log->info("displaying taxonomy tag", {canon_tagid => $canon_tagid, new_tagid => $new_tagid})
				if $log->is_info();
			if ($new_tagid !~ /^(\w\w):/) {
				$new_tagid = $lc . ':' . $new_tagid;
			}
			$new_tagid_path = canonicalize_taxonomy_tag_link($lc, $tagtype, $new_tagid, $tag_prefix);
			$request_ref->{current_link} .= $new_tagid_path;
			$request_ref->{world_current_link}
				.= canonicalize_taxonomy_tag_link($lc, $tagtype, $canon_tagid, $tag_prefix);
		}
		else {
			$display_tag = canonicalize_tag2($tagtype, $tagid);
			# Use "no_language" normalization for tags types without a taxonomy
			$new_tagid = get_string_id_for_lang("no_language", $display_tag);
			$display_tag = display_tag_name($tagtype, $display_tag);
			if ($tagtype eq 'emb_codes') {
				$canon_tagid = $new_tagid;
				$canon_tagid =~ s/-($ec_code_regexp)$/-ec/ie;
			}
			$new_tagid_path = canonicalize_tag_link($tagtype, $new_tagid, $tag_prefix);
			$request_ref->{current_link} .= $new_tagid_path;
			my $current_lc = $lc;
			$lc = 'en';
			$request_ref->{world_current_link} .= canonicalize_tag_link($tagtype, $new_tagid, $tag_prefix);
			$lc = $current_lc;
			$log->info("displaying normal tag", {canon_tagid => $canon_tagid, new_tagid => $new_tagid})
				if $log->is_info();
		}

		$tag_ref->{canon_tagid} = $canon_tagid;
		$tag_ref->{new_tagid} = $new_tagid;
		$tag_ref->{new_tagid_path} = $new_tagid_path;
		$tag_ref->{display_tag} = $display_tag;
		$tag_ref->{tagtype_path} = '/' . $tag_type_plural{$tagtype}{$lc};
		$tag_ref->{tagtype_name} = lang_in_other_lc($lc, $tagtype . '_s');

		# We will redirect if the tag is not canonical
		if ($new_tagid ne $tagid) {
			$redirect_to_canonical_url = 1;
		}
	}

	if (defined $request_ref->{groupby_tagtype}) {
		$request_ref->{current_link} .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
		$request_ref->{world_current_link} .= "/" . $tag_type_plural{$request_ref->{groupby_tagtype}}{$lc};
	}

	# If the query contained tags in non-canonical form, redirect to the form with the canonical tags
	# The redirect is temporary (302), as the canonicalization could change if the corresponding taxonomies change
	if ($redirect_to_canonical_url) {
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

	# Ask search engines to not index the page if it is related to a user
	if ($header_meta_noindex) {
		$header .= '<meta name="robots" content="noindex">' . "\n";
	}

	return;
}

=head2 generate_title_from_request_tags ($tags_ref)

Generate a title from the tags in the request.

=head3 Parameters

=head4 $tags_ref Array of tag filter objects

=head3 Return value

Title string.

=cut

sub generate_title_from_request_tags ($tags_ref) {

	my $title = join(" / ", map {($_->{tag_prefix} // '') . $_->{display_tag}} @{$tags_ref});

	return $title;
}

=head2 generate_description_from_display_tag_options ($tagtype, $tagid, $display_tag, $canon_tagid)

Generate a description for some tag types, like additives, if there is a template set in the Config.pm file.

This feature was coded before the introduction of knowledge panels.
It is in maintenance mode, and should be reimplemented as facets knowledge panels
(server side, or with client side facets knowledge panels)

=cut

sub generate_description_from_display_tag_options ($tagtype, $tagid, $display_tag, $canon_tagid) {

	my $description = "";

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
						foreach my $groupid (split(/,/, $properties{$tagtype}{$canon_tagid}{$exposure_property})) {
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

					$table .= '<td style="background-color:black;color:white;">' . lang($group . "_age") . "</td>";
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
								. lang("additives_efsa_evaluation_exposure_" . $percentile . "_greater_than_" . $dose)
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

	return $description;
}

=head2 display_tag ( $request_ref )

This function is called to display either:

1. Products that have a specific tag:  /category/cakes
  or that don't have a specific tag /category/-cakes
  or that have 2 specific tags /category/cake/brand/oreo
2. List of tags of a given type:  /labels
  possibly for products that have a specific tag: /category/cakes/labels
  or more specific tags:  /category/cakes/label/organic/additives

When displaying products for a tag, the function generates tag type specific HTML
that is displayed at the top of the page:
- tag parents and children
- maps for tag types that have a location (e.g. packaging codes)
- special properties for some tag types (e.g. additives)

The function then calls search_and_display_products() to display the paginated list of products.

When displaying a list of tags, the function calls display_list_of_tags().

=cut

sub display_tag ($request_ref) {

	local $log->context->{tags} = $request_ref->{tags};

	my $request_lc = $request_ref->{lc};

	init_tags_texts() unless %tags_texts;

	canonicalize_request_tags_and_redirect_to_canonical_url($request_ref);

	my $title = generate_title_from_request_tags($request_ref->{tags});

	# Refactoring in progress
	# TODO: some of the following variables may be removed, and instead we could use the $request_ref->{tags} array
	my $tagtype = deep_get($request_ref, qw(tags 0 tagtype));
	my $tagid = deep_get($request_ref, qw(tags 0 tagid));
	my $display_tag = deep_get($request_ref, qw(tags 0 display_tag));
	my $new_tagid = deep_get($request_ref, qw(tags 0 new_tagid));
	my $new_tagid_path = deep_get($request_ref, qw(tags 0 new_tagid_path));
	my $canon_tagid = deep_get($request_ref, qw(tags 0 canon_tagid));

	my $tagtype2 = deep_get($request_ref, qw(tags 1 tagtype));
	my $tagid2 = deep_get($request_ref, qw(tags 1 tagid));
	my $display_tag2 = deep_get($request_ref, qw(tags 1 display_tag));
	my $new_tagid2 = deep_get($request_ref, qw(tags 1 new_tagid));
	my $new_tagid2path = deep_get($request_ref, qw(tags 1 new_tagid_path));
	my $canon_tagid2 = deep_get($request_ref, qw(tags 1 canon_tagid));

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

			$description = generate_description_from_display_tag_options($tagtype, $tagid, $display_tag, $canon_tagid);
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
				$display_tag = $app_user;
			}
			else {

				# User

				$user_or_org_ref = retrieve_user($tagid);

				if (not defined $user_or_org_ref) {
					display_error_and_exit(lang("error_unknown_user"), 404);
				}
			}

			if (defined $user_or_org_ref) {

				if ($user_or_org_ref->{name} ne '') {
					$title = $user_or_org_ref->{name};
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
							text => sprintf(lang('contributors_products'), $user_or_org_ref->{name}),
							url => canonicalize_tag_link("users", get_string_id_for_lang("no_language", $tagid)),
						},
						{
							text => sprintf(lang('editors_products'), $user_or_org_ref->{name}),
							url => canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $tagid)),
						},
						{
							text => sprintf(lang('photographers_products'), $user_or_org_ref->{name}),
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

		# Pass template data to generate navigation links
		# These are variables that ae used to inject data
		# Used in tag.tt.html

		$tag_template_data_ref->{tags} = $request_ref->{tags};

		if (not defined $request_ref->{groupby_tagtype}) {

			if (not defined $tagid2) {

				# We are on the main page of the tag (not a sub-page with another tag)
				# so we display more information related to the tag

				my $tag_logo_html;

				if (defined $taxonomy_fields{$tagtype}) {
					$tag_logo_html = display_tags_hierarchy_taxonomy($lc, $tagtype, [$canon_tagid]);
				}
				else {
					$tag_logo_html = display_tags_hierarchy($tagtype, [$canon_tagid]);
				}

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

	# Add parameters corresponding to the tag filters so that they can be added to the query by add_params_to_query()

	foreach my $tag_ref (@{$request_ref->{tags}}) {
		if ($tag_ref->{tagtype} eq 'users') {
			deep_set($request_ref, "body_json", "creator", $tag_ref->{tagid});
		}
		else {
			my $field_name = $tag_ref->{tagtype} . "_tags";
			my $current_value = deep_get($request_ref, "body_json", $field_name);
			my $new_value = ($tag_ref->{tag_prefix} // '') . ($tag_ref->{canon_tagid} // $tag_ref->{tagid});
			if ($current_value) {
				$new_value = $current_value . ',' . $new_value;
			}
			deep_set($request_ref, "body_json", $field_name, $new_value);
		}
	}

	my $query_ref = {};
	my $sort_by;

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

=head2 list_all_request_params ( $request_ref, $query_ref )

Return an array of names of all request parameters.

=cut

sub list_all_request_params ($request_ref) {

	# CGI params (query string and POST body)
	my @params = multi_param();

	# Add params from the JSON body if any
	if (defined $request_ref->{body_json}) {
		push @params, keys %{$request_ref->{body_json}};
	}

	return @params;
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

	foreach my $field (list_all_request_params($request_ref)) {
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
<script src="$static_subdomain/js/product-preferences.js"></script>
<script src="$static_subdomain/js/product-search.js"></script>
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
		my $key_count = generate_query_cache_key("search_products_count", $query_ref, $request_ref);
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
	$log->info("PAGINATION: READY\n");
	my $canon_rel_url = $request_ref->{canon_rel_url} // "UNDEF";
	$log->info("PAGINATION: current_link: $current_link - canon_rel_url: $canon_rel_url\n");

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

	print STDERR "zzz lc: $lc - request_ref->lc: $request_ref->{lc}\n";

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
						# check if groupby_tag is used
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
		$title = escape_single_quote_and_newlines(lang("number_of_additives"));
	}
	elsif ($field eq "forest_footprint") {
		$allow_decimals = "allowDecimals:true,\n";
		$title = escape_single_quote_and_newlines(lang($field));
	}
	elsif ($field =~ /_n$/) {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote_and_newlines(lang($field . "_s"));
	}
	elsif ($field eq "product_quantity") {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote_and_newlines(lang("quantity"));
		$unit = ' (g)';
		$unit2 = 'g';
	}
	elsif ($field eq "nova_group") {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote_and_newlines(lang("nova_groups_s"));
	}
	elsif ($field eq "ecoscore_score") {
		$allow_decimals = "allowDecimals:false,\n";
		$title = escape_single_quote_and_newlines(lang("ecoscore_score"));
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

		$graph_ref->{graph_title} = escape_single_quote_and_newlines($graph_ref->{graph_title});

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
		my %emb_code_data = %{$packager_codes{$emb_code}};
		if (exists $emb_code_data{lat}) {
			# some lat/lng have , for floating point numbers
			$lat = $emb_code_data{lat};
			$lng = $emb_code_data{lng};
			$lat =~ s/,/\./g;
			$lng =~ s/,/\./g;
		}
		elsif (exists $emb_code_data{fsa_rating_business_geo_lat}) {
			$lat = $emb_code_data{fsa_rating_business_geo_lat};
			$lng = $emb_code_data{fsa_rating_business_geo_lng};
		}
		elsif ($emb_code_data{cc} eq 'uk') {
			#my $address = 'uk' . '.' . $emb_code_data{local_authority};
			my $address = 'uk' . '.' . ($emb_code_data{canon_local_authority} // '');
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

	my $request_lc = $request_ref->{lc};

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
	$template_data_ref->{language} = $request_lc;
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
	$template_data_ref->{css_timestamp}
		= $file_timestamps{'css/dist/app-' . lang_in_other_lc($request_lc, 'text_direction') . '.css'};
	$template_data_ref->{header} = $header;
	$template_data_ref->{page_type} = $request_ref->{page_type} // "other";
	$template_data_ref->{page_format} = $request_ref->{page_format} // "normal";

	if ($request_ref->{schema_org_itemtype}) {
		$template_data_ref->{schema_org_itemtype} = $request_ref->{schema_org_itemtype};
	}

	my $site_name = lang_in_other_lc($request_lc, "site_name");
	if ($server_options{producers_platform}) {
		$site_name = lang_in_other_lc($request_lc, "producers_platform");
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

	my $status_code = $request_ref->{status_code} // 200;

	my $http_headers_ref = {
		'-status' => $status_code,
		'-expires' => '-1d',
		'-charset' => 'UTF-8',
	};

	# init_user() may set or unset the session cookie
	if (defined $request_ref->{cookie}) {
		$http_headers_ref->{'-cookie'} = [$request_ref->{cookie}];
	}

	# Horrible hack to remove everything but the graph from the page
	# need to build a temporary report (2023/12) (Stéphane)
	# TODO: remove when not needed
	if (request_param($request_ref, 'graph_only')) {
		$html
			=~ s/(<body[^>]*>).*?(<script src="http(s?):\/\/static.openfoodfacts.(localhost|org)\/js\/dist\/modernizr.js")/$1\n\n<div id="container" style="height: 400px"><\/div>\n\n$2/s;
	}

	print header(%$http_headers_ref);

	my $r = Apache2::RequestUtil->request();
	$r->rflush;
	# Setting the status makes mod_perl append a default error to the body
	# Send 200 instead.
	$r->status(200);

	binmode(STDOUT, ":encoding(UTF-8)");

	$log->debug("display done", {lc => $lc, mongodb => $mongodb, data_root => $data_root})
		if $log->is_debug();

	print $html;
	return;
}

sub display_image_box ($product_ref, $id, $minheight_ref) {

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

			if (-e "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$filename.full.json") {
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

	my $request_lc = $request_ref->{lc};
	my $rev = single_param("rev");
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision") if $log->is_info();
		$product_ref = retrieve_product_rev($product_id, $rev);
	}
	else {
		$product_ref = retrieve_product($product_id);
	}

	if (not is_valid_code($code)) {

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
$Lang{app_please_take_pictures}{$request_lc}
<button onclick="captureImage();" data-icon="off-camera">$Lang{app_take_a_picture}{$request_lc}</button>
<div id="upload_image_result"></div>
<p>$Lang{app_take_a_picture_note}{$request_lc}</p>
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
					my $value = $Lang{$field}{$request_lc};

					$html .= <<HTML
<label for="$field">$Lang{$field}{$request_lc}</label>
<input type="text" name="$field" id="$field" value="" placeholder="$value">
HTML
						;
				}

				$html .= <<HTML
</div>
<div id="save_button">
<input type="submit" id="save" name="save" value="$Lang{save}{$request_lc}">
</div>
<div id="saving" style="display:none">
<img src="loading2.gif" style="margin-right:10px"> $Lang{saving}{$request_lc}
</div>
<div id="saved" style="display:none">
$Lang{saved}{$request_lc}
</div>
<div id="not_saved" style="display:none">
$Lang{not_saved}{$request_lc}
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
			my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
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
	my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
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

sub display_product_history ($request_ref, $code, $product_ref) {

	if ($product_ref->{rev} <= 0) {
		return;
	}

	my $path = product_path($product_ref);
	my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
	if (not defined $changes_ref) {
		$changes_ref = [];
	}

	my $current_rev = $product_ref->{rev};
	my @revisions = ();

	foreach my $change_ref (reverse @{$changes_ref}) {

		my $userid = get_change_userid_or_uuid($change_ref);
		my $uuid = $change_ref->{app_uuid};
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
			uuid => $uuid,
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
		revisions => \@revisions,
		product => $product_ref,
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

		my $status_code = $request_ref->{status_code} // "200";
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

		my $status_code = $request_ref->{status_code} // 200;

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
			my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - '
				. lang_in_other_lc($target_lc, $imagetype . '_alt');
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
