use ProductOpener::PerlStandards;

sub generate_nutrient_set_preferred_from_sets {
    my ($nutrient_sets_ref) = @_; 
    my @nutrient_sets = @$nutrient_sets_ref;
    
    my $nutrient_set_preferred_ref = {};
    if (@nutrient_sets) {
        $nutrient_set_preferred_ref = $nutrient_sets[0];

        if (exists $nutrient_set_preferred_ref->{nutrients} 
            && ref $nutrient_set_preferred_ref->{nutrients} eq 'HASH') 
        {
            for my $nutrient (keys %{$nutrient_set_preferred_ref->{nutrients}}) {
                $nutrient_set_preferred_ref->{nutrients}{$nutrient}{source} = $nutrient_set_preferred_ref->{source};
                $nutrient_set_preferred_ref->{nutrients}{$nutrient}{source_per} = $nutrient_set_preferred_ref->{per};
            }
        }
    }
    return $nutrient_set_preferred_ref;
}

1;