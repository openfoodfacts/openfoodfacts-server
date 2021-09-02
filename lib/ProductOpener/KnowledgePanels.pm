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

		&compute_knowledge_panels
		&compute_ecoscore_panels

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


=head1 FUNCTIONS


=head2 compute_knowledge_panels( $product_ref, $target_lc, $target_cc, $options_ref )

Compute all knowledge panels for a product, with strings (descriptions, recommendations etc.)
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

Defines how some panels should be computed (or not computed)

- skip_[attribute_id] : do not compute a specific attribute

=head3 Return values

Panels are returned in the "knowledge_panels_[$target_lc]" hash of the product reference
passed as input.

=cut

sub compute_knowledge_panels($$$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;
	my $options_ref = shift;	

	$log->debug("compute knowledge panels for product", { code => $product_ref->{code}, target_lc => $target_lc }) if $log->is_debug();

	# Initialize panels
	
    my $panels_ref = {};

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

        $panels_ref->{"tags_brands_doyouknow_nutella"} = $test_panel_ref;
    }

    # Add knowledge panels

    $panels_ref->{"ecoscore"} = compute_attribute_ecoscore($product_ref, $target_lc, $target_cc);

    $product_ref->{"knowledge_panels_" . $target_lc} = $panels_ref;
}


=head2 compute_ecoscore_panel ( $product_ref, $target_lc, $target_cc )

Computes a knowledge panel to describe the Eco-Score, including sub-panels
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

sub compute_attribute_ecoscore($$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $target_cc = shift;

	$log->debug("compute ecoscore panel", { code => $product_ref->{code}, ecoscore_data => $product_ref->{ecoscore_data} }) if $log->is_debug();

	my $panel_ref = {
        parent_panel_id => "root",
        type => "score",
        level => "info",
        topics => [
            "environment"
        ],
        elements => []
    };
		
	if ((defined $product_ref->{ecoscore_data}) and ($product_ref->{ecoscore_data}{status} eq "known")) {
		
		my $score = $product_ref->{ecoscore_data}{score};
		my $grade = $product_ref->{ecoscore_data}{grade};
		
		if (defined $product_ref->{ecoscore_data}{"score_" . $cc}) {
			$score = $product_ref->{ecoscore_data}{"score_" . $cc};
			$grade = $product_ref->{ecoscore_data}{"grade_" . $cc};			
		}
		
		$log->debug("compute ecoscore panel - known", { code => $product_ref->{code}, score => $score, grade => $grade }) if $log->is_debug();
		
        $panel_ref->{grade} = $grade;
        
        # We can reuse some strings from the Eco-Score attribute
        $panel_ref->{title} = sprintf(lang_in_other_lc($target_lc, "attribute_ecoscore_grade_title"), uc($grade))
            . ' - ' . lang_in_other_lc($target_lc, "attribute_ecoscore_" . $grade . "_description_short");
		$panel_ref->{icon_url} = "$static_subdomain/images/attributes/ecoscore-$grade.svg";

        # Agribalyse part of the Eco-Score

        my $agribalyse_category_name = $product_ref->{ecoscore_data}{agribalyse}{name_en};
        if (defined $product_ref->{ecoscore_data}{agribalyse}{"name_" . $target_lc}) {
            $agribalyse_category_name = $product_ref->{ecoscore_data}{agribalyse}{"name_" . $target_lc};
        }

        # Agribalyse grade
        my $agribalyse_grade;		
        if ($product_ref->{ecoscore_data}{agribalyse}{score} >= 80) {
            $agribalyse_grade = "a";
        }
        elsif ($product_ref->{ecoscore_data}{agribalyse}{score} >= 60) {
            $agribalyse_grade = "b";
        }
        elsif ($product_ref->{ecoscore_data}{agribalyse}{score} >= 40) {
            $agribalyse_grade = "c";
        }
        elsif ($product_ref->{ecoscore_data}{agribalyse}{score} >= 20) {
            $agribalyse_grade = "d";
        }
        else {
            $agribalyse_grade = "e";
        }        

        push @{$panel_ref->{elements}}, {
            element_type => "text",
            element => {
                text_type => "h1",
                html => "Average impact of products of the " . $agribalyse_category_name . " category: "
                    . uc($agribalyse_grade) . " (" . $product_ref->{ecoscore_data}{agribalyse}{score} . "/100)"
            }
        };

        # TODO: add Agribalyse panel to show impact of the different steps

        push @{$panel_ref->{elements}}, {
            element_type => "text",
            element => {
                text_type => "h1",
                html => "Impact of " . product_name_brand($product_ref) . separator_before_colon($target_lc) . ": "
                    . uc($grade) . " (" . $score . "/100)"
            }
        };

        # TODO: add panels for the different bonuses and maluses

	}
	else {
		$panel_ref->{grade} = "unknown";
		$panel_ref->{icon_url} = "$static_subdomain/images/attributes/ecoscore-unknown.svg";
		$panel_ref->{title} = lang_in_other_lc($target_lc, "attribute_ecoscore_unknown_title")
		    . ' - ' . lang_in_other_lc($target_lc, "attribute_ecoscore_unknown_description_short");		
	}
	
	return $panel_ref;
}

1;
