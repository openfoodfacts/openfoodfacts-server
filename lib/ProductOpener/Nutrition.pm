use ProductOpener::PerlStandards;
use ProductOpener::Units qw/unit_to_g/;

sub generate_nutrient_set_preferred_from_sets {
    my ($nutrient_sets_ref) = @_; 
    my @nutrient_sets = @$nutrient_sets_ref;
    
    my $nutrient_set_preferred_ref = {};
    
    if (@nutrient_sets) {
        @nutrient_sets = sort_sets_by_priority(@nutrient_sets);

        if (%{$nutrient_sets[0]}) {
            $nutrient_set_preferred_ref->{preparation} = $nutrient_sets[0]{preparation};
            $nutrient_set_preferred_ref->{per} = $nutrient_sets[0]{per};
            $nutrient_set_preferred_ref->{per_quantity} = $nutrient_sets[0]{per_quantity};
            $nutrient_set_preferred_ref->{per_unit} = $nutrient_sets[0]{per_unit};
        }
        
        $nutrient_set_preferred_ref = set_nutrient_values($nutrient_set_preferred_ref, @nutrient_sets);
    }
    return $nutrient_set_preferred_ref;
}

my %source_priority = (
    manufacturer => 0,
    packaging => 1,
    usda => 2,
    estimate => 3,
    _default => 4,
);

my %preparation_priority = (
    prepared => 0,
    as_sold => 1,
    _default => 2,
);

my %per_priority = (
    "100g" => 0,
    "100ml" => 0,
    serving => 1,
    _default => 2,
);

sub sort_sets_by_priority (@nutrient_sets) {
    return sort {
        my $source_key_a = defined $a->{source} ? $a->{source} : '_default';
        my $source_key_b = defined $b->{source} ? $b->{source} : '_default';
        my $source_a = $source_priority{$source_key_a};
        my $source_b = $source_priority{$source_key_b};

        my $per_key_a = defined $a->{per} ? $a->{per} : '_default';
        my $per_key_b = defined $b->{per} ? $b->{per} : '_default';
        my $per_a = $per_priority{$per_key_a};
        my $per_b = $per_priority{$per_key_b};

        my $preparation_key_a = defined $a->{preparation} ? $a->{preparation} : '_default';
        my $preparation_key_b = defined $b->{preparation} ? $b->{preparation} : '_default';
        my $preparation_a = $preparation_priority{$preparation_key_a};
        my $preparation_b = $preparation_priority{$preparation_key_b};
        
        return $source_a <=> $source_b || $per_a <=> $per_b || $preparation_a <=> $preparation_b;
    } @nutrient_sets;
}

sub set_nutrient_values ($nutrient_set_preferred_ref, @nutrient_sets) {
    foreach my $nutrient_set (@nutrient_sets) {
        if (    defined $nutrient_set->{preparation}
            and $nutrient_set->{preparation} eq $nutrient_set_preferred_ref->{preparation}
            and exists $nutrient_set->{nutrients} 
            and ref $nutrient_set->{nutrients} eq 'HASH') 
        {
            foreach my $nutrient (keys %{$nutrient_set->{nutrients}}) {
                if (!exists $nutrient_set_preferred_ref->{nutrients}{$nutrient}
                    and $nutrient_set->{per} eq $nutrient_set_preferred_ref->{per}) 
                {
                    $nutrient_set_preferred_ref->{nutrients}{$nutrient} = $nutrient_set->{nutrients}{$nutrient};
                    nutrient_in_g($nutrient_set_preferred_ref->{nutrients}{$nutrient});
                    $nutrient_set_preferred_ref->{nutrients}{$nutrient}{source} = $nutrient_set->{source};
                    $nutrient_set_preferred_ref->{nutrients}{$nutrient}{source_per} = $nutrient_set->{per};    
                }
            }
        }
    } 
    return $nutrient_set_preferred_ref;
}

sub nutrient_in_g ($nutrient_ref) {
    if ($nutrient_ref->{unit} ne "g") {
        $nutrient_ref->{value} = unit_to_g($nutrient_ref->{value}, $nutrient_ref->{unit});
        $nutrient_ref->{value_string} = sprintf("%s", $nutrient_ref->{value});
        $nutrient_ref->{unit} = "g";
    }
}
1;