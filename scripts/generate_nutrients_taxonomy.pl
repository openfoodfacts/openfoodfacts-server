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

    my %translations = ();
    my %properties = ();

    foreach my $key (sort keys %{$Nutriments{$nid}}) {

        if ($key =~ /^\w\w(_\w\w)?$/) {
            $translations{$key} = [$Nutriments{$nid}{$key}];
        }
        elsif ($key =~ /^(\w\w(_\w\w)?)_synonyms$/) {
            my $lc = $1;
            $translations{$lc} = [ (@{$translations{$lc}}, @{$Nutriments{$nid}{$key}})];
        }
        else {
            $properties{$key} = $Nutriments{$nid}{$key};
        }

        # Extra translations / synonyms from the nutrients taxonomy created by @aleene

        foreach my $lc (sort keys %{$synonyms_for{nutrients}}) {

            my $lc_tagid = get_string_id_for_lang($lc, $translations_to{"nutrients"}{"en:$nid"}{$lc});
            print STDERR "nid: $nid - lc_tagid: $lc_tagid\n";

            if (defined $synonyms_for{nutrients}{$lc}{$lc_tagid}) {
                defined $translations{$lc} or $translations{$lc} = [];

                my %current_synonyms = ();
                foreach my $synonym (@{$translations{$lc}}) {
                    my $synonym_id = get_string_id_for_lang($lc, $synonym);
                    $current_synonyms{$synonym_id} = 1;
                }

                # Add synonyms we don't have yet
                foreach my $synonym (@{$synonyms_for{nutrients}{$lc}{$lc_tagid}}) {
                    print STDERR "synonym: $synonym\n";
                    my $synonym_id = get_string_id_for_lang($lc, $synonym);
                    if (not exists($current_synonyms{$synonym_id})) {
                        push @{$translations{$lc}}, $synonym
                    }
                }
            }
        }
        
    }

    print $OUT 'en:' . join(", ", map { local $_ = $_; s/,/\\,/; $_ } @{$translations{en}}) . "\n";

    foreach my $lc (sort keys %translations) {
        next if $lc eq 'en';
        next if @{$translations{$lc}} == 0;
        # Escape commas to \,
        print $OUT "$lc:" . join(", ", map { local $_ = $_; s/,/\\,/; $_ } @{$translations{$lc}}) . "\n";
    }

    foreach my $property (sort keys %properties) {
        print $OUT "$property:en: " . $properties{$property} . "\n";
    }

    print $OUT "\n";
}

close $OUT;
