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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::Producers;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);


BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(

		&init_columns_fields_match
		&generate_import_export_columns_groups_for_select2

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;


# Analyze the headers column names and rows content to pre-assign fields to columns

sub init_columns_fields_match($$) {

	my $headers_ref = shift;
	my $rows_ref = shift;

	my $columns_fields_ref = {};

	# Go through all rows to extract examples, compute stats etc.

	my $row = 0;

	foreach my $row_ref (@$rows_ref) {

		my $col = 0;

		foreach my $value (@$row_ref) {

			my $column = $headers_ref->[$col];

			defined $columns_fields_ref->{$column} or $columns_fields_ref->{$column} = { examples => [], existing_examples => {}, n => 0, numbers => 0, letters => 0, both => 0 };

			# empty value?

			if ($value =~ /^\s*$/) {

			}
			else {
				# defined value
				$columns_fields_ref->{$column}{n}++;

				# examples
				if (@{$columns_fields_ref->{$column}{examples}} < 3) {
					if (not defined $columns_fields_ref->{$column}{existing_examples}{$value}) {
						$columns_fields_ref->{$column}{existing_examples}{$value} = 1;
						push @{$columns_fields_ref->{$column}{examples}}, $value;
					}
				}

				# content
				if ($value =~ /[0-9]/) {
					$columns_fields_ref->{$column}{numbers}++;
				}
				if ($value =~ /[a-z]/i) {
					$columns_fields_ref->{$column}{letters}++;
				}
				if ($value =~ /[0-9].*[a-z]/i) {
					$columns_fields_ref->{$column}{both}++;
				}
			}

			$col++;
		}

		$row++;
	}

	# Match known column names to OFF fields

	foreach my $column (@$headers_ref) {

		my ($field, $value_or_unit, $tag);

		my $column_id = get_string_id_for_lang("no_language", $column);

		if ($column_id =~ /^(code|barcode|ean|ean13|ean-13)$/) {
			$field = "code";
		}

		# If we don't know if the column contains value + unit, value, or unit,
		# try to guess from the content of the column
		if (not defined $value_or_unit) {
			if ($columns_fields_ref->{$column}{both}) {
				$value_or_unit = "value_unit";
			}
			elsif ($columns_fields_ref->{$column}{numbers}) {
				$value_or_unit = "value";
			}
			elsif ($columns_fields_ref->{$column}{letters}) {
				$value_or_unit = "unit";
			}
		}

		$columns_fields_ref->{$column}{field} = $field;
		$columns_fields_ref->{$column}{value_unit} = $value_or_unit;
		$columns_fields_ref->{$column}{tag} = $tag;
	}

	return $columns_fields_ref;
}


# Generate an array of options for select2

sub generate_import_export_columns_groups_for_select2($$) {

	my $fields_groups_ref = shift;
	my $lcs_ref = shift; # array of language codes

	# Sample select2 groups and fields definition format from Config.pm:
	my $sample_fields_groups_ref = [
		["identification", ["code", "producer_product_id", "producer_version_id", "lang", "product_name", "generic_name",
			"quantity_value_unit", "net_weight_value_unit", "drained_weight_value_unit", "volume_value_unit", "packaging",
			"brands", "categories", "categories_specific", "labels", "labels_specific", "countries", "stores"]
		],
		["origins", ["origins", "origin", "manufacturing_places", "producer", "emb_codes"]
		],
		["ingredients", ["ingredients_text", "allergens", "traces"]
		],
		["nutrition"],
		["nutrition_other"],
		["other", ["conservation_conditions", "warning", "preparation", "recipe_idea", "recycling_instructions_to_recycle", "recycling_instructions_to_discard", "customer_service", "link"]
		],
	];

	# Create an options array for select2

	my $select2_options_sample = <<JSON
{
  "results": [
    {
      "text": "Group 1",
      "children" : [
        {
            "id": 1,
            "text": "Option 1.1"
        },
        {
            "id": 2,
            "text": "Option 1.2"
        }
      ]
    },
    {
      "text": "Group 2",
      "children" : [
        {
            "id": 3,
            "text": "Option 2.1"
        },
        {
            "id": 4,
            "text": "Option 2.2"
        }
      ]
    }
  ],
}
JSON
;

	# Populate the select2 options array from the groups and fields definition

	my $select2_options_ref  = [ ];

	foreach my $group_ref (@$fields_groups_ref) {

		my $group_id = $group_ref->[0];
		my $select2_group_ref = { text => lang("fields_group_" . $group_id), children => [ ] };

		if (($group_id eq "nutrition") or ($group_id eq "nutrition_other")) {

			# Go through the nutriment table
			foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}) {

				next if $nutriment =~ /^\#/;
				my $nid = $nutriment;

				# %Food::nutriments_tables ids have an ending - for nutrients that are not displayed by default

				if ($group_id eq "nutrition") {
					if ($nid =~ /-$/) {
						next;
					}
				}
				else {
					if ($nid !~ /-$/) {
						next;
					}
				}

				$nid =~ s/^(-|!)+//g;
				$nid =~ s/-$//g;

				my $field = $nid;

				my $name;
				if (exists $Nutriments{$nid}{$lc}) {
					$name = $Nutriments{$nid}{$lc};
				}
				else {
					$name = $Nutriments{$nid}{en};
				}

				push @{$select2_group_ref->{children}}, { id => $nid . "_100g_value_unit", text => ucfirst($name) };
			}
		}
		else {

			foreach my $field (@{$group_ref->[1]}) {
				my $name;
				if ($field eq "code") {
					$name = lang("barcode");
				}
				elsif ($field =~ /_value_unit$/) {
					# Column can contain value + unit, value, or unit for a specific field
					my $field_name = $`;
					$name = lang($field_name);
				}
				elsif ($field =~ /_specific$/) {
					# Column is for a specific tag with a Yes/No value (e.g. a single column for the "Organic" label)
					# e.g. labels_specific -> Label (specific)
					my $tagtype = $`;
					$name = lang($tagtype . "_s") . " (" . lang("specific") . ")";
				}
				elsif (defined $tags_fields{$field}) {
					my $tagtype = $field;
					$name = lang($tagtype . "_p");
				}
				else {
					$name = lang($field);
				}

				$log->debug("Select2 option", { group_id => $group_id, field=>$field, name=>$name }) if $log->is_debug();

				if (defined $language_fields{$field}) {

					foreach my $l (@$lcs_ref) {
						my $language = "";	# Don't specify the language if there is just one
						if (@$lcs_ref > 1) {
							$language = " (" . display_taxonomy_tag($lc,'languages',$language_codes{$l}) . ")";
						}
						$log->debug("Select2 option - language field", { group_id => $group_id, field=>$field, name=>$name, lc=>$lc, l=>$l, language=>$language }) if $log->is_debug();
						push @{$select2_group_ref->{children}}, { id => $field . "_$l", text => ucfirst($name) . $language };
					}
				}
				else {
					push @{$select2_group_ref->{children}}, { id => $field, text => ucfirst($name) };
				}
			}
		}

		push @$select2_options_ref, $select2_group_ref;
	}

	return $select2_options_ref;
}



1;

