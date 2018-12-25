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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

# Generate a list of the top brands, categories, users, additives etc.

my @fields = qw (
brands 
categories
packaging 
origins
manufacturing_places
ingredients 
labels 
nutriments 
traces 
users
photographers
informers
correctors
checkers
additives
allergens
emb_codes
cities
purchase_places
stores
countries
ingredients_from_palm_oil
ingredients_that_may_be_from_palm_oil
status
unknown_nutrients
);



my %langs = ();
my $total = 0;

my @dates = ('created_t', 'completed_t');
my %langs_dates = ();
my %products = ();

foreach my $l (values %lang_lc) {

	$lc = $l;
	$lang = $l;
	
	
	my %dates = ();
	$langs_dates{$lc} = {};
	foreach my $date (@dates) {
		$dates{$date} = {};
		$langs_dates{$lc}{$date} = {};
	}	
	
	my $fields_ref = {code => 1};
	my %tags = ();

	foreach my $tagtype (@fields) {
		$fields_ref->{$tagtype . "_tags"} = 1;
		$tags{$tagtype} = {};
		$tags{$tagtype . "_nutriments"} = {};
	}
	delete $fields_ref->{users_tags};
	$fields_ref->{creator} = 1;
	$fields_ref->{nutriments} = 1;
	$fields_ref->{created_t} = 1;
	$fields_ref->{complete} = 1;
	$fields_ref->{completed_t} = 1;
		
	my $cursor = get_products_collection()->query({lc=>$lc})->fields($fields_ref);
	my $count = $cursor->count();
	
	$langs{$l} = $count;
	$total += $count;
		
	print STDERR "lc: $lc - $count products\n";


	my %codes = ();
	my $true_end = 0;
	my $true_start = 100000000000000000;
	my $complete = 0;
		
	while (my $product_ref = $cursor->next) {
		
		my $code = $product_ref->{code};
		if (not defined $codes{$code}) {
			$codes{$code} = 1;
		}
		else {
			$codes{$code} += 1;
			#print STDERR "code $code seen $codes{$code} times!\n";
		}
		
		foreach my $tagtype (@fields) {
			if ($tagtype eq 'users') {
				$tags{$tagtype}{$product_ref->{creator}}++;
			}
			elsif (defined $product_ref->{$tagtype . "_tags"}) {
				foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
					$tags{$tagtype}{$tagid}++;
					
					if ($tagtype eq 'ingredients') {
						#print STDERR "code: $code - ingredient: $tagid \n";
					}
					
					# nutriment info?
					next if (not defined $product_ref->{nutriments});
					next if (not defined $product_ref->{nutriments}{energy});
					next if (not defined $product_ref->{nutriments}{proteins});
					next if (not defined $product_ref->{nutriments}{carbohydrates});
					next if (not defined $product_ref->{nutriments}{fat});
					$tags{$tagtype . "_nutriments"}{$tagid}++;
				}
			}
		}
		
		foreach my $date (@dates) {
			# print "dates products $lc $date : " . $product_ref->{$date} . "\n";
			if ((defined $product_ref->{$date}) and ($product_ref->{$date} > 0)) {
				$dates{$date}{int($product_ref->{$date} / 86400)}++;
				if ($product_ref->{$date} / 86400 > $true_end) {
					$true_end = int($product_ref->{$date} / 86400);
				}
				if ($product_ref->{$date} / 86400 < $true_start) {
					$true_start = int($product_ref->{$date} / 86400);
				}				
			}
		}		
		
		if (($product_ref->{complete} > 0) and ((not defined $product_ref->{completed_t}) or ($product_ref->{completed_t} <= 0)) ) {
			print "product $code - complete: $product_ref->{complete} , completed_t: $product_ref->{completed_t}\n";
		}
		elsif ($product_ref->{completed_t} > 0) {
			$complete++;
			print "completed products: $complete\n";
		}
		
		$products{$lc}++;
		
	}
	
	foreach my $date (@dates) {
		my @sorted_dates = sort ( {$dates{$date}{$a} <=> $dates{$date}{$b}} keys %{$dates{$date}});
		my $start = $sorted_dates[0];
		my $end = $sorted_dates[$#sorted_dates];
		
		# somehow we don't get the biggest day...
		if ($true_end > $end) {
			$end = $true_end;
		}
		if ($true_start < $start) {
			$start = $true_start;
		}	
		
		$langs_dates{$lc}{$date . ".start"} = $start;
		$langs_dates{$lc}{$date . ".end"} = $end;
		
		#print "dates_stats_$lc lc: $lc - date: $date - start: $start - end: $end\n";
		
		my $current = 0;
		for (my $i = $start; $i <= $end; $i++) {
			$current += $dates{$date}{$i};
			$langs_dates{$lc}{$date}{$i} = $current;
			#print "dates_current_$lc lc: $lc - date: $date - start: $start - end: $end - i: $i - $current\n";
		}
	}


	store("$data_root/index/tags_count.$lc.sto", \%tags);


	foreach my $tagtype (@fields) {

		my @tags;

		if (not defined $taxonomy_fields{$tagtype}) {
			@tags = sort ({$a cmp $b} keys %{$tags{$tagtype}});
		}
		else {
			@tags = sort ( { ($tags{$tagtype}{$b} <=> $tags{$tagtype}{$a}) || ($a cmp $b)  } keys %{$tags{$tagtype}});
		}
		
		my $html = "<h1>" . sprintf(lang("list_of_x"), $Lang{$tagtype . "_p"}{$lang}) . "</h1>";
		
		if (-e "$data_root/lang/$lc/texts/" . get_fileid($Lang{$tagtype . "_p"}{$lang}) . ".list.html") {
			open (my $IN, q{<}, "$data_root/lang/$lc/texts/" . get_fileid($Lang{$tagtype . "_p"}{$lang}) . ".list.html");
			$html .= join("\n", (<$IN>));
			close $IN;
		}
		
		$html .= "<p>" . ($#tags + 1) . " ". $Lang{$tagtype . "_p"}{$lang} . ":</p>";
		
		print "tagtype: $tagtype - " . $Lang{$tagtype . "_p"}{$lang} . " - count: " . ($#tags + 1) . "\n";
		
		my $th_nutriments = '';
		
		if ($tagtype eq 'categories') {
			$th_nutriments = "<th>" . ucfirst($Lang{"products_with_nutriments"}{$lang}) . "</th>";
		}
		
		if ($tagtype eq 'categories') {
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
		my $js = <<JS
var ${tagtype}Tags = [
JS
;
		
		foreach my $tagid (@tags) {
			
			my $link;
			my $products = $tags{$tagtype}{$tagid};
			if ($products == 0) {
				$products = "";
			}

			my $td_nutriments = '';
			if ($tagtype eq 'categories') {
				$td_nutriments .= "<td style=\"text-align:right\">" . $tags{$tagtype . "_nutriments"}{$tagid} . "</td>";
			}
			
			# known tag?
			if ($tagtype eq 'categories') {
				if ((defined $canon_tags{$lc}) and (defined $canon_tags{$lc}{$tagtype}) and (defined $canon_tags{$lc}{$tagtype}{$tagid})) {
					$td_nutriments .= "<td></td>";
				}
				else {
					$td_nutriments .= "<td style=\"text-align:center\">*</td>";
				}
			}
			
			my $link = canonicalize_tag_link($tagtype, $tagid);
			
			my $info = '';
			my $extra_td = '';
			
			if ($tagtype eq 'additives') {
				if ($tags_levels{$lc}{$tagtype}{$tagid}) {
					# $info = ' class="additives_' . $ingredients_classes{$tagtype}{$tagid}{level} . '" title="' . $ingredients_classes{$tagtype}{$tagid}{warning} . '" ';
					my $risk_level = lang("risk_level_" . $tags_levels{$lc}{$tagtype}{$tagid});
					$risk_level =~ s/ /\&nbsp;/g;
					$extra_td = '<td class="level_' . $tags_levels{$lc}{$tagtype}{$tagid} . '">' . $risk_level . '</td>';
				}
				else {
					#$extra_td = '<td class="additives_0">' . lang("risk_level_0") . '</td>';				
					$extra_td = '<td></td>';
				}
			}
			
				if ((defined $tags_levels{$lc}{$tagtype}) and (defined $tags_levels{$lc}{$tagtype}{$tagid})) {
					$info = ' class="level_' . $tags_levels{$lc}{$tagtype}{$tagid} . '" ';
				}			
			
			if (defined $taxonomy_fields{$tagtype}) {
				$html .= "<tr><td>" . display_taxonomy_tag_link($lc,$tagtype,$tagid) . "</td><td style=\"text-align:right\">$products</td>" . $td_nutriments . $extra_td . "</tr>\n";
				$js .= "\n\"" . display_taxonomy_tag($lc,$tagtype, $tagid) . "\",";
			}
			else {
			
				$html .= "<tr><td><a href=\"$link\"$info>" . canonicalize_tag2($tagtype, $tagid) . "</a></td><td style=\"text-align:right\">$products</td>" . $td_nutriments . $extra_td . "</tr>\n";
			$js .= "\n\"" . canonicalize_tag2($tagtype, $tagid) . "\",";
			}
		}
		
		$html .= "</tbody></table></div>";
		
		if ($tagtype eq 'categories') {
			$html .= "<p>La colonne * indique que la catégorie ne fait pas partie de la hiérarchie de la catégorie. S'il y a une *, la catégorie n'est pas dans la hiérarchie.</p>";
		}
		
		my $tagtype_p = $Lang{$tagtype . "_p"}{$lang};
		
		$html .= <<HTML
<initjs>
    oTable = \$('#tagstable').dataTable({
	language: {
		search: "$Lang{tagstable_search}{$lang}",
		info: "_TOTAL_ $tagtype_p",
		infoFiltered: " - $Lang{tagstable_filtered}{$lang}"
	},
	paging: false
    });
</initjs>
<scripts>
<script src="/js/datatables.min.js"></script>
</scripts>
<header>
<link rel="stylesheet" href="/js/datatables.min.css" />
</header>
HTML
;
		
		 #open (OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/texts/" . get_fileid(lang($tagtype . "_p")) . ".html");
		 #print OUT $html;
		 #close OUT;
		 
		$js =~ s/,$//;
		$js .= <<JS
];
JS
;

		(-e "$www_root/js/lang/$lang") or mkdir ("$www_root/js/lang/$lang", 0755);
		 open (my $OUT, ">:encoding(UTF-8)", "$www_root/js/lang/$lang/$tagtype.js");
		 print $OUT $js;
		 close $OUT;
		 
		 
	}
}

my $html = "<p>$total products:</p>";
foreach my $l (sort { $langs{$b} <=> $langs{$a}} keys %langs) {

        if ($langs{$l} > 0) {
                $lang = $l;
                $html .= "<p><a href=\"https://$lang.$server_domain/\">" . $Langs{$l} . "</a> - $langs{$l} " . lang("products") . "</p>";
        }

}

open (my $OUT, ">:encoding(UTF-8)", "$www_root/langs.html");
print $OUT $html;
close $OUT;


my $html = "$total products: ";
foreach my $l (sort { $langs{$b} <=> $langs{$a}} keys %langs) {

        if ($langs{$l} > 0) {
                $lang = $l;
                $html .= "<a href=\"https://$lang.$server_domain/\" title=\"" . $langs{$l} . " " . lang("products").  "\">" . $Langs{$l} . "</a> - ";
        }

}
$html =~ s/ - $//;
open (my $OUT, ">:encoding(UTF-8)", "$www_root/products_langs.html");
print $OUT $html;
close $OUT;


# Number of products and complete products

foreach my $lc (sort keys %langs) {


	my $meta = '';
	if (-e "$www_root/images/misc/products_graph_$lc.png") {
		$meta = <<HTML
<meta property="og:image" content="https://$lc.openfoodfacts.org/images/misc/products_graph_$lc.png"/>
HTML
;
		print "found meta products_graph_$lc.png image\n";
	}

	$lang = $lc;

	my $series = '';
	
	my $end = 0;
	my $start = 100000000000;
	
	foreach my $date (@dates) {
		if ($langs_dates{$lc}{$date . ".start"} < $start) {
			$start = $langs_dates{$lc}{$date . ".start"};
		}
		if ($langs_dates{$lc}{$date . ".end"} > $end) {
			$end = $langs_dates{$lc}{$date . ".end"};
		}
	}	

	foreach my $date (@dates) {
		my @sorted_dates = sort ( {$langs_dates{$lc}{$date}{$a} <=> $langs_dates{$lc}{$b}} keys %{$langs_dates{$lc}{$date}});

		my $series_start = $langs_dates{$lc}{$date . ".start"};
		my $series_end = $langs_dates{$lc}{$date . ".end"};
		
		my $name = $Lang{"products_stats_$date"}{$lang};
		my $series_point_start = $series_start * 86400 * 1000;
		$series .= <<HTML
{
	name: '$name',
	pointInterval: 24 * 3600 * 1000,
    pointStart: $series_point_start,	
	data: [
HTML
;
		
		my $current = 0;
		my $i = 0;
		for (my $t = $series_start ; $t < $end; $t++) {
			if (defined $langs_dates{$lc}{$date}{$t}) {
				$current = $langs_dates{$lc}{$date}{$t};
			}
			$series .= $current . ', ';
			$i++;
			if ($i % 10 == 0) {
				$series =~ s/ $/\n/;
			}
		}
		$series =~ s/,\n?$//;
		$series .= "\n]\n},\n";
	}
	
	$series =~ s/,\n$//;


	
	my $html = <<HTML
<initjs>

Highcharts.setOptions({
	lang: {
		months: $Lang{months}{$lang},
		weekdays: $Lang{weekdays}{$lang}
	}
});

        \$('#container').highcharts({
            chart: {
                type: 'area'
            },
            title: {
                text: '$Lang{products_stats}{$lang} - $Langs{$lang}'
            },
            subtitle: {
                text: 'Source: <a href="https://$lc.openfoodfacts.org">'+
                    '$lc.openfoodfacts.org</a>'
            },
            xAxis: {
		        type: 'datetime',	
            },
            yAxis: {
                title: {
                    text: '$Lang{products_p}{$lang}'
                },
                labels: {
                    formatter: function() {
                        return this.value;
                    }
                }
            },
			tooltip: {
                shared: true
			},
            plotOptions: {
                area: {
                    //pointStart: 1940,
                    marker: {
                        enabled: false,
                        symbol: 'circle',
                        radius: 2,
                        states: {
                            hover: {
                                enabled: true
                            }
                        }
                    }
                }
            },
            series: [
$series
			]
        });

</initjs>   

<scripts>
<script src="/js/highcharts.4.0.4.js"></script></scripts>
<header>
$meta
</header>
 	
<div id="container" style="height: 400px"></div>
	
HTML
;	

	open (my $OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/texts/products_stats.html");
	print $OUT $html;
	close $OUT;

}




# All languages

# Number of products and complete products

my $date = "created_t";


	my $series = '';
	
	my $end = 0;
	my $start = 100000000000;
	
	foreach my $lc (sort keys %langs) {
		if ($langs_dates{$lc}{$date . ".start"} < $start) {
			$start = $langs_dates{$lc}{$date . ".start"};
		}
		if ($langs_dates{$lc}{$date . ".end"} > $end) {
			$end = $langs_dates{$lc}{$date . ".end"};
		}
	}	

	foreach my $lc (sort  { $langs_dates{$a}{$date . ".start"} <=> $langs_dates{$b}{$date . ".start"} } keys %langs) {

	$lang = $lc;	
	
		my @sorted_dates = sort ( {$langs_dates{$lc}{$date}{$a} <=> $langs_dates{$lc}{$b}} keys %{$langs_dates{$lc}{$date}});

		my $series_start = $langs_dates{$lc}{$date . ".start"};
		my $series_end = $langs_dates{$lc}{$date . ".end"};
		
		next if $series_start < 100;
		
		my $name = $Langs{$lc};
		my $series_point_start = $series_start * 86400 * 1000;
		$series .= <<HTML
{
	name: '$name',
	pointInterval: 24 * 3600 * 1000,
    pointStart: $series_point_start,	
	data: [
HTML
;
		
		my $current = 0;
		my $i = 0;
		for (my $t = $series_start ; $t < $end; $t++) {
			if (defined $langs_dates{$lc}{$date}{$t}) {
				$current = $langs_dates{$lc}{$date}{$t};
			}
			$series .= $current . ', ';
			$i++;
			if ($i % 10 == 0) {
				$series =~ s/ $/\n/;
			}
		}
		$series =~ s/,\n?$//;
		$series .= "\n]\n},\n";
	}
	
	$series =~ s/,\n$//;

$lang = 'en';
$lc = 'en';
	
	my $html = <<HTML


        \$('#container').highcharts({
            chart: {
                type: 'area'
            },
            title: {
                text: '$Lang{products_stats}{$lang}'
            },
            subtitle: {
                text: 'Source: <a href="https://openfoodfacts.org">'+
                    'openfoodfacts.org</a>'
            },
			tooltip: {
                shared: true
			},
            xAxis: {
		        type: 'datetime',	
            },
            yAxis: {
                title: {
                    text: '$Lang{products_p}{$lang}'
                },
                labels: {
                    formatter: function() {
                        return this.value;
                    }
                }
            },
            plotOptions: {
                area: {
                    stacking: 'normal',
                    marker: {
                        enabled: false,
                        symbol: 'circle',
                        radius: 2,
                        states: {
                            hover: {
                                enabled: true
                            }
                        }
                    }
                }
            },
            series: [
$series
			]
        });

	
HTML
;	

	open (my $OUT, ">:encoding(UTF-8)", "$www_root/products.js");
	print $OUT $html;
	close $OUT;





exit(0);

