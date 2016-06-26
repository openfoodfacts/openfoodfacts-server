package Blogs::Graph;
use strict;
use warnings FATAL => 'all';
use Blogs::PointRepartition qw/:all/;
use Blogs::Product qw/:all/;
use Blogs::Tags qw/:all/;
use CGI qw/:cgi :form escapeHTML/;

# Handle statistics:
# - gather and prepare data to show
# - build graph

sub new {
    my $class = shift;
    my $self = {
        # stats_props: array of product properties used to build the graph
        stats_props       => shift,
        # product-ref: Product reference
        product_ref       => shift,
        # products_others: array of all other products whose scores are compared with the score of the product reference
        products_matching => shift,
        # verbose: 0/1
        verbose           => shift
    };
    #    print "product ref categories = ", $self->{product_ref}->{dic_props}->{categories_tags}[0], "\n";
    # Initialize all structures for the final graph

    # x, y coordinates on the graph and label to display for the product reference
    $self->{xaxis_prod_ref_real} = ();
    $self->{yaxis_prod_ref_real} = ();
    $self->{label_prod_ref} = ();

    # x, y coordinates on the graph and label to display for all matching products
    $self->{xaxis_others_real} = ();
    $self->{yaxis_others_real} = ();
    $self->{labels_others} = ();
    $self->{url_others} = ();

    # Graph uses its own data set which is a conversion of products_matching: preparation of these datasets
    $self->{data_set_ref} = ();
    $self->{data_set_others} = ();
    $self->{xaxis_others_distributed} = ();
    $self->{yaxis_others_distributed} = ();

    bless $self, $class;
    return $self;
}

sub show {
    my ( $self ) = @_;
    $self->prepare_data();
    $self->prepare_graph();
}

sub prepare_data {
    my ( $self ) = @_;

    if ($self->{verbose} eq 1) {
        print ".. preparing the data for the show \n";
    }

    # preparing product reference
    my $product_ref = $self->{product_ref};
    my $product_ref_props = $product_ref->{dic_props};
    my $mini_prod->{"code"} = $product_ref_props->{"code"};
    $mini_prod->{"generic_name"} = $product_ref_props->{"generic_name"};
    $mini_prod->{"brands_tags"} = $product_ref_props->{"brands_tags"};
    $mini_prod->{"url_product"} = $product_ref_props->{"url_product"};
    $mini_prod->{"url_img"} = $product_ref_props->{"url_img"};
    $mini_prod->{"lc"} = $product_ref_props->{"lc"};
    $mini_prod->{"images"} = $product_ref_props->{"images"};
    $mini_prod->{"score_proximity"} = $product_ref->{score_proximity};
    $mini_prod->{"score_nutrition"} = $product_ref->{score_nutrition};
    $mini_prod->{"x_val_real"} = $product_ref->{score_proximity};
    $mini_prod->{"y_val_real"} = $self->convert_scoreval_to_note( $product_ref->{score_nutrition} );

    push( @{$self->{data_set_ref}}, $mini_prod );

    # preparing data for all other matching products
    foreach my $product_other (@{$self->{products_matching}}) {
        my $product_other_ref_props = $product_other->{dic_props};
        my $mini_prod_other->{"code"} = $product_other_ref_props->{"code"};
        $mini_prod_other->{"generic_name"} = $product_other_ref_props->{"generic_name"};
        $mini_prod_other->{"brands_tags"} = $product_other_ref_props->{"brands_tags"};
        $mini_prod_other->{"url_product"} = $product_other_ref_props->{"url_product"};
        $mini_prod_other->{"url_img"} = $product_other_ref_props->{"url_img"};
        $mini_prod_other->{"lc"} = $product_other_ref_props->{"lc"};
        $mini_prod_other->{"images"} = $product_other_ref_props->{"images"};

        $product_other->Blogs::Product::compute_scores( $product_ref );

        $mini_prod_other->{"score_proximity"} = $product_other->{score_proximity};
        $mini_prod_other->{"score_nutrition"} = $product_other->{score_nutrition};
        $mini_prod_other->{"x_val_real"} = $product_other->{score_proximity};
        $mini_prod_other->{"y_val_real"} = $self->convert_scoreval_to_note( $product_other->{score_nutrition} );

        push ( @{$self->{xaxis_others_real}}, $mini_prod_other->{"x_val_real"} );
        push ( @{$self->{yaxis_others_real}}, $mini_prod_other->{"y_val_real"} );
        push ( @{$self->{data_set_others}}, $mini_prod_other );
    }
}

