#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::Text qw/:all/;
use ProductOpener::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

# Passing values to the template
my $template_data_ref = {};

my $html;

# Automated requests by Google Spreadsheet can overload the server
# https://github.com/openfoodfacts/openfoodfacts-server/issues/4357
# User-Agent: Mozilla/5.0 (compatible; GoogleDocs; apps-spreadsheets; +http://docs.google.com)

if (user_agent() =~ /apps-spreadsheets/) {

	display_error_and_exit(
		"Automated queries using Google Spreadsheet overload the Open Food Facts server. We cannot support them. You can contact us at contact\@openfoodfacts.org to tell us about your use case, so that we can see if there is another way to support it.",
		200
	);
}

my $request_ref = ProductOpener::Display::init_request();
$request_ref->{search} = 1;

my $action = single_param('action') || 'display';

if ((defined single_param('search_terms')) and (not defined single_param('action'))) {
	$action = 'process';
}

# /cgi/search.pl is "v1" of the search API.
# The api_version parameter enables clients to request the product data to be returned in the format of a different version
# For instance api_version=3 enables the new format of the packagings field
foreach my $parameter ('fields', 'json', 'jsonp', 'jqm', 'jqm_loadmore', 'xml', 'rss', 'api_version') {

	if (defined single_param($parameter)) {
		$request_ref->{$parameter} = single_param($parameter);
	}
}

# if the query request json or xml, either through the json=1 parameter or a .json extension
# set the $request_ref->{api} field to indicate that it is an API query
if ((defined single_param('json')) or (defined single_param('jsonp')) or (defined single_param('xml'))) {
	if (not defined $request_ref->{api_version}) {
		$request_ref->{api_version} = 0;
		$request_ref->{api} = 'v0';
	}
	else {
		$request_ref->{api} = 'v' . $request_ref->{api_version};
	}
}

my @search_fields
	= qw(brands categories packaging labels origins manufacturing_places emb_codes purchase_places stores countries
	ingredients additives allergens traces nutrition_grades nova_groups ecoscore languages creator editors states);

$admin and push @search_fields, "lang";

my %search_tags_fields = (
	packaging => 1,
	brands => 1,
	categories => 1,
	labels => 1,
	origins => 1,
	manufacturing_places => 1,
	emb_codes => 1,
	allergens => 1,
	traces => 1,
	nutrition_grades => 1,
	nova_groups => 1,
	eco_score => 1,
	purchase_places => 1,
	stores => 1,
	countries => 1,
	additives => 1,
	states => 1,
	editors => 1,
	languages => 1
);

my @search_ingredient_classes = (
	'additives', 'ingredients_from_palm_oil',
	'ingredients_that_may_be_from_palm_oil', 'ingredients_from_or_that_may_be_from_palm_oil'
);

# Read all the parameters, watch for XSS

my $tags_n = 2;
my $nutriments_n = 2;

my $search_terms
	= remove_tags_and_quote(decode utf8 => single_param('search_terms2'));    #advanced search takes precedence
if ((not defined $search_terms) or ($search_terms eq '')) {
	$search_terms = remove_tags_and_quote(decode utf8 => single_param('search_terms'));
}

# check if the search term looks like a barcode

if (    (not defined single_param('json'))
	and (not defined single_param('jsonp'))
	and (not defined single_param('jqm'))
	and (not defined single_param('jqm_loadmore'))
	and (not defined single_param('xml'))
	and (not defined single_param('rss'))
	and ($search_terms =~ /^(\d{4,24})$/))
{

	my $code = normalize_code($search_terms);

	my $product_id = product_id_for_owner($Owner_id, $code);

	my $product_ref = product_exists($product_id);    # returns 0 if not

	if ($product_ref) {
		$log->info("product code exists, redirecting to product page", {code => $code});
		my $location = product_url($product_ref);

		my $r = shift;
		$r->headers_out->set(Location => $location);
		$r->status(301);
		return 301;

	}
}

my @search_tags = ();
my @search_nutriments = ();
my %search_ingredient_classes = ();
my %search_ingredient_classes_checked = ();

