// Declaration of d3 variable (cf. d3js)
var d3;

// **************
// constants_endpoints
// **************
// Endpoints (cf. REST endpoints in App.py)
var URL_ROOT_API = "https://tuttifrutti.alwaysdata.net/";
var ENDPOINT_STORES = "/fetchStores/";
var ENDPOINT_SCORE_DBS = "/fetchScoreDbs";

/*
 * purpose: Constants related to template page stats.html for displaying the statistics of database_aggregation into a table
 */

// json properties for each database
var FLD_DB_DISPLAY_NAME = "dbDisplayName";
var FLD_DB_NICK_NAME = "dbNickname";

// **************
// constants
// **************

// Minimum proximity of matching products with reference-product for being part of suggestions
var MAX_STORES_TO_SHOW_PER_COUNTRY = 100;
var MIN_SCORE_FOR_SUGGESTIONS = 70;
var MAX_SUGGESTIONS = 50;
// popup messages
var MSG_WAITING_SCR_FETCH_STORES = ".. fetching stores ..";
var MSG_WAITING_SCR_MATCH_REQUEST = ".. please wait ..";

// url parameters (optional)
var URL_PARAM_BARCODE="barcode";
var URL_PARAM_COUNTRY="country";
var URL_PARAM_SCORE="score";

var GRAPH_WIDTH = $(window).innerWidth() * 75 / 100;
var GRAPH_HEIGHT = $(window).innerHeight() * 40 / 100;
var OPEN_OFF_PAGE_FOR_SELECTED_PRODUCT = false;
var PRODUCT_CODE_DEFAULT = '3960145823988';

/* ids of html-item for attaching graph data and product reference details (image, etc.) */
var ID_SERVER_ACTIVITY = "#server_activity";
var ID_PRODUCT_CODE = "#prod_ref_code";
var ID_PRODUCT_NAME = "#prod_ref_name";
var ID_INPUT_PRODUCT_CODE = "#input_product_code";
var ID_INPUT_COUNTRY = "#input_country";
var ID_INPUT_STORE = "#input_store";
var ID_INPUT_SCORE_DB = "#input_score_db";
var ID_PRODUCT_IMG = "#prod_ref_image";
var ID_PRODUCT_CATEGORIES = "#prod_ref_categories";
var ID_PRODUCT_OFF = "#url_off_prod";
var ID_PRODUCT_JSON = "#url_off_json_prod";
var ID_GRAPH = "#graph";
var ID_WARNING = "#msg_warning_prod_ref";
var ID_IMG_OFF = "#img_off_prod";
var ID_IMG_JSON = "#img_off_json";
var ID_PRODUCTS_SUGGESTION = "#products_suggestion";
var ID_SUGGESTION_DETAILS = "#suggestion_details";
var ID_SUGGESTION_LEFT = "#suggestion_left";
var ID_SUGGESTION_RIGHT = "#suggestion_right";
var ID_MENU_SELECTION = "#menu_selection";

// no # in partial id below !! (used to assign live ids to products' images)
var ID_PRODUCT_IMAGE_PARTIAL = "prod_img_";
var ID_NB_SUGGESTIONS = "#nb_suggestions";
var ID_DETAILS_SELECTED_PRODUCT = "#selected_product_details";

// Messages
var MSG_NO_NUTRIMENTS_PROD_REF = "Beware: no nutriments are known for this product.. check in OFF for details!";
var MSG_NO_DATA_RETRIEVED = "NO MATCH FOUND!";

// Others
// Circles drawn in SVG in the graph are appended after some basic other SVG-items; thereafter, 1 circle is bound to 1 product with the shift constant below plus the range of interval of Y-axis (number of stripes appended to the graph!)
var SHIFT_ARRAY_POSITION_SVG_CIRCLES_VS_PRODUCTS = 3;
var CIRCLE_COLOR_DEFAULT = "steelblue";
var CIRCLE_COLOR_SELECTED = "red";
var CIRCLE_RADIUS_DEFAULT = 5;
var CIRCLE_RADIUS_SELECTED = 15;

// file location listing all countries in OFF
var FILE_COUNTRIES = "/static/data/countries.json";

/* addition of extra properties to ease sorting */
var COUNTRY_PROPERTY_EN_LABEL = "en_label";
var COUNTRY_PROPERTY_EN_NAME = "en_name";
var COUNTRY_PROPERTY_EN_CODE = "en_code";

/* property names in the JSON store files */
var STORE_NAME_PROPERTY = "name";
var STORE_ID_PROPERTY = "id";
var STORE_PRODUCTS_COUNT_PROPERTY = "products";

/* local storage of stores for selected countries (cached data):
 * if no country is selected, it means "world", and nothing is appended to this stores local variable, otherwise the country is appended
 */
var LOCALSTORAGE_COUNTRIES = "countries";
var LOCALSTORAGE_STORES_PARTIAL = "stores_for_country_";
var LOCAL_STORAGE_SCORE_DATABASES = "score_databases";
var LOCAL_STORAGE_CURRENT_DATABASE = "current_score_database_used";

/* world is the default OFF-site for displaying product details */
var URL_OFF_DEFAULT_COUNTRY = "world";

