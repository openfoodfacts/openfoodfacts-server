/* eslint-disable no-alert */
/* eslint-disable no-warning-comments */
/* eslint-env jquery */
/* eslint max-statements-per-line: ["error", { "max": 2 }] */
/* eslint no-plusplus: ["warn", { "allowForLoopAfterthoughts": true }]*/
/* eslint max-params: ["error", 5] */
/* eslint no-unused-expressions: ["error", { "allowTernary": true }] */

// Product Opener (Open Food Facts web app) uses:
// * jQuery 2.1.4:                view-source:https://static.openfoodfacts.org/js/dist/jquery.js (~84 KB)
//                                http://code.jquery.com/jquery-2.1.4.min.js
// * jQuery-UI 1.12.1:            view-source:https://static.openfoodfacts.org/js/dist/jquery-ui.js (~82 KB)
//                                http://code.jquery.com/ui/1.12.1/jquery-ui.min.js
// * Tagify 3.x:                  https://github.com/yairEO/tagify (~47 KB)
// * Foundation 5 CSS Framework:  https://sudheerdev.github.io/Foundation5CheatSheet/
//                                See also: https://github.com/openfoodfacts/openfoodfacts-server/pull/2987

// Dev notes
// * This script needs: jquery, jquery UI (autocomplete)
// * things to test:
//   * https://world.openfoodfacts.org/properties
//   * https://world.openfoodfacts.org/property/has_funny_barcode
//   * https://world.openfoodfacts.org/property/packaging:character:wikidata/value/Q462
//   * https://world.openfoodfacts.org/product/8420567015200/merlu-blanc-panure-croustillante-star-wars-maremundi
//     * see property-values display
//     * search for properties containing "char"
//     * add a property-value pair
//     * edit a property-value pair
//     * delete a property-value pair
//     * add a new property-value pair containing the previous deleted property-value

// Issues: see https://github.com/openfoodfacts/folksonomy_frontend/issues

// Cors issues? See: https://stackoverflow.com/a/43268098
// Deploy a cors proxy: https://elements.heroku.com/buttons/marcus2vinicius/cors-anywhere
//const corsProxy = "https://pure-63603.herokuapp.com/"; // For dev environment
const corsProxy = "";                                        // For production

const feAPI = corsProxy + "https://api.folksonomy.openfoodfacts.org";
//const feAPI = corsProxy + "http://fr.openfoodfacts.localhost:8000"; // For dev environment
var feAPIProductURL, code, bearer, prop;
const authrenewal = 1 * 5 * 60 * 60 * 1000;
//folksonomy_engine_init();


// eslint-disable-next-line no-unused-vars
function folskonomy_engine_init() {
    const pageType = isPageType(); // test page type
    console.log("FEUS - Folksonomy Engine User Script - 2021-11-19T16:49 - mode: " + pageType);

    console.log("authrenewal: " + authrenewal); // days * hours * minutes * seconds * ms


    // css
    // See https://stackoverflow.com/questions/4376431/javascript-heredoc
    const css = `
/*
 * The Open Food Facts web app already loads jquery-ui.css but it doesn't work properly with the "dialog" function.
 * We add the CSS this way so that the embedded, relatively linked images load correctly.
 * (Use //ajax... so that https or http is selected as appropriate to avoid "mixed content".)
 */

@import url("https://ajax.googleapis.com/ajax/libs/jqueryui/1.11.4/themes/redmond/jquery-ui.css");
@import url("https://rawgit.com/free-jqgrid/jqGrid/master/css/ui.jqgrid.css");
@import url("https://netdna.bootstrapcdn.com/font-awesome/4.4.0/css/font-awesome.min.css");

.feus {
  background-color: #f7edf8;
  margin-bottom: 1rem;
}

#free_prop_body *, #fe_new_row * {
  margin-bottom: 0.1rem !important;
}

.feus h2 {
  /* border-bottom: 1px solid #1eff3a; */
}

.feus p {
  margin-bottom: 0.3rem;
}

#free_properties_form table {
  background: none;
  margin-top: 1rem;
}

#free_properties_form table tr * {
  padding: .4rem .4rem;
  vertical-align: middle;
}

#fe_new_row * {
  vertical-align: top !important;
}


`;
    // apply custom CSS
    const s = document.createElement('style');
    s.type = 'text/css';
    s.innerHTML = css;
    document.documentElement.appendChild(s);


    if (pageType === "edit"               || pageType === "product view"  ||
        pageType === "saved-product page" || pageType === "property"           ||
        pageType === "properties") {

        code = $("#barcode").html();
        console.log("FEUS - barcode: " + code);
        feAPIProductURL = feAPI + "/product/" + code;
    }

    if (pageType === "product view") {
        displayFolksonomyPropertyValues();
    }

    if (pageType === "edit") {
        displayFolksonomyForm();
    }

    if (pageType === "property") {
        // detect /property/test or /property/test/value/test_value
        const results = new RegExp('/property/([^/]*)(/value/)?(.*)').exec(window.location.href);
        if (results === null) {
            return null;
        }
        const property = results[1];
        const value = results[3];
        displayProductsWithProperty(property, value);
    }

    if (pageType === "properties") {
        displayAllProperties();
    }
}

