/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) on 03/09/18.
 */

/* COUNTRIES */
function fetch_countries() {
    var cached_countries = getCachedCountries();
    if (cached_countries != null) {
        fillHtmlElementWithCountries(cached_countries);
    }
}

function getCachedCountries() {
    var key_localstorage_countries = LOCALSTORAGE_COUNTRIES;
    var countries = JSON.parse(window.localStorage.getItem(key_localstorage_countries));
    if (countries != null) {
        return countries;
    } else {
        var data_countries = undefined;
        /* fetch countries from json file (made synchronous this way with $.ajax instead of $.getJSON
        which is only asynchronous!) */
        $.ajax({
            url: URL_ROOT_API + FILE_COUNTRIES,
            dataType: 'json',
            async: false,
            success: function (json) {
                stats_json = json;
                data_countries = $.map(stats_json, function (value, index) {
                    // add to each value the key of the object (e.g. "en:Poland") for future use in REST services
                    value[COUNTRY_PROPERTY_EN_LABEL] = index;
                    value[COUNTRY_PROPERTY_EN_NAME] = value.name["en"];
                    if (value.hasOwnProperty("country_code_2")) {
                        value[COUNTRY_PROPERTY_EN_CODE] = value.country_code_2["en"].toUpperCase();
                    } else if (value.hasOwnProperty("country_code_3")) {
                        value[COUNTRY_PROPERTY_EN_CODE] = value.country_code_3["en"].toUpperCase();
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
    }
}

function cacheCountries(countries) {
    var key_localstorage_countries = LOCALSTORAGE_COUNTRIES;
    window.localStorage.setItem(key_localstorage_countries, JSON.stringify(countries));
}

function set_user_country(ctrlCountrySelected) {
    en_country_name =  ctrlCountrySelected.value;
    if (en_country_name == "") {
        user_country = undefined;
    } else {
        /* get country object (it is used to reach the country OFF-page directly when viewing product details) */
        user_country = [];
        user_country.push(find_country_object(en_country_name));
    }
}

function find_country_object (en_country) {
    countries = getCachedCountries();
    index_of_found = -1;
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
    if (cached_stores_for_country != null) {
        fillHtmlElementWithStores(cached_stores_for_country);
    } else {
        
    }
}

function getCachedStoresForCountry(country) {
    var key_localstorage_stores = LOCALSTORAGE_STORES_PARTIAL + country;
    stores_for_country = JSON.parse(window.localStorage.getItem(key_localstorage_stores));
    if (stores_for_country != null) {
        return stores_for_country;
    } else {
        block_screen(MSG_WAITING_SCR_FETCH_STORES);
        $.ajax({
            type: "GET",
            url: URL_ROOT_API + ENDPOINT_STORES,
            contentType: "application/json; charset=utf-8",
            data: {
                country: country
            },
            success: function (data) {
                if (data != null) {
                    data.tags.sort(function_sort_stores_by_nb_products);
                    stores_most_relevant = data.tags.filter(function (store, indx) {
                        return indx < MAX_STORES_TO_SHOW_PER_COUNTRY;
                    });
                    stores_most_relevant
                        .sort(function_sort_stores_by_name);
                    // store locally the stores for this country for later usage
                    cacheStoresForCountry(country, stores_most_relevant);
                    // map the stores in the Html element
                    fillHtmlElementWithStores(stores_most_relevant);
                }
                unblock_screen();
            }
        });
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
    new_url_off = url_off;
    country_code = undefined;
    if (user_country != undefined) {
        country_code= user_country[0].en_code;
    }
    if (country_code != undefined) {
        new_url_off=url_off.replace("//"+URL_OFF_DEFAULT_COUNTRY.toLowerCase()+".", "//"+country_code.toLowerCase().trim()+".");
    }
    return new_url_off;
}