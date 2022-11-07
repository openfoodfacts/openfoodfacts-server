#!/bin/sh
ssconvert AGRIBALYSE_vf.xlsm AGRIBALYSE_vf.csv -S
tail -n +9 AGRIBALYSE_vf.csv.2 | sort --numeric-sort --field-separator "," | perl -MText::CSV -le '
    binmode(STDOUT, ":utf8"); $csv = Text::CSV->new({binary=>1}); 
    while ($row_ref = $csv->getline(STDIN)){
        my ($code,              # Agribalyse code 
        $ciqual_code,           # Ciqual code (equal to above)
        $group,                 # Groupe d aliment
        $sub_group,             # Sous-groupe d aliment
        $name_fr,               # Nom du Produit en Français
        $name_en,               # LCI Name
        $dqr,                   # DQR (data quality rating) warning: the AGB file has a hidden H column
        $ef_agriculture,        # Agriculture
        $ef_processing,         # Transformation
        $ef_packaging,          # Emballage
        $ef_transportation,     # Transport
        $ef_distribution,       # Supermarché et distribution
        $ef_consumption,        # Consommation
        $ef_total,              # Total
        $co2_agriculture,       # Agriculture
        $co2_processing,        # Transformation
        $co2_packaging,         # Emballage
        $co2_transportation,    # Transport
        $co2_distribution,      # Supermarché et distribution
        $co2_consumption,       # Consommation
        $co2_total              # Total
        ) = @$row_ref;
        print "$code,$ciqual_code,$group,$sub_group,$name_fr,$name_en,$dqr,$ef_agriculture,$ef_processing,$ef_packaging,$ef_transportation,$ef_distribution,$ef_consumption,$ef_total,$co2_agriculture,$co2_processing,$co2_packaging,$co2_transportation,$co2_distribution,$co2_consumption,$co2_total";
    }' > AGRIBALYSE_details_by_step.csv