/**
 * Display all the free properties created and filed by users.
 * Examples:
 *    * Photo_Front: To be updated
 *
 * @returns {undefined}
 */
function displayFolksonomyPropertyValues() {
    //$(".details").before(
    $("div[itemtype='https://schema.org/Product']").append(
        String('<!-- ---- Folksonomy Engine ----- -->' +
        '<div id="free_properties_1" class="feus row card ">' +
        '<div  class="column large-12 h-space-tiny ">' +
        '<h2>Personalized properties (<span data-tooltip aria-haspopup="true" class="has-tip" data-position="top" data-alignment="left" title="Be aware the data model might be modified. Use at your own risk.">beta</span>)</h2>' +
        '<p id="fe_login_info"></p>' +
        "<p>These properties are created and filed by users for any kind of usages. Feel free to add your own. " +
        "You can dive into <a href='/properties'>the list of properties already used by the community</a> " +
        "or explore the <a href='https://wiki.openfoodfacts.org/Folksonomy/Property'>properties' documentation and its search engine</a>.</p>" +
        "<p>Be aware the data model might be modified. Use at your own risk.</p>" +
        "<p>This is brought by the <a href='https://wiki.openfoodfacts.org/Folksonomy_Engine'>folksonomy engine project</a>. Don't hesitate to participate or give feedback.</p>" +
        '<form id="free_properties_form">' +
        '<table>' +
        '<tr>' +
        '<th> </th>' +
        '<th class="prop_title">Property <a href="/properties">🔗</a></th>' +
        '<th class="val_title">Value</th>' +
        '</tr>' +
        '<tbody id="free_prop_body">') +
        '</tbody>' +
        '<!-- ---- New row ---- -->' +
        '<tr id="fe_new_row">' +
        '<td><input type="hidden" name="owner"> </td>' +
        '<td>' +
        '<input id="fe_form_new_property" name="property" class="text tagify-me" value="" lang="en" placeholder="Enter a property" ></input>' +
            '<small id="fe_prop_eg" >Example: color</small>' +
            '<small id="fe_prop_err" style="visibility: hidden;"><br>Can contain only lower case letters, numbers, "-", "_", and ":"</small>' +
        '</td>' +
        '<td>' +
        '<input id="fe_form_new_value" name="value" placeholder="value" ></input>' +
        '<small id="fe_prop_eg" >Example: blue</small>' +
        '</td>' +
        '<td><span id="new_kv_button" class="button tiny round">Submit</span></td>' +
        '</tr>' +
        '</table>' +
        '</form>' +
        '</div>' +
        '</div>' +
        '<!-- ----- /Folksonomy Engine ----- -->');


    // Autocomplete on property field
    fetch(feAPI + "/keys").
        then(function(u){ return u.json(); }).
        then(function(json){

        /* [    { "k": "knockoff_brand", "count": 25, "values": 7 },
                { "k": "packaging:has_character", "count": 18, "values": 1 }  ] */
        const list = $.map(json, function (value) {
                    return {
                        label: value.k + " (" + value.count + ")",
                        value: value.k
                    };
                });
        // jquery UI autocomplete: https://jqueryui.com/autocomplete/
        $("#fe_form_new_property").autocomplete({
            source: list,
        });
    });

    // Control new property entry
    $("#fe_form_new_property").on("keyup", function() {
        const kControl = /^[a-z0-9_-]+(\\:[a-z0-9_-]+)*$/; // a property is made of lower case letters + numbers + - + _ and :
        if ($("#fe_form_new_property").val() && kControl.test($("#fe_form_new_property").val()) === false) {
            console.log("k syntax is bad!");
            $("#fe_prop_err").css("visibility", "visible");
        }
        else {
            $("#fe_prop_err").css("visibility", "hidden");
        }
    });

    // Suggest values depending on the property
    $("#fe_form_new_value").on("focus", function() {
        if (!$("#fe_form_new_property").val()) {
            console.log("No property provided");

            return;
        }
        if ($("#fe_form_new_property").val() === prop) {
            console.log("Property hasn't changed");

            return;
        }
        prop = $("#fe_form_new_property").val();
        $( "#fe_form_new_value" ).autocomplete();
        $( "#fe_form_new_value" ).autocomplete('option', 'source', []);
        // call API. Eg. https://api.folksonomy.openfoodfacts.org/products?k=packaging:has_character
        fetch(feAPI + "/products?k=" + $("#fe_form_new_property").val()).
            then(function(u){ return u.json(); }).
            then(function(json){

                /* const json = 
                    [
                        { "product": "8711327484184", "k": "packaging:has_character", "v": "yes" },
                        { "product": "9310036071174", "k": "packaging:has_character", "v": "yes" }
                    ]
                */
                // @todo: Build following JSON
                /*  [
                        { "label": "yes (95%)", "value": "yes" },
                        { "label": "no (5%)",   "value": "no" }
                    ]
                */
                const list = findOcc(json, "v");
                console.log("list: ", list);

                list.sort(function(a, b) {
                    return a.occurence < b.occurence;
                });

                const value_list = list.map(function (value) {
                    // { "label": "yes(2)", "value": "yes" }
                    const rObj = {};
                    rObj.label = value.v + "(" + value.occurrence + ")";
                    rObj.value = value.v;
                    
                    return rObj; // { "label": "yes(2)", "value": "yes" }
                });
                console.log("value_list: ", value_list);

                return value_list;
            }).
            then(function(value_list){
                console.log("Data have been read: ", value_list);
                //jquery UI autocomplete: https://jqueryui.com/autocomplete/
                $("#fe_form_new_value").autocomplete({
                    source: value_list,
                    minLength: 0, // Start immediatly
                }).focus(function() { //bind('focus', function () {
                    $(this).autocomplete("search", "");
                });
                $("#fe_form_new_value").autocomplete("search", ""); // Needed for first focus
            }
        );
        console.log("end");
    });

    // New property (key) / value submit
    $('#new_kv_button').on("click", function() {
        // Do not submit anything if property or value is empty
        if (!$("#fe_form_new_property").val()) {
            console.log("No property provided");

            return;
        }
        if (!$("#fe_form_new_value").val()) {
            console.log("No value provided");

            return;
        }
        isWellLoggedIn() ?
        addKV(code, $("#fe_form_new_property").val(), $("#fe_form_new_value").val(), ""):
        loginProcess(function () {
            addKV(code, $("#fe_form_new_property").val(), $("#fe_form_new_value").val(), "");
        });
    });

    // Get all property/value pairs and display it
    console.log("FEUS - displayFolksonomyPropertyValues() - call: " + feAPIProductURL);
    $.getJSON(feAPIProductURL, function(data) {
        if (data === null) {
            console.log("FEUS - displayFolksonomyPropertyValues() - No data");
            
            return;
        }
        console.log("FEUS - displayFolksonomyPropertyValues() - " + JSON.stringify(data));
        let index = data.length;
        let content = "";
        // Sort by property
        const d = data.sort(function(a,b){ return a.k <b.k ? 1 :-1; });
        while (index--) {
            content += ('<tr>' +
                        '<td class="version" data-version="' + d[index].version + '"> </td>' +
                        '<td class="property"><a href="/property/' + d[index].k + '">'                      + d[index].k + '</a></td>' +
                        '<td class="value"><a href="/property/' + d[index].k + '/value/' + d[index].v +'">' + d[index].v + '</a></td>' +
                        '<td>'+
                        '<span class="button tiny fe_save_kv" style="display: none">save</span> '+
                        '<span class="button tiny fe_edit_kv">Edit</span> '+
                        '<span class="button tiny fe_del_kv">Delete</span>'+
                        '</td>' +
                        '</tr>');
        }
        $("#free_prop_body").prepend(content);
        $(".fe_del_kv").on("click", function() {
            console.log("FEUS - displayFolksonomyPropertyValues() - 'Delete' pressed");
            isWellLoggedIn() ? delPropertyValue($(this)) : loginProcess(); 
        } );
        $(".fe_edit_kv").on("click", function() {
            console.log("FEUS - displayFolksonomyPropertyValues() - 'Edit' pressed");
            isWellLoggedIn() ?
            editPropertyValue($(this)) :
            loginProcess(function () {
                editPropertyValue(this);
            });
        } );
    });
}


