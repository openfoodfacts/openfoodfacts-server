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
# Product Opener is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Product Opener. If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Config qw/%options/;
use ProductOpener::Display qw/process_template/;

# The nutrition section of the product edit form is displayed only for product types
# for which the nutrition feature is enabled (e.g. food products), or for products that
# already have nutrition data, so that contributors can delete it.

sub render_product_edit_form ($product_type, $product_has_nutrition_data = 0) {
	local $options{product_type} = $product_type;

	my $html = '';
	my $template_data_ref = {
		errors_index => -1,
		input_sets => {},
		pers => [],
		product_has_nutrition_data => $product_has_nutrition_data,
	};
	my $request_ref = {lc => 'en'};

	ok(
		process_template(
			'web/pages/product_edit/product_edit_form_display.tt.html',
			$template_data_ref, \$html, $request_ref
		),
		"render the product edit form for $product_type products"
	);

	return $html;
}

my $food_form = render_product_edit_form('food');
like($food_form, qr{href="#nutrition"}, 'food edit form includes the nutrition navigation link');
like($food_form, qr{<section class="card fieldset" id="nutrition">}, 'food edit form includes the nutrition section');

my $beauty_form = render_product_edit_form('beauty');
unlike($beauty_form, qr{href="#nutrition"}, 'beauty edit form excludes the nutrition navigation link');
unlike($beauty_form, qr{id="nutrition"}, 'beauty edit form excludes the nutrition section');

my $beauty_form_with_nutrition_data = render_product_edit_form('beauty', 1);
like($beauty_form_with_nutrition_data,
	qr{href="#nutrition"},
	'beauty edit form includes the nutrition navigation link when the product has nutrition data');
like(
	$beauty_form_with_nutrition_data,
	qr{<section class="card fieldset" id="nutrition">},
	'beauty edit form includes the nutrition section when the product has nutrition data'
);
# The "no nutrition data" checkbox is the only way to delete the data of those products
like($beauty_form_with_nutrition_data,
	qr{name="no_nutrition_data"},
	'beauty edit form includes the no nutrition data checkbox when the product has nutrition data');

done_testing();
