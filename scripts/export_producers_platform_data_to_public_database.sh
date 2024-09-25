#!/bin/bash
# import various producers data to public platform in automated mode
# this script must be launched in /srv/off-pro/

export PERL5LIB="lib:${PERL5LIB}"

filter_organizations_that_have_automated_export() {
    perl -e '
        use strict;
        use warnings;
        use ProductOpener::Data qw/get_orgs_collection/;

        my %producers = ();

        my @res = get_orgs_collection()
                        ->find({ activate_automated_daily_export_to_public_platform => "on" })
                        ->fields({ org_id => 1 })
                        ->all;

        $producers{"org-" . $_->{org_id}} = undef for @res;

        print "$_\n" for keys %producers;
    '
}

for producer in $(filter_organizations_that_have_automated_export)
do
    scripts/export_and_import_to_public_database.pl --query states_tags=en:to-be-exported --owner $producer
done