function displayProductsWithProperty(_property, _value) {

    /* curl -X 'GET' \
        'https://api.folksonomy.openfoodfacts.org/products?k=test&v=test' \
        -H 'accept: application/json'
    */
    //$("#main_column p").remove();  // remove <p>Invalid address.</p>
    $("#main_column").append('<!-- display products with property ' + _property + (_value ? ": "+ _value : '') + ' -->' +
                                '<h2 id="property_title">Property: '+ _property + (_value ? ": "+ _value : '') + '</h2>' +
                                '<p>You should find a <a href="https://wiki.openfoodfacts.org/Folksonomy/Property/'+ _property + '">dedicated documentation</a>' +
                                ' about this property on Open Food Facts wiki</p>' +
                                '<p>List of products using this property:</p>' +
                                '<div id="fe_infobox" style="float: right; border: solid black; width: 20%">Tip: you can also find the <a href="/properties">list of all properties</a>.</div>' +
                                '<ul id="product_list"></ul>');
    //$("#main_column h1").remove(); // remove <h1>Error</h1>

    console.log("FEUS - displayProductsWithProperty(_property) - GET " + feAPI + "/products?k=" + _property + (_value ? "&v="+ _value : ''));
    $.getJSON(feAPI + "/products?k=" + _property + (_value ? "&v="+ _value : ''), function(data) {
        console.log("FEUS - displayProductsWithProperty() - " + JSON.stringify(data));
        let index = data.length; 
        let content = "";
        //const mainAPI = window.location.origin;
        //$.getJSON(mainAPI +
        content +=
            '<table id="properties_list">' +
            '<tr>' +
            '<th class="product_code">Code</th>' +
            '<th class="values">Values</th>' +
            '</tr>' +
            '<tbody id="free_prop_body">';
        while (index--) {
            content += ('<tr>' +
                        '<td class="product_code">' +
                        '<a href="/product/'+ data[index].product + '">' + data[index].product + '</a>' +
                        '</td>' +
                        '<td class="property_value">'+
                        '<a href="/property/'+ _property + '/value/' + data[index].v + '">' + data[index].v + '</a>' +
                        '</td>' +
                        '</tr>');
        }
        content +=
            '' +
            '</tbody>' +
            '</table>';
        $("#product_list").append(content);
    });
}