for (my $i = 0; defined single_param("tagtype_$i"); $i++) {

	my $tagtype = remove_tags_and_quote(decode utf8 => single_param("tagtype_$i"));
	my $tag_contains = remove_tags_and_quote(decode utf8 => single_param("tag_contains_$i"));
	my $tag = remove_tags_and_quote(decode utf8 => single_param("tag_$i"));

	push @search_tags, [$tagtype, $tag_contains, $tag,];
}

foreach my $tagtype (@search_ingredient_classes) {

	$search_ingredient_classes{$tagtype} = single_param($tagtype);
	not defined $search_ingredient_classes{$tagtype} and $search_ingredient_classes{$tagtype} = 'indifferent';
	$search_ingredient_classes_checked{$tagtype} = {$search_ingredient_classes{$tagtype} => 'checked="checked"'};
}

for (my $i = 0; defined single_param("nutriment_$i"); $i++) {

	my $nutriment = remove_tags_and_quote(decode utf8 => single_param("nutriment_$i"));
	my $nutriment_compare = remove_tags_and_quote(decode utf8 => single_param("nutriment_compare_$i"));
	my $nutriment_value = remove_tags_and_quote(decode utf8 => single_param("nutriment_value_$i"));

	if ($lc eq 'fr') {
		$nutriment_value =~ s/,/\./g;
	}
	push @search_nutriments, [$nutriment, $nutriment_compare, $nutriment_value,];
}

my $sort_by = remove_tags_and_quote(decode utf8 => single_param("sort_by"));
if (    ($sort_by ne 'created_t')
	and ($sort_by ne 'last_modified_t')
	and ($sort_by ne 'last_modified_t_complete_first')
	and ($sort_by ne 'scans_n')
	and ($sort_by ne 'unique_scans_n')
	and ($sort_by ne 'product_name')
	and ($sort_by ne 'completeness')
	and ($sort_by ne 'popularity_key'))
{
	$sort_by = 'unique_scans_n';
}

my $limit = 0 + (single_param('page_size') || $page_size);
if (($limit < 2) or ($limit > 1000)) {
	$limit = $page_size;
}

my $graph_ref = {graph_title => remove_tags_and_quote(decode utf8 => single_param("graph_title"))};
my $map_title = remove_tags_and_quote(decode utf8 => single_param("map_title"));

foreach my $axis ('x', 'y') {
	$graph_ref->{"axis_$axis"} = remove_tags_and_quote(decode utf8 => single_param("axis_$axis"));
}

foreach my $series (@search_series, "nutrition_grades") {

	$graph_ref->{"series_$series"} = remove_tags_and_quote(decode utf8 => single_param("series_$series"));
	if ($graph_ref->{"series_$series"} ne 'on') {
		delete $graph_ref->{"series_$series"};
	}
}

