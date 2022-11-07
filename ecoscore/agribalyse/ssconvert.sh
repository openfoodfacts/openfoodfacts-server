#!/bin/sh
ssconvert AGRIBALYSE_vf.xlsm AGRIBALYSE_vf.csv -S
tail -n +9 AGRIBALYSE_vf.csv.2 | sort --numeric-sort --field-separator "," > AGRIBALYSE_details_by_step.csv