function displayAllProperties() {

    /* curl -X 'GET' \
            'https://api.folksonomy.openfoodfacts.org/keys' \
            -H 'accept: application/json'
    */
    // TODO: add owner filter?
    //$("#main_column p").remove(); // remove <p>Invalid address.</p>
    $("#main_column").append(String('<h2 id="property_title">Properties</h2>' +
                                '<p>List of all properties.</p>' +
                                '<table id="properties_list">' +
                                '<tr>' +
                                '<th> </th>' +
                                '<th class="property_name">Property</th>' +
                                '<th class="count">Count</th>' +
                                '<th class="values">Values</th>' +
                                '<th class="doc">Documentation</th>' +
                                '</tr>' +
                                '<tbody id="free_prop_body">') +
                                '</tbody>' +
                                '</table>');
    //$("#main_column h1").remove(); // remove <h1>Error</h1>
    console.log("FEUS - displayAllProperties(_owner) - GET " + feAPI + "/keys");
    $.getJSON(feAPI + "/keys", function(data) {
        console.log("FEUS - displayAllProperties() - " + JSON.stringify(data));
        let index = data.length;
        let content = "";
        // sort by count
        const d = data.sort(function(a,b){ return a.count >b.count ?1 :-1; });
        while (index--) {
            content += ('<tr class="property">' +
                        '<td> </td>' +
                        '<td><a href="/property/'+ d[index].k + '">' + d[index].k + '</a></td>' +
                        '<td>' + d[index].count + '</td>' +
                        '<td>' + d[index].values + '</td>' +
                        '<td><a href="https://wiki.openfoodfacts.org/Folksonomy/Property/' + d[index].k + '">🔗</a></td>' +
                        '</tr>');
        }
        $("#properties_list").append(content);
    });
}


function delPropertyValue(_this) {

    /* curl -X 'DELETE' \
        'https://api.folksonomy.openfoodfacts.org/product/3760256070970/Test1620205047424?version=1' \
        -H 'accept: application/json' \
        -H 'Authorization: Bearer charlesnepote__U0da47a42-eb96-4386-b2eb-6e1657b7f969'
    */
    console.log("FEUS - delPropertyValue() - start");
    console.log($(_this).parent().text());
    const property = $(_this).parent().parent().children(".property").text();
    const version = $(_this).parent().parent().children(".version").attr("data-version");
    console.log(`
        curl -X 'DELETE' \\
            '${feAPI}/product/${code}/${property}?version=${version}' \\
            -H 'accept: application/json' \\
            -H 'Authorization: Bearer ${bearer}'`);
    fetch(feAPI + "/product/" + code + "/" + property + "?version=" + version,{
        method: 'DELETE',
        headers: new Headers({
            'Accept': 'application/json',
            'Authorization': 'Bearer ' + bearer,
            //'Content-Type':'application/json',
        }),
    }).
            then((resp) => {
        //console.log("FEUS - delPropertyValue() - resp: ", resp);
        console.log("FEUS - delPropertyValue() - resp.status: ", resp.status, ", ", resp.statusText);
        if (resp.ok) {
            // if success or delete the row
            console.log("FEUS - delPropertyValue() - remove row");
            $(_this).parent().parent().remove();
        }
    }).
        catch((err) => {
        console.log('FEUS - deleteKV() - ERROR. Something went wrong:' + err);
    });
}


/**
 * Add a property-value pair (a declaration) to a product
 * 
 * @param {string} _code The product barcode
 * @param {string} _k  The property to add
 * @param {string} _v  The value to add
 * @param {string} _owner The owner or "" if it's a public declaration
 * @returns {string} Returns values from http POST
 * @todo returns {string} Returns if yes (0) or no (1) the new declaration has been created ?
 */
