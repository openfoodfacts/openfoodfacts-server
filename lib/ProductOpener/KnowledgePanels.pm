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
		&create_ecoscore_panels

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

    if ($product_ref->{code} eq "3017620422003") {
	
        my $test_panel_ref = {
            parent_panel_id => "root",
            type => "doyouknow",
            level => "trivia",
            topics => [
                "ingredients"
            ],
            title => "Do you know why Nutella contains hazelnuts?",
            subtitle => "It all started after the second world war...",
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

    create_ecoscore_panel($product_ref, $target_lc, $target_cc);
}


=head2 create_panel_from_json_template ( $panel_id, $panel_template, $panel_data_ref, $product_ref, $target_lc, $target_cc )

Creates a knowledge panel from a JSON template.
The template is passed both the full product data + optional panel specific data.
The template is thus responsible for all the display logic (what to display and how to display it).

=head3 Arguments

=head4 panel id $panel_id

=head4 panel template $panel_template

Relative path to the the template panel file, from the "/templates" directory.
e.g. "api/knowledge-panels/ecoscore/agribalyse.tt.json"

=head4 panel data reference $panel_data_ref (optional, can be an empty hash)

Used to pass data that is necessary for the panel but is not contained in the product data.

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Eco-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=head3 Return value

The return value is a reference to the resulting knowledge panel data structure.

=cut

sub create_panel_from_json_template ($$$$$$) {

    my $panel_id = shift;
    my $panel_template = shift;
    my $panel_data_ref = shift;
    my $product_ref = shift;
    my $target_lc = shift;
    my $target_cc = shift;

    my $panel_json;

    if (not process_template($panel_template, { panel => $panel_data_ref, product => $product_ref }, \$panel_json)) {
        # The template is invalid
        $product_ref->{"knowledge_panels_" . $target_lc}{$panel_id} = {
            "template" => $panel_template, 
            "template_error" => $tt->error() . "",
        };
    }
    else {

        # Turn the JSON to valid JSON

        # Convert multilines strings between backticks `` into single line strings
        # In the template, we use multiline strings for readability
        # e.g. when we want to generate HTML

        sub convert_multiline_string_to_singleline($) {
            my $line = shift;
            $line =~ s/\n/\\n/sg;
            return '"' . $line . '"';
        }

        $panel_json =~ s/\`([^\`]*)\`/convert_multiline_string_to_singleline($1)/seg;

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
            $product_ref->{"knowledge_panels_" . $target_lc}{$panel_id} = {
                "template" => $panel_template, 
                "json_error" => $json_decode_error,
                "json" => $panel_json,
                "json_debug_url" => "$static_subdomain/files/debug/knowledge_panels/$panel_id.json"
            };

            # Save the JSON file so that it can be more easily debugged
            (-e "$www_root/files") or mkdir("$www_root/files", 0755);
            (-e "$www_root/files/debug") or mkdir("$www_root/files/debug", 0755);
            (-e "$www_root/files/debug/knowledge_panels") or mkdir("$www_root/files/debug/knowledge_panels", 0755);
            my $target_file = "$www_root/files/debug/knowledge_panels/$panel_id.json";
            open(my $out, ">:encoding(UTF-8)", $target_file) or die "cannot open $target_file";
            print $out $panel_json;
            close($out);
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

=head3 Return value

The return value is a reference to the resulting knowledge panel data structure.

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

        create_panel_from_json_template("ecoscore", "api/knowledge-panels/ecoscore/ecoscore.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);

        # Add an Agribalyse panel to show the impact of the different steps for the category on average

        create_panel_from_json_template("ecoscore_agribalyse", "api/knowledge-panels/ecoscore/agribalyse.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);

        # TODO: add panels for the different bonuses and maluses

        foreach my $adjustment ("production_system", "origins_of_ingredients", "threatened_species", "packaging") {

            if (not defined $product_ref->{ecoscore_data}{adjustments}{$adjustment}{value}) {
                $grade = "unknown";
            }
            elsif ($product_ref->{ecoscore_data}{adjustments}{$adjustment}{value} < 0) {
                $grade = "minus";
            }
            else {
                $grade = "plus";
            }

            $title = lang("ecoscore_" . $adjustment);

            $panel_data_ref = {
                "grade" => $grade,
                "title" => $title,
            };            

            create_panel_from_json_template("ecoscore_" . $adjustment, "api/knowledge-panels/ecoscore/" . $adjustment . ".tt.json",
                $panel_data_ref, $product_ref, $target_lc, $target_cc);
        }

	}
	else {
        my $panel_data_ref = {};
        create_panel_from_json_template("ecoscore", "api/knowledge-panels/ecoscore/ecoscore_unknown.tt.json",
            $panel_data_ref, $product_ref, $target_lc, $target_cc);
	}
}

1;
