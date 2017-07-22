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
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;

my $action = param('action') || 'display';

my $request_ref = {'search' => 1};

if ((defined param('search_terms')) and (not defined param('action'))) {
	$action = 'process';
}

foreach my $parameter ('json', 'jsonp', 'jqm', 'jqm_loadmore', 'xml', 'rss') {

	if (defined param($parameter)) {
		$request_ref->{$parameter} = param($parameter);
	}
}

my @search_fields = qw(brands categories packaging labels origins manufacturing_places emb_codes purchase_places stores countries additives allergens traces nutrition_grades languages creator editors states );

$admin and push @search_fields, "lang";

my %search_tags_fields =  (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, manufacturing_places => 1, emb_codes => 1, allergens=> 1, traces => 1, nutrition_grades => 1, purchase_places => 1, stores => 1, countries => 1, additives => 1, states=>1, editors=>1, languages => 1 );

my @search_ingredient_classes = ('additives', 'ingredients_from_palm_oil', 'ingredients_that_may_be_from_palm_oil', 'ingredients_from_or_that_may_be_from_palm_oil');


# Read all the parameters, watch for XSS

my $tags_n = 2;
my $nutriments_n = 2;

my $search_terms = remove_tags_and_quote(decode utf8=>param('search_terms2'));	#advanced search takes precedence
if ((not defined $search_terms) or ($search_terms eq '')) {
	$search_terms = remove_tags_and_quote(decode utf8=>param('search_terms'));
}

# check if the search term looks like a barcode

if ((not defined param('jqm')) and ($search_terms =~ /^(\d{8})\d*$/)) {

		my $code = $search_terms;
		
		my $product_ref = product_exists($code); # returns 0 if not
		
		if ($product_ref) {
			print STDERR "search.pl - product code $code exists, redirecting to product page\n";
			my $location = product_url($product_ref);
			

			my $r = shift;
			$r->headers_out->set(Location =>$location);
			$r->status(301);  
			return 301;
			
		}
}


my @search_tags = ();
my @search_nutriments = ();
my %search_ingredient_classes = {};
my %search_ingredient_classes_checked = {};

for (my $i = 0; defined param("tagtype_$i") ; $i++) {

	my $tagtype = remove_tags_and_quote(decode utf8=>param("tagtype_$i"));
	my $tag_contains = remove_tags_and_quote(decode utf8=>param("tag_contains_$i"));
	my $tag = remove_tags_and_quote(decode utf8=>param("tag_$i"));
		
	push @search_tags, [
		$tagtype, $tag_contains, $tag,
	];
}

foreach my $tagtype (@search_ingredient_classes) {
	
	$search_ingredient_classes{$tagtype} = param($tagtype);
	not defined $search_ingredient_classes{$tagtype} and $search_ingredient_classes{$tagtype} = 'indifferent';
	$search_ingredient_classes_checked{$tagtype} = { $search_ingredient_classes{$tagtype} => 'checked="checked"' };
}

for (my $i = 0; $i < $nutriments_n ; $i++) {

	my $nutriment = remove_tags_and_quote(decode utf8=>param("nutriment_$i"));
	my $nutriment_compare = remove_tags_and_quote(decode utf8=>param("nutriment_compare_$i"));
	my $nutriment_value = remove_tags_and_quote(decode utf8=>param("nutriment_value_$i"));
	
	if ($lc eq 'fr') {
		$nutriment_value =~ s/,/\./g;
	}
	push @search_nutriments, [
		$nutriment, $nutriment_compare, $nutriment_value,
	];
}

my $sort_by = remove_tags_and_quote(decode utf8=>param("sort_by"));
if (($sort_by ne 'created_t') and ($sort_by ne 'last_modified_t') and ($sort_by ne 'last_modified_t_complete_first')
	and ($sort_by ne 'scans_n') and ($sort_by ne 'unique_scans_n')) {
	$sort_by = 'unique_scans_n';
}

my $limit = param('page_size') || $page_size;
if (($limit < 2) or ($limit > 1000)) {
	$limit = $page_size;
}