function addKV(_code, _k, _v, _owner) {

    /* curl -X 'POST' \
                'https://api.folksonomy.openfoodfacts.org/product' \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer charlesnepote__U68ee7c02-20ff-42ab-a5a7-9436df6d5300' \
                -H 'Content-Type: application/json' \
                -d '{
                    "product": "3760256070970",
                    "k": "test",
                    "v": "test1",
                    "owner": "charlesnepote"
                    }'
    */
    console.log("FEUS - addKV() - addKV(" + _code + "," + _k  + "," + _v  + "," + _owner + ")");
    console.log("FEUS - "+
                "curl -X 'POST' \\\n" +
                "        '" + feAPI + "/product' \\\n" +
                "        -H 'accept; application/json' \\\n" +
                "        -H 'Authorization: Bearer " + bearer + "' \\\n" +
                "        -H 'Content-Type: application/json' \\\n" +
                "        -d '{ \"product\": \"" + _code + "\", \"k\": \"" + _k + "\", \"v\": \"" + _v + "\", \"owner\": \""+_owner+"\" }'");
    let resStatus = 0;
    fetch(feAPI + "/product",{
        method: 'POST',
        //mode: 'no-cors',         // no!
        //withCredentials: true,   // no! provide CORS error
        //credentials: 'include',  // no! provide CORS error
        headers: new Headers({
            'Accept': 'application/json',
            'Authorization': 'Bearer ' + bearer,
            'Content-Type': 'application/json'
        }),
        body: '{"product": "' + _code + '", "k": "' + _k + '", "v": "' +_v + '", "owner": "' + _owner + '"}'
    }).
        then((res) => {
        resStatus = res.status;
        if (res.status == 200) {
            // update UI
            // 1. Add a new row to the table
            $("#free_prop_body").append('<tr>'+
                                        '<td class="version" data-version="1"></td>'+
                                        '<td class="property"><a href="/property/' + _k + '">' + _k + '</a></td>'+
                                        '<td class="value"><a href="/property/' + _k + '/value/' + _v + '">' + _v + '</a></td>'+
                                        '<td>'+
                                        '<span class="button tiny fe_save_kv" style="display: none">save</span> '+
                                        '<span class="button tiny fe_edit_kv">Edit</span> '+
                                        '<span class="button tiny fe_del_kv">Delete</span>'+
                                        '</td>'+
                                        '</tr>');
            $(".fe_del_kv").click( function() { isWellLoggedIn() ? delPropertyValue($(this)) : loginProcess(); } );
            $(".fe_edit_kv").click( function() { isWellLoggedIn() ? editPropertyValue($(this)) : loginProcess(); } );
            // 2. clear the form
            $("#fe_form_new_property").val("");
            $("#fe_form_new_value").val("");
            
            return res.json();
        } else {
            console.log(res);
            throw Error(res.statusText+res.status);
        }
        //return res.json();
        }).
        then((res) => {
        // When API answers an 422 error, the message is included in a {detail: {msg: "xxx"}} object
        // When API answers a 200, the message is "ok"
        const data = res.data ? res.data : res.detail.msg;
        console.log(JSON.stringify(data));
    }).
        catch((err) => { // network errors like 500
        console.log('FEUS - addKV() - ERROR. Something went wrong: ' +
                    resStatus +
                    err);
    });
}


function editPropertyValue(_this) {
    // UI: create input field and replace "edit" button by "save" button
    console.log("FEUS - editPropertyValue() - start");
    const property = $(_this).parent().parent().children(".property").text();
    const property_id = property.replace(/\W/g,'_'); // create an valid id 
    const oldValue = $(_this).parent().parent().children(".value").text();
    const version = $(_this).parent().parent().children(".version").data("version");

    // build UI: make value editable
    $(_this).parent().parent().children(".value").html('<input id="fe_' + property_id + '_form_value" type="text" maxlength="255" name="value" value="'+oldValue+'"  autofocus required />');
    //$(_this).parent().parent().children(".value").text('<input class="fe_form_value" type="text" maxlength="255" name="value" autofocus required>'+_value+'</input>');
    // replace [Edit] by [Save]
    $(_this).hide();
    $(_this).parent().children(".fe_save_kv").show();
    console.log("FEUS - editPropertyValue() - ", $(_this).parent().parent().find("#fe_" + property_id + "_form_value"));

    // call modifyKV if save button
    $(".fe_save_kv").on("click",
        function() {
            // Do not save anything if value is empty
            if (!$("#fe_" + property_id + "_form_value").val()) {
                console.log("FEUS - editPropertyValue() - No value provided!");

                return;
            }
            isWellLoggedIn() ?
            updatePropertyValue(code, property, $(_this).parent().parent().find("#fe_" + property_id + "_form_value").val(), "", version+1) :
            loginProcess();
        }
    ); 
}


