#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
use Log::Any qw($log);

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;

# $lc = 'fr';
# $lang = 'fr';

my %map_options =
(
uk => "map.setView(new L.LatLng(54.0617609,-3.4433238),6);",
);


sub display_madenearyou($) {

	my $request_ref = shift;
	
	not $request_ref->{blocks_ref} and $request_ref->{blocks_ref} = [];
	

	my $title = $request_ref->{title};
	my $description = $request_ref->{description};
	my $content_ref = $request_ref->{content_ref};
	my $blocks_ref = $request_ref->{blocks_ref};
	
	my $html;
	
	if (open(my $IN, "<:encoding(UTF-8)", "$data_root/madenearme/madenearme-$cc.html")) {
	
		$html = join("", (<$IN>));
		close $IN;
	}
	else {
		$html = "$cc not found";
	}
	

	$html =~ s/<HEADER>/$header/;
	$html =~ s/<INITJS>/$initjs/;
	$html =~ s/<CONTENT>/$$content_ref/;

	print header ( -expires=>'-1d', -charset=>'UTF-8');
	
	
	
	
	binmode(STDOUT, ":encoding(UTF-8)");
	print $html;

}


my $action = param('action') || 'display';

$action = 'process';

my $request_ref = {};

if ((defined param('search_terms')) and (not defined param('action'))) {
	$action = 'process';
}

if (defined param('jqm')) {
	$request_ref->{jqm} = param('jqm');
}

if (defined param('jqm_loadmore')) {
	$request_ref->{jqm_loadmore} = param('jqm_loadmore');
}

my @search_fields = qw(brands categories packaging labels origins emb_codes purchase_places stores additives traces status );
my %search_tags_fields =  (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, emb_codes => 1, traces => 1, purchase_places => 1, stores => 1, additives => 1, status=>1);

my @search_ingredient_classes = ('additives', 'ingredients_from_palm_oil', 'ingredients_that_may_be_from_palm_oil', 'ingredients_from_or_that_may_be_from_palm_oil');


# Read all the parameters, watch for XSS

my $tags_n = 3;
my $nutriments_n = 3;

my $search_terms = remove_tags_and_quote(decode utf8=>param('search_terms2'));	#advanced search takes precedence
if ((not defined $search_terms) or ($search_terms eq '')) {
	$search_terms = remove_tags_and_quote(decode utf8=>param('search_terms'));
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
		
	push @search_nutriments, [
		$nutriment, $nutriment_compare, $nutriment_value,
	];
}

my $sort_by = remove_tags_and_quote(decode utf8=>param("sort_by"));
if (($sort_by ne 'created_t') and ($sort_by ne 'last_modified_t') and ($sort_by ne 'last_modified_t_complete_first')) {
	$sort_by = 'product_name';
}

my $limit = param('page_size') || $page_size;
if (($limit < 2) or ($limit > 1000)) {
	$limit = $page_size;
}

my $graph_ref = {graph_title=>remove_tags_and_quote(decode utf8=>param("graph_title"))};
my $map_title = remove_tags_and_quote(decode utf8=>param("map_title"));



if ($action eq 'process') {

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
	
	# Tags criteria
	
	my $and;
	
	for (my $i = 0; $i < $tags_n ; $i++) {
	
		my ($tagtype, $contains, $tag) = @{$search_tags[$i]};
		
		if (($tagtype ne 'search_tag') and ($tag ne '')) {
		
			my $tagid = get_fileid(canonicalize_tag2($tagtype, $tag));
			
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
	
	$log->info("building query", { lc => $lc, cc => $cc, query => $query_ref }) if $log->is_info();
	
	$query_ref->{lc} = $lc;
	
	# Graph, map, export or search


	
		$request_ref->{current_link_query} .= "&generate_map=1";
		
		# We want products with emb codes
		$query_ref->{"emb_codes_tags"} = { '$exists' => 1 };	
		
		$request_ref->{map_options} = $map_options{$cc} || "";
		
		${$request_ref->{content_ref}} .= $html . search_and_map_products($request_ref, $query_ref, $graph_ref);

		$request_ref->{title} = lang("search_title_map");
		if ($map_title ne '') {
			$request_ref->{title} = $map_title . " - " . lang("search_map");
		}
		$request_ref->{full_width} = 1;
		
		
		my $html =	<<HTML
<div id="container" style="height: 600px"></div>
HTML
;
		$request_ref->{content_ref} = \$html;

	display_madenearyou($request_ref);
	
}