sub prepare_graph {
    my ( $self ) = @_;

    my $product_ref = $self->{product_ref};
    my $product_ref_props = $product_ref->{dic_props};

    print ".. preparing the graph itself with d3.js \n";
    my $nb_categs_ref = scalar( @{$product_ref_props->{"categories_tags"}} );
    print scalar( @{$product_ref_props->{"categories_tags"}} ), "\n";

    #    print @{$self->{data_set_ref}}, "\n";
    #    print "b0 \n";
    #    my $mini_prod = $self->{data_set_ref};
    #    print $mini_prod->{"x_val_real"}, "\n";
    #    print "b0..1 \n";
    #    print $self->{data_set_ref}->{"x_val_real"}, "\n";
    #    print "b1 \n";
    #    print "!!! ", @{$self->{data_set_ref}}[0]->{"y_val_real"}, "\n";
    push ( @{$self->{xaxis_prod_ref_real}}, $nb_categs_ref * @{$self->{data_set_ref}}[0]->{"x_val_real"} );
    push ( @{$self->{yaxis_prod_ref_real}}, @{$self->{data_set_ref}}[0]->{"y_val_real"} );
    my $label_prod_ref = @{$self->{data_set_ref}}[0]->{"code"};
    push ( @{$self->{label_prod_ref}}, $label_prod_ref );

    # prepare for all other matching products
    # ..using a uniform repartition
    my $nb_particles = scalar @{$self->{data_set_others}};
    my $sample = Blogs::PointRepartition->new( $nb_particles );

    my @all_positions = $sample->new_positions_disc_coordinates();
    my $x = $all_positions[0];
    my $y = $all_positions[1];
    my $nb_items = scalar( @{$x} );
    #    print "x = ", @{$x}, " // y = ", @{$y}, " \n";
    my $v_x = ();
    my $v_y = ();
    for (my $i = 0; $i < $nb_items; $i++) {
        push ( @{$v_x}, $x->[$i] );
        push ( @{$v_y}, $y->[$i] );
    }
    for (my $j = 0; $j < (scalar @{$v_x}); $j++) {
        my $mini_prod = $self->{data_set_others}[$j];
        my $x_j = $mini_prod->{"x_val_real"};
        my $y_j = $mini_prod->{"y_val_real"};
        # NOTE: since we display 2 graphs (1 for all points, and 1 for the coloured stripes A..E with a specific design
        # ..for the cell matching the product reference, we need to extend the x values (multiplied by the number
        # ..of categories of the product reference)
        my $x_coord = $x_j - ((1 + @{$v_x}[$j]) / (2 * $nb_categs_ref));
        my $y_coord = $y_j - (0.5 * (1 - @{$v_y}[$j]));
        push ( @{$self->{xaxis_others_distributed}}, $x_coord );
        push ( @{$self->{yaxis_others_distributed}}, $y_coord );
        my $code_mini_prod = $mini_prod->{"code"};
        # todo: check hard-coded url : world or fr??
        my $url_prod = "http://fr.openfoodfacts.org/produit/${code_mini_prod}";
        # todo: image_front_url available in production Mongo-Db but NOT in the API Data? In case property not found, take default image
        my $url_img = $mini_prod->{"image_front_url"} || "http://static.openfoodfacts.org/images/products/800/150/500/3529/front_fr.21.400.jpg";
        my $the_label = "<div style = 'background-color: #ffffff'>"
            .$mini_prod->{"generic_name"}."<br/>"
            .(join "/", @{$mini_prod->{"brands_tags"}})."/"
            ."<br/>"
            ."<img src='".$url_img."' height = '125px' />"
            ."<br/></div>";
        push ( @{$self->{url_others}}, $url_prod );
        push ( @{$self->{labels_others}}, $the_label );
    }

    print ".. outputting in file.. \n";

    print "\n";
    print "Product ref. x / y: ", $self->{xaxis_prod_ref_real}[0], " / ", $self->{yaxis_prod_ref_real}[0], "\n";
    print "Matching products with COUNTER:\n";
    print "\t Counter(x): <hard> \n";
    print "\t x = ", $self->{xaxis_others_distributed}, "\n";
    print "\t Counter(y): <hard> \n";
    print "\t y = ", $self->{yaxis_others_distributed}, "\n";

    # ouput HTML content

    my $html .= <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="iso-8859-1">
    <style> /* set the CSS */
      body {
        font: 11px Arial;
      }

      .axis path,
      .axis line {
        fill: none;
        stroke: grey;
        stroke-width: 2;
        shape-rendering: crispEdges;
      }
      div.tooltip {
        position: absolute;
        text-align: center;
        width: 120px;
        height: 120px;
        padding: 2px;
        font: 10px sans-serif;
        background: lightsteelblue;
        border: 0;
        border-radius: 8px;
        pointer-events: none;
      }
    </style>
</head>
<body>
    <div style='text-align: center'>
        <h2>Your selected product : $Lang{$product_ref_props->{generic_name}}  [$Lang{$product_ref_props->{code}}]</h2>
    </div>
    <!-- load the d3.js library -->
    <script src="http://d3js.org/d3.v3.min.js"></script>
    <script>
    // Set the dimensions of the canvas / graph
                            var margin = {top: 30, right: 30, bottom: 60, left: 50},
    width = 1000 - margin.left - margin.right,
        height = 600 - margin.top - margin.bottom;
    var x = d3.scale.linear().range([0, width]);
    var y = d3.scale.linear().range([height, 0]);
    var nb_categs = $Lang{$nb_categs_ref};
    var nb_nutrition_grades = 5;
    // Define the axes
    var xAxis = d3.svg.axis().scale(x)
            .orient("bottom").ticks(nb_categs)
            .tickFormat(function (d) {
                if (d == 0)
                    return "very low";
                if (d == 1)
                    return "very high";
                return "";
            });
    var yAxis = d3.svg.axis().scale(y)
            .orient("left")
            .ticks(nb_nutrition_grades)
            .tickFormat(function (d) {
                if (d == 1)
                    return "E";
                if (d == 2)
                    return "D";
                if (d == 3)
                    return "C";
                if (d == 4)
                    return "B";
                if (d == 5)
                    return "A";
                return "";
            });

    // Define the div for the tooltip
    var div = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("opacity", 0);

    // Adds the svg canvas
    var svg = d3.select("body")
            .append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .append("g")
            .attr("transform",
            "translate(" + margin.left + "," + margin.top + ")");
    // taken from my Python project as d3_json object
    // Scale the range of the data
    x.domain([0, 1]);
    y.domain([0, nb_nutrition_grades]);
    var data_rect = [{'v': 1, 'color': 'rgb(240,0,0)'},
                     {'v': 2, 'color': 'rgb(255,1,128)'},
                     {'v': 3, 'color': 'rgb(255,103,1)'},
                     {'v': 4, 'color': 'rgb(255,242,0)'},
                     {'v': 5, 'color': 'rgb(0,255,0)'}];
    svg.selectAll("rect")
         .data(data_rect)
       .enter()
         .append("rect")
         .attr("width", width)
         .attr("height", height / 5)
         .attr("y", function (d) {
           return (5 - d.v) * height / 5
         })
         .attr("fill", function (d) {
           return d.color
         })
         .attr("fill-opacity", .5);
    // Add the scatterplot
    // .. for the product reference
    var data_prod_ref = [{'nutrition_grade': 1}];
    var data_prod_ref = [{'nutrition_grade': $Lang{ $self->{yaxis_prod_ref_real}[0] }}];
    svg.selectAll("ellipse")
         .data( data_prod_ref )
       .enter().append("ellipse")
         .attr("cx", width * (1 - (1 / nb_categs) / 2))
         .attr("cy", function (d) {
           return (height * (1 - (d.nutrition_grade / nb_nutrition_grades)) + (height / nb_nutrition_grades * 0.5));
         })
         .attr("rx", width / nb_categs * 0.5)
         .attr("ry", (height / nb_nutrition_grades) * 0.5)
         .attr("fill", "#ffffff")
         .attr("fill-opacity", 0.75);
    // .. for all matching products
    var data_others = [
HTML
    ;

    for (my $i = 0; $i < scalar( @{$self->{xaxis_others_distributed}} ); $i++)
    {
        if ($i != 0) {
            print $fh ", ";
        }
        my $content = "'content': \"".$self->{labels_others}[$i]."\"";
        my $url = "'url': '".$self->{url_others}[$i]."'";
        $html .= <<HTML
            {'y': $Lang{ $self->{yaxis_others_distributed}[$i] }, 'x': $Lang{ $self->{xaxis_others_distributed}[$i] }, $Lang{$content}, $Lang{$url} }
HTML
        ;
    }
    $html .= <<HTML
];
HTML
    ;

    $html .= <<HTML
svg.selectAll("circle")
.data(data_others)
.enter().append("circle")
.attr("r", 3)
.attr("stroke", "#000080")
.attr("stroke-width", 1)
.attr("fill", "steelblue")
.attr("cx", function (d) {
return d.x * width;
})
.attr("cy", function (d) {
return height * (1 - d.y / nb_nutrition_grades);
})
.on("mouseover", function (d) {
div.transition()
.duration(200)
.style("opacity", .85);
div.html(d.content)
.style("left", (d3.event.pageX) + "px")
.style("top", (d3.event.pageY - 28) + "px");
})
.on("mouseout", function (d) {
div.transition()
.duration(500)
.style("opacity", 0);
})
.on("click", function (d) {
window.open(d.url);
});
// Add the X Axis
svg.append("g")
.attr("class", "x axis")
.attr("transform", "translate(0," + height + ")")
.call(xAxis);
// Add the X-axis label
svg.append("text")
.attr("x", width * 0.5)
.attr("y", height + 30)
.attr("dy", "1em")
.style("text-anchor", "middle")
.style("font-size", "14pt")
.text("Similarity with product reference");
// Add the Y Axis
svg.append("g")
.attr("class", "y axis")
.call(yAxis);
// Add the Y-axis label
svg.append("text")
.attr("transform", "rotate(-90)")
.attr("x", -(height * 0.5))
.attr("y", -45)
.attr("dy", "1em")
.style("text-anchor", "middle")
.style("font-size", "14pt")
.text("Nutrition grade");
</script>
  </body>
</html>
HTML
    ;

    # todo: copied from search.pl. please update accordingly
    ${$request_ref->{content_ref}} .= $html;
    $request_ref->{title} = lang("search_products");
    display_new($request_ref);

    print ".. graph finished! .. ciao man";

}

sub convert_scoreval_to_note {
    my ( $self, $score_nutrition) = @_;
    $self->{score_nutrition} = $score_nutrition if defined( $score_nutrition );
    #    print "convert scoreval to note = $score_nutrition \n";
    # todo: distinguer Eaux et Boissons des aliments solides .. ici, que aliments solides
    # ici http://fr.openfoodfacts.org/score-nutritionnel-france
    # A - Vert : jusqu'à -1
    # B - Jaune : de 0 à 2
    # C - Orange : de 3 à 10
    # D - Rose : de 11 à 18
    # E - Rouge : 19 et plus
    if ($score_nutrition < 0) {
        return 5;  # A
    } else {
        if ($score_nutrition < 3) {
            return 4;  # B
        } else {
            if ($score_nutrition < 11) {
                return 3;  # C
            } else {
                if ($score_nutrition < 19) {
                    return 2;  # D
                } else {
                    return 1;  # E
                }
            }
        }
    }
}

1;