function updatePropertyValue(_code, _k, _v, _owner, _version) {
    // {
    //   "product": "string",
    //   "k": "string",
    //   "v": "string",
    //   "owner": "",
    //   "version": 1,
    //   "editor": "string",
    //   "last_edit": "2021-05-06T07:50:53.258Z",
    //   "comment": ""
    // }
    /* curl -X 'PUT' \
                'https://api.folksonomy.openfoodfacts.org/product' \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer charlesnepote__U68ee7c02-20ff-42ab-a5a7-9436df6d5300' \
                -H 'Content-Type: application/json' \
                -d '{
                    "product": "3760256070970",
                    "k": "test",
                    "v": "test1"
                    }'
    */
    console.log("FEUS - "+
                "curl -X 'PUT' \\\n" +
                "        '" + feAPI + "/product' \\\n" +
                "        -H 'accept; application/json' \\\n" +
                "        -H 'Authorization: Bearer " + bearer + "' \\\n" +
                "        -H 'Content-Type: application/json' \\\n" +
                "        -d '{ \"product\": \"" + _code + "\", \"k\": \"" + _k + "\", \"v\": \"" + _v + "\", \"version\": " + _version + " }'");
    let resStatus = 0;
    fetch(feAPI + "/product",{
        method: 'PUT',
        headers: new Headers({
            'Accept': 'application/json',
            'Authorization': 'Bearer ' + bearer,
            'Content-Type':'application/json',
        }),
        body: '{"product": "' + _code + '", "k": "' + _k + '", "v": "' +_v + '", "version": "' + _version + '"}'
    }).
        then((res) => {
            resStatus = res.status;
        if (res.status >= 200 && res.status <= 299) {
            return res.json();
        } else {
            console.log(res);
            throw Error(res.statusText+res.status);
        }
        //return res.json();
    }).
        then((resp) => {
        if (resStatus == 500) {
            console.log("FEUS - 500 error");
        }
        if (resStatus == 200) {
            console.log("FEUS - resp: ", resp, " - status: ", resStatus);
        }
        else {
            const data = resp.data; //
            console.log(JSON.stringify(data));
            console.log("FEUS - " + resp + resStatus);
        }
    }).
        catch((err) => { // network errors like 500
        console.log('FEUS - updatePropertyValue() - ERROR. Something went wrong: ' +
                    resStatus +
                    err);
    });
}


/**
 * Displays all the free properties created and filed by users (product edition mode).
 * Examples:
 *    * Photo_Front: To be updated
 *
 * @returns {undefined}
 */
function displayFolksonomyForm() {
    $(".details").before(
        '<div id="free_properties" style="background-color: ">' +
        '<h2>User properties</h2>' +
        '<p>These properties are created and filled by users for any kind of usages.</p>' +
        '<div id="product_free_properties" class="fieldset">' +
        '</div>' +
        '</div>');

    $.getJSON(feAPIProductURL, function(data) {
        console.log("FEUS - displayFolksonomyForm() - URL: " + feAPIProductURL);
        console.log("FEUS - displayFolksonomyForm() - " + JSON.stringify(data));
        let index = data.length;
        let content = "";
        const d = data.sort(function(a,b){ return a.k <b.k ?1 :-1; });
        while (index--) {
            content += ('<form class="free_properties_form">' +
                        '<p class="property_value">' +
                        '<label for="feus-' + d[index].k + '" class="property">' + d[index].k + '</label> ' +
                        '<input id="feus-' + d[index].k + '" name="'+ d[index].k + '" class="value text" value="'+ d[index].v + '">' +
                        '</p>' +
                        '</form>');
        }
        $("#product_free_properties").append(content);
    });

    $("#free_properties").append(
        '<form class="new_free_properties_form" action="'+ feAPI + '/product">' +
        '<p class="property_value">' +
        '<label for="k" class="property">Property: </label> ' +
        '<input id="feus-k" name="k" class="value text"></input>' +
        '<label for="v" class="property">Value: </label> ' +
        '<input id="feus-v" name="v" class="value text"></input>' +
        '</p>' +
        '<button>New property</button>' +
        '</form>'
    );
}


/**
 * isPageType: Detects which kind of page has been loaded
 * See also https://github.com/openfoodfacts/openfoodfacts-server/pull/4533/files
 *
 * @returns  {String} - Type of page: api|saved-product page|edit|list|search form|product view|error page
 */
