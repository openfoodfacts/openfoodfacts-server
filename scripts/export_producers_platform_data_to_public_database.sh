#!/bin/bash
# import various producers data to public platform in automated mode
# this script must be launched in /srv/off-pro/

export PERL5LIB="lib:${PERL5LIB}"

filter_organizations_that_have_automated_export() {
    perl -e '
        use strict;
        use warnings;
        use ProductOpener::Orgs qw/list_org_ids retrieve_org/;

        my %producers = qw(
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
        );

        my @orgs = map { 
            "org-" . $_->{"org_id"} 
        }
        grep { 
            exists $_->{"activate_automated_daily_export_to_public_platform"} 
            and $_->{"activate_automated_daily_export_to_public_platform"} eq "on"
        } 
        map { retrieve_org($_) } list_org_ids();

        $producers{$_} = undef for @orgs;

        print "$_\n" for keys %producers;
    '
}

PRODUCERS=$(filter_organizations_that_have_automated_export)

for producer in ${PRODUCERS[@]}
do
    scripts/export_and_import_to_public_database.pl --query states_tags=en:to-be-exported --owner $producer
done
