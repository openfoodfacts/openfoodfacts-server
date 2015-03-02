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


use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Tags qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

Blogs::Display::init();
use Blogs::Lang qw/:all/;

my $action = param('action') || 'display';

my $request_ref = {'search' => 1};

if ((defined param('search_terms')) and (not defined param('action'))) {
	$action = 'process';
}

if (defined param('jqm')) {
	$request_ref->{jqm} = param('jqm');
}

if (defined param('jqm_loadmore')) {
	$request_ref->{jqm_loadmore} = param('jqm_loadmore');
}

my @search_fields = qw(brands categories packaging labels origins emb_codes purchase_places stores additives allergens traces states );
my %search_tags_fields =  (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, emb_codes => 1, allergens=> 1, traces => 1, purchase_places => 1, stores => 1, additives => 1, states=>1);

my @search_ingredient_classes = ('additives', 'ingredients_from_palm_oil', 'ingredients_that_may_be_from_palm_oil', 'ingredients_from_or_that_may_be_from_palm_oil');


# Read all the parameters, watch for XSS

my $tags_n = 3;
my $nutriments_n = 3;

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

for (my $i = 0; $i < $tags_n ; $i++) {

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

foreach my $series (@search_series) {

	$graph_ref->{"series_$series"} = remove_tags_and_quote(decode utf8=>param("series_$series"));
	if ($graph_ref->{"series_$series"} ne 'on') {
		delete $graph_ref->{"series_$series"};
	}
}


if ($action eq 'display') {

	# Display the search form

	my $html = start_form(-id=>"search_form", -action=>"/cgi/search.pl") ;
	
	my $tagsinput = "";
	
	$html .= <<HTML
<label for="search_terms2">$Lang{search_terms}{$lang}</label>
<input name="search_terms2" id="search_terms2" class="text ui-widget-content ui-corner-all${tagsinput}" value="$search_terms" />
<p class="note">&rarr; $Lang{search_terms_note}{$lang}</p>			

<h3>$Lang{search_tags}{$lang}</h3>	
HTML
;

	my %search_fields_labels = ();
	foreach my $field (@search_fields) {
		$search_fields_labels{$field} = lang($field . "_p");
	}
	$search_fields_labels{search_tag} = lang("search_tag");

	for (my $i = 0; $i < $tags_n ; $i++) {
	
		$html .= popup_menu(-name=>"tagtype_$i", -id=>"tagtype_$i", -value=> $search_tags[$i][0], -values=>['search_tag', @search_fields], -labels=>\%search_fields_labels)
		. popup_menu(-name=>"tag_contains_$i", -id=>"tag_contains_$i", -value=> $search_tags[$i][1], -values=>["contains", "does_not_contain"],
			-labels=>{"contains" => lang("search_contains"), "does_not_contain" => lang("search_does_not_contain")} )
		.
		<<HTML
<input id="tag_$i" name="tag_$i" value="$search_tags[$i][2]" class="text ui-widget-content ui-corner-all" />
<br /><br />
HTML
;
	}
	
	$html .= <<HTML	
<h3>$Lang{search_ingredients}{$lang}</h3>	
HTML
;

	foreach my $tagtype (@search_ingredient_classes) {
	
		not defined $search_ingredient_classes{$tagtype} and $search_ingredient_classes{$tagtype} = 'indifferent';
	
		$html .= ucfirst(lang($tagtype . "_p")) . lang("sep") . ": " ;
		$html .= radio_group(-name=>$tagtype,
			     -values=>['without', 'with', 'indifferent'], -default=>$search_ingredient_classes{$tagtype},
			     -labels=>{with=>lang("search_with"), without=>lang("search_without"), indifferent=>lang("search_indifferent")})
			. "<br />";
		
		if ($tagtype eq 'additives') {
			$html .= "<br />";
		}
	
	}


	$html .= <<HTML	
<h3>$Lang{search_nutriments}{$lang}</h3>	
HTML
;

	my %nutriments_labels = ();
	foreach my $nid (@nutriments) {
		$nutriments_labels{$nid} = $Nutriments{$nid}{$lang};
		print STDERR "search.pl - nutriments - $nid -- $nutriments_labels{$nid} \n";
	}
	$nutriments_labels{search_nutriment} = lang("search_nutriment");

	for (my $i = 0; $i < $nutriments_n ; $i++) {
	
		$html .= popup_menu(-name=>"nutriment_$i", -id=>"nutriment_$i", -value=> $search_nutriments[$i][0], -values=>['search_nutriment', @nutriments], -labels=>\%nutriments_labels)
		. popup_menu(-name=>"nutriment_compare_$i", -id=>"nutriment_compare_$i", -value=> $search_nutriments[$i][1], -values=>['lt','lte','gt','gte','eq'],
			-labels => {'lt' => '<', 'lte' => '<=', 'gt' => '>', 'gte' => '>=', 'eq' => '='} )
		.
		<<HTML
<input id="nutriment_value_$i" name="nutriment_value_$i" value="$search_nutriments[$i][2]" class="text ui-widget-content ui-corner-all" />
<br /><br />
HTML
;
	}

	$html .= <<HTML
<label for="sort_by">$Lang{sort_by}{$lang}</label>
HTML
	. popup_menu(-name=>"sort_by", -id=>"sort_by", -value=> $sort_by, -values=>['unique_scans_n','product_name','created_t','last_modified_t'],
		-labels=>{unique_scans_n=>lang("sort_popularity"), product_name=>lang("sort_product_name"), created_t=>lang("sort_created_t"), last_modified_t=>lang("sort_modified_t")}) 

	. <<HTML
<br />
<label for="page_size">$Lang{search_page_size}{$lang}</label>	
HTML
	. popup_menu(-name=>"page_size", -id=>"page_size", -value=> $limit, -values=>[20, 50, 100, 250, 500, 1000]) 
	
	. "<br /><br />"

	. submit(-name=>'search', -label=>lang("search_button"), -class=>"jbutton")
	
	. hidden(-name=>'action', -type=>"hidden", -value=>"process", -override=>1);
	
	# Graphs and visualization
	
	$html .= <<HTML
<h3>$Lang{search_graph_title}{$lang}</h3>

<p class="note">&rarr; $Lang{search_graph_note}{$lang}</p>			

<label for="graph_title">$Lang{graph_title}{$lang}</label>
<input name="graph_title" id="graph_title" class="text ui-widget-content ui-corner-all" style="width:400px" value="$graph_ref->{graph_title}" />

<h4>$Lang{search_graph_2_axis}{$lang}</h4>
HTML
;

	# Compute possible axis values
	my @axis_values = @nutriments;
	my %axis_labels = %nutriments_labels;
	push @axis_values, "additives_n";
	$axis_labels{additives_n} = lang("number_of_additives");
	$axis_labels{products_n} = lang("number_of_products");

	foreach my $axis ('x','y') {
		if ($axis eq 'y') {
			unshift @axis_values, "products_n";
		}
		$html .= "<label for=\"\">" . lang("axis_$axis") . "</label>"
			. popup_menu(-name=>"axis_$axis", -id=>"axis_$axis", -value=> $graph_ref->{"axis_" . $axis}, -values=>\@axis_values, -labels=>\%axis_labels)
			. "<br />";
	}
	
	$html .= "<p>" . lang("search_series") . "</p>";
	
	foreach my $series (@search_series) {

		next if $series eq 'default';
		my $checked = '';
		if ($graph_ref->{"series_$series"} eq 'on') {
			$checked = 'checked="checked"';
		}
	
		$html .= <<HTML
<input type="checkbox" id="series_$series" name="series_$series" $checked />
<label for="series_$series" class="checkbox_label">$Lang{"search_series_$series"}{$lang}</label><br /><br/>
HTML
;	
	
	}
	
	$html .= submit(-name=>'graph', -label=>lang("search_generate_graph"), -class=>"jbutton");	
	
	# Maps
	$html .= <<HTML
<h3>$Lang{search_map_title}{$lang}</h3>

<p class="note">&rarr; $Lang{search_map_note}{$lang}</p>			

<label for="map_title">$Lang{map_title}{$lang}</label>
<input name="map_title" id="map_title" class="text ui-widget-content ui-corner-all" style="width:400px" value="$map_title" /><br /><br />
HTML
;	
	
	$html .= submit(-name=>'generate_map', -label=>lang("search_generate_map"), -class=>"jbutton");	
	
	
	# Download results
	
	$html .= <<HTML
<br/>
<h3>$Lang{search_download_results}{$lang}</h3>

<p>$Lang{search_download_results_description}{$lang}</p>
<div style="margin-left:30px">
HTML
;
	# <p>$Lang{search_flatten_tags}{$lang}</p>

	if (0) {
	foreach my $field (@search_fields) {
		if (defined $search_tags_fields{$field}) {
			
			my $checked = '';
			
			if ($flatten{$field} eq 'on') {
				$checked = 'checked="checked"';
			}
		
			$html .= <<HTML
<input type="checkbox" id="flatten_$field" name="flatten_$field" $checked />
<label for="flatten_$field" class="checkbox_label">$Lang{"$field" . "_s"}{$lang}</label><br />
HTML
;
		
		}
	}
	}

	$html .= "</div>\n";
	$html .= submit(-name=>'download', -label=>lang("search_download_button"), -class=>"jbutton");	
	

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
	
	for (my $i = 0; $i < $tags_n ; $i++) {
	
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
			
				# 2 or 3 criterias on the same field?
				my $remove = 0;
				if (defined $query_ref->{$tagtype . "_tags"}) {
					$remove = 1;
					$and = [{ $tagtype . "_tags" => $query_ref->{$tagtype . "_tags"} }];
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
		
	foreach my $series (@search_series) {

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
			binmode(STDOUT, ":utf8");
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
			display_new($request_ref);
		}
		else {

			my %response = ();
			$response{jqm} = ${$request_ref->{content_ref}};
			$response{jqm} =~ s/(href|src)=("\/)/$1="http:\/\/$lc.openfoodfacts.org\//g;

			my $data =  encode_json(\%response);
	
			print "Content-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\n\r\n" . $data;	
		}
	
		if (param('search_terms')) {
			open (OUT, ">>:encoding(UTF-8)", "$data_root/logs/search_log");
			print OUT remote_addr() . "\t" . time() . "\t" . decode utf8=>param('search_terms')
				. "\tpage: $page\tcount:" . $request_ref->{count} . "\n";
			close (OUT);
		}
	}
}
