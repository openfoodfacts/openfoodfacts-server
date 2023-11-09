#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Text qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $template_data_ref = {};

my $type = single_param('type') || 'add';
my $action = single_param('action') || 'display';

my $ingredients_text = remove_tags_and_quote(decode utf8 => single_param('ingredients_text'));

my $html = '';
$template_data_ref->{action} = $action;
$template_data_ref->{type} = $type;

$template_data_ref->{ingredients_text} = $ingredients_text;

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

	my $html_details = display_ingredients_analysis_details($product_ref);
	$html_details =~ s/.*tabindex="-1">/<div>/;

	$template_data_ref->{lc} = $lc;
	$template_data_ref->{html_details} = $html_details;
	$template_data_ref->{display_ingredients_analysis} = display_ingredients_analysis($product_ref);
	$template_data_ref->{product_ref} = $product_ref;
	$template_data_ref->{preparsed_ingredients_text} = preparse_ingredients_text($lc, $ingredients_text);

	my $json = JSON::PP->new->pretty->encode($product_ref->{ingredients});
	$template_data_ref->{json} = $json;
}

process_template('web/pages/test_ingredients/test_ingredients_analysis.tt.html', $template_data_ref, \$html)
	or $html = '';

$request_ref->{title} = "Ingredients analysis test";
$request_ref->{content_ref} = \$html;
display_page($request_ref);
