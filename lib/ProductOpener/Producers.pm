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
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/:all/;

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

	# TODO

	return $columns_fields_ref;
}


# Generate an array of options for select2

sub generate_import_export_columns_groups_for_select2($$) {

	my $fields_groups_ref = shift;
	my $lcs_ref = shift; # array of language codes

	# Sample select2 groups and fields definition format from Config.pm:
	my $sample_fields_groups_ref = [
		["identification", ["code", "producer_product_id", "producer_version_id", "lc", "product_name", "generic_name",
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

	my $select2_options_ref  = [];

	foreach my $group_ref (@$fields_groups_ref) {

		my $group_id = $group_ref->[0];
		my $select2_group_ref = { text => lang("fields_group_" . $group_id), children => [] };

		if (($group_id eq "nutrition") or ($group_id eq "nutrition_other")) {

			# TODO
		}
		else {

			foreach my $field (@{$group_ref->[1]}) {
				my $name;
				if ($field =~ /_value_unit$/) {
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

				# TODO language specific fields

				push @{$select2_group_ref->{children}}, { id => $field, text => $name };
			}
		}

		push @$select2_options_ref, $select2_group_ref;
	}

	return $select2_options_ref;
}



1;