function isPageType() {
    // Detect API page. Example: https://world.openfoodfacts.org/api/v0/product/3599741003380.json
    if (new RegExp('api/v0/').test(document.URL) === true) { return "api"; }

    // Detect API page. Examples:
    // * https://world.openfoodfacts.org/property/test
    // * https://world.openfoodfacts.org/property/test/value/test
    if (new RegExp('/property/').test(document.URL) === true) { return "property"; }

    // Detect properties page. Example: https://world.openfoodfacts.org/properties
    if (new RegExp('properties$').test(document.URL) === true) { return "properties"; }

    // Detect producers platform
    //if (new RegExp('\\.pro\\.open').test(document.URL) === true) { proPlatform = true; }

    // Detect "edit" mode.
    if (new RegExp('product\\.pl').test(document.URL) === true) {
        if ($("body").hasClass("error_page")) { return "error page"; } // perhaps a more specific test for product-not-found?
        //if (!$("#sorted_langs").length) { return "saved-product page"; } // Detect "Changes saved." page
        //else { return "edit"; }

        return ($("#sorted_langs").length) ? "edit" : "saved-product page";
    }

    // Detect other error pages
    if ($("body").hasClass("error_page")) { return "error page"; }

    // Detect page containing a list of products (home page, search results...)
    if ($("body").hasClass("list_of_products_page")) { return "list"; }
    // Hack for Open Products Facts, Open Pet Food Facts, Open Beauty Facts
    if ($(".products")[0]) { return "list"; }

    // Detect search form
    if (new RegExp('cgi/search.pl$').test(document.URL) === true) { return "search form"; }

    // Detect recentchanges
    if ($("body").hasClass("recent_changes_page")) { return "recent changes"; }

    //Detect if in the list of ingredients
    if (new RegExp('ingredients').test(document.URL) === true) { return "ingredients"; }

    // Finally, it's a product view
    if ($("body").hasClass("product_page")) { return "product view"; }

    // Hack for Open Products Facts, Open Beauty Facts...
    if ($("body").attr("typeof") === "food:foodProduct") { return "product view"; }
}


function loginProcess(callback) {
    // Try to authenticate using the Open Food Facts cookie first
    var cookie = $.cookie('session') ? $.cookie('session') : "";
    if (cookie) {
        console.log("FEUS - loginProcess(callback) => getCredentialsFromCookie()");
        getCredentialsFromCookie(cookie, callback);
        
        //return;
    }
    else {
        window.alert("You must be logged in first!");

        //return;
    }
    // TODO: Reenable login ?
    // Else display a form
    // const loginWindow =
    //     '<div data-reveal-id="dialog-form" id="fe_login_dialog" title="Dialog Form" aria-hidden="true" role="dialog">' +
    //     '<form name="login_form">' +
    //     '<label>Username:</label>' +
    //     '<input name="username" type="text" value="'+ getConnectedUserID() + '">' +
    //     '<label>Password:</label>' +
    //     '<input name="password" type="password" value="">' +
    //     '<input id="login_submit" type="submit" value="Login">' +
    //     '</form>' +
    //     '<div id="login_result"></div>' +
    //     '</div>';
    // $('#free_properties_1').append(loginWindow);
    // //showPopupInfo(loginWindow); // open a new window
    // $('#fe_login_dialog').foundation('reveal', 'open');

    // const form = document.forms.login_form;
    // console.log(form);
    // form.addEventListener('submit', (e) => {
    //     console.log("FEUS - Submited");
    //     e.preventDefault();  // Do not submit the form
    //     const username = $('[name="username"]').val();
    //     const password = $('[name="password"]').val();
    //     console.log("FEUS - loginProcess - username: " + username);
    //     getCredentials(username, password, function() {
    //         console.log("FEUS - loginProcess() - callback");
    //         if (isWellLoggedIn() === true) { togglePopupInfo(loginWindow); }
    //     });
    // });

}


function getCredentialsFromCookie(_cookie, callback) {
    console.log("FEUS - getCredentialsFromCookie - call " + feAPI + "/auth with callback", callback);
    console.log(`
    curl -X 'POST' \\
        'http://api.fr.openfoodfacts.localhost:8000/auth_by_cookie' \\
        -H 'accept: application/json' \\
        -H 'Cookie: ${_cookie}' \\
        -d ''`
    );
    // Cookie should be in the form: session=user_session&1WVzzIhNZgV1WtUtuw2s4vuSkeBqBn3bBC9I4tcRcYX5FlMTnPXSz89Fh0MO4hIR&user_id&charlesnepote'
    fetch(feAPI + '/auth_by_cookie',{
        method: 'POST',
        //credentials: 'same-origin',
        credentials: 'include',
        headers:{
            Accept: 'application/json',
        }
    }).
        then((payload) => payload.json()).
        then((resp) => {
        console.log(resp);
        console.log(resp.access_token);
        if (resp.access_token) {
            bearer = resp.access_token;
            console.log("FEUS - getCredentialsFromCookie - bearer: " + bearer);
            localStorage.setItem('bearer',resp.access_token);
            localStorage.setItem('date',new Date().getTime());
        }
        else {
            console.log("FEUS - getCredentialsFromCookie - Enable to get credentials!");
            window.alert("Enable to get credentials!");
        }
        callback();
    }).
        catch((err) => {
        console.log('FEUS - getCredentialsFromCookie - ERROR. Something went wrong:' + err);
    });

}


