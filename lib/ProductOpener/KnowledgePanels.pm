# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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


=head1 NAME

ProductOpener::KnowledgePanels - Generate product knowledge panels that can be requested through the API

=head1 SYNOPSIS

Apps can request through the API knowledge panels for one product.
They are returned in the same structured format for all panels.

=head1 DESCRIPTION

See https://docs.google.com/document/d/1vJ9gatmv8pCXxyOERmYD16jOKRWJpz1RaQQ5MEcTxms/edit

=cut


package ProductOpener::KnowledgePanels;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);


BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&create_knowledge_panels

		);    # symbols to export on request
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
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;

use JSON::PP;
use Encode;

=head1 FUNCTIONS


=head2 create_knowledge_panels( $product_ref, $target_lc, $target_cc, $options_ref )

Create all knowledge panels for a product, with strings (descriptions, recommendations etc.)
in a specific language, and return them in an array of panels.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc (or "data")

Returned panels contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

If $target_lc is equal to "data", no strings are returned.

=head4 country code $target_cc

Needed for some country specific panels like the Eco-Score.

=head4 options $options_ref

Defines how some panels should be created (or not created)

- skip_[panel_id] : do not create a specific panel

=head3 Return values

Panels are returned in the "knowledge_panels_[$target_lc]" hash of the product reference
passed as input.

=cut

sub create_knowledge_panels($$$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;
	my $options_ref = shift;	

	$log->debug("create knowledge panels for product", { code => $product_ref->{code}, target_lc => $target_lc }) if $log->is_debug();

	# Initialize panels
	
    $product_ref->{"knowledge_panels_" . $target_lc} = {};

    # Test panel to test the start of the API
    # Disabled, kept as reference when we create a "Do you know" panel
    if ($product_ref->{code} eq "3017620422003--disabled") {
	
        my $test_panel_ref = {
            parent_panel_id => "root",
            type => "doyouknow",
            level => "trivia",
            topics => [
                "ingredients"
            ],
            title_element => [
                title => "Do you know why Nutella contains hazelnuts?",
                subtitle => "It all started after the second world war...",
            ],
            elements => [
                {
                    element_type => "text",
                    element => {
                        text_type => "default",
                        html => "Cocoa beans were expensive and hard to come by after the second world war, so in Piedmont (Italy) where Pietro Ferrero created Nutella, they were replaced with hazelnuts to make <em>gianduja</em>, a mix of hazelnut paste and chocolate."
                    }
                },
                {
                    element_type => "image",
                    element => {
                        url => "https://static.openfoodfacts.org/images/attributes/contains-nuts.png",
                        width => 192,
                        height => 192
                    }
                }
            ]
        };

        $product_ref->{"knowledge_panels_" . $target_lc}{"tags_brands_nutella_doyouknow"} = $test_panel_ref;
    }

    # Add knowledge panels

    # Create recommendation panels first, as they will be included in cards such has the health card and environment card
    create_recommendation_panels($product_ref, $target_lc, $target_cc);

    create_health_card_panel($product_ref, $target_lc, $target_cc);
    create_environment_card_panel($product_ref, $target_lc, $target_cc);

    # Create the root panel that contains the panels we want to show directly on the product page
    create_panel_from_json_template("root", "api/knowledge-panels/root.tt.json",
        {}, $product_ref, $target_lc, $target_cc);    
}


=head2 convert_multiline_string_to_singleline($line)

Helper function to allow to enter multiline strings in JSON templates.
The function converts the multiline string into a single line string.

=cut

sub convert_multiline_string_to_singleline($) {
    my $line = shift;
    # \R will match all Unicode newline sequence
    $line =~ s/\R/\\n/sg;
    # Escape quotes unless they have been escaped already
    # negative look behind to not convert \" to \\"
    $line =~ s/(?<!\\)"/\\"/g;
    return '"' . $line . '"';
}


=head2 create_panel_from_json_template ( $panel_id, $panel_template, $panel_data_ref, $product_ref, $target_lc, $target_cc )

Creates a knowledge panel from a JSON template.
The template is passed both the full product data + optional panel specific data.
The template is thus responsible for all the display logic (what to display and how to display it).

