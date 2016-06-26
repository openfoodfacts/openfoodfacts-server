package Blogs::DataEnv;
use strict;
use warnings FATAL => 'all';

# Environment for data. Specifies the set of fields (selection/projection of fields) retrieved from server for matching products (Querier)

sub new {
    # Usage : new DataEnv(String[] set_of_properties)
    my $class = shift;
    my $self = {
        # Address of array of properties
        _prod_props_to_display => shift
    };
    # Array of properties
    my @prod_props_to_display = @{$self->{_prod_props_to_display}};

    if (!( grep /code/, @prod_props_to_display)) {
        push @prod_props_to_display, "code";
    }
    if (!( grep /_id/, @prod_props_to_display)) {
        push @prod_props_to_display, "_id";
    }
    # set_of_properties: [] of properties
    $self->{_prod_props_to_display} = \@prod_props_to_display;
    bless $self, $class;
    return $self;
}
1;

