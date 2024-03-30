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

ProductOpener::View::Graph - HTTP response as a Graph

=cut

package ProductOpener::View::Graph;
use ProductOpener::PerlStandards;

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
		title => escape_single_quote_and_newlines(lang("number_of_products")),
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



1;

