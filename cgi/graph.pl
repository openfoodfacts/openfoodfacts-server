
# ################################
# CHECK START
# Goal: code-snippet for getting the value of the product reference in the url (param)
# inspired from search.pl
# ################################

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Tags qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

Blogs::Display::init();
use Blogs::Lang qw/:all/;

my $code = param('code');

# ################################
# CHECK END
# ################################

my @product_props_tofetch = ("code", "generic_name", "countries_tags", "categories_tags", "nutriments", "allergens",
    "brands_tags", "image_front_url");
my $data_env1 = DataEnv->new( \@product_props_tofetch );
my $querier = Querier->new( $data_env1, 0 );

# ################################
# CHECK START
# Goal: code-snippet for connecting to the mongo-db
# todo: insert in Querier->connect() or use the API in product-opener
# inspired from Display.pm lines 137-139
# ################################
$connection = MongoDB::Connection->new("host" => "localhost:27017");
$database =  $database = $connection->get_database($mongodb);
$products_collection = $database->get_collection('products');
# ################################
# CHECK END
# ################################

# retrieve product details into object
my @products = $querier->fetch( "code", $code );
my $nb_products = scalar( @products );

if ($nb_products == 0)
{
    print "WARNING: the product with code $code could not be found! \n";
} else {
    if ($nb_products > 1) {
        print "WARNING: more than 1 product match ... choosing 1st product";
    }
    my $myProduct = pop @products;
    # $myProduct is the  product reference!
    $myProduct->Product::set_as_reference( 1 );

    # fetch similar products with the same categories
    my $props_to_match = ("categories_tags");  # for the search of similar products based on this set of properties (matching criteria)
    my $products_match = $querier->find_match( $myProduct, $props_to_match );
    print ".. NUMBER of matching distinct products found: ", scalar( @{$products_match} ), "\n";

    my $statsProps = ("nutriments");  # for all products, extracting of these specific items for building the statistical graphs
    my $g = Graph->new( $statsProps, $myProduct, $products_match, 1 );
    $g->show();
}

# ################################
# CHECK START
# Goal: closing the connection to mongo-db
# todo: use the API in product-opener
# inspired from Display.pm lines 137-139
# ################################
# closing connection
$querier->disconnect();
# ################################
# CHECK END
# ################################

1;
