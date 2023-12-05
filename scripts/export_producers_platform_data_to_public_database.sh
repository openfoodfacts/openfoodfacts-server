#!/bin/sh
# import various producers data to public platform in automated mode
# this script must be launched in /srv/off-pro/

export PERL5LIB="lib:${PERL5LIB}"

PRODUCERS=(
org-barilla-france-sa
org-ferrero-france-commerciale
org-unilever-france-gms
org-unilever-france-rhd
org-nestle-france
org-panzani-sa
org-cristalco
org-materne
org-garofalo-france
org-brasseries-kronenbourg
org-carrefour
org-lustucru-frais
org-nestle-waters
org-kambly
org-kambly-france
org-saint-hubert
org-d-aucy
org-lea-nature
org-auchan-apaw
org-les-mousquetaires
)

for producer in ${PRODUCERS[@]}
do
    scripts/export_and_import_to_public_database.pl --query states_tags=en:to-be-exported --owner $producer
done