// **************
// waiting_screen
// **************
/* got from https://stackoverflow.com/questions/9152416/javascript-how-to-block-the-whole-screen-while-waiting-for-ajax-response */
function block_screen(msg) {
    $('#screenBlock').empty();
    $('#screenBlock').append("<p>" + msg + "</p>");
    $('#screenBlock').css({opacity: 0, width: $(document).width(), height: $(document).height()});
    $('#screenBlock').addClass('blockDiv');
    $('#screenBlock').show();
    $('#screenBlock').animate({opacity: 0.85}, 100);
}

function unblock_screen() {
    $('#screenBlock').animate({opacity: 0}, 100, function () {
        $('#screenBlock').hide();
    });
}

// **************
// country_store
// **************

/* COUNTRIES */
function fetch_countries() {
    var cached_countries = getCachedCountries();
    if (cached_countries !== null && cached_countries != undefined) {
        fillHtmlElementWithCountries(cached_countries);
    }
}

function getCachedCountries() {
    var key_localstorage_countries = LOCALSTORAGE_COUNTRIES;
    var countries = JSON.parse(window.localStorage.getItem(key_localstorage_countries));
    if (countries === null) {
        var data_countries;

        /* fetch countries from json file (made synchronous this way with $.ajax instead of $.getJSON
         which is only asynchronous!) */
        $.ajax({
            url: URL_ROOT_API + FILE_COUNTRIES,
            dataType: 'json',
            async: false,
            success: function (json) {
                const stats_json = json;
                data_countries = $.map(stats_json, function (value, index) {
                    // add to each value the key of the object (e.g. "en:Poland") for future use in REST services
                    value[COUNTRY_PROPERTY_EN_LABEL] = index;
                    value[COUNTRY_PROPERTY_EN_NAME] = value.name.en;
                    if (Object.prototype.hasOwnProperty.call(value, "country_code_2")) {
                        value[COUNTRY_PROPERTY_EN_CODE] = value.country_code_2.en.toUpperCase();
                    } else if (Object.prototype.hasOwnProperty.call(value, "country_code_3")) {
                        value[COUNTRY_PROPERTY_EN_CODE] = value.country_code_3.en.toUpperCase();
                    } else {
                        value[COUNTRY_PROPERTY_EN_CODE] = "";
                    }

                    return [value];
                });

                data_countries.sort(function_sort_countries);

                // store locally the countries for later usage (country code)
                cacheCountries(data_countries);
            }
        });

        return data_countries;
    } else {
        return countries;
    }
}

function cacheCountries(countries) {
    var key_localstorage_countries = LOCALSTORAGE_COUNTRIES;
    window.localStorage.setItem(key_localstorage_countries, JSON.stringify(countries));
}

function set_user_country(ctrlCountrySelected) {
  const en_country_name =  ctrlCountrySelected.value;
  if (en_country_name == "") {
    user_country = undefined;
  } else {

    /* get country object (it is used to reach the country OFF-page directly when viewing product details) */
    user_country = [];
    user_country.push(find_country_object(en_country_name));
  }
}

function find_country_object (en_country) {
    const countries = getCachedCountries();
    let index_of_found = -1;
    for (var i=0; i < countries.length && index_of_found < 0; i++) {
        if (countries[i].en_label == en_country) {
            index_of_found = i;
        }
    }

    return (index_of_found < 0) ? undefined : countries[index_of_found];
}

/* STORES */
function fetch_stores(ctrlCountrySelected) {
    var cached_stores_for_country = getCachedStoresForCountry(ctrlCountrySelected.value);
    if (cached_stores_for_country !== null && cached_stores_for_country !== undefined) {
        fillHtmlElementWithStores(cached_stores_for_country);
    }
}

function getCachedStoresForCountry(country) {
    var key_localstorage_stores = LOCALSTORAGE_STORES_PARTIAL + country;
    const stores_for_country = JSON.parse(window.localStorage.getItem(key_localstorage_stores));
    if (stores_for_country === null) {
        block_screen(MSG_WAITING_SCR_FETCH_STORES);
        $.ajax({
            type: "GET",
            url: URL_ROOT_API + ENDPOINT_STORES,
            contentType: "application/json; charset=utf-8",
            data: {
                country: country
            },
            success: function (data) {
                if (data !== null && data !== undefined) {
                    data.tags.sort(function_sort_stores_by_nb_products);
                    const stores_most_relevant = data.tags.filter(function (store, indx) {
                        return indx < MAX_STORES_TO_SHOW_PER_COUNTRY;
                    });
                    stores_most_relevant.sort(function_sort_stores_by_name);
                    // store locally the stores for this country for later usage
                    cacheStoresForCountry(country, stores_most_relevant);
                    // map the stores in the Html element
                    fillHtmlElementWithStores(stores_most_relevant);
                }
                unblock_screen();
            }
        });
    } else {
        return stores_for_country;
    }
}

function cacheStoresForCountry(country, stores) {
    var key_localstorage_stores = LOCALSTORAGE_STORES_PARTIAL + country;
    window.localStorage.setItem(key_localstorage_stores, JSON.stringify(stores));
}

/*
 Replace in the OFF-url the world default website with the regionalized-one (country selected by user in the Interface)
 */
