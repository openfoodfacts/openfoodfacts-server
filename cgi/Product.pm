package Blogs::Product;
use strict;
use warnings FATAL => 'all';

sub new {
    my $class = shift;
    my $self = {
        # Properties (Hash)
        dic_props => shift,
    };
    # Add additional entities to object Product
    # product reference (no by default)
    $self->{isRef} = 0;
    # Nb of categories' intersections with reference product:
    # while fetching similar products, always 1 at creation since there was a match on a category
    $self->{nb_categories_intersect_with_ref} = 1;
    # Proximity with product reference is computed later on
    $self->{score_proximity} = 0;  # X-axis
    $self->{score_nutrition} = 0;  # Y-axis
    # exclude from graph if no comparison possible (0/1; 0= do not exclude).
    # We can add exclusion criteria such as:
    #  * generic-name is empty
    #  * too far in similarity with reference product (nb categories intersections too low)
    $self->{excludeFromGraph} = 0;

    bless $self, $class;
    return $self;
}

sub get_id {
    my ( $self ) = @_;
    my $dic_props = $self->{dic_props};
    return $dic_props->{"_id"};
}

sub set_as_reference {
    my ( $self, $is_ref ) = @_;
    $self->{isRef} = $is_ref;

    if ($is_ref eq 1) {
        $self->{score_proximity} = 1;
        # compute also the nutrition score
        $self->{score_nutrition} = $self->calc_score_nutrition();
        print "score nutrition of product reference = ", $self->calc_score_nutrition(), "\n";
    }
}

sub incr_intersection_with_ref {
    # When a match on category is found with product reference, then we increment the number of intersected categories
    # ..in order to speed up a bit the proximity computation thereafter
    my ( $self ) = @_;
    $self->{nb_categories_intersect_with_ref} += 1;
}

sub compute_scores {
    my ( $self, $product_ref ) = @_;
    $self->calc_score_proximity($product_ref);
    $self->calc_score_nutrition();
}

sub calc_score_proximity {
    # The bigger the intersection of categories between self and product_ref, the closer
    # Note: if intersection is 100%, then proximity is 100%
    # Proximity = nb_categ_intersect / nb_categ_prod_ref
    my ( $self, $product_ref ) = @_;
    # categories_tags is an Array
    my $nb_categs_ref = scalar @{$product_ref->{dic_props}->{categories_tags}};
    $self->{score_proximity} = $self->{nb_categories_intersect_with_ref} / $nb_categs_ref;
}

sub calc_score_nutrition {
    # see : http://fr.openfoodfacts.org/score-nutritionnel-france
    my ( $self ) = @_;
    my $dic_props = $self->{dic_props};
    # nutriments is a Hash
    my $nutriments = $dic_props->{"nutriments"};
    if (!(exists( $nutriments->{"nutrition-score-uk"} ))) {
        # add security in case this is the product reference (we want it to be shown in the graph and not to be excluded)
        if ($self->{isRef} == 1) {
            $self->{score_nutrition} = 0;
            $self->{score_proximity} = 0;
        } else {
            $self->{excludeFromGraph} = 1;
        }
    } else {
        # todo: to be reviewed for waters, countries, etc., as explained in the above url
        # initialize: Data Environment, Gui for display, and Querier
        $self->{score_nutrition} = int( $nutriments->{"nutrition-score-uk"} );
    }
}

1;