my $graph_ref = {graph_title=>remove_tags_and_quote(decode utf8=>param("graph_title"))};
my $map_title = remove_tags_and_quote(decode utf8=>param("map_title"));

foreach my $axis ('x','y') {
	$graph_ref->{"axis_$axis"} = remove_tags_and_quote(decode utf8=>param("axis_$axis"));
}

my %flatten = ();
my $flatten = 0;

foreach my $field (@search_fields) {
	if (defined $search_tags_fields{$field}) {
		$flatten{$field} = remove_tags_and_quote(decode utf8=>param("flatten_$field"));
		if ($flatten{$field} eq 'on') {
			$flatten = 1;
		}
		else {
			delete $flatten{$field};
		}
	}
}

foreach my $series (@search_series, "nutrition_grades") {

	$graph_ref->{"series_$series"} = remove_tags_and_quote(decode utf8=>param("series_$series"));
	if ($graph_ref->{"series_$series"} ne 'on') {
		delete $graph_ref->{"series_$series"};
	}
}


if ($action eq 'display') {

	my $active_list = 'active';
	my $active_map = '';
	my $active_graph = '';
	
	if (param("generate_map")) {
		$active_list = '';
		$active_map = 'active';
	}
	elsif (param("graph")) {
		$active_list = '';
		$active_graph = 'active';	
	}

	# Display the search form

	my $html = start_form(-id=>"search_form", -action=>"/cgi/search.pl") ;	
	
	$html .= <<HTML
<div class="row">
	<div class="large-12 columns">
<label for="search_terms2">$Lang{search_terms_note}{$lc}</label>
<input type="text" name="search_terms2" id="search_terms2" value="$search_terms" />
	</div>
</div>	

<h3>$Lang{search_tags}{$lang}</h3>
<label>$Lang{search_criteria}{$lc}</label>	
HTML
;

	my %search_fields_labels = ();
	foreach my $field (@search_fields) {
		if ((not defined $tags_fields{$field}) and (lang($field) ne '')) {
			$search_fields_labels{$field} = lc(lang($field));
		}
		else {
			if ($field eq 'creator') {
				$search_fields_labels{$field} = lang("users_p");
			}
			else {
				$search_fields_labels{$field} = lang($field . "_p");
			}
		}
	}
	$search_fields_labels{search_tag} = lang("search_tag");
	
	$html .= <<HTML
<div class="row">
HTML
;

	for (my $i = 0; ($i < $tags_n) or defined param("tagtype_$i") ; $i++) {
	
		$html .= <<HTML
	<div class="small-12 medium-12 large-6 columns criterion-row" style="padding-top:1rem">
		<div class="row">
			<div class="small-12 medium-12 large-5 columns">
HTML
;
	
		$html .= popup_menu(-name=>"tagtype_$i", -id=>"tagtype_$i", -value=> $search_tags[$i][0], -values=>['search_tag', @search_fields], -labels=>\%search_fields_labels);
		
		$html .= <<HTML
			</div>
			<div class="small-12 medium-12 large-3 columns">
HTML
;
		$html .=  popup_menu(-name=>"tag_contains_$i", -id=>"tag_contains_$i", -value=> $search_tags[$i][1], -values=>["contains", "does_not_contain"],
                        -labels=>{"contains" => lang("search_contains"), "does_not_contain" => lang("search_does_not_contain")} );

		$html .= <<HTML						
			</div>
			<div class="small-12 medium-12 large-4 columns tag-search-criterion">
				<input type="text" id="tag_$i" name="tag_$i" value="$search_tags[$i][2]" placeholder="$Lang{search_value}{$lc}"/>
			</div>
		</div>
	</div>
HTML
;
	}
	
	$html .= <<HTML	
</div>

<h3>$Lang{search_ingredients}{$lang}</h3>	

<div class="row">
HTML
;

	foreach my $tagtype (@search_ingredient_classes) {
	
		not defined $search_ingredient_classes{$tagtype} and $search_ingredient_classes{$tagtype} = 'indifferent';
	
		my $label = ucfirst(lang($tagtype . "_p")) ;
		
		$html .= <<HTML
	<div class="small-12 medium-12 large-6 columns">
		<label>$label</label>		
HTML
;		
				
		
		$html .= <<HTML
			<input type="radio" name="$tagtype" value="without" id="without_$tagtype" $search_ingredient_classes_checked{$tagtype}{without}/>
				<label for="without_$tagtype">$Lang{search_without}{$lc}</label>
			<input type="radio" name="$tagtype" value="with" id="with_$tagtype" $search_ingredient_classes_checked{$tagtype}{with}/>
				<label for="with_$tagtype">$Lang{search_with}{$lc}</label>
			<input type="radio" name="$tagtype" value="indifferent" id="indifferent_$tagtype" $search_ingredient_classes_checked{$tagtype}{indifferent}/>
				<label for="indifferent_$tagtype">$Lang{search_indifferent}{$lc}</label>			
	</div>
HTML
;		
	}


	$html .= <<HTML	
</div>

<h3>$Lang{search_nutriments}{$lang}</h3>
<div class="row">	
HTML
;

	my %nutriments_labels = ();
	foreach my $nid (@{$nutriments_lists{$nutriment_table}}) {
		$nutriments_labels{$nid} = $Nutriments{$nid}{$lang};
		print STDERR "search.pl - nutriments - $nid -- $nutriments_labels{$nid} \n";
	}
	$nutriments_labels{search_nutriment} = lang("search_nutriment");

	for (my $i = 0; $i < $nutriments_n ; $i++) {
	
		$html .= <<HTML
	<div class="small-12 medium-12 large-6 columns">
		<div class="row">
			<div class="small-8 columns">
HTML
;			
	
		$html .= popup_menu(-name=>"nutriment_$i", -id=>"nutriment_$i", -value=> $search_nutriments[$i][0], -values=>['search_nutriment', @{$nutriments_lists{$nutriment_table}}], -labels=>\%nutriments_labels);
		 
		
		$html .= <<HTML
			</div>
			<div class="small-2 columns">
HTML
;
		$html .= popup_menu(-name=>"nutriment_compare_$i", -id=>"nutriment_compare_$i", -value=> $search_nutriments[$i][1], -values=>['lt','lte','gt','gte','eq'],
			-labels => {'lt' => '<', 'lte' => "\N{U+2264}", 'gt' => '>', 'gte' => "\N{U+2265}", 'eq' => '='} );

		$html .= <<HTML
			</div>
			<div class="small-2 columns">
				<input type="text" id="nutriment_value_$i" name="nutriment_value_$i" value="$search_nutriments[$i][2]" />
			</div>
		</div>
	</div>
HTML
;
	}
	
	# Different types to display results
	
	my $popup_sort = popup_menu(-name=>"sort_by", -id=>"sort_by", -value=> $sort_by,
		-values=>['unique_scans_n','product_name','created_t','last_modified_t'],
		-labels=>{unique_scans_n=>lang("sort_popularity"), product_name=>lang("sort_product_name"),
			created_t=>lang("sort_created_t"), last_modified_t=>lang("sort_modified_t")});
			
	my $popup_size = popup_menu(-name=>"page_size", -id=>"page_size", -value=> $limit, -values=>[20, 50, 100, 250, 500, 1000]);
	
	$html .= <<HTML
</div>

<input type="hidden" name="action" value="process" />

<ul class="accordion" style="margin-left:0" data-accordion>
	<li class="accordion-navigation">
		<a href="#results_list" style="border-top:1px solid #ccc"><h3>$Lang{search_list_choice}{$lc}</h3></a>
		<div id="results_list" class="content $active_list">
		
			<div class="row">
				<div class="small-6 columns">
					<label for="sort_by">$Lang{sort_by}{$lang}</label>
					$popup_sort
				</div>
				<div class="small-6 columns">
					<label for="page_size">$Lang{search_page_size}{$lc}</label>	
					$popup_size
				</div>
			</div>
		
		<input type="submit" name="search" class="button" value="$Lang{search_button}{$lc}" />
		</div>
	</li>
HTML
;	
			
	# Graphs and visualization
	
	$html .= <<HTML
	<li class="accordion-navigation">
		<a href="#results_graph" style="border-top:1px solid #ccc"><h3>$Lang{search_graph_choice}{$lc}</h3></a>
		<div id="results_graph" class="content $active_graph">

			<div class="alert-box info">$Lang{search_graph_note}{$lang}</div>

			<label for="graph_title">$Lang{graph_title}{$lang}</label>
			<input type="text" name="graph_title" id="graph_title" value="$graph_ref->{graph_title}" />

			<p>$Lang{search_graph_instructions}{$lc}</p>

			<div class="row">
HTML
;

	# Compute possible axis values
	my @axis_values = @{$nutriments_lists{$nutriment_table}};
	my %axis_labels = %nutriments_labels;
	push @axis_values, "additives_n", "ingredients_n";
	$axis_labels{additives_n} = lang("number_of_additives");
	$axis_labels{ingredients_n} = lang("ingredients_n_s");
	$axis_labels{products_n} = lang("number_of_products");

	foreach my $axis ('x','y') {
		if ($axis eq 'y') {
			unshift @axis_values, "products_n";
		}
		$html .= <<HTML
				<div class="small-12 medium-6 columns">
HTML
;
		$html .= "<label for=\"axis_$axis\">" . lang("axis_$axis") . "</label>"
			. popup_menu(-name=>"axis_$axis", -id=>"axis_$axis", -value=> $graph_ref->{"axis_" . $axis}, -values=>\@axis_values, -labels=>\%axis_labels);
			
		$html .= <<HTML
				</div>
HTML
;			
	}
	
	$html .= <<HTML
			</div>
			
			<div class="row">
				<div class="small-12 medium-6 columns">
					<p>$Lang{search_series}{$lc}</p>
HTML
;
	
	foreach my $series (@search_series, "nutrition_grades") {

		next if $series eq 'default';
		my $checked = '';
		if ($graph_ref->{"series_$series"} eq 'on') {
			$checked = 'checked="checked"';
		}
		
			if ($series eq 'nutrition_grades') {
				$html .= <<HTML
				</div>
				<div class="small-12 medium-6 columns">
					<p>$Lang{or}{$lc}</p>
HTML
;
			}
	
		$html .= <<HTML
					<input type="checkbox" id="series_$series" name="series_$series" $checked />
					<label for="series_$series" class="checkbox_label">$Lang{"search_series_$series"}{$lc}</label>

HTML
;	
		
	}
	
	$html .= <<HTML
				</div>
			</div>
			
			<input type="submit" name="graph" value="$Lang{search_generate_graph}{$lc}" class="button" />

		</div>
	</li>
	
	<!-- Map results -->
	
	<li class="accordion-navigation">
		<a href="#results_map" style="border-top:1px solid #ccc"><h3>$Lang{search_map_choice}{$lc}</h3></a>
		<div id="results_map" class="content $active_map">
	
			<div class="alert-box info">$Lang{search_map_note}{$lc}</div>
	
			<label for="map_title">$Lang{map_title}{$lc}</label>
			<input type="text" name="map_title" id="map_title" value="$map_title" />
			
			<input type="submit" name="generate_map" value="$Lang{search_generate_map}{$lc}" class="button" />

		</div>
	</li>
	
	<!-- Download results -->
	
	<li class="accordion-navigation">
		<a href="#results_download" style="border-top:1px solid #ccc"><h3>$Lang{search_download_choice}{$lc}</h3></a>
		<div id="results_download" class="content">

			<p>$Lang{search_download_results}{$lc}</p>
			<p>$Lang{search_download_results_description}{$lc}</p>
			
			<input type="submit" name="download" value="$Lang{search_download_button}{$lc}" class="button" />

		</div>
	</li>
</ul>
</form>
<script type="text/javascript" src="/js/search.js"></script>
HTML
;
	
	${$request_ref->{content_ref}} .= $html;

	$request_ref->{title} = lang("search_products");
	
	display_new($request_ref);	
	
}


