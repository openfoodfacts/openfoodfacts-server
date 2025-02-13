#!/bin/sh

cd /srv/off-pro/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./export_and_import_to_public_database.pl --query states_tags=en:to-be-automatically-exported --owner all


