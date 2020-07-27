/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) on 16/05/18.
 */

// sort function for the countries
function_sort_countries = getSortMethod('+' + COUNTRY_PROPERTY_EN_NAME);
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
    var _args = Array.prototype.slice.call(arguments);
    return function (a, b) {
        for (var x in _args) {
            var ax;
            var bx;
            var cx;

            tmp_ax = a[_args[x].substring(1)];
            if ((typeof tmp_ax) == "number") {
                // numbers
                ax = Number(tmp_ax);
                bx = Number(b[_args[x].substring(1)]);
            } else {
                // strings => try converting into numbers anyway
                ax = Number(tmp_ax);
                bx = Number(b[_args[x].substring(1)]);
                if (isNaN(ax) || isNaN(bx)) {
                    // well, these are really strings
                    ax = tmp_ax;
                    bx = b[_args[x].substring(1)];
                }

            }
            if (_args[x].substring(0, 1) == "-") {
                cx = ax;
                ax = bx;
                bx = cx;
            }
            if (ax != bx) {
                return ax < bx ? -1 : 1;
            }
        }
    }
}


function filter_suggestions(prod_ref, matching_products, db_graph) {
    return matching_products.filter(
        function (a) {
            if (db_graph["bottomUp"] == true) {
                return ( (prod_ref.score == db_graph["scoreMaxValue"]) ? a.score >= prod_ref.score : a.score > prod_ref.score)
                    && a.score_proximity >= MIN_SCORE_FOR_SUGGESTIONS;
            } else {
                return ( (prod_ref.score == db_graph["scoreMinValue"]) ? a.score <= prod_ref.score : a.score < prod_ref.score)
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
    if (!url) url = window.location.href;
    name = name.replace(/[\[\]]/g, '\\$&');
    var regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)'),
        results = regex.exec(url);
    if (!results) return null;
    if (!results[2]) return '';
    return decodeURIComponent(results[2].replace(/\+/g, ' '));
}

/*
 Clearing cache of Browser
 */
function clearCache() {
    msg = "Deleting cached DATA will enforce an update with the freshest data from the server.\n\n";
    msg += "Note: if you need to reload APP files from the server due to a misbehaviour of the App, then please delete the cache of your Browser instead.\n"
    msg += "\n\n";

    msg += "DATA LOCAL STORAGE (persistent)\n";
    msg += "\tNumber of items in the LOCAL-cache: " + window.localStorage.length + "\n\n";
    for (var i = 0; i < window.localStorage.length; i++) {
        msg += "\t-> " + window.localStorage.key(i) + "\n";
    }
    msg += "\n";
    msg += "DATA SESSION STORAGE (current browsing)\n";
    msg += "\tNumber of items in the SESSION-cache: " + window.sessionStorage.length + "\n\n";
    for (var i = 0; i < window.sessionStorage.length; i++) {
        msg += "\t-> " + window.sessionStorage.key(i) + "\n";
    }
    msg += "\n";
    msg += "\nDo you want to delete all DATA-caches and get the freshest data from the server?\n\n";
    resp = confirm(msg);
    if (resp) {
        window.localStorage.clear();
        window.sessionStorage.clear();
        window.location = URL_ROOT_API;
    }
}