Some special features that are not included in the JSON format are supported:

1. Multiline strings can be included using backticks ` at the start and end of the multinine strings.
- The multiline strings will be converted to a single string.
- Quotes " are automatically escaped unless they are already escaped

2. Comments can be included by starting a line with //
- Comments will be removed in the resulting JSON, they are only intended to make the source template easier to understand.

3. Trailing commas are removed
- For each loops in templates can result in trailing commas when separating items in a list with a comma
(e.g. if want to generate a list of labels)

=head3 Arguments

=head4 panel id $panel_id

=head4 panel template $panel_template

Relative path to the the template panel file, from the "/templates" directory.
e.g. "api/knowledge-panels/environment/ecoscore/agribalyse.tt.json"

=head4 panel data reference $panel_data_ref (optional, can be an empty hash)

Used to pass data that is necessary for the panel but is not contained in the product data.

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Eco-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_panel_from_json_template ($$$$$$) {

    my $panel_id = shift;
    my $panel_template = shift;
    my $panel_data_ref = shift;
    my $product_ref = shift;
    my $target_lc = shift;
    my $target_cc = shift;

    my $panel_json;

    # We pass several structures to the template:
    # - panel: this panel data
    # - panels: the hash of all panels created so far (useful for panels that include previously created panels
    # only if they have indeed been created)
    # - product: the product data

    if (not process_template($panel_template, {
            panel => $panel_data_ref,
            panels => $product_ref->{"knowledge_panels_" . $target_lc},
            product => $product_ref,
        }, 
        \$panel_json)) {
        # The template is invalid
        $product_ref->{"knowledge_panels_" . $target_lc}{$panel_id} = {
            "template" => $panel_template, 
            "template_error" => $tt->error() . "",
        };
    }
    else {

        # Turn the JSON to valid JSON

        # Remove comment lines starting with //
        # comments are not allowed in JSON, but they can be useful to have in the templates source
        # /m modifier: ^ and $ match the start and end of each line
        $panel_json =~ s/^(\s*)\/\/(.*)$//mg;

        # Convert multilines strings between backticks `` into single line strings
        # In the template, we use multiline strings for readability
        # e.g. when we want to generate HTML

        # Also escape quotes " to \"

        $panel_json =~ s/\`([^\`]*)\`/convert_multiline_string_to_singleline($1)/seg;

        # Remove trailing commas at the end of a string delimited by quotes
        # Useful when using a foreach loop to generate a list of comma separated elements
        # The negative look-behind is used in order not to remove commas after quotes, ] and } and digits
        # (e.g. we want to keep the comma in "field1": "value1", "field2": "value2", and in "percent: 8, ")
        # Note: this will fail if the string ends with a digit.
        # As it is a trailing comma inside a string, it's not a terrible issue, the string will be valid,
        # but it will have an unneeded trailing comma.
        # The group (\W) at the end is to avoid removing commas before an opening quote (e.g. for "field": true, "other_field": ..)
        $panel_json =~ s/(?<!("|'|\]|\}|\d))\s*,\s*"(\W)/"$2/g;

        # Remove trailing commas after the last element of a array or hash, as they will make the JSON invalid
        # It makes things much simpler in templates if they can output a trailing comma though
        # e.g. in FOREACH loops.
        # So we remove them here.

        $panel_json =~ s/,(\s*)(\]|\})/$2/sg;
        $panel_json =  encode('UTF-8', $panel_json);

        eval {
            $product_ref->{"knowledge_panels_" . $target_lc}{$panel_id} = decode_json($panel_json);
            1;
        }
        or do {
            # The JSON generated by the template is invalid
            my $json_decode_error = $@;

            # Save the JSON file so that it can be more easily debugged, and that we can monitor issues
            my $target_file = "/files/debug/knowledge_panels/$panel_id." . $product_ref->{code} . ".json";
            (-e "$www_root/files") or mkdir("$www_root/files", 0755);
            (-e "$www_root/files/debug") or mkdir("$www_root/files/debug", 0755);
            (-e "$www_root/files/debug/knowledge_panels") or mkdir("$www_root/files/debug/knowledge_panels", 0755);
            open(my $out, ">:encoding(UTF-8)", $www_root . $target_file) or die "cannot open $www_root/$target_file";
            print $out $panel_json;
            close($out);

            $product_ref->{"knowledge_panels_" . $target_lc}{$panel_id} = {
                "template" => $panel_template, 
                "json_error" => $json_decode_error,
                "json" => $panel_json,
                "json_debug_url" => $static_subdomain . $target_file
            };            
        }
    }
}


=head2 create_ecoscore_panel ( $product_ref, $target_lc, $target_cc )

Creates a knowledge panel to describe the Eco-Score, including sub-panels
for the different components of the Eco-Score.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Eco-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_ecoscore_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create ecoscore panel", { code => $product_ref->{code}, ecoscore_data => $product_ref->{ecoscore_data} }) if $log->is_debug();
		
	if ((defined $product_ref->{ecoscore_data}) and ($product_ref->{ecoscore_data}{status} eq "known")) {
		
		my $score = $product_ref->{ecoscore_data}{score};
		my $grade = $product_ref->{ecoscore_data}{grade};
		
		if (defined $product_ref->{ecoscore_data}{"score_" . $cc}) {
			$score = $product_ref->{ecoscore_data}{"score_" . $cc};
			$grade = $product_ref->{ecoscore_data}{"grade_" . $cc};			
		}
		
		$log->debug("create ecoscore panel - known", { code => $product_ref->{code}, score => $score, grade => $grade }) if $log->is_debug();

        # Agribalyse part of the Eco-Score

        my $agribalyse_category_name = $product_ref->{ecoscore_data}{agribalyse}{name_en};
        if (defined $product_ref->{ecoscore_data}{agribalyse}{"name_" . $target_lc}) {
            $agribalyse_category_name = $product_ref->{ecoscore_data}{agribalyse}{"name_" . $target_lc};
        }

        # Agribalyse grade
        my $agribalyse_score = $product_ref->{ecoscore_data}{agribalyse}{score};
        my $agribalyse_grade;

        if ($agribalyse_score >= 80) {
            $agribalyse_grade = "a";
        }
        elsif ($agribalyse_score >= 60) {
            $agribalyse_grade = "b";
        }
        elsif ($agribalyse_score >= 40) {
            $agribalyse_grade = "c";
        }
        elsif ($agribalyse_score >= 20) {
            $agribalyse_grade = "d";
        }
        else {
            $agribalyse_grade = "e";
        }

        # We can reuse some strings from the Eco-Score attribute
        my $title = sprintf(lang_in_other_lc($target_lc, "attribute_ecoscore_grade_title"), uc($grade))
            . ' - ' . lang_in_other_lc($target_lc, "attribute_ecoscore_" . $grade . "_description_short");

        my $panel_data_ref = {
            "agribalyse_category_name" => $agribalyse_category_name,
            "agribalyse_score" => $agribalyse_score,
            "agribalyse_grade" => $agribalyse_grade,
            "score" => $score,
            "grade" => $grade,
            "title" => $title,
        };

        create_panel_from_json_template("ecoscore", "api/knowledge-panels/environment/ecoscore/ecoscore.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);

        # Add an Agribalyse panel to show the impact of the different steps for the category on average

        create_panel_from_json_template("ecoscore_agribalyse", "api/knowledge-panels/environment/ecoscore/agribalyse.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);

        create_panel_from_json_template("carbon_footprint", "api/knowledge-panels/environment/carbon_footprint.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);            

        # Add panels for the different bonuses and maluses

        foreach my $adjustment ("production_system", "origins_of_ingredients", "threatened_species", "packaging") {

            my $adjustment_panel_data_ref = {
            };            

            create_panel_from_json_template("ecoscore_" . $adjustment, "api/knowledge-panels/environment/ecoscore/" . $adjustment . ".tt.json",
                $adjustment_panel_data_ref, $product_ref, $target_lc, $target_cc);
        }

        # Add panel for the final Eco-Score of the product
        create_panel_from_json_template("ecoscore_total", "api/knowledge-panels/environment/ecoscore/total.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);
	}
	else {
        my $panel_data_ref = {};
        create_panel_from_json_template("ecoscore", "api/knowledge-panels/environment/ecoscore/ecoscore_unknown.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);
	}

    # Add panels for environmental Eco-Score labels
    if ((defined $product_ref->{ecoscore_data}) and (defined $product_ref->{ecoscore_data}{adjustments})
        and (defined $product_ref->{ecoscore_data}{adjustments}{production_system})
        and (defined $product_ref->{ecoscore_data}{adjustments}{production_system}{labels})) {

        foreach my $labelid (@{$product_ref->{ecoscore_data}{adjustments}{production_system}{labels}}) {
            my $label_panel_data_ref = {
                label => $labelid,
                evaluation => "good",
            };

            # Add label icon
            my $icon_url = get_tag_image($target_lc, "labels", $labelid);
            if (defined $icon_url) {
                $label_panel_data_ref->{icon_url} = $static_subdomain . $icon_url;
            }

            # Add properties of interest
            foreach my $property (qw(environmental_benefits description)) {
                my $property_value = get_inherited_property("labels", $labelid, $property . ":" . $target_lc);
                if (defined $property_value) {
                    $label_panel_data_ref->{$property} = $property_value;
                }
            }

            create_panel_from_json_template("environment_label_" . $labelid, "api/knowledge-panels/environment/label.tt.json",
                $label_panel_data_ref, $product_ref, $target_lc, $target_cc);
        }
    }    
}


=head2 create_environment_card_panel ( $product_ref, $target_lc, $target_cc )

Creates a knowledge panel card that contains all knowledge panels related to the environment.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Eco-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_environment_card_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create environment card panel", { code => $product_ref->{code} }) if $log->is_debug();

    my $panel_data_ref = {};

    # Create Eco-Score related panels
    create_ecoscore_panel($product_ref, $target_lc, $target_cc);

    # Create panel for palm oil
    if ((defined $product_ref->{ecoscore_data}) and (defined $product_ref->{ecoscore_data}{adjustments})
        and (defined $product_ref->{ecoscore_data}{adjustments}{threatened_species})
        and ($product_ref->{ecoscore_data}{adjustments}{threatened_species}{value} != 0)) {

        create_panel_from_json_template("palm_oil", "api/knowledge-panels/environment/palm_oil.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);
    }

    # Create panel for packaging recycling
    create_panel_from_json_template("packaging_recycling", "api/knowledge-panels/environment/packaging_recycling.tt.json",
        $panel_data_ref, $product_ref, $target_lc, $target_cc);

    # Create panel for manufacturing place
    create_manufacturing_place_panel($product_ref, $target_lc, $target_cc);

    # Origins of ingredients for the environment card
    create_panel_from_json_template("origins_of_ingredients", "api/knowledge-panels/environment/origins_of_ingredients.tt.json",
        $panel_data_ref, $product_ref, $target_lc, $target_cc);

    # Create the environment_card panel
    create_panel_from_json_template("environment_card", "api/knowledge-panels/environment/environment_card.tt.json",
        $panel_data_ref, $product_ref, $target_lc, $target_cc);    
}


=head2 create_manufacturing_place_panel ( $product_ref, $target_lc, $target_cc )

Creates a knowledge panel when we know the location of the manufacturing place,
usually through a packaging code.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Eco-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_manufacturing_place_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create_manufacturing_place_panel", { code => $product_ref->{code} }) if $log->is_debug();

    # Go through the product packaging codes, keep the first one with associated geo coordinates
    if (defined $product_ref->{emb_codes_tags}) {
        foreach my $packager_code_tagid (@{$product_ref->{emb_codes_tags}}) {
            # we will create a panel for the first known location
            if (exists $packager_codes{$packager_code_tagid}) {
                $log->debug("packager code found for the canon_tagid", { cc => $packager_codes{$packager_code_tagid}{cc} }) if $log->is_debug();
                my ($lat, $lng) = get_packager_code_coordinates($packager_code_tagid);
                if ((defined $lat) and (defined $lng)) {

                    my $panel_data_ref = {
                        packager_code_data => $packager_codes{$packager_code_tagid},
                        lat => $lat + 0.0,
                        lng => $lng + 0.0,
                    };

                    create_panel_from_json_template("manufacturing_place", "api/knowledge-panels/environment/manufacturing_place.tt.json",
                        $panel_data_ref, $product_ref, $target_lc, $target_cc);
                }
            }
        }
    }
}


=head2 create_health_card_panel ( $product_ref, $target_lc, $target_cc )

Creates a knowledge panel card that contains all knowledge panels related to health.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

We may display country specific recommendations from health authorities, or country specific scores.

=cut

sub create_health_card_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create health card panel", { code => $product_ref->{code} }) if $log->is_debug();

    my $panel_data_ref = {};

    # Create Nutri-Score panel
    create_nutriscore_panel($product_ref, $target_lc, $target_cc);

    # Create the nutrition facts table panel
    create_nutrition_facts_table_panel($product_ref, $target_lc, $target_cc);

    # Create the physical activities panel
    create_physical_activities_panel($product_ref, $target_lc, $target_cc);

    # Create the ingredients panel
    create_ingredients_panel($product_ref, $target_lc, $target_cc);

    # Create the additives panel
    create_additives_panel($product_ref, $target_lc, $target_cc);

    # Create the health_card panel
    create_panel_from_json_template("health_card", "api/knowledge-panels/health/health_card.tt.json",
        $panel_data_ref, $product_ref, $target_lc, $target_cc);    
}


=head2 create_nutriscore_panel ( $product_ref, $target_lc, $target_cc )

Creates knowledge panels to describe the Nutri-Score.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_nutriscore_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create nutriscore panel", { code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data} }) if $log->is_debug();
	
    my $panel_data_ref = data_to_display_nutriscore_and_nutrient_levels($product_ref);

    if ((not $panel_data_ref->{do_not_display})
        and (not $panel_data_ref->{nutriscore_grade} eq "not-applicable")) {

        $panel_data_ref->{title} = lang_in_other_lc($target_lc, "attribute_nutriscore_" . $panel_data_ref->{nutriscore_grade} . "_description_short");

        # Nutri-Score panel: score + details
        create_panel_from_json_template("nutriscore", "api/knowledge-panels/health/nutriscore/nutriscore.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);

    }
}


=head2 create_nutrition_facts_table_panel ( $product_ref, $target_lc, $target_cc )

Creates a knowledge panel with the nutrition facts table.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_nutrition_facts_table_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create nutrition facts panel", { code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data} }) if $log->is_debug();

    # Generate a panel only for food products that have a nutrition table
    if ((not ((defined $options{no_nutrition_table}) and ($options{no_nutrition_table})))
        and (not ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on'))) ) {
	
        # Compare the product nutrition facts to the most specific category
        my $comparisons_ref = compare_product_nutrition_facts_to_categories($product_ref, $target_cc, 1);
        my $panel_data_ref = data_to_display_nutrition_table($product_ref, $comparisons_ref);

        create_panel_from_json_template("nutrition_facts_table", "api/knowledge-panels/health/nutrition/nutrition_facts_table.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);
    }
}


=head2 create_physical_activities_panel ( $product_ref, $target_lc, $target_cc )

Creates a knowledge panel to indicate how much time is needed to burn the calories of a product
for various activities.

Description: https://en.wikipedia.org/wiki/Metabolic_equivalent_of_task

1 MET = (kJ / 4.2) / (kg * hour)

Data: https://sites.google.com/site/compendiumofphysicalactivities/


=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=head3 Data

=head4 Activity energy equivalent of task

Data: https://sites.google.com/site/compendiumofphysicalactivities/

=cut

my %activities_met = (
    'walking' => 3.5,   # walking, 2.8 to 3.2 mph, level, moderate pace, firm surface
    'swimming' => 5.8,  # swimming laps, freestyle, front crawl, slow, light or moderate effort
    'bicycling' => 7.5, # bicycling, general
    'running' => 10,    # running, 6 mph (10 min/mile)
);

my @sorted_activities = sort ({ $activities_met{$a} <=> $activities_met{$b} } keys %activities_met);

sub create_physical_activities_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create physical_activities panel", { code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data} }) if $log->is_debug();

    # Generate a panel only for food products that have an energy per 100g value
    if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{energy_100g}) and ($product_ref->{nutriments}{energy_100g} > 0)) {

        my $energy = $product_ref->{nutriments}{energy_100g};

        # Compute energy density: low, moderate, high
        # We might want to move it to the nutrients level at some point

        my $energy_density = "low";
        my $evaluation = "good";

        # Values correspond to the 3 points and 6 point thresholds of the Nutri-Score for energy
        if (has_tag($product_ref, "categories", "en:beverages")) {
            if ($energy > 180) {
                $energy_density = "high";
                $evaluation = "bad";
            }
            elsif ($energy > 90) {
                $energy_density = "moderate";
                $evaluation = "average";
            }
        }
        else {
            if ($energy > 2010) {
                $energy_density = "high";
                $evaluation = "bad";
            }
            elsif ($energy > 1005) {
                $energy_density = "moderate";
                $evaluation = "average";
            }
        }

        my $weight = 70;
	
        my $panel_data_ref = {
            energy => $energy,
            energy_density => $energy_density,
            evaluation => $evaluation,
            weight => $weight,
            activities => [],
        };

        foreach my $activity (@sorted_activities) {
            my $minutes = 60 * ($energy / 4.2) / ($activities_met{$activity} * $weight);
            my $activity_ref = {
                id => $activity,
                activity => $activity,
                name => lang("activity_" . $activity),
                minutes => $minutes,
            };
            if ($activity eq "walking") {
                $activity_ref->{steps} = $minutes * 100;
                $panel_data_ref->{walking_steps} = $activity_ref->{steps};
                $panel_data_ref->{walking_minutes} = $activity_ref->{minutes};
            }
            push @{$panel_data_ref->{activities}}, $activity_ref;
        }

        create_panel_from_json_template("physical_activities", "api/knowledge-panels/health/nutrition/physical_activities.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);
    }
}


=head2 create_ingredients_panel ( $product_ref, $target_lc, $target_cc )

Creates a knowledge panel with the list of ingredients.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_ingredients_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create ingredients panel", { code => $product_ref->{code} }) if $log->is_debug();

	# try to display ingredients in the requested language if available

	my $ingredients_text = $product_ref->{ingredients_text};
    my $ingredients_text_with_allergens = $product_ref->{ingredients_text_with_allergens};
	my $ingredients_text_lc = $product_ref->{lc};

	if ((defined $product_ref->{"ingredients_text" . "_" . $target_lc}) and ($product_ref->{"ingredients_text" . "_" . $target_lc} ne '')) {
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $target_lc};
		$ingredients_text_with_allergens = $product_ref->{"ingredients_text_with_allergens" . "_" . $target_lc};
		$ingredients_text_lc = $target_lc;
	}

    my $panel_data_ref = {
        ingredients_text => $ingredients_text,
        ingredients_text_with_allergens => $ingredients_text_with_allergens,
        ingredients_text_lc => $ingredients_text_lc,
        ingredients_text_language => display_taxonomy_tag($target_lc,'languages',$language_codes{$ingredients_text_lc}),
    };

    create_panel_from_json_template("ingredients", "api/knowledge-panels/health/ingredients/ingredients.tt.json",
        $panel_data_ref, $product_ref, $target_lc, $target_cc);
}


=head2 create_additives_panel ( $product_ref, $target_lc, $target_cc )

Creates knowledge panels for additives.

=head3 Arguments

=head4 product reference $product_ref

=head4 language code $target_lc

=head4 country code $target_cc

=cut

sub create_additives_panel($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create additives panel", { code => $product_ref->{code} }) if $log->is_debug();

    # Create a panel only if the product has additives

    if ((defined $product_ref->{additives_tags}) and (scalar @{$product_ref->{additives_tags}} > 0 )) {

        my $additives_panel_data_ref = {
        };

        foreach my $additive (@{$product_ref->{additives_tags}}) {

            my $additive_panel_id = "additive_" . $additive;

            my $additive_panel_data_ref = {
                additive => $additive,
            };

            # Wikipedia abstracts, in target language or English

            my $target_lcs_ref = [$target_lc];
            if ($target_lc ne "en") {
                push @$target_lcs_ref, "en";
            }

            add_taxonomy_properties_in_target_languages_to_object($additive_panel_data_ref, "additives", $additive,
                ["wikipedia_url", "wikipedia_title", "wikipedia_abstract"], $target_lcs_ref);

            create_panel_from_json_template("additive_" . $additive, "api/knowledge-panels/health/ingredients/additive.tt.json",
                $additive_panel_data_ref, $product_ref, $target_lc, $target_cc);
        }

        create_panel_from_json_template("additives", "api/knowledge-panels/health/ingredients/additives.tt.json",
            $additives_panel_data_ref, $product_ref, $target_lc, $target_cc);

    }
}


=head2 add_taxonomy_properties_in_target_languages_to_object ( $object_ref, $tagtype, $tagid, $properties_ref, $target_lcs_ref )

This function adds to the hash ref $object_ref (for instance a data structure passed to a template) the values
of selected properties, if they exist in one of the target languages.

For instance for the panel for an additive, we can include a Wikipedia abstract in the requested language if available,
or in English if not.

=head3 Arguments

=head4 object reference $object_ref

=head4 taxonomy $tagtype

=head4 tag id $tagoid

=head4 list of properties $properties_ref

Properties to add to the resulting object.

=head4 language codes $target_lcs

Reference to an array of preferred languages, with the preferred language first.

=cut

sub add_taxonomy_properties_in_target_languages_to_object ($$$$$) {

    my $object_ref = shift;
    my $tagtype = shift;
    my $tagid = shift;

    my $properties_ref = shift;
    my $target_lcs_ref = shift;

    foreach my $property (@$properties_ref) {
        my $property_value;
        my $property_lc;
        # get property value for first language for which it is defined
        foreach my $target_lc (@$target_lcs_ref) {
            $property_value = get_property($tagtype, $tagid, $property . ":" . $target_lc);
            if (defined $property_value) {
                $property_lc = $target_lc;
                last;
            }
        }
        if (defined $property_value) {
            $object_ref->{$property} = $property_value;
            $object_ref->{$property . "_lc"} = $property_lc;
            $object_ref->{$property . "_language"} = display_taxonomy_tag($target_lcs_ref->[0], "languages", $language_codes{$property_lc});
        }
    }
}


=head2 create_recommendation_panels ( $product_ref, $target_lc, $target_cc )

Creates knowledge panels with recommendations (e.g. related to health or the environment).
Recommendations can depend on product properties (e.g. categories or ingredients)
and user properties (e.g. country and language to get country specific recommendations,
but possibly also user preferences regarding trusted sources of information).

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_recommendation_panels($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("create health recommendation panels", { code => $product_ref->{code}, }) if $log->is_debug();

    # The code below defines the conditions to show recommendations (which recommendation for which product and which user)
    # Those conditions could be implemented at some point in a configuration file, once we have a better idea of usage and the types of conditions.

    # Note: in order to simplify the display logic, we can use the same panel id (e.g. "recommendation_health") for different panels.
    # If there are multiple panels matching with the same id, only the last one will be kept.
    # This can be used for instance if we want to have a default worldwide recommendation, and the more precise or relevant recommendations
    # at the country level.

    # Health

    # Alcohol
    if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {

        create_panel_from_json_template("recommendation_health", "api/knowledge-panels/recommendations/health/world/who_alcohol.tt.json",
            {}, $product_ref, $target_lc, $target_cc);
    }

    # France - Santé publique France

    if (($target_cc eq 'fr') and ($target_lc eq 'fr')) {

        # Alcohol

        if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {

            create_panel_from_json_template("recommendation_health", "api/knowledge-panels/recommendations/health/fr/spf_alcohol.tt.json",
                {}, $product_ref, $target_lc, $target_cc);
        }

        # Pulses (légumes secs)

         if (has_tag($product_ref, "categories", "en:pulses")) {

            create_panel_from_json_template("recommendation_health", "api/knowledge-panels/recommendations/health/fr/spf_pulses.tt.json",
                {}, $product_ref, $target_lc, $target_cc);
        }       

    }
}

1;