if ($action eq 'display') {

	$template_data_ref->{search_terms} = $search_terms;

	my $active_list = 'active';
	my $active_map = '';
	my $active_graph = '';

	if (single_param("generate_map")) {
		$active_list = '';
		$active_map = 'active';
	}
	elsif (single_param("graph")) {
		$active_list = '';
		$active_graph = 'active';
	}

	$template_data_ref->{active_list} = $active_list;
	$template_data_ref->{active_graph} = $active_graph;
	$template_data_ref->{active_map} = $active_map;

	my %search_fields_labels = ();
	my @tags_fields_options;

	push(
		@tags_fields_options,
		{
			value => "search",
			label => lang("search_tag"),
		}
	);

	foreach my $field (@search_fields) {
		my $label;

		if ((not defined $tags_fields{$field}) and (lang($field) ne '')) {
			$label = lc(lang($field));
		}
		else {
			if ($field eq 'creator') {
				$label = lang("users_p");
			}
			else {
				$label = lang($field . "_p");
			}
		}
		push(
			@tags_fields_options,
			{
				value => $field,
				label => $label,
			}
		);
	}

	$template_data_ref->{tags_fields_options} = \@tags_fields_options;

	$template_data_ref->{contain_options} = [
		{value => "contains", label => lang("search_contains")},
		{value => "does_not_contain", label => lang("search_does_not_contain")},
	];

	for (my $i = 0; ($i < $tags_n) or defined single_param("tagtype_$i"); $i++) {

		push @{$template_data_ref->{criteria}},
			{
			id => $i,
			selected_tags_field_value => $search_tags[$i][0],
			selected_contain_value => $search_tags[$i][1],
			input_value => $search_tags[$i][2],
			};
	}

	foreach my $tagtype (@search_ingredient_classes) {

		not defined $search_ingredient_classes{$tagtype} and $search_ingredient_classes{$tagtype} = 'indifferent';

		push @{$template_data_ref->{ingredients}},
			{
			tagtype => $tagtype,
			search_ingredient_classes_checked_without => $search_ingredient_classes_checked{$tagtype}{without},
			search_ingredient_classes_checked_with => $search_ingredient_classes_checked{$tagtype}{with},
			search_ingredient_classes_checked_indifferent => $search_ingredient_classes_checked{$tagtype}{indifferent},
			};
	}

	# Compute possible fields values
	my @axis_values = @{$nutriments_lists{$nutriment_table}};
	my %axis_labels = ();
	foreach my $nid (@{$nutriments_lists{$nutriment_table}}, "fruits-vegetables-nuts-estimate-from-ingredients") {
		$axis_labels{$nid} = display_taxonomy_tag($lc, "nutrients", "zz:$nid");
		$log->debug("nutriments", {nid => $nid, value => $axis_labels{$nid}}) if $log->is_debug();
	}

	my @other_search_fields = (
		"additives_n", "ingredients_n", "known_ingredients_n", "unknown_ingredients_n",
		"fruits-vegetables-nuts-estimate-from-ingredients",
		"forest_footprint", "product_quantity", "nova_group", 'ecoscore_score',
	);

	# Add the fields related to packaging
	foreach my $material ("all", "en:plastic", "en:glass", "en:metal", "en:paper-or-cardboard", "en:unknown") {
		foreach my $subfield ("weight", "weight_100g", "weight_percent") {
			push @other_search_fields, "packagings_materials.$material.$subfield";
		}
	}

	$axis_labels{search_nutriment} = lang("search_nutriment");
	$axis_labels{products_n} = lang("number_of_products");

	foreach my $field (@other_search_fields) {
		my ($title, $unit, $unit2, $allow_decimals) = get_search_field_title_and_details($field);
		push @axis_values, $field;
		$axis_labels{$field} = $title;
	}

	my @sorted_axis_values = ("", sort({lc($axis_labels{$a}) cmp lc($axis_labels{$b})} @axis_values));

	my @fields_options = ();

	foreach my $field (@sorted_axis_values) {
		push @fields_options,
			{
			value => $field,
			label => $axis_labels{$field},
			};
	}

	$template_data_ref->{fields_options} = \@fields_options;

	$template_data_ref->{compare_options} = [
		{
			'value' => "lt",
			'label' => '<',
		},
		{
			'value' => "lte",
			'label' => "\N{U+2264}",
		},
		{
			'value' => "gt",
			'label' => '>',
		},
		{
			'value' => "gte",
			'label' => "\N{U+2265}",
		},
		{
			'value' => "eq",
			'label' => '=',
		},
	];

	for (my $i = 0; ($i < $nutriments_n) or (defined single_param("nutriment_$i")); $i++) {

		push @{$template_data_ref->{nutriments}},
			{
			id => $i,
			selected_field_value => $search_nutriments[$i][0],
			selected_compare_value => $search_nutriments[$i][1],
			input_value => $search_nutriments[$i][2],
			};
	}

	# Different types to display results

	$template_data_ref->{sort_options} = [
		{
			'value' => "unique_scans_n",
			'label' => lang("sort_popularity"),
		},
		{
			'value' => "product_name",
			'label' => lang("sort_product_name"),
		},
		{
			'value' => "created_t",
			'label' => lang("sort_created_t"),
		},
		{
			'value' => "last_modified_t",
			'label' => lang("sort_modified_t"),
		},
		{
			'value' => "completeness",
			'label' => lang("sort_completeness"),
		},
	];

	push @{$template_data_ref->{selected_sort_by_value}}, $sort_by;

	my @size_array = (20, 50, 100, 250, 500, 1000);
	push @{$template_data_ref->{size_options}}, @size_array;

	$template_data_ref->{axes} = [];
	foreach my $axis ('x', 'y') {
		push @{$template_data_ref->{axes}},
			{
			id => $axis,
			selected_field_value => $graph_ref->{"axis_" . $axis},
			};
	}

	foreach my $series (@search_series, "nutrition_grades") {

		next if $series eq 'default';
		my $checked = '';
		if (($graph_ref->{"series_$series"} // '') eq 'on') {
			$checked = 'checked="checked"';
		}

		push @{$template_data_ref->{search_series}},
			{
			series => $series,
			checked => $checked,
			};

	}

	$styles .= <<CSS
.select2-container--default .select2-results > .select2-results__options {
    max-height: 400px
}
CSS
		;

	$scripts .= <<HTML
<script type="text/javascript" src="/js/dist/search.js"></script>
HTML
		;

	$initjs .= <<JS
var select2_options = {
		placeholder: "$Lang{select_a_field}{$lc}",
		allowClear: true
};

\$(".select2_field").select2(select2_options);


\$('#result_accordion').on('toggled', function (event, accordion) {
	\$(".select2_field").select2(select2_options);
});

JS
		;

	process_template('web/pages/search_form/search_form.tt.html', $template_data_ref, \$html) or $html = '';
	$html .= "<p>" . $tt->error() . "</p>";

	${$request_ref->{content_ref}} .= $html;

	display_page($request_ref);

}

elsif ($action eq 'process') {

	# Display the search results or construct CSV file for download

	# analyze parameters and construct query

	my $current_link = "/cgi/search.pl?action=process";

	my $query_ref = {};

	my $page = 0 + (single_param('page') || 1);
	if (($page < 1) or ($page > 1000)) {
		$page = 1;
	}

	# Search terms

	if ((defined $search_terms) and ($search_terms ne '')) {

		# does it look like a packaging code
		if (
			($search_terms !~ /,/)
			and (  ($search_terms =~ /^(\w\w)(\s|-|\.)?(\d(\s|-|\.)?){5}(\s|-|\.|\d)*C(\s|-|\.)?E/i)
				or ($search_terms =~ /^(emb|e)(\s|-|\.)?(\d(\s|-|\.)?){5}/i))
			)
		{
			$query_ref->{"emb_codes_tags"}
				= get_string_id_for_lang("no_language", normalize_packager_codes($search_terms));
		}
		else {

			my %terms = ();

			foreach my $term (split(/,|'|’|\s/, $search_terms)) {
				if (length(get_string_id_for_lang($lc, $term)) >= 2) {
					$terms{normalize_search_terms(get_string_id_for_lang($lc, $term))} = 1;
				}
			}
			if (scalar keys %terms > 0) {
				$query_ref->{_keywords} = {'$all' => [keys %terms]};
				$current_link .= "\&search_terms=" . URI::Escape::XS::encodeURIComponent($search_terms);
			}
		}
	}

	# Tags criteria

	my $and;

	for (my $i = 0; (defined $search_tags[$i]); $i++) {

		my ($tagtype, $contains, $tag) = @{$search_tags[$i]};

		if (($tagtype ne 'search_tag') and ($tag ne '')) {

			my $tagid;
			if (defined $taxonomy_fields{$tagtype}) {
				$tagid = get_taxonomyid($lc, canonicalize_taxonomy_tag($lc, $tagtype, $tag));
				$log->debug("taxonomy", {tag => $tag, tagid => $tagid}) if $log->is_debug();
			}
			else {
				$tagid = get_string_id_for_lang("no_language", canonicalize_tag2($tagtype, $tag));
			}

			if ($tagtype eq 'additives') {
				$tagid =~ s/-.*//;
			}

			if ($tagid ne '') {

				my $suffix = "";

				if (defined $tags_fields{$tagtype}) {
					$suffix = "_tags";
				}

				# 2 or more criteria on the same field?
				my $remove = 0;
				if (defined $query_ref->{$tagtype . $suffix}) {
					$remove = 1;
					if (not defined $and) {
						$and = [];
					}
					push @$and, {$tagtype . $suffix => $query_ref->{$tagtype . $suffix}};
				}

				if ($contains eq 'contains') {
					$query_ref->{$tagtype . $suffix} = $tagid;
				}
				else {
					$query_ref->{$tagtype . $suffix} = {'$ne' => $tagid};
				}

				if ($remove) {
					push @$and, {$tagtype . $suffix => $query_ref->{$tagtype . $suffix}};
					delete $query_ref->{$tagtype . $suffix};
					$query_ref->{"\$and"} = $and;
				}

				$current_link .= "\&tagtype_$i=$tagtype\&tag_contains_$i=$contains\&tag_$i="
					. URI::Escape::XS::encodeURIComponent($tag);

				# TODO: 2 or 3 criteria on the same field
				# db.foo.find( { $and: [ { a: 1 }, { a: { $gt: 5 } } ] } ) ?
			}
		}
	}

	# Ingredient classes

	foreach my $tagtype (@search_ingredient_classes) {

		if ($search_ingredient_classes{$tagtype} eq 'with') {
			$query_ref->{$tagtype . "_n"}{'$gte'} = 1;
			$current_link .= "\&$tagtype=with";
		}
		elsif ($search_ingredient_classes{$tagtype} eq 'without') {
			$query_ref->{$tagtype . "_n"}{'$lt'} = 1;
			$current_link .= "\&$tagtype=without";
		}
	}

	# Nutriments

	for (my $i = 0; (defined $search_nutriments[$i]); $i++) {

		my ($nutriment, $compare, $value, $unit) = @{$search_nutriments[$i]};

		if (($nutriment ne 'search_nutriment') and ($value ne '')) {

			my $field;

			if (   ($nutriment eq "ingredients_n")
				or ($nutriment eq "additives_n")
				or ($nutriment eq "known_ingredients_n")
				or ($nutriment eq "unknown_ingredients_n")
				or ($nutriment eq "forest_footprint"))
			{
				$field = $nutriment;
			}
			else {
				$field = "nutriments.${nutriment}_100g";
			}

			if ($compare eq 'eq') {
				$query_ref->{$field} = $value + 0.0;    # + 0.0 to force scalar to be treated as a number
			}
			elsif ($compare =~ /^(lt|lte|gt|gte)$/) {
				if (defined $query_ref->{$field}) {
					$query_ref->{$field}{'$' . $compare} = $value + 0.0;
				}
				else {
					$query_ref->{$field} = {'$' . $compare => $value + 0.0};
				}
			}
			$current_link .= "\&nutriment_$i=$nutriment\&nutriment_compare_$i=$compare\&nutriment_value_$i="
				. URI::Escape::XS::encodeURIComponent($value);

			# TODO support range queries: < and > on the same nutriment
			# my $doc32 = $collection->find({'x' => { '$gte' => 2, '$lt' => 4 }});
		}
	}

	my @fields = keys %tag_type_singular;

	foreach my $field (@fields) {

		next if defined $search_ingredient_classes{$field};

		if ((defined single_param($field)) and (single_param($field) ne '')) {

			$query_ref->{$field} = decode utf8 => single_param($field);
			$current_link .= "\&$field=" . URI::Escape::XS::encodeURIComponent(decode utf8 => single_param($field));
		}
	}

	if (defined $sort_by) {
		$current_link .= "&sort_by=$sort_by";
	}

	$current_link .= "\&page_size=$limit";

	# Graphs

	foreach my $axis ('x', 'y') {
		if ((defined single_param("axis_$axis")) and (single_param("axis_$axis") ne '')) {
			$current_link
				.= "\&axis_$axis=" . URI::Escape::XS::encodeURIComponent(decode utf8 => single_param("axis_$axis"));
		}
	}

	if ((defined single_param('graph_title')) and (single_param('graph_title') ne '')) {
		$current_link
			.= "\&graph_title=" . URI::Escape::XS::encodeURIComponent(decode utf8 => single_param("graph_title"));
	}

	if ((defined single_param('map_title')) and (single_param('map_title') ne '')) {
		$current_link .= "\&map_title=" . URI::Escape::XS::encodeURIComponent(decode utf8 => single_param("map_title"));
	}

	foreach my $series (@search_series, "nutrition_grades") {

		next if $series eq 'default';
		if ($graph_ref->{"series_$series"}) {
			$current_link .= "\&series_$series=on";
		}
	}

	$request_ref->{current_link} = $current_link;

	my $html = '';

	#$query_ref->{lc} = $lc;

	$log->debug("query", {query => $query_ref}) if $log->is_debug();

	my $share = lang('share');

	my $map = single_param("generate_map") || '';
	my $graph = single_param("graph") || '';
	my $download = single_param("download") || '';

	open(my $OUT, ">>:encoding(UTF-8)", "$BASE_DIRS{LOGS}/search_log_debug");
	print $OUT remote_addr() . "\t" . time() . "\t" . decode utf8 => single_param('search_terms') . " - map: $map
	 - graph: $graph - download: $download - page: $page\n";
	close($OUT);

	# Graph, map, export or search

	if (single_param("generate_map")) {

		$request_ref->{current_link} .= "&generate_map=1";

		# We want products with emb codes
		$query_ref->{"emb_codes_tags"} = {'$exists' => 1};

		${$request_ref->{content_ref}} .= $html . search_and_map_products($request_ref, $query_ref, $graph_ref);

		$request_ref->{title} = lang("search_title_map");
		if ($map_title ne '') {
			$request_ref->{title} = $map_title . " - " . lang("search_map");
		}

		${$request_ref->{content_ref}} .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;display:none;">
<a href="$request_ref->{current_link_query_display}&amp;action=display" class="button small" title="$request_ref->{title}">
	@{[ display_icon('share') ]}
	<span class="show-for-large-up"> $share</span>
</a></div>
HTML
			;

		display_page($request_ref);
	}
	elsif (
		single_param("generate_graph_scatter_plot")    # old parameter, kept for existing links
		or single_param("graph")
		)
	{

		$graph_ref->{type} = "scatter_plot";
		$request_ref->{current_link} .= "&graph=1";

		# We want existing values for axis fields
		foreach my $axis ('x', 'y') {

			if ($graph_ref->{"axis_$axis"} ne "") {
				my $field = $graph_ref->{"axis_$axis"};
				# Get the field path components
				my @fields = get_search_field_path_components($field);
				# Convert to dot notation to get the MongoDB field
				$query_ref->{join(".", @fields)} = {'$exists' => 1};
			}
		}

		${$request_ref->{content_ref}} .= $html . search_and_graph_products($request_ref, $query_ref, $graph_ref);

		$request_ref->{title} = lang("search_title_graph");
		if ($graph_ref->{graph_title} ne '') {
			$request_ref->{title} = $graph_ref->{graph_title} . " - " . lang("search_graph");
		}

		${$request_ref->{content_ref}} .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;display:none;">
<a href="$request_ref->{current_link_query_display}&amp;action=display" class="button small" title="$request_ref->{title}">
	@{[ display_icon('share') ]}
	<span class="show-for-large-up"> $share</span>
</a></div>
HTML
			;

		display_page($request_ref);
	}
	elsif (single_param("download")) {

		# CSV export

		$request_ref->{format} = single_param('format');
		search_and_export_products($request_ref, $query_ref, $sort_by);

	}
	else {

		# Normal search results

		$log->debug("displaying results", {current_link => $request_ref->{current_link}}) if $log->is_debug();

		${$request_ref->{content_ref}}
			.= $html . search_and_display_products($request_ref, $query_ref, $sort_by, $limit, $page);

		$request_ref->{title} = lang("search_results") . " - " . display_taxonomy_tag($lc, "countries", $country);

		#This is used to have a special share button on some browsers
		if (not defined $request_ref->{jqm}) {
			${$request_ref->{content_ref}} .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;display:none;">
<a href="$request_ref->{current_link}" class="button small" title="$request_ref->{title}">
	@{[ display_icon('share') ]}
	<span class="show-for-large-up"> $share</span>
</a></div>
HTML
				;
			display_page($request_ref);
		}
		else {

			my %response = ();
			$response{jqm} = ${$request_ref->{content_ref}};

			my $data = encode_json(\%response);

			write_cors_headers();
			print "Content-Type: application/json; charset=UTF-8\r\n\r\n" . $data;
		}

		if (single_param('search_terms')) {
			open(my $OUT, ">>:encoding(UTF-8)", "$BASE_DIRS{LOGS}/search_log");
			print $OUT remote_addr() . "\t"
				. time() . "\t"
				. decode utf8 => single_param('search_terms')
				. "\tpage: $page\n";
			close($OUT);
		}
	}
}
