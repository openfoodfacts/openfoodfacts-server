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
        $name_en                # LCI Name
        ) = @$row_ref;
        print "$code,$ciqual_code,$group,$sub_group,$name_fr,$name_en";
    }' > AGRIBALYSE_summary.csv
