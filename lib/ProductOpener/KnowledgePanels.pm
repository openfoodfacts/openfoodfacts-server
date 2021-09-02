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

        $product_ref->{"knowledge_panels_" . $target_lc}{"tags_brands_doyouknow_nutella"} = $test_panel_ref;

    }
}

1;