elsif ($action eq 'process') {

	# Display the search results or construct CSV file for download

	# analyze parameters and construct query
	
	my $current_link = "/cgi/search.pl?action=process";
	
	my $query_ref = {};

	my $page = param('page') || 1;
	if (($page < 1) or ($page > 1000)) {
		$page = 1;
	}
	
	# Search terms
	
	if ((defined $search_terms) and ($search_terms ne '')) {
	
		# does it look like a packaging code
		if (($search_terms !~/,/) and 
			(($search_terms =~ /^(\w\w)(\s|-|\.)?(\d(\s|-|\.)?){5}(\s|-|\.|\d)*C(\s|-|\.)?E/i) 
			or ($search_terms =~ /^(emb|e)(\s|-|\.)?(\d(\s|-|\.)?){5}/i))) {
				$query_ref->{"emb_codes_tags"} = get_fileid(normalize_packager_codes($search_terms));
		}
		else {
	
			my %terms = ();	
		
			foreach my $term (split(/,|'|\s/, $search_terms)) {
				if (length(get_fileid($term)) >= 2) {
					$terms{normalize_search_terms(get_fileid($term))} = 1;
				}
			}
			if (scalar keys %terms > 0) {
				$query_ref->{_keywords} = { '$all' => [keys %terms]};
				$current_link .= "\&search_terms=" . URI::Escape::XS::encodeURIComponent($search_terms);
			}
		}
	}
	
	# Tags criteria
	
	my $and;
	
	for (my $i = 0;  (defined $search_tags[$i]) ; $i++) {
	
		my ($tagtype, $contains, $tag) = @{$search_tags[$i]};
		
		if (($tagtype ne 'search_tag') and ($tag ne '')) {
		
			my $tagid; 
			if (defined $taxonomy_fields{$tagtype}) {
				$tagid = get_taxonomyid(canonicalize_taxonomy_tag($lc,$tagtype, $tag)); 
				print STDERR "search - taxonomy - tag: $tag - tagid: $tagid\n";
			}
			else {
				$tagid = get_fileid(canonicalize_tag2($tagtype, $tag));
			}
			
			if ($tagtype eq 'additives') {
				$tagid =~ s/-.*//;
			}	
			
			if ($tagid ne '') {
			
				if (not defined $tags_fields{$tagtype}) {
					
					if ($contains eq 'contains') {
						$query_ref->{$tagtype} = $tagid;
					}
					else {
						$query_ref->{$tagtype} =  { '$ne' => $tagid };
					}				
				
				}
				else {
			
					# 2 or more criterias on the same field?
					my $remove = 0;
					if (defined $query_ref->{$tagtype . "_tags"}) {
						$remove = 1;
						if (not defined $and) {
							$and = [];
						}
						push @$and, { $tagtype . "_tags" => $query_ref->{$tagtype . "_tags"} };
					}
				
					if ($contains eq 'contains') {
						$query_ref->{$tagtype . "_tags"} = $tagid;
					}
					else {
						$query_ref->{$tagtype . "_tags"} =  { '$ne' => $tagid };
					}
					
					if ($remove) {
						push @$and, { $tagtype . "_tags" => $query_ref->{$tagtype . "_tags"} };
						delete $query_ref->{$tagtype . "_tags"};
						$query_ref->{"\$and"} = $and;
					}
				
				}
				
				$current_link .= "\&tagtype_$i=$tagtype\&tag_contains_$i=$contains\&tag_$i=" . URI::Escape::XS::encodeURIComponent($tag);
				
				# TODO: 2 or 3 criterias on the same field
				# db.foo.find( { $and: [ { a: 1 }, { a: { $gt: 5 } } ] } ) ?
			}
		}
	}	
	
	# Ingredient classes
	
	foreach my $tagtype (@search_ingredient_classes) {
	
		if ($search_ingredient_classes{$tagtype} eq 'with') {
			$query_ref->{$tagtype . "_n"}{ '$gte'} = 1;
			$current_link .= "\&$tagtype=with";
		}
		elsif ($search_ingredient_classes{$tagtype} eq 'without') {
			$query_ref->{$tagtype . "_n"}{ '$lt'} = 1;
			$current_link .= "\&$tagtype=without";
		}
	}
	
	# Nutriments
	
	for (my $i = 0; $i < $nutriments_n ; $i++) {
	
		my ($nutriment, $compare, $value, $unit) = @{$search_nutriments[$i]};
		
		if (($nutriment ne 'search_nutriment') and ($value ne '')) {
					
			if ($compare eq 'eq') {
				$query_ref->{"nutriments.${nutriment}_100g"} = $value + 0.0; # + 0.0 to force scalar to be treated as a number
			}
			elsif ($compare =~ /^(lt|lte|gt|gte)$/) {
				if (defined $query_ref->{"nutriments.${nutriment}_100g"}) {
					$query_ref->{"nutriments.${nutriment}_100g"}{ '$' . $compare}  = $value + 0.0;
				}
				else {
					$query_ref->{"nutriments.${nutriment}_100g"} = { '$' . $compare  => $value + 0.0 };
				}
			}				
			$current_link .= "\&nutriment_$i=$nutriment\&nutriment_compare_$i=$compare\&nutriment_value_$i=" . URI::Escape::XS::encodeURIComponent($value);
			
			# TODO support range queries: < and > on the same nutriment
			# my $doc32 = $collection->find({'x' => { '$gte' => 2, '$lt' => 4 }});
		}
	}		

	
	my @fields = keys %tag_type_singular;
	
	foreach my $field (@fields) {
	
		next if defined $search_ingredient_classes{$field};

		if ((defined param($field)) and (param($field) ne '')) {
		
			$query_ref->{$field} = decode utf8=>param($field);
			$current_link .= "\&$field=" . URI::Escape::XS::encodeURIComponent(decode utf8=>param($field));
		}	
	}
	
	if (defined $sort_by) {
		$current_link .= "&sort_by=$sort_by";
	}
	
	$current_link .= "\&page_size=$limit";
	
	# Graphs
	
	foreach my $axis ('x','y') {
		if (param("axis_$axis") ne '') {
			$current_link .= "\&axis_$axis=" .  URI::Escape::XS::encodeURIComponent(decode utf8=>param("axis_$axis"));
		}
	}	
	
	if (param('graph_title') ne '') {
		$current_link .= "\&graph_title=" . URI::Escape::XS::encodeURIComponent(decode utf8=>param("graph_title"));
	}
	
	if (param('map_title') ne '') {
		$current_link .= "\&map_title=" . URI::Escape::XS::encodeURIComponent(decode utf8=>param("map_title"));
	}
		
	foreach my $series (@search_series, "nutrition_grades") {

		next if $series eq 'default';
		if ($graph_ref->{"series_$series"}) {
			$current_link .= "\&series_$series=on";
		}
	}
	
	$request_ref->{current_link_query} = $current_link;
	
	my $html = '';
	#$query_ref->{lc} = $lc;
	
	use Data::Dumper;
	print STDERR "search.pl - query: \n" . Dumper($query_ref) . "\n";
	
	
	
	my $share = lang('share');

	# Graph, map, export or search

	if (param("generate_map")) {
	
		$request_ref->{current_link_query} .= "&generate_map=1";
		
		# We want products with emb codes
		$query_ref->{"emb_codes_tags"} = { '$exists' => 1 };	
		
		${$request_ref->{content_ref}} .= $html . search_and_map_products($request_ref, $query_ref, $graph_ref);

		$request_ref->{title} = lang("search_title_map");
		if ($map_title ne '') {
			$request_ref->{title} = $map_title . " - " . lang("search_map");
		}
		$request_ref->{full_width} = 1;
		
		${$request_ref->{content_ref}} .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;display:none;">
<a href="$request_ref->{current_link_query_display}&amp;action=display" class="button small icon" title="$request_ref->{title}">
	<i class="fi-share"></i>
	<span class="show-for-large-up"> $share</span>
</a></div>
HTML
;
		
		display_new($request_ref);	
	}
	elsif (param("generate_graph_scatter_plot")  # old parameter, kept for existing links
		or param("graph")) {
	
		$graph_ref->{type} = "scatter_plot";
		$request_ref->{current_link_query} .= "&graph=1";
		
		# We want existing values for axis fields
		foreach my $axis ('x','y') {
			if ($graph_ref->{"axis_$axis"} !~ /_n$/) {
				(defined $query_ref->{"nutriments." . $graph_ref->{"axis_$axis"} . "_100g"}) or $query_ref->{"nutriments." . $graph_ref->{"axis_$axis"} . "_100g"} = {};
				$query_ref->{"nutriments." . $graph_ref->{"axis_$axis"} . "_100g"} { '$exists'} = 1  ;	
			}
		}
		
		${$request_ref->{content_ref}} .= $html . search_and_graph_products($request_ref, $query_ref, $graph_ref);

		$request_ref->{title} = lang("search_title_graph");
		if ($graph_ref->{graph_title} ne '') {
			$request_ref->{title} = $graph_ref->{graph_title} . " - " . lang("search_graph");
		}
		$request_ref->{full_width} = 1;
		
		${$request_ref->{content_ref}} .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;display:none;">
<a href="$request_ref->{current_link_query_display}&amp;action=display" class="button small icon" title="$request_ref->{title}">
	<i class="fi-share"></i>
	<span class="show-for-large-up"> $share</span>
</a></div>
HTML
;
		
		display_new($request_ref);	
	}
	elsif (param("download")) {
		# CSV export
		
		my $csv = search_and_export_products($request_ref, $query_ref, $sort_by, $flatten, \%flatten);
		
		if ($csv) {
			use Apache2::RequestRec ();
			my $r = Apache2::RequestUtil->request();
			$r->headers_out->set("Content-type" => "text/csv; charset=UTF-8");
			$r->headers_out->set("Content-disposition" => "attachment;filename=openfoodfacts_search.csv");
			binmode(STDOUT, ":encoding(UTF-8)");
			print "Content-Type: text/csv; charset=UTF-8\r\n\r\n" . $csv ;
		}
		else {
			$request_ref->{title} = lang("search_results");
			display_new($request_ref);
		}
		
	}
	else {
	
		# Normal search results
		
		print STDERR "search.pl - current_link: $request_ref->{current_link} - current_link_query: $request_ref->{current_link_query} \n";	
		
		${$request_ref->{content_ref}} .= $html . search_and_display_products($request_ref, $query_ref, $sort_by, $limit, $page);

		$request_ref->{title} = lang("search_results") . " - " . display_taxonomy_tag($lc,"countries",$country);
	

	
		if (not defined $request_ref->{jqm}) {
			${$request_ref->{content_ref}} .= <<HTML
<div class="share_button right" style="float:right;margin-top:-10px;display:none;">
<a href="$request_ref->{current_link_query_display}&amp;action=display" class="button small icon" title="$request_ref->{title}">
	<i class="fi-share"></i>
	<span class="show-for-large-up"> $share</span>
</a></div>
HTML
;
			display_new($request_ref);
		}
		else {

			my %response = ();
			$response{jqm} = ${$request_ref->{content_ref}};

			my $data =  encode_json(\%response);
	
			print "Content-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\n\r\n" . $data;	
		}
	
		if (param('search_terms')) {
			open (my $OUT, ">>:encoding(UTF-8)", "$data_root/logs/search_log");
			print $OUT remote_addr() . "\t" . time() . "\t" . decode utf8=>param('search_terms')
				. "\tpage: $page\tcount:" . $request_ref->{count} . "\n";
			close ($OUT);
		}
	}
}
