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
use ProductOpener::Texts qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients
	qw/clean_ingredients_text extract_additives_from_text extract_ingredients_from_text preparse_ingredients_text/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::EnvironmentalImpact qw/estimate_environmental_impact_service/;
use ProductOpener::Web qw/get_languages_options_list/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;

use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $template_data_ref = {};

my $type = single_param('type') || 'add';
my $action = single_param('action') || 'display';

my $ingredients_text = remove_tags_and_quote(decode utf8 => single_param('ingredients_text'));
my $estimator = single_param('estimator') || 'product_opener';

# Nutrients taken into account for estimating the ingredients percentages
my @nutrients = ('fat', 'saturated-fat', 'carbohydrates', 'sugars', 'fiber', 'proteins', 'salt');
my %nutrients_values;
foreach my $nutrient (@nutrients) {
	my $value = single_param($nutrient);
	if ((defined $value) and ($value ne "")) {
		# If the nutrient is defined, use it (and ensure numeric value
		$nutrients_values{$nutrient} = $value + 0;
	}
}

my $html = '';
$template_data_ref->{action} = $action;
$template_data_ref->{type} = $type;

$template_data_ref->{ingredients_text} = $ingredients_text;
$template_data_ref->{estimator} = $estimator;
$template_data_ref->{nutrients_values} = \%nutrients_values;
$template_data_ref->{nutrients} = \@nutrients;

my $target_lc = single_param('target_lc') || $lc;
$template_data_ref->{target_lc} = $target_lc;

if ($action eq 'process') {

	# Create a dummy product
	my $product_ref = {
		code => 0,
		lc => $target_lc,
		"ingredients_text_${target_lc}" => $ingredients_text,
		"ingredients_text" => $ingredients_text,
		nutriments => {map {$_ . '_100g' => $nutrients_values{$_}} keys %nutrients_values},
	};

	clean_ingredients_text($product_ref);
	$log->debug("extract_ingredients_from_text") if $log->is_debug();
	extract_ingredients_from_text($product_ref, {estimate_ingredients_percent => $estimator});
	$log->debug("extract_additives_from_text") if $log->is_debug();
	extract_additives_from_text($product_ref);

	# Environmental impact
	my $errors_ref = [];
	estimate_environmental_impact_service($product_ref, {}, $errors_ref);

	$template_data_ref->{ecobalyse_request_json}
		= JSON::MaybeXS->new->canonical->pretty->encode($product_ref->{environmental_impact}{ecobalyse_request} || {});
	# If there was an error, we have ecobalyse_response, otherwise we have ecobalyse_response_data
	$template_data_ref->{ecobalyse_response_json}
		= JSON::MaybeXS->new->canonical->pretty->encode($product_ref->{environmental_impact} || {});

	my $html_details = display_ingredients_analysis_details($product_ref);
	# Remove everything before the tabindex div to see the details, as we want to show the details directly
	$html_details =~ s/.*tabindex="-1">/<div>/s;

	$template_data_ref->{html_details} = $html_details;
	$template_data_ref->{display_ingredients_analysis} = display_ingredients_analysis($product_ref);
	$template_data_ref->{product_ref} = $product_ref;
	$template_data_ref->{lang_options} = get_languages_options_list($lc);

	my $json = JSON::MaybeXS->new->canonical->pretty->encode($product_ref->{ingredients});
	$template_data_ref->{json} = $json;
}

process_template('web/pages/test_ingredients/test_ingredients_analysis.tt.html', $template_data_ref, \$html)
	or $html = "template error: " . $tt->error();

$request_ref->{title} = "Ingredients analysis test";
$request_ref->{content_ref} = \$html;
display_page($request_ref);
