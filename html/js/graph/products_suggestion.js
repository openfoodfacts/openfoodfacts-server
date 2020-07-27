/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) Richard on 08/05/18.
 */
var suggested_products = [];
/*
 [x, y]: x = number of product selected once products filtered and ordered
 note: in order to access the circle drawn in the graph, use suggested_products[x].num_circle
 y = DOM-image of selected product
 */
var client_current_selection = [-1, undefined];

function cleanup_suggestions() {
    /* clear previous suggestions if any */
    $(ID_PRODUCTS_SUGGESTION).empty();
    $(ID_NB_SUGGESTIONS).empty();
    $(ID_NB_SUGGESTIONS).append(0);
    $(ID_PRODUCTS_SUGGESTION).attr("height", "" + (6 + $(window).innerHeight() / 3) + "px");
    $(ID_PRODUCTS_SUGGESTION).append("<ul></ul>");
    $(ID_MENU_SELECTION).attr("height", "" + ($(window).innerHeight() / 5) + "px");

}

function get_graph_stripe_colour (db_graph, score_of_product) {
    // Compute which stripe colour to set for the border of product suggested
    indx_colour_stripe = undefined;
    if (db_graph["bottomUp"] == true) {
        indx_colour_stripe = (db_graph["scoreIntervalsStripeColour"].length - 1) - (db_graph["scoreMaxValue"] - score_of_product);
    } else {
        indx_colour_stripe = score_of_product - db_graph["scoreMinValue"];
    }

    return db_graph["scoreIntervalsStripeColour"][indx_colour_stripe];
}

function make_suggestions(product_ref, products, db_graph) {
    client_current_selection = [-1, undefined];
    cleanup_suggestions();

    if (products.length > 0) {
        /* sort products by: 1) desc proximity with product reference, 2) score */
        products = filter_suggestions(product_ref, products, db_graph);
        if (db_graph["bottomUp"] == true) {
            products.sort(function_sort_products_bottomUp);
        } else {
            products.sort(function_sort_products_upToBottom);
        }
        suggested_products = products.slice(0, MAX_SUGGESTIONS);
        $(ID_NB_SUGGESTIONS).empty();
        $(ID_NB_SUGGESTIONS).append(suggested_products.length);
        suggested_products.forEach(function (product, index) {
            // $(ID_PRODUCTS_SUGGESTION + " > div").append("<div class='cell_suggestion' onclick='alert("+cx+")'><img src='" + product.img + "' height='150px' /></div>");
            style_for_border_colour = "border-color: " + get_graph_stripe_colour(db_graph, product.score);
            $(ID_PRODUCTS_SUGGESTION + " > ul").append("<li><img id='" + ID_PRODUCT_IMAGE_PARTIAL + index + "' src='" + product.img + "' class='grade_border' style='" + style_for_border_colour + "' height='250px' onclick='process_selected_suggestion(this, " + index + ")' /></li>");
        });
    }
}

function process_selected_suggestion(img_selected, index) {
    deactivate_previous_selection();
    client_current_selection[0] = index;
    client_current_selection[1] = img_selected;
    activate_selection();

}

function deactivate_previous_selection() {
    if (client_current_selection[0] > -1) {
        rangeInterval = (current_db_for_graph["scoreMaxValue"] - current_db_for_graph["scoreMinValue"] + 1);

        style_for_border_colour = "border-color: " + get_graph_stripe_colour(current_db_for_graph, suggested_products[client_current_selection[0]].score);
        client_current_selection[1].setAttribute("style", style_for_border_colour);

        circle_node = $("#svg_graph")[0].childNodes[0]
            .childNodes[suggested_products[client_current_selection[0]].num_circle + SHIFT_ARRAY_POSITION_SVG_CIRCLES_VS_PRODUCTS + rangeInterval];
        circle_node.setAttribute("r", "" + CIRCLE_RADIUS_DEFAULT + "");
        circle_node.setAttribute("fill", CIRCLE_COLOR_DEFAULT);
    }
}