function urlReplaceWorldWithSelectedCountry(url_off) {

    /* replace 'world' with country code if available */
    let new_url_off = url_off;
    let country_code;
    if (user_country != undefined) {
        country_code= user_country[0].en_code;
    }
    if (country_code != undefined) {
        new_url_off=url_off.replace("//"+URL_OFF_DEFAULT_COUNTRY.toLowerCase()+".", "//"+country_code.toLowerCase().trim()+".");
    }

    return new_url_off;
}

// **************
// utils
// **************

// sort function for the countries
var function_sort_countries = getSortMethod('+' + COUNTRY_PROPERTY_EN_NAME);
// sort function for the stores by number of products backwards (most popular stores)
var function_sort_stores_by_nb_products = getSortMethod('-' + STORE_PRODUCTS_COUNT_PROPERTY);
// sort function for the stores by name alphabetically
var function_sort_stores_by_name = getSortMethod('+' + STORE_NAME_PROPERTY);
// sort function for both similarity with prod. ref and nutrition score (downwards)
var function_sort_products_bottomUp = getSortMethod('-score', '-score_proximity');
var function_sort_products_upToBottom = getSortMethod('+score', '-score_proximity');
// sort method for point abscisses (ascending)
var function_sort_min_abscisse = getSortMethod('+x');

/*
 see https://stackoverflow.com/questions/6129952/javascript-sort-array-by-two-fields
 Triple sort function; usage here: http://gregtaff.com/misc/multi_field_sort/
 */
function getSortMethod() {
    var args = Array.prototype.slice.call(arguments);

    return function (a, b) {
        for (var x in args) {
            if (Object.prototype.hasOwnProperty.call(args, x)) {
                var ax;
                var bx;
                var cx;

                const tmp_ax = a[args[x].substring(1)];
                if ((typeof tmp_ax) == "number") {
                    // numbers
                    ax = Number(tmp_ax);
                    bx = Number(b[args[x].substring(1)]);
                } else {
                    // strings => try converting into numbers anyway
                    ax = Number(tmp_ax);
                    bx = Number(b[args[x].substring(1)]);
                    if (isNaN(ax) || isNaN(bx)) {
                        // well, these are really strings
                        ax = tmp_ax;
                        bx = b[args[x].substring(1)];
                    }

                }
                if (args[x].substring(0, 1) == "-") {
                    cx = ax;
                    ax = bx;
                    bx = cx;
                }
                if (ax != bx) {
                    return ax < bx ? -1 : 1;
                }
            }
        }
    };
}


function filter_suggestions(prod_ref, matching_products, db_graph) {
    return matching_products.filter(
        function (a) {
            if (db_graph.bottomUp == true) {
                return ( (prod_ref.score == db_graph.scoreMaxValue) ? a.score >= prod_ref.score : a.score > prod_ref.score)
                    && a.score_proximity >= MIN_SCORE_FOR_SUGGESTIONS;
            } else {
                return ( (prod_ref.score == db_graph.scoreMinValue) ? a.score <= prod_ref.score : a.score < prod_ref.score)
                    && a.score_proximity >= MIN_SCORE_FOR_SUGGESTIONS;
            }
        }
    );
}

/*
 * Extract url parameter (barcode)
 * code got from https://stackoverflow.com/questions/901115/how-can-i-get-query-string-values-in-javascript
 */
function getParameterByName(name, url) {
    let url_def = url;
    if (!url) {
        url_def = window.location.href;
    }
    const name_formatted = name.replace(/[[]]/g, '$&');
    var regex = new RegExp('[?&]' + name_formatted + '(=([^&#]*)|&|#|$)'),
        results = regex.exec(url_def);
    if (!results) {
        return null;
    }
    if (!results[2]) {
        return '';
    }

    return decodeURIComponent(results[2].replace(/\+/g, ' '));
}

// **************
// score_databases
// **************

/* SCORE DATABASES */
function fetch_score_databases() {
    var cached_databases = getCachedScoreDatabases();
    if (cached_databases !== null && cached_databases !== undefined) {
        // Default db to use is param score if specified in URL, otherwise first db (holds data to draw the graph as well)
        const url_score_db = getParameterByName(URL_PARAM_SCORE, window.location.href);
        if (url_score_db !== null && url_score_db !== undefined && url_score_db != "") {
            const param_db_for_graph = cached_databases.stats.filter(function (db) {
                return db[FLD_DB_NICK_NAME].toLowerCase() == url_score_db.toLowerCase();
            });
            if (param_db_for_graph !== null && param_db_for_graph !== undefined) {
                current_db_for_graph = param_db_for_graph[0];
            }
        }
        if (current_db_for_graph === null) {
            current_db_for_graph = getCachedCurrentDatabase();
        }
        if (current_db_for_graph === null) {
            current_db_for_graph = cached_databases.stats[0];
        }
        cacheCurrentScoreDatabase(current_db_for_graph);
        fillHtmlElementWithDatabases(cached_databases.stats);
    }
}

function getCachedScoreDatabases() {
    var key_localstorage_databases = LOCAL_STORAGE_SCORE_DATABASES;
    var databases = JSON.parse(window.localStorage.getItem(key_localstorage_databases));
    if (databases === null) {
        var data_score_databases;
        $.ajax({
            type: "GET",
            url: URL_ROOT_API + ENDPOINT_SCORE_DBS,
            async: false,
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                data_score_databases = filterDatabases(data);
                cacheScoreDatabases(data_score_databases);
            }
        });

        return data_score_databases;
    } else {
        return databases;
    }
}

