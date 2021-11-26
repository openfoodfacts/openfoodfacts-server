#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
# 
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;

# As of 2021-11-26, the names, synonyms, translations and properties of the different nutrients
# are hardcoded in Food.pm
# This script extracts the harcoded values to output them in taxonomy format.
# We will then remove the hardcoded values from Food.pm and use the taxonomy instead.

# Load the existing nutrients.txt created by @aleene
ProductOpener::Tags::retrieve_tags_taxonomy('nutrients_old');

open (my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/nutrients.txt");

# Go over all nutrients defined in Food.pm

foreach my $nid (@{$nutriments_tables{europe}}) {

    $nid =~ s/^!//;
    $nid =~ s/^-+//;
    $nid =~ s/-+$//;

    next if $nid =~ /^#/;

    my %translations = ();
    my %properties = ();

    foreach my $key (sort keys %{$Nutriments{$nid}}) {

        # iu and dv are properties, we change their names so that they are not confused with 2 letter language codes
        my $new_key = $key;
        if ($new_key =~ /^(iu|dv)/) {
            $new_key .= "_value";
        }

        print "key: $key - new_key: $new_key\n";

        if ($new_key =~ /^\w\w(_\w\w)?$/) {

            my $value = $Nutriments{$nid}{$key};

            # Butyric acid (4:0) -> make main name Butyric acid
            # Docosahexaenoic acid / DHA (22:6 n-3)
            $value =~ s/\s+\(\d+:\d+[^\)]*\)\s*//;

            # Vitamin B9 (Folic acid)
            $value =~ s/ \(([^\)]+)\)/ \/ $1/g;

            $translations{$key} = [split(/ \/ /, $value)];

            print "key: $key - value: $value\n";
        }
        elsif ($new_key =~ /^(\w\w(_\w\w)?)_synonyms$/) {
            my $lc = $1;
            $translations{$lc} = [ (@{$translations{$lc}}, @{$Nutriments{$nid}{$key}})];
        }
        else {
            $properties{$new_key} = $Nutriments{$nid}{$key};
        }
    }

    # Extra translations / synonyms from the nutrients taxonomy created by @aleene

    foreach my $lc (sort keys %{$synonyms_for{nutrients_old}}) {

        my $lc_tagid = get_string_id_for_lang($lc, $translations_to{"nutrients_old"}{"en:$nid"}{$lc});

        if (defined $synonyms_for{nutrients_old}{$lc}{$lc_tagid}) {
            defined $translations{$lc} or $translations{$lc} = [];

            my %current_synonyms = ();
            foreach my $synonym (@{$translations{$lc}}) {
                my $synonym_id = get_string_id_for_lang($lc, $synonym);
                $current_synonyms{$synonym_id} = 1;
            }

            # Add synonyms we don't have yet
            foreach my $synonym (@{$synonyms_for{nutrients_old}{$lc}{$lc_tagid}}) {
                my $synonym_id = get_string_id_for_lang($lc, $synonym);
                if (not exists($current_synonyms{$synonym_id})) {
                    push @{$translations{$lc}}, $synonym;
                    $current_synonyms{$synonym_id} = 1;
                }
            }
        }
        
    }

    # Add g as the unit if there is no unit
    defined $properties{"unit"} or $properties{"unit"} = "g";

    print $OUT 'zz:' . $nid . "\n";
    print $OUT 'en:' . join(", ", map { local $_ = $_; s/ \/ /, /; $_ } map { local $_ = $_; s/,/\\,/g; $_ } @{$translations{en}}) . "\n";
    print $OUT 'xx:' . join(", ", map { local $_ = $_; s/ \/ /, /; $_ } map { local $_ = $_; s/,/\\,/g; $_ } @{$translations{en}}) . "\n";

    foreach my $lc (sort keys %translations) {
        next if $lc eq 'en';
        next if @{$translations{$lc}} == 0;
        # Escape commas to \,
        # change " / " to a comma
        # # Docosahexaenoic acid / DHA (22:6 n-3)
        print $OUT "$lc:" . join(", ", map { local $_ = $_; s/ \/ /, /; $_ } map { local $_ = $_; s/,/\\,/g; $_ } @{$translations{$lc}}) . "\n";
    }

    foreach my $property (sort keys %properties) {
        print $OUT "$property:en: " . $properties{$property} . "\n";
    }

    print $OUT "\n";
}

close $OUT;
