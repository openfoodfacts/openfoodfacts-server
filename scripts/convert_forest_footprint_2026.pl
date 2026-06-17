#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;
use Text::CSV;

use FindBin;
use lib "$FindBin::Bin/../lib";

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

=head1 NAME

convert_forest_footprint_2026.pl - Convert Forest Footprint 2026 TSV files by populating _id columns

=head1 SYNOPSIS

    perl convert_forest_footprint_2026.pl

=head1 DESCRIPTION

This script reads the Forest Footprint 2026 TSV files and populates the empty _id columns
using the canonicalize_taxonomy_tag function. It processes the following files:

- ingredient.ingredient_category.equivalence.tsv
- ingredient_category.primary_ingredient.equivalence.tsv
- label.primary_ingredient.risk.tsv
- origin.primary_ingredient.footprint.tsv

=cut

sub populate_tsv_ids {
    my ($input_file, $output_file, $mappings_ref) = @_;
    
    my $csv = Text::CSV->new({
        binary => 1, 
        sep_char => "\t",
        eol => "\n",
        quote_char => undef,  # Don't quote fields in TSV
    }) or die "Cannot use CSV: " . Text::CSV->error_diag();
    
    my $errors = 0;
    my $warnings = 0;
    
    print "Processing $input_file...\n";
    
    open(my $io, "<:encoding(UTF-8)", $input_file) 
        or die "Cannot open $input_file: $!";
    
    open(my $out_io, ">:encoding(UTF-8)", $output_file)
        or die "Cannot open $output_file: $!";
    
    # Get header
    my $header_ref = $csv->getline($io);
    if (not defined $header_ref) {
        die "Could not read header from $input_file";
    }
    
    $csv->column_names(@$header_ref);
    
    # Write header to output
    $csv->print($out_io, $header_ref);
    
    while (my $row_ref = $csv->getline_hr($io)) {
        my @row = @$header_ref;
        
        # Process each field mapping
        foreach my $mapping (@$mappings_ref) {
            my ($fr_field, $id_field, $tagtype, $language) = @$mapping;
            
            if (defined $row_ref->{$fr_field} && $row_ref->{$fr_field} ne "") {
                my $fr_value = $row_ref->{$fr_field};
                
                # Check if ID field is already populated
                if (defined $row_ref->{$id_field} && $row_ref->{$id_field} ne "") {
                    print "Warning: $id_field already populated for $fr_value\n";
                    $warnings++;
                    next;
                }
                
                # Use canonicalize_taxonomy_tag to get the ID
                my $exists = 0;
                my $tagid = canonicalize_taxonomy_tag($language, $tagtype, $fr_value, \$exists);
                
                if ($exists) {
                    $row_ref->{$id_field} = $tagid;
                }
                else {
                    print "Warning: No taxonomy entry found for $fr_value ($tagtype)\n";
                    $warnings++;
                }
            }
        }
        
        # Write the processed row - need to convert hash ref to array ref
        my @row_values = map { $row_ref->{$_} // '' } @$header_ref;
        $csv->print($out_io, \@row_values);
    }
    
    close($io);
    close($out_io);
    
    print "Processed $input_file -> $output_file (warnings: $warnings)\n";
    
    return ($errors, $warnings);
}

sub main {
    my $data_dir = "$data_root/external-data/forest-footprint/2026";
    
    my @file_mappings = (
        {
            input => "$data_dir/ingredient.ingredient_category.equivalence.tsv",
            output => "$data_dir/ingredient.ingredient_category.equivalence.populated.tsv",
            mappings => [
                ["ingredient_fr", "ingredient_id", "ingredients", "fr"],
                ["ingredient_category_fr", "ingredient_category_id", "ingredients", "fr"],
            ],
        },
        {
            input => "$data_dir/ingredient_category.primary_ingredient.equivalence.tsv",
            output => "$data_dir/ingredient_category.primary_ingredient.equivalence.populated.tsv",
            mappings => [
                ["ingredient_category_fr", "ingredient_category_id", "ingredients", "fr"],
                ["primary_ingredient_fr", "primary_ingredient_id", "ingredients", "fr"],
            ],
        },
        {
            input => "$data_dir/label.primary_ingredient.risk.tsv",
            output => "$data_dir/label.primary_ingredient.risk.populated.tsv",
            mappings => [
                ["label_fr", "label_id", "labels", "fr"],
            ],
        },
        {
            input => "$data_dir/origin.primary_ingredient.footprint.tsv",
            output => "$data_dir/origin.primary_ingredient.footprint.populated.tsv",
            mappings => [
                ["origin_fr", "origin_id", "origins", "fr"],
            ],
        },
    );

    my $total_errors = 0;
    my $total_warnings = 0;
    
    foreach my $file_info (@file_mappings) {
        my ($errors, $warnings) = populate_tsv_ids(
            $file_info->{input},
            $file_info->{output},
            $file_info->{mappings},
        );
        
        $total_errors += $errors;
        $total_warnings += $warnings;

        #  If there are no errors, unlint the original files and rename the .populated files to the original files after processing
        if ($errors == 0) {
            unlink($file_info->{input}) or warn "Could not delete original file: $!";
            rename($file_info->{output}, $file_info->{input}) or warn "Could not rename file: $!";  
        }
    }
    
    print "\nConversion complete!\n";
    print "Total warnings: $total_warnings\n";
    print "Total errors: $total_errors\n";
    
    if ($total_warnings > 0) {
        print "\nNote: Warnings indicate taxonomy entries that were not found.\n";
        print "This is normal for custom ingredients or labels not yet in the main taxonomy.\n";
    }
}

main();