function getCachedCurrentDatabase() {
    var key_localstorage_current_db = LOCAL_STORAGE_CURRENT_DATABASE;
    const current_db = JSON.parse(window.localStorage.getItem(key_localstorage_current_db));

    return current_db;
}

function filterDatabases(databases) {
    const dbs_to_show = databases.stats.filter(function (db) {
        // Mock for filtering only active dbs for everybody and all dbs for testing purposes
        if (window.location.href.search("/test") >= 0 || db.isActive == true) {
            return db;
        }

      return null;
    });
    databases.stats = dbs_to_show;

    return databases;
}

function cacheScoreDatabases(databases) {
    var key_localstorage_databases = LOCAL_STORAGE_SCORE_DATABASES;
    window.localStorage.setItem(key_localstorage_databases, JSON.stringify(databases));
}

function cacheCurrentScoreDatabase(current_db) {
    var key_localstorage_current_db = LOCAL_STORAGE_CURRENT_DATABASE;
    if (current_db !== null && current_db !== undefined) {
        window.localStorage.setItem(key_localstorage_current_db, JSON.stringify(current_db));
    }
}

function changeScoreDb(ctrl) {
  current_db_for_graph = getCachedScoreDatabases().stats[ctrl.selectedIndex];
  cacheCurrentScoreDatabase(current_db_for_graph);
}

// **************
// products_suggestion
// **************

/* Note:
 [x, y]: x = number of product selected once products filtered and ordered
 note: in order to access the circle drawn in the graph, use suggested_products[x].num_circle
 y = DOM-image of selected product
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
    let component_height;
    component_height = 6 + ($(window).innerHeight() / 5);
    $(ID_PRODUCTS_SUGGESTION).attr("height", String(component_height) + "px");
    $(ID_PRODUCTS_SUGGESTION).append("<ul></ul>");
    component_height = $(window).innerHeight() / 5;
    $(ID_MENU_SELECTION).attr("height", String(component_height) + "px");
}

function get_graph_stripe_colour (db_graph, score_of_product) {
    // Compute which stripe colour to set for the border of product suggested
    let indx_colour_stripe;
    if (db_graph.bottomUp == true) {
        indx_colour_stripe = (db_graph.scoreIntervalsStripeColour.length - 1) - (db_graph.scoreMaxValue - score_of_product);
    } else {
        indx_colour_stripe = score_of_product - db_graph.scoreMinValue;
    }

    return db_graph.scoreIntervalsStripeColour[indx_colour_stripe];
}

function make_suggestions(product_ref, products, db_graph) {
    client_current_selection = [-1, undefined];
    cleanup_suggestions();

    if (products.length > 0) {

        /* sort products by: 1) desc proximity with product reference, 2) score */
        const products_filtered = filter_suggestions(product_ref, products, db_graph);
        if (db_graph.bottomUp == true) {
            products_filtered.sort(function_sort_products_bottomUp);
        } else {
            products_filtered.sort(function_sort_products_upToBottom);
        }
        suggested_products = products_filtered.slice(0, MAX_SUGGESTIONS);
        $(ID_NB_SUGGESTIONS).empty();
        $(ID_NB_SUGGESTIONS).append(suggested_products.length);
        suggested_products.forEach(function (product, index) {
            const style_for_border_colour = "border-color: " + get_graph_stripe_colour(db_graph, product.score);
            $(ID_PRODUCTS_SUGGESTION + " > ul").append("<li><img id='" + ID_PRODUCT_IMAGE_PARTIAL + index + "' src='" + product.img + "' class='grade_border' style='" + style_for_border_colour + "' height='250px' onclick='process_selected_suggestion(this, " + index + ")' /></li>");
            $(ID_PRODUCTS_SUGGESTION + " > ul").append("<li><img id='" + ID_PRODUCT_IMAGE_PARTIAL + index + "' src='" + product.img + "' class='grade_border' style='" + style_for_border_colour + "' height='250px' /></li>");
            // Bind onclick event
            $(ID_PRODUCT_IMAGE_PARTIAL + index).click(function() {
                process_selected_suggestion(this, " + index + ");
            });
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
        const rangeInterval = (current_db_for_graph.scoreMaxValue - current_db_for_graph.scoreMinValue + 1);

        const style_for_border_colour = "border-color: " + get_graph_stripe_colour(current_db_for_graph, suggested_products[client_current_selection[0]].score);
        client_current_selection[1].setAttribute("style", style_for_border_colour);

        const circle_node = $("#svg_graph")[0].childNodes[0].childNodes[suggested_products[client_current_selection[0]].num_circle + SHIFT_ARRAY_POSITION_SVG_CIRCLES_VS_PRODUCTS + rangeInterval];
        circle_node.setAttribute("r", String(CIRCLE_RADIUS_DEFAULT));
        circle_node.setAttribute("fill", CIRCLE_COLOR_DEFAULT);
    }
}