// function getCredentials(_username, _password, callback) {
//     console.log("FEUS - getCredentials - call " + feAPI + "/auth");
//     console.log("FEUS - getCredentials - username: " + _username);
//     fetch(feAPI + '/auth',{
//         method: 'POST',
//         headers:{
//             Accept: 'application/json',
//             'Content-Type': 'application/x-www-form-urlencoded',
//         },
//         body: 'grant_type=&username='+_username+'&password='+_password+'&scope=&client_id=&client_secret=',
//     }).
//         then((payload) => payload.json()).
//         then((resp) => {
//         console.log(resp);
//         console.log(resp.access_token);
//         bearer = resp.access_token;
//         console.log("FEUS - getCredentials - bearer: " + bearer);
//         localStorage.setItem('bearer',resp.access_token);
//         localStorage.setItem('date',new Date().getTime());

//         if (isWellLoggedIn() == true) { togglePopupInfo(loginWindow); }
//     }).
//         catch((err) => {
//         console.log('FEUS - getCredentials - ERROR. Something went wrong:' + err);
//     });
// }


// // Show pop-up
// function showPopupInfo(message) {
//     console.log("showPopupInfo(message) > " + $("#popup-info"));
//     // Inspiration: http://christianelagace.com
//     // If not already exists, create div for popup
//     if($("#popup-info").length === 0) {
//         $('body').append('<div id="popup-info" title="Information"></div>');
//         $("#popup-info").dialog({autoOpen: false});
//     }

//     $("#popup-info").html(message);

//     // transforme la division en popup
//     const popup = $("#popup-info").dialog({
//         autoOpen: true,
//         width: 400,
//         dialogClass: 'dialogstyleperso',
//     });
//     // add style if necessarry
//     //$("#power-user-help").prev().addClass('ui-state-information');

//     return popup;
// }


// // Toggle popup
// function togglePopupInfo(message) {
//     if ($("#popup-info").dialog( "isOpen" ) === true) {
//         $("#popup-info").dialog( "close" );
        
//         return false;
//     } else {

//         return showPowerUserInfo(message);
//     }
// }


/**
 * isWellLoggedIn: returns if the user is logged in or not
 * 
 * @returns  {boolean} - 
 */
function isWellLoggedIn() {
    // User is not identified and has never been
    if (localStorage.getItem('bearer') === null) {
        console.log("FEUS - isWellLoggedIn() - false (bearer does not exist)");
        
        return false;
    }
    const deadLine = parseFloat(localStorage.getItem('date')) + parseFloat(authrenewal);
    //const rest = (deadLine - new Date().getTime())/1000; // Delay between deadline and now, in seconds
    //console.log("FEUS - isWellLoggedIn() - deadLine (" + deadLine + ") - new Date().getTime() (" + new Date().getTime() + ") = " + rest);
    //console.log("FEUS - isWellLoggedIn() - localStorage.getItem('date'):" + localStorage.getItem('date'));
    if (deadLine < new Date().getTime()) {
        console.log("FEUS - isWellLoggedIn() - false");
        
        return false;
    }
    else {
        bearer = localStorage.getItem('bearer');
        console.log("FEUS - isWellLoggedIn() - true - Bearer: " + bearer);

        return true;
    }
}




// /**
//  * getConnectedUserID: returns user id of the current connected user
//  * 
//  * @returns  {string} - user id; Example: "charlesnepote"
//  */
// function getConnectedUserID() {
//     // Extract connected user_id by reading <span id="#logged_in_user_id">charlesnepote</span>
//     const user_name = $("#logged_in_user_id").text();
//     console.log("getConnectedUserID() > user_name: " + user_name);
    
//     return user_name;
// }


/**
 * Returns an array with the frequency of each value related to a particular key
 * 
 * @param {array} arr  Array of objects
 *                     [
 *                       {"p": "2567", "v": "yes"},
 *                       {"p": "5745", "v": "yes"}
 *                     ]
 * @param {string} key Name of key
 * @returns {array}    Array of objects containing the frequency of the key "key"
 *                     [{key1: 3}, {key2: 5}]
 */
function findOcc(arr, key) {
    const arr2 = [];
    arr.forEach((x) => {
    // Checking if there is any object in arr2 which contains the key value
    if (arr2.some((val) => val[key] == x[key])) {
        // If yes! then increase the occurrence by 1
        arr2.forEach((k) => {
        if (k[key] === x[key]) {
            k.occurrence++;
        }
        });
    } else {
        // If not! Then create a new object initialize it with the
        // present iteration key's value and set the occurrence to 1
        const a = {};
        a[key] = x[key];
        a.occurrence = 1;
        arr2.push(a);
    }
    });

    return arr2; // [{val1: 3}, {val2: 5}]
}
    