function activate_selection() {
    rangeInterval = (current_db_for_graph["scoreMaxValue"] - current_db_for_graph["scoreMinValue"] + 1);
    // Box around selection in the ribbon
    client_current_selection[1].setAttribute("class", "product_selected");
    client_current_selection[1].setAttribute("style", "");
    // focus circle bound to selection
    circle_node = $("#svg_graph")[0].childNodes[0]
        .childNodes[suggested_products[client_current_selection[0]].num_circle + SHIFT_ARRAY_POSITION_SVG_CIRCLES_VS_PRODUCTS + rangeInterval];
    circle_node.setAttribute("r", "" + CIRCLE_RADIUS_SELECTED + "");
    circle_node.setAttribute("fill", CIRCLE_COLOR_SELECTED);
    $(ID_INPUT_PRODUCT_CODE).val(suggested_products[client_current_selection[0]].code);
    /*selected_product_url = suggested_products[client_current_selection[0]].url;
     window.open(selected_product_url, '_blank');*/
}

/*
 shift: positive or negative to select a picture after left/right button has been pressed
 */
function select_picture(shift) {
    if (suggested_products.length > 0) {
        curr_pos = client_current_selection[0];
        if (curr_pos < 0) {
            curr_pos = 0;
        } else {
            curr_pos += shift;
            // check out-of-bound
            if (curr_pos < 0) {
                curr_pos = 0;
            }
            if (curr_pos > (suggested_products.length - 1)) {
                curr_pos = suggested_products.length - 1;
            }
        }
        deactivate_previous_selection();
        client_current_selection[0] = curr_pos;
        next_image = $("#" + ID_PRODUCT_IMAGE_PARTIAL + curr_pos)[0];
        client_current_selection[1] = next_image;
        activate_selection();
    }
}

function show_details() {
    curr_prod = suggested_products[client_current_selection[0]];
    style_for_border_colour = "border-color: " + get_graph_stripe_colour(current_db_for_graph, curr_prod.score);
    $(ID_DETAILS_SELECTED_PRODUCT).empty();

    /* Replace world with country selected by the user in the GUI in the url 
     of the product to access the regionalized OFF page directly */
    curr_prod.url = urlReplaceWorldWithSelectedCountry(curr_prod.url);
    $(ID_DETAILS_SELECTED_PRODUCT).append("<table class='table_sel_prod'><tr><td class='sel_prod_img'>" +
        "<div><a href='" + curr_prod.url + "' target='_blank'>" +
        "<img src='" + curr_prod.img + "' class='grade_border' style='" + style_for_border_colour + "' /></a></div></td>" +
        "<td class='sel_prod_header'><div class='sel_prod_code'>" + curr_prod.code + "</div><br /><div class='sel_prod_brands'>" +
        curr_prod.brands + "</div><br /><div class='sel_prod_name'>" + curr_prod.name + "</div>" +
        "<div class='sel_prod_similarity'>[Similarity: " + curr_prod.score_proximity + "%]</div></td></tr></table>");
    $(ID_DETAILS_SELECTED_PRODUCT).append(curr_prod.categories);
    $(ID_DETAILS_SELECTED_PRODUCT).append("<div class='close_details_sel_prod' onclick='hide_details()'>close</div>");
    $(ID_DETAILS_SELECTED_PRODUCT).css({opacity: 0, width: $(document).width(), height: $(document).height()});
    $(ID_DETAILS_SELECTED_PRODUCT).addClass('detailsProduct');
    $(ID_DETAILS_SELECTED_PRODUCT).show();
    $(ID_DETAILS_SELECTED_PRODUCT).animate({opacity: 0.95}, 100);
}

function hide_details() {
    $(ID_DETAILS_SELECTED_PRODUCT).empty();
    $(ID_DETAILS_SELECTED_PRODUCT).animate({opacity: 0}, 100, function () {
        $(ID_DETAILS_SELECTED_PRODUCT).hide();
    });
}

function go_search() {
    curr_prod = client_current_selection[0];
    if (curr_prod >= 0) {
        code_product = suggested_products[curr_prod].code;
        $(ID_INPUT_PRODUCT_CODE).val(code_product);
        $(ID_INPUT_PRODUCT_CODE).css("background-color", OFF_BACKGROUND_COLOR);
        $(ID_BTN_SUBMIT).click();
    }
}