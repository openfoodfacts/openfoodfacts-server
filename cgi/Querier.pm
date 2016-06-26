package Blogs::Querier;
use strict;
use warnings FATAL => 'all';
use MongoDB;    # https://metacpan.org/pod/MongoDB pour un exemple
use JSON;
use Product qw/:all/;

sub new
{
    # Usage : new Querier(DataEnv data_env, boolean verbose)
    my $class = shift;
    my $self = {
        # Object DataEnv
        _data_env => shift,
        _verbose  => shift,
        _pongo    => 1
    };

    bless $self, $class;

    return $self;
}


sub connect {
    # Connection to the OFF-Product database
    my ( $self ) = @_;
    my $verbose = $self->{_verbose};

    # todo: review since hard-coded!
    if ($verbose == 1) {
        print '.. connecting to server MongoClient ("127.0.0.1", 27017)\n';
    }
    $self->{_pongo} = MongoDB->connect( 'mongodb://127.0.0.1:27017' );

    if ($verbose == 1) {
        print ".. connecting to OPENFOODFACTS database and getting PRODUCTS collection\n";
    }
    my $coll_products = $self->{_pongo}->MongoDB::MongoClient::ns( 'off-fr.products' ); # database off-fr, collection products
    my $nb_prods = $coll_products->find()->count();
    if ($verbose == 1) {
        print "${nb_prods} products are referenced\n";
    }
}

sub disconnect {
    # Closing connection
    my ( $self ) = @_;
    my $verbose = $self->{_verbose};

    if ($verbose == 1) {
        print ".. closing connection\n";
    }
    $self->{_pongo}->MongoDB::MongoClient::disconnect();
    if ($verbose == 1) {
        print "done.\n";
    }
}

sub fetch {
    # Fecthes all products matching a single criterium
    #  :param prop: criterium key
    #  :param val: criterium value
    #  :return: list of Product
    my ( $self, $prop, $val) = @_;
    $self->{_prop} = $prop if defined( $prop );
    $self->{_val} = $val if defined( $val );

    my @products_fetched = ();

    # Preparing projection fields for the find request (no _id)
    my %fields_projection;
    # ..retrieve from stored object _data_env the array of product properties
    my $obj_data_env = $self->{_data_env};
    my @product_properties = @{$obj_data_env->{_prod_props_to_display}};

    my $a_property = "";
    foreach $a_property (@product_properties) {
#        print "prop = $a_property";
#        print "\n";
        $fields_projection{$a_property} = 1;
    }
    # id, code and categories always retrieved (used as filter criteria = projection)
    $fields_projection{"_id"} = 1;
    $fields_projection{"code"} = 1;
    $fields_projection{"categories_tags"} = 1;

    if ($self->{_verbose}) {
        print ".. fetching product details with { $self->{_prop}: $self->{_val} } ..\n";
    }

    my $pongo = $self->{_pongo};
    # todo: add fields_projection to retrieve just the required fields from the MongoDB
    #    my $cursor = $pongo->ns( 'off-fr.products' )->find( { $prop => $val }, %fields_projection );
    my $cursor = $pongo->MongoDB::MongoClient::ns( 'off-fr.products' )->find( { $prop => $val } );
    #    print %fields_projection;
    #    print "RESULT \n";
    # ******
    # note: checkbot.pl line 61 pour reprise du code
    # ******
    my $count = $cursor->count();
    if ($count > 0) {
        my $result = $cursor->result;
        print "found $count products \n";
        #    my $perl_scalar = decode_json $cursor;
        #    #    my $json = encode_json \$cursor;
        #    print "$perl_scalar \n";
        # todo : remove or update counter below (used just to reduce the nb of items match and debugging purposes)
        my $_tmp_nb_max = 50;
        my $_tmp_cpt=0;
        while ( my $product = $result->next ) {
            my $temp = $product;
            my $objProduct = Product->new( $temp );
            if ($_tmp_cpt < $_tmp_nb_max) {
                push ( @products_fetched, $objProduct );
            }
            $_tmp_cpt++;
        }
    }
    return @products_fetched;
}

sub find_match {
    # Perform a find for each watched criterion in aProduct
    #   :param properties_to_match: property-set for finding matching products (Array)
    #   :param a_product:  product with watched criteria
    #   :return: list of unique products matching the watched criteria of the aProduct
    my ( $self, $a_product, $properties_to_match) = @_;
    $self->{_a_product} = $a_product if defined( $a_product );
    $self->{_properties_to_match} = $properties_to_match if defined( $properties_to_match );

    my $dic_props = $a_product->{dic_props};    # is a Hash
    my $matching_products = ();

    my $tmp_matching_products = { };  # dictionary in order to avoid duplicates
    my $_id_prod_ref = $a_product->Product::get_id();
    foreach my $criterium ($properties_to_match) {
        my @tmp_array = @{$dic_props->{$criterium}};
        foreach my $crit_value (@tmp_array) {
            my @prods = $self->fetch( $criterium, $crit_value );    # $prod is an Array of Products
            if ($self->{_verbose} == 1) {
                print "\t $crit_value \t\t found ", scalar( @prods ), "\n";
            }
            # add matching products (no duplicate since we are using a dictionary)
            foreach my $prod (@prods) {
                # $prod is an object Product
                # removing identity product / add product
                my $_id_prod = $prod->Product::get_id();
                if ($_id_prod != $_id_prod_ref) {
                    if (!(exists($tmp_matching_products->{$_id_prod}))) {
                        $tmp_matching_products->{$_id_prod} = $prod;
                        # Add the Product to the returned array (easier to deal with later on)
                        push(@{$matching_products}, $prod);
                    } else {
                        $tmp_matching_products->{$_id_prod}->Product::incr_intersection_with_ref();
                    }
                }
            }
        }
    }

    return $matching_products;
}

1;