function activate_selection() {
    const rangeInterval = (current_db_for_graph.scoreMaxValue - current_db_for_graph.scoreMinValue + 1);
    // Box around selection in the ribbon
    client_current_selection[1].setAttribute("class", "product_selected");
    client_current_selection[1].setAttribute("style", "");
    // focus circle bound to selection
    const circle_node = $("#svg_graph")[0].childNodes[0].childNodes[suggested_products[client_current_selection[0]].num_circle + SHIFT_ARRAY_POSITION_SVG_CIRCLES_VS_PRODUCTS + rangeInterval];
    circle_node.setAttribute("r", String(CIRCLE_RADIUS_SELECTED));
    circle_node.setAttribute("fill", CIRCLE_COLOR_SELECTED);
    $(ID_INPUT_PRODUCT_CODE).val(suggested_products[client_current_selection[0]].code);
}

/*
 shift: positive or negative to select a picture after left/right button has been pressed
 */
function select_picture(shift) {
    if (suggested_products.length > 0) {
        let curr_pos = client_current_selection[0];
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
        const next_image = $("#" + ID_PRODUCT_IMAGE_PARTIAL + curr_pos)[0];
        client_current_selection[1] = next_image;
        activate_selection();
    }
}

function show_details() {
    const curr_prod = suggested_products[client_current_selection[0]];
    const style_for_border_colour = "border-color: " + get_graph_stripe_colour(current_db_for_graph, curr_prod.score);
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
    $(ID_DETAILS_SELECTED_PRODUCT).append("<div class='close_details_sel_prod'>close</div>");
    $(ID_DETAILS_SELECTED_PRODUCT).children(".close_details_sel_prod").click(function() {
        hide_details();
    });
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


// **************
// graph part
// **************

/* draw SVG graph:
 - id_attach_graph: id of html-item for attaching the graph itself
 - db_graph is same as current_db_for_graph, but packed here together with function
 - prod_ref: object containing all required data for showing object details (score, categories, image, url)
 - prod_matching: array of all matching products objects containing all required information (score, tooltip, etc.)
 - item_display_code_of_selected_product : html item receiving the code of the selected product in the graph (ex.: div's id)
 - open_off_page: true (/false) opens in a separate tab the off page for the selected product in the graph
 */
function draw_graph(db_graph,
                    prod_ref,
                    prod_matching) {
    // Set the dimensions of the canvas / graph
    var margin = {top: 30, right: 30, bottom: 60, left: 50},
        width = GRAPH_WIDTH - margin.left - margin.right - (GRAPH_WIDTH * 4 / 100),
        height = GRAPH_HEIGHT - margin.top - margin.bottom;

    var x = d3.scale.linear().range([0, width]);
    var y = d3.scale.linear().range([height, 0]);

    var nb_categs = (Object.prototype.hasOwnProperty.call(prod_ref, "categories_tags") && prod_ref.categories_tags.length > 0) ? prod_ref.categories_tags.length : 8;

    /* Number of x-axis ticks displayed in the graph (score is then minimum 1-(nb_categs_displayed/nb_categs) ) */
    var nb_categs_displayed = Math.ceil(nb_categs / 2);
    var nb_nutrition_grades = (Object.prototype.hasOwnProperty.call(db_graph, "scoreNbIntervals")) ? db_graph.scoreNbIntervals : 5;
    var x_axis_min_value = 1 - (nb_categs_displayed / nb_categs);
    var shift_left_x_values = x_axis_min_value;

    // Define the axes
    var xAxis = d3.svg.axis().scale(x).orient("bottom").ticks(nb_categs_displayed).tickFormat(function (d) {
        if (d == x_axis_min_value) {
            return "low";
        }
        if (d == 1) {
            return "high";
        }

        return "";
    });

    /* Draw vertical lines for each tick */
    /* ..generates [0..nb_categs_displayed] */
    var rangeCategs = [...Array(nb_categs_displayed + 1).keys()];
    var dataX = [];
    rangeCategs.forEach(function (d) {
        if (d > 0) {
            dataX.push(d / nb_categs_displayed);
        }
    });
    var xAxisVertical = d3.svg.axis().scale(x).orient("top").ticks(nb_categs_displayed).tickValues(dataX).innerTickSize([height]).outerTickSize([height]);

    var yAxis = d3.svg.axis().scale(y).orient("left").ticks(nb_nutrition_grades).tickFormat(function (d) {
        if (d >= db_graph.scoreMinValue && d <= db_graph.scoreMaxValue) {
            if (db_graph.bottomUp == true) {
                return db_graph.scoreIntervalsLabels[d - 1];
            } else {
                return db_graph.scoreIntervalsLabels[db_graph.scoreNbIntervals - d];
            }
        }

        return "";
    });

    // Define the div for the tooltip
    var div = d3.select("body").append("div").attr("class", "tooltip").style("opacity", 0).style("display", "none");

    // Adds the svg canvas
    var svg = d3.select("body").append("svg").attr("id", "svg_graph").attr("width", width + margin.left + margin.right).attr("height", height + margin.top + margin.bottom).append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");
    svg.append("g").attr("class", "x axis").attr("transform", "translate(0," + height + margin.top + margin.bottom + ")").call(xAxisVertical);

    // Scale the range of the data
    x.domain([x_axis_min_value, 1]);
    y.domain([0, nb_nutrition_grades]);

    /*var data_rect = [{'v': 1, 'color': 'rgb(230,62,17)'}, {'v': 2, 'color': 'rgb(238,129,0)'}, {
     'v': 3,
     'color': 'rgb(254,203,2)'
     }, {'v': 4, 'color': 'rgb(133,187,47)'}, {'v': 5, 'color': 'rgb(3,129,65)'}];*/

    /* Draw coloured stripes from bottom to top (bottom-up direction) */
    var data_rect_2 = [];
    var rangeInterval = (db_graph.scoreMaxValue - db_graph.scoreMinValue + 1);
    var step_for_stripe = rangeInterval / db_graph.scoreNbIntervals;
    var indx_array = 0;
    for (var i = db_graph.scoreMinValue; i <= db_graph.scoreMaxValue; i += step_for_stripe) {
        data_rect_2.push({'v': i, 'color': db_graph.scoreIntervalsStripeColour[indx_array]});
        indx_array += 1;
    }

    svg.selectAll("rect").data(data_rect_2).enter().append("rect").attr("width", width).attr("height", height / db_graph.scoreNbIntervals).attr("y", function (d) {
        if (db_graph.bottomUp == true) {
            return (rangeInterval - d.v) * height / rangeInterval;
        } else {
            return (d.v - step_for_stripe) * height / rangeInterval;
        }
    }).attr("fill", function (d) {
        return d.color;
    });
    // *****

    // Add the scatterplot
    // .. for the product reference
    var data_prod_ref = [{'score': 1}];
    if (prod_ref.length != 0) {
        data_prod_ref = [{'score': prod_ref.score}];
    }
    svg.selectAll("ellipse").data(data_prod_ref).enter().append("ellipse").attr("cx", width * (1 - ((1 / nb_categs_displayed) / 2))).attr("cy", function (d) {
        if (db_graph.bottomUp == true) {
            return ((height * (1 - (d.score / nb_nutrition_grades))) + (height / nb_nutrition_grades * 0.5));
        } else {
            return ((height * ((d.score - 1) / nb_nutrition_grades)) + (height / nb_nutrition_grades * 0.5));
        }
    }).attr("rx", width / nb_categs_displayed * 0.5).attr("ry", (height / nb_nutrition_grades) * 0.5).attr("fill", "#ffffff").attr("fill-opacity", 0.75);

    /* Filtering of matching products to suggest, and extraction of minimum abscisse in order to determine the width of the square box for suggestions */
    //data_prod_ref[0].y_val_real = data_prod_ref[0].score;
    var prods_filtered_for_graph = filter_suggestions(data_prod_ref[0], prod_matching, db_graph);
    prods_filtered_for_graph.sort(function_sort_min_abscisse);

    var square_of_suggestions;
    if (db_graph.bottomUp == true) {
        square_of_suggestions = [
            {
                "width": prods_filtered_for_graph.length == 0 ? (1 / nb_categs_displayed) : (1 - prods_filtered_for_graph[0].x) * (nb_categs / nb_categs_displayed),

                /* Height of the suggestion square is the range of intervals minus the difference between the score of product ref. and the min. value */
                "height": data_prod_ref[0].score == db_graph.scoreMaxValue ? 1 : (rangeInterval - (data_prod_ref[0].score - (db_graph.scoreMinValue - 1)))
            }
        ];
    } else {
        // width unchanged, but height is reversed
        square_of_suggestions = [
            {
                "width": prods_filtered_for_graph.length == 0 ? (1 / nb_categs_displayed) : (1 - prods_filtered_for_graph[0].x) * (nb_categs / nb_categs_displayed),
                "height": data_prod_ref[0].score == db_graph.scoreMinValue ? 1 : (data_prod_ref[0].score - 1)
            }
        ];
    }
    svg.selectAll("polyline").data(square_of_suggestions).enter().append("polyline").style("stroke", "black").style("fill", "none").attr("points", function (d) {
        const w = (width * d.width) + CIRCLE_RADIUS_SELECTED;
        const h = d.height * (height / rangeInterval);
        const rect_points = width + "," + 0 + ", " + width + "," + h + ", " + (width - w) + "," + h + ", " + (width - w) + "," + 0 + ", " + width + "," + 0;

        return rect_points;
    })
    ;

    // .. for all matching products
    var data_others = prod_matching;

    svg.selectAll("circle").data(data_others).enter().append("circle").attr("r", CIRCLE_RADIUS_DEFAULT).attr("stroke", "#000080").attr("stroke-width", 1).attr("fill", CIRCLE_COLOR_DEFAULT).attr("cx", function (d, ind) {

        // Store position of svg.circle in the product itself for leveraging browsing in the suggestion panel
        d.num_circle = ind;

        return (d.x - shift_left_x_values) * nb_categs / nb_categs_displayed * width;
    }).attr("cy", function (d) {
        if (db_graph.bottomUp == true) {
            return height * (1 - (d.y / nb_nutrition_grades));
        } else {
            return height * (d.y / nb_nutrition_grades);
        }
    }).on("mouseover", function (d) {
        div.transition().duration(200).style("opacity", 0.85);
        div.html(d.content).style("left", (d3.event.pageX) + "px").style("top", (d3.event.pageY - 28) + "px");
    }).on("mouseout", function () {
        div.transition().duration(500).style("opacity", 0);
    }).on("click", function (d) {
        $(ID_INPUT_PRODUCT_CODE).val(d.code);
        $(ID_INPUT_PRODUCT_CODE).removeClass("barcode_no_selection");
        $(ID_INPUT_PRODUCT_CODE).addClass("barcode_product_selected");
        if (OPEN_OFF_PAGE_FOR_SELECTED_PRODUCT) {
            window.open(d.url, '_blank');
        }
    });

    // Add the X Axis
    svg.append("g").attr("class", "x axis").attr("transform", "translate(0," + height + ")").call(xAxis);

    // Add the X-axis label
    svg.append("text").attr("x", width * 0.5).attr("y", height + 30).attr("dy", "1em").style("text-anchor", "middle").style("font-size", "inherit").text("Similarity with product reference");

    // Add the Y Axis
    svg.append("g").attr("class", "y axis").call(yAxis);

    // Add the Y-axis label
    svg.append("text").attr("transform", "rotate(-90)").attr("x", -(height * 0.5)).attr("y", -45).attr("dy", "1em").style("text-anchor", "middle").style("font-size", "inherit").text(db_graph.scoreLabelYAxis);

    $(ID_GRAPH).empty();
    $("svg").detach().appendTo(ID_GRAPH);
}

function display_product_ref_details(prod_ref) {
    // update globals
    const code = prod_ref.code;
    const name = prod_ref.name;
    let image = prod_ref.images;
    if (image == "") {
        image = prod_ref.image_fake_off;
    }
    const no_nutriments = prod_ref.no_nutriments;
    const categories = prod_ref.categories_tags.join("<br />");
    let url_off = prod_ref.url_product;

    /* replace 'world' with country code if available */
    let country_code;
    if (user_country !== null && user_country !== undefined) {
        country_code = user_country[0].en_code;
    }
    if (country_code !== null && country_code !== undefined) {
        url_off = url_off.replace("//" + URL_OFF_DEFAULT_COUNTRY.toLowerCase() + ".", "//" + country_code.toLowerCase().trim() + ".");
    }
    const url_json = prod_ref.url_json;
    const style_for_border_colour = "grade_" + prod_ref.score;
    $(ID_PRODUCT_CODE).empty();
    $(ID_PRODUCT_CODE).append(code);
    $(ID_INPUT_PRODUCT_CODE).empty();
    $(ID_INPUT_PRODUCT_CODE).append(code);
    $(ID_PRODUCT_NAME).empty();
    $(ID_PRODUCT_NAME).append(name);
    $(ID_PRODUCT_IMG).attr("src", image);
    let component_height;
    component_height = $(window).innerHeight() / 7;
    $(ID_PRODUCT_IMG).attr("height", String(component_height) + "px");
    $(ID_PRODUCT_IMG).attr("class", style_for_border_colour);
    component_height = $(window).innerHeight() / 7 / 3;
    $(ID_IMG_OFF).attr("height", String(component_height) + "px");
    $(ID_IMG_OFF).attr("max-height", "28px");
    $(ID_IMG_JSON).attr("height", String(component_height) + "px");
    $(ID_IMG_JSON).attr("max-height", "28px");

    $(ID_PRODUCT_CATEGORIES).empty();
    $(ID_PRODUCT_CATEGORIES).append(categories);
    $(ID_PRODUCT_OFF).attr("href", url_off);
    $(ID_PRODUCT_JSON).attr("href", url_json);
    $(ID_WARNING).empty();
    if (no_nutriments) {
        $(ID_WARNING).append(MSG_NO_NUTRIMENTS_PROD_REF);
    }
}

function draw_page(prod_ref, prod_matching) {
    display_product_ref_details(prod_ref);
    draw_graph(current_db_for_graph,
        prod_ref,
        prod_matching);
    make_suggestions(prod_ref, prod_matching, current_db_for_graph);
}


// **************
// main
// **************
var nav_language = window.navigator.userLanguage || window.navigator.language;
var user_country;
var current_db_for_graph;

function init() {
    // add event listeners to html components
    $(ID_INPUT_COUNTRY).change(function() {
        set_user_country($(ID_INPUT_COUNTRY+' option:selected')[0]);
        fetch_stores($(ID_INPUT_COUNTRY+' option:selected')[0]);
    });
    $(ID_INPUT_SCORE_DB).change(function() {
        changeScoreDb(this);
    });
    $(ID_SUGGESTION_LEFT).click(function() {
        select_picture(-1);
    });
    $(ID_SUGGESTION_DETAILS).click(function() {
        show_details();
    });
    $(ID_SUGGESTION_RIGHT).click(function() {
        select_picture(+1);
    });

    // load score databases
    fetch_score_databases();
    // load countries and set country
    fetch_countries();

    // set score db being used if cached locally: this is useful when using the barcode scanner App
    // which knows nothing about the current context when it launches the URL back with barcode.
    // We want to remember which score database is being used by the user
    const current_db_used = getCachedCurrentDatabase();
    if (current_db_used !== null && current_db_used !== undefined) {
        current_db_for_graph = current_db_used;
        $(ID_INPUT_SCORE_DB).val(current_db_used[FLD_DB_NICK_NAME]);
    }
    $(ID_INPUT_PRODUCT_CODE).removeClass("barcode_no_selection");
    $(ID_INPUT_PRODUCT_CODE).addClass("barcode_product_selected");
    $(ID_SERVER_ACTIVITY).css("visibility", "hidden");
    draw_graph(current_db_for_graph, [], []);
    cleanup_suggestions();
    $(function () {
        $("#submitBtn").click(go_fetch);
    });

    // Insert barcode from url if available, otherwise default product barcode
    const url_barcode = getParameterByName(URL_PARAM_BARCODE, window.location.href);
    if (url_barcode === null) {
        $(ID_INPUT_PRODUCT_CODE).val(PRODUCT_CODE_DEFAULT);
    } else {
        $(ID_INPUT_PRODUCT_CODE).val(url_barcode);
        go_fetch();
    }
}

function guess_country_from_nav_lang() {
    let is_found = false;
    const data_countries = getCachedCountries();
    // set country: 1) from url param if set; 2) from navigator
    const url_country = getParameterByName(URL_PARAM_COUNTRY, window.location.href);
    if (url_country !== null && url_country !== undefined && url_country != "") {
        const nav_country = url_country;
        // filter countries and fetch the one holding the country code of the navigator
        user_country = data_countries.filter(
            function (ctry) {
                return ctry[COUNTRY_PROPERTY_EN_LABEL].toLowerCase() == nav_country.toLowerCase();
            }
        );
    } else {
        const nav_country = ( (nav_language.indexOf('-') >= 0) ? nav_language.split('-')[1] : nav_language).toUpperCase();
        // filter countries and fetch the one holding the country code of the navigator
        user_country = data_countries.filter(
            function (ctry) {
                return ctry[COUNTRY_PROPERTY_EN_CODE] == nav_country;
            }
        );
    }

    if (user_country !== null && user_country !== undefined) {
        var index_option;
        for (index_option in $(ID_INPUT_COUNTRY)[0]) {
            if (Object.prototype.hasOwnProperty.call($(ID_INPUT_COUNTRY)[0], index_option)) {
                const current_option = $(ID_INPUT_COUNTRY)[0][index_option];
                if (current_option.value === user_country[0][COUNTRY_PROPERTY_EN_LABEL]) {
                    is_found = true;
                    current_option.selected = true;
                    break;
                }
            }
        }
        if (is_found) {
            // Load stores for guessed country
            fetch_stores($(ID_INPUT_COUNTRY)[0][index_option]);
            // fetch_stores("en:luxembourg");
        }
    }
}

function fillHtmlElementWithCountries(data_countries) {
    if (data_countries !== null && data_countries !== undefined) {
        var options = data_countries.map(function (country) {
            return $("<option></option>").val(country[COUNTRY_PROPERTY_EN_LABEL]).text(country[COUNTRY_PROPERTY_EN_NAME]);
        });
        $(ID_INPUT_COUNTRY).empty();
        $(ID_INPUT_COUNTRY).append($("<option></option>").val('').text(''));
        $(ID_INPUT_COUNTRY).append(options);

        guess_country_from_nav_lang();
    }
}

function fillHtmlElementWithStores(stores_by_country) {
    if (stores_by_country === undefined) {
        $(ID_INPUT_STORE).empty();
        $(ID_INPUT_STORE).append($("<option></option>").val('').text(''));
    } else {
        var options = stores_by_country.map(function (store) {
            return $("<option></option>").val(store[STORE_ID_PROPERTY]).text(store[STORE_NAME_PROPERTY]);
        });
        $(ID_INPUT_STORE).empty();
        $(ID_INPUT_STORE).append($("<option></option>").val('').text(''));
        $(ID_INPUT_STORE).append(options);
    }
}

function fillHtmlElementWithDatabases(score_databases) {
    if (score_databases === undefined) {
        $(ID_INPUT_SCORE_DB).empty();
        $(ID_INPUT_SCORE_DB).append($("<option></option>").val('').text(''));
    } else {
        var options = score_databases.map(function (score_db) {
            return $("<option></option>").val(score_db[FLD_DB_NICK_NAME]).text(score_db[FLD_DB_DISPLAY_NAME]);
        });
        $(ID_INPUT_SCORE_DB).empty();
        $(ID_INPUT_SCORE_DB).append(options);
    }
}

function go_fetch() {
    // clear some staff
    $(ID_INPUT_PRODUCT_CODE).removeClass("barcode_product_selected");
    $(ID_INPUT_PRODUCT_CODE).addClass("barcode_no_selection");
    $(ID_WARNING).empty();

    block_screen(MSG_WAITING_SCR_MATCH_REQUEST);
    //url_score = getParameterByName(URL_PARAM_SCORE, window.location.href);
    $.ajax({
        type: "GET",
        url: URL_ROOT_API + "/fetchPGraph/",
        contentType: "application/json; charset=utf-8",
        data: {barcode: $(ID_INPUT_PRODUCT_CODE).val(),
            country: $(ID_INPUT_COUNTRY+" option:selected")[0].value,
            store: $(ID_INPUT_STORE+" option:selected")[0].value,
            score: $(ID_INPUT_SCORE_DB+" option:selected")[0].value},
        success: function (data) {
            unblock_screen();
            try {
                var product_ref = data.graph[0];
                var products_matching = data.graph[1];
                draw_page(product_ref, products_matching);
            } catch (e) {
                // possibly no data retrieved (product may have been excluded from search due to a lack of information (nutriments, etc.)
                $(ID_WARNING).empty();
                $(ID_WARNING).append(MSG_NO_DATA_RETRIEVED);
            }
        }
    });
}


$(document).ready(function() {
    init();
});
