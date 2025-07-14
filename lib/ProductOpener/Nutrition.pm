use ProductOpener::PerlStandards;

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
        
        foreach my $nutrient_set (@nutrient_sets) {
            if (exists $nutrient_set->{nutrients} 
                && ref $nutrient_set->{nutrients} eq 'HASH') 
            {
                foreach my $nutrient (keys %{$nutrient_set->{nutrients}}) {
                    $nutrient_set_preferred_ref->{nutrients}{$nutrient} = $nutrient_set->{nutrients}{$nutrient};
                    $nutrient_set_preferred_ref->{nutrients}{$nutrient}{source} = $nutrient_set->{source};
                    $nutrient_set_preferred_ref->{nutrients}{$nutrient}{source_per} = $nutrient_set->{per};
                }
            }
        }  
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
        my $source_a = $source_priority{$a->{source}} // $source_priority{_default};
        my $source_b = $source_priority{$b->{source}} // $source_priority{_default};

        my $per_a = $per_priority{$a->{per}} // $per_priority{_default};
        my $per_b = $per_priority{$b->{per}} // $per_priority{_default};

        my $preparation_a = $preparation_priority{$a->{preparation}} // $preparation_priority{_default};
        my $preparation_b = $preparation_priority{$b->{preparation}} // $preparation_priority{_default};
        
        return 
               $source_a <=> $source_b
            || $per_a <=> $per_b
            || $preparation_a <=> $preparation_b;
    } @nutrient_sets;
}

1;