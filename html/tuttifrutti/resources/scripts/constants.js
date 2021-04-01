/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) on 18/03/18.
 */
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

var GRAPH_WIDTH = $(window).innerWidth();
var GRAPH_HEIGHT = $(window).innerHeight() * 40 / 100;
var OPEN_OFF_PAGE_FOR_SELECTED_PRODUCT = false;
// var PRODUCT_CODE_DEFAULT = '4104420017849';
var PRODUCT_CODE_DEFAULT = '0059749894456';
var OFF_BACKGROUND_COLOR = "#09f";

/* ids of html-item for attaching graph data and product reference details (image, etc.) */
var ID_CELL_BANNER = "#banner";
var ID_SERVER_LOG = '#echoResultLog';
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
var ID_MENU_SELECTION = "#menu_selection";
var ID_BTN_SUBMIT = "#submitBtn";
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