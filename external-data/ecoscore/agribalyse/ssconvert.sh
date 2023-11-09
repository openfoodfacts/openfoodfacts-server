#!/bin/sh
ssconvert AGRIBALYSE_vf.xlsm AGRIBALYSE_vf.csv -S
tail -n +9 AGRIBALYSE_vf.csv.2 | sort --numeric-sort --field-separator "," | perl -MText::CSV -le '
    binmode(STDOUT, ":utf8"); $csv = Text::CSV->new({binary=>1}); 
    while ($row_ref = $csv->getline(STDIN)){
        $csv->print(*STDOUT, [@$row_ref[0..5]]);
    }' > AGRIBALYSE_summary.csv
grep -oP '(?<=v)[0-9\.]*' AGRIBALYSE_vf.csv.0 > AGRIBALYSE_version.txt
