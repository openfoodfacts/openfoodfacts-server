#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use Log::Any qw($log);

ProductOpener::Display::init();

my $type = param('type') || 'add';
my $action = param('action') || 'display';

my $ingredients_text = remove_tags_and_quote(decode utf8=>param('ingredients_text'));


my $html = '<p>You can use this form to see how an ingredient list is analyzed.</p>';

$html .= start_form(-method => "GET");

$html .= <<HTML
Ingredients text (language code: $lc): <br/>

<textarea id="ingredients_text" name="ingredients_text" style="height:8rem;">$ingredients_text</textarea>
HTML
;

$html .= ''
. hidden(-name=>'type', -value=>$type, -override=>1)
. hidden(-name=>'action', -value=>'process', -override=>1);

$html .= submit()
. end_form();


if ($action eq 'process') {

	# Create a dummy product
	my $product_ref = {
		code => 0,
		lc => $lc,
		"ingredients_text_$lc" => $ingredients_text,
		"ingredients_text" => $ingredients_text,
	};

	clean_ingredients_text($product_ref);
	$log->debug("extract_ingredients_from_text") if $log->is_debug();
	extract_ingredients_from_text($product_ref);
	$log->debug("extract_ingredients_classes_from_text") if $log->is_debug();
	extract_ingredients_classes_from_text($product_ref);

	$html .= display_ingredients_analysis($product_ref);

	my $html_details = display_ingredients_analysis_details($product_ref);
	$html_details =~ s/.*tabindex="-1">/<div>/;

	$html .= "<h4>Ingredients analysis</h4>" . $html_details;

	$html .= "<h4>JSON</h4>"
	. '<pre>'
	. JSON::PP->new->pretty->encode($product_ref->{ingredients})
	. '</pre>'
}


my $full_width = 1;
if ($action ne 'display') {
	$full_width = 0;
}

display_new( {
	title=>"Ingredient Analysis Test",
	content_ref=>\$html,
	full_width=>$full_width,
});
