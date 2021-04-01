/* draw SVG graph:
 - id_attach_graph: id of html-item for attaching the graph itself
 - db_graph is same as current_db_for_graph, but packed here together with function
 - prod_ref: object containing all required data for showing object details (score, categories, image, url)
 - prod_matching: array of all matching products objects containing all required information (score, tooltip, etc.)
 - item_display_code_of_selected_product : html item receiving the code of the selected product in the graph (ex.: div's id)
 - open_off_page: true (/false) opens in a separate tab the off page for the selected product in the graph
 */
function draw_graph(id_attach_graph,
                    db_graph,
                    prod_ref,
                    prod_matching,
                    item_display_code_of_selected_product,
                    open_off_page) {
    // Set the dimensions of the canvas / graph
    var margin = {top: 30, right: 30, bottom: 60, left: 50},
        width = GRAPH_WIDTH - margin.left - margin.right - (GRAPH_WIDTH * 4 / 100),
        height = GRAPH_HEIGHT - margin.top - margin.bottom;

    var x = d3.scale.linear().range([0, width]);
    var y = d3.scale.linear().range([height, 0]);

    var nb_categs = (prod_ref.categories_tags == undefined || prod_ref.categories_tags.length == 0) ? 8 : prod_ref.categories_tags.length;
    /* Number of x-axis ticks displayed in the graph (score is then minimum 1-(nb_categs_displayed/nb_categs) ) */
    var nb_categs_displayed = Math.ceil(nb_categs / 2);
    var nb_nutrition_grades = db_graph["scoreNbIntervals"];
    var x_axis_min_value = 1 - (nb_categs_displayed / nb_categs);
    var shift_left_x_values = x_axis_min_value;

    // Define the axes
    var xAxis = d3.svg.axis().scale(x)
        .orient("bottom").ticks(nb_categs_displayed)
        .tickFormat(function (d) {
            if (d == x_axis_min_value)
                return "low";
            if (d == 1)
                return "high";
            return "";
        });

    /* Draw vertical lines for each tick */
    /* ..generates [0..nb_categs_displayed] */
    var rangeCategs = [...Array(nb_categs_displayed + 1).keys()
]
    ;
    var dataX = [];
    rangeCategs.forEach(function (d) {
        if (d > 0) {
            dataX.push(d / nb_categs_displayed);
        }
    });
    var xAxisVertical = d3.svg.axis().scale(x)
            .orient("top").ticks(nb_categs_displayed)
            .tickValues(dataX)
            .innerTickSize([height])
            .outerTickSize([height])
        ;

    var yAxis = d3.svg.axis().scale(y)
        .orient("left")
        .ticks(nb_nutrition_grades)
        .tickFormat(function (d) {
            if (d >= db_graph["scoreMinValue"] && d <= db_graph["scoreMaxValue"]) {
                if (db_graph["bottomUp"] == true) {
                    return db_graph["scoreIntervalsLabels"][d - 1];
                } else {
                    return db_graph["scoreIntervalsLabels"][db_graph["scoreNbIntervals"] - d];
                }
            }
            return "";
        });

    // Define the div for the tooltip
    var div = d3.select("body").append("div")
        .attr("class", "tooltip")
        .style("opacity", 0)
        .style("display", "none");

    // Adds the svg canvas
    var svg = d3.select("body")
        .append("svg")
        .attr("id", "svg_graph")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform",
            "translate(" + margin.left + "," + margin.top + ")");

    /* todo: check because new added */
    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + margin.top + margin.bottom + ")")
        .call(xAxisVertical);


    // Scale the range of the data
    x.domain([x_axis_min_value, 1]);
    y.domain([0, nb_nutrition_grades]);

    /*var data_rect = [{'v': 1, 'color': 'rgb(230,62,17)'}, {'v': 2, 'color': 'rgb(238,129,0)'}, {
     'v': 3,
     'color': 'rgb(254,203,2)'
     }, {'v': 4, 'color': 'rgb(133,187,47)'}, {'v': 5, 'color': 'rgb(3,129,65)'}];*/

    /* Draw coloured stripes from bottom to top (bottom-up direction) */
    var data_rect_2 = [];
    var rangeInterval = (db_graph["scoreMaxValue"] - db_graph["scoreMinValue"] + 1);
    var step_for_stripe = rangeInterval / db_graph["scoreNbIntervals"];
    var indx_array = 0;
    for (var i = db_graph["scoreMinValue"]; i <= db_graph["scoreMaxValue"]; i += step_for_stripe) {
        // Tick number: when starting, equals 0 + stripe's step
        numTick = (i - db_graph["scoreMinValue"]) + step_for_stripe;
        data_rect_2.push({'v': i, 'color': db_graph["scoreIntervalsStripeColour"][indx_array]});
        indx_array++;
    }

    svg.selectAll("rect")
        .data(data_rect_2)
        .enter()
        .append("rect")
        .attr("width", width)
        .attr("height", height / db_graph["scoreNbIntervals"])
        .attr("y", function (d) {
            if (db_graph["bottomUp"] == true) {
                return (rangeInterval - d.v) * height / rangeInterval;
            } else {
                return (d.v - step_for_stripe) * height / rangeInterval;
            }
        })
        .attr("fill", function (d) {
            return d.color
        });
    // *****

    // Add the scatterplot
    // .. for the product reference
    var data_prod_ref = [{'score': 1}];
    if (prod_ref.length != 0)
        data_prod_ref = [{'score': prod_ref["score"]}];
    svg.selectAll("ellipse")
        .data(data_prod_ref)
        .enter().append("ellipse")
        .attr("cx", width * (1 - (1 / nb_categs_displayed) / 2))
        .attr("cy", function (d) {
            if (db_graph["bottomUp"] == true) {
                return (height * (1 - (d.score / nb_nutrition_grades)) + (height / nb_nutrition_grades * 0.5));
            } else {
                return (height * ((d.score - 1) / nb_nutrition_grades) + (height / nb_nutrition_grades * 0.5));
            }
        })
        .attr("rx", width / nb_categs_displayed * 0.5)
        .attr("ry", (height / nb_nutrition_grades) * 0.5)
        .attr("fill", "#ffffff")
        .attr("fill-opacity", 0.75);

    /* Filtering of matching products to suggest, and extraction of minimum abscisse in order to determine the width of the square box for suggestions */
    //data_prod_ref[0].y_val_real = data_prod_ref[0].score;
    var prods_filtered_for_graph = filter_suggestions(data_prod_ref[0], prod_matching, db_graph);
    prods_filtered_for_graph.sort(function_sort_min_abscisse);

    var square_of_suggestions = undefined;
    if (db_graph["bottomUp"] == true) {
        square_of_suggestions = [{
            "width": prods_filtered_for_graph.length == 0 ? (1 / nb_categs_displayed) : (1 - prods_filtered_for_graph[0].x) * (nb_categs / nb_categs_displayed),
            /* Height of the suggestion square is the range of intervals minus the difference between the score of product ref. and the min. value */
            "height": data_prod_ref[0].score == db_graph["scoreMaxValue"] ? 1 : (rangeInterval - (data_prod_ref[0].score - (db_graph["scoreMinValue"] - 1)))
        }];
    } else {
        // width unchanged, but height is reversed
        square_of_suggestions = [{
            "width": prods_filtered_for_graph.length == 0 ? (1 / nb_categs_displayed) : (1 - prods_filtered_for_graph[0].x) * (nb_categs / nb_categs_displayed),
            "height": data_prod_ref[0].score == db_graph["scoreMinValue"] ? 1 : (data_prod_ref[0].score - 1)
        }];
    }
    svg.selectAll("polyline")
        .data(square_of_suggestions)
        .enter().append("polyline")
        .style("stroke", "black")  // colour the line
        .style("fill", "none")     // remove any fill colour
        .attr("points", function (d) {
            w = width * d.width + CIRCLE_RADIUS_SELECTED;
            h = d.height * (height / rangeInterval);
            rect_points = width + "," + 0 + ", " + width + "," + h + ", " + (width - w) + "," + h + ", " + (width - w) + "," + 0 + ", " + width + "," + 0;
            return rect_points
        })
    ;

    // .. for all matching products
    var data_others = prod_matching;

    svg.selectAll("circle")
        .data(data_others)
        .enter().append("circle")
        .attr("r", CIRCLE_RADIUS_DEFAULT)
        .attr("stroke", "#000080")
        .attr("stroke-width", 1)
        .attr("fill", CIRCLE_COLOR_DEFAULT)
        .attr("cx", function (d, i) {
            // Store position of svg.circle in the product itself for leveraging browsing in the suggestion panel
            d.num_circle = i;
            return (d.x - shift_left_x_values) * nb_categs / nb_categs_displayed * width;
        })
        .attr("cy", function (d) {
            if (db_graph["bottomUp"] == true) {
                return height * (1 - d.y / nb_nutrition_grades);
            } else {
                return height * (d.y / nb_nutrition_grades);
            }
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
            $(item_display_code_of_selected_product).val(d.code);
            $(item_display_code_of_selected_product).css("background-color", OFF_BACKGROUND_COLOR);
            if (open_off_page) {
                window.open(d.url, '_blank');


            }
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
        .style("font-size", "inherit")
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
        .style("font-size", "inherit")
        .text(db_graph["scoreLabelYAxis"]);

    $(id_attach_graph).empty();
    $("svg").detach().appendTo(id_attach_graph);
};;

function display_product_ref_details(prod_ref,
                                     id_code,
                                     id_input_code,
                                     id_name,
                                     id_img,
                                     id_categories,
                                     id_off,
                                     id_json,
                                     id_warning) {
    // update globals
    current_product = prod_ref;

    code = prod_ref["code"];
    name = prod_ref["name"];
    image = prod_ref["images"];
    if (image == "") {
        image = prod_ref["image_fake_off"];
    }
    no_nutriments = prod_ref["no_nutriments"];
    categories = prod_ref["categories_tags"].join("<br />");
    url_off = prod_ref["url_product"];
    /* replace 'world' with country code if available */
    country_code = undefined;
    if (user_country != undefined) {
        country_code = user_country[0].en_code;
    }
    if (country_code != undefined) {
        url_off = url_off.replace("//" + URL_OFF_DEFAULT_COUNTRY.toLowerCase() + ".", "//" + country_code.toLowerCase().trim() + ".");
    }
    url_json = prod_ref["url_json"];
    style_for_border_colour = "grade_" + prod_ref["score"];
    $(id_code).empty();
    $(id_code).append(code);
    $(id_input_code).empty();
    $(id_input_code).append(code);
    $(id_name).empty();
    $(id_name).append(name);
    $(id_img).attr("src", image);
    $(id_img).attr("height", "" + ($(window).innerHeight() / 7) + "px");
    $(id_img).attr("class", style_for_border_colour);
    $(ID_IMG_OFF).attr("height", "" + ($(window).innerHeight() / 7 / 3) + "px");
    $(ID_IMG_OFF).attr("max-height", "28px");
    $(ID_IMG_JSON).attr("height", "" + ($(window).innerHeight() / 7 / 3) + "px");
    $(ID_IMG_JSON).attr("max-height", "28px");
    /*$(id_img).attr("height", "35px");*/
    $(id_categories).empty();
    $(id_categories).append(categories);
    $(id_off).attr("href", url_off);
    $(id_json).attr("href", url_json);
    $(id_warning).empty();
    if (no_nutriments) {
        $(id_warning).append(MSG_NO_NUTRIMENTS_PROD_REF);
    }
}

function draw_page(prod_ref, prod_matching) {
    display_product_ref_details(prod_ref,
        ID_PRODUCT_CODE,
        ID_INPUT_PRODUCT_CODE,
        ID_PRODUCT_NAME,
        ID_PRODUCT_IMG,
        ID_PRODUCT_CATEGORIES,
        ID_PRODUCT_OFF,
        ID_PRODUCT_JSON,
        ID_WARNING);
    draw_graph(ID_GRAPH,
        current_db_for_graph,
        prod_ref,
        prod_matching,
        ID_INPUT_PRODUCT_CODE,
        OPEN_OFF_PAGE_FOR_SELECTED_PRODUCT);
    make_suggestions(prod_ref, prod_matching, current_db_for_graph);
}

