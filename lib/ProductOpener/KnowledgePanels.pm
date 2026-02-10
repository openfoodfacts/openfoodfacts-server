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

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);
use Data::Dumper;

use ProductOpener::Booleans qw(:all);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&initialize_knowledge_panels_options
		&create_knowledge_panels
		&create_panel_from_json_template
		&add_taxonomy_properties_in_target_languages_to_object
		&create_reuse_card_panel

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Users qw/$User_id/;
use ProductOpener::Food qw/%categories_nutriments_per_country/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/f_lang f_lang_in_lc lang lang_in_other_lc/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Images qw/data_to_display_image/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::PackagerCodes qw/%packager_codes/;
use ProductOpener::KnowledgePanelsIngredients qw/:all/;
use ProductOpener::KnowledgePanelsContribution qw/create_contribution_card_panel/;
use ProductOpener::KnowledgePanelsReportProblem qw/create_report_problem_card_panel/;
use ProductOpener::KnowledgePanelsProduct qw/create_product_card_panel/;
use ProductOpener::ProductsFeatures qw/feature_enabled/;

use JSON::MaybeXS;
use Encode;
use Data::DeepAccess qw(deep_get);
use boolean;

=head1 FUNCTIONS

=head2 initialize_knowledge_panels_options( $knowledge_panels_options_ref, $request_ref )

Initialize the options for knowledge panels from parameters.

=cut

sub initialize_knowledge_panels_options ($knowledge_panels_options_ref, $request_ref) {

	# Activate simplified_root + simplified cards only when specified
	$knowledge_panels_options_ref->{activate_knowledge_panels_simplified}
		= normalize_boolean(single_param("activate_knowledge_panels_simplified"));

	# Activate physical activity knowledge panel only when specified
	$knowledge_panels_options_ref->{activate_knowledge_panel_physical_activities}
		= normalize_boolean(single_param("activate_knowledge_panel_physical_activities"));

	# Specify if we knowledge panels are requested from the app or the website
	# in order to allow different behaviours (e.g. showing ingredients before nutrition on the web)
	# possible values: "web", "app"
	my $knowledge_panels_client = single_param("knowledge_panels_client");
	# set a default value if client is not defined to app or web
	if (   (not defined $knowledge_panels_client)
		or (($knowledge_panels_client ne "web") and ($knowledge_panels_client ne "app")))
	{
		# Default to app mode
		$knowledge_panels_client = 'app';
		# but if it's not an api request, we consider it should be web
		if (not defined $request_ref->{api}) {
			$knowledge_panels_client = "web";
		}
	}
	$knowledge_panels_options_ref->{knowledge_panels_client} = $knowledge_panels_client;

	my $included_panels = single_param('knowledge_panels_included') || '';
	my %included_panels = map {$_ => 1} split(/,/, $included_panels);
	my $excluded_panels = single_param('knowledge_panels_excluded') || '';
	my %excluded_panels = map {$_ => 1} split(/,/, $excluded_panels);
	$knowledge_panels_options_ref->{knowledge_panels_includes} = sub {
		my $panel_id = shift;
		# excluded overrides included
		return (    (not exists $excluded_panels{$panel_id})
				and (not $included_panels or exists $included_panels{$panel_id}));
	};

	# some info about users
	$knowledge_panels_options_ref->{user_logged_in} = defined $User_id;

	return;
}

=head2 create_knowledge_panels( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Create all knowledge panels for a product, with strings (descriptions, recommendations etc.)
in a specific language, and return them in an array of panels.

=head3 Arguments

=head4 product reference $product_ref

#11872 Find and replace Storable with JSON

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc (or "data")

Returned panels contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

If $target_lc is equal to "data", no strings are returned.

=head4 country code $target_cc

Needed for some country specific panels like the Environmental-Score.

=head4 options $options_ref

Defines how some panels should be created (or not created)

- deactivate_[panel_id] : do not create a default panel -- currently unimplemented
- activate_[panel_id] : create an on demand panel -- currently only for physical_activities panel

=head4 request reference $request_ref

Contains the request parameters, including the API request parameters.

=head3 Return values

Panels are returned in the "knowledge_panels_[$target_lc]" hash of the product reference
passed as input.

=cut

sub create_knowledge_panels ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create knowledge panels for product", {code => $product_ref->{code}, target_lc => $target_lc})
		if $log->is_debug();

	# Initialize panels

	$product_ref->{"knowledge_panels_" . $target_lc} = {};

	# Test panel to test the start of the API
	# Disabled, kept as reference when we create a "Do you know" panel
	if ($product_ref->{code} eq "3017620422003--disabled") {

		my $test_panel_ref = {
			parent_panel_id => "root",
			type => "doyouknow",
			level => "trivia",
			topics => ["ingredients"],
			title_element => [
				title => "Do you know why Nutella contains hazelnuts?",
				subtitle => "It all started after the second world war...",
			],
			elements => [
				{
					element_type => "text",
					element => {
						text_type => "default",
						html =>
							"Cocoa beans were expensive and hard to come by after the second world war, so in Piedmont (Italy) where Pietro Ferrero created Nutella, they were replaced with hazelnuts to make <em>gianduja</em>, a mix of hazelnut paste and chocolate."
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

	my $panel_is_requested = $options_ref->{knowledge_panels_includes};

	# Create recommendation panels first, as they will be included in cards such has the health card and environment card
	if (    $panel_is_requested->('health_card')
		and $panel_is_requested->('environment_card')
		and feature_enabled('food_recommendations'))
	{
		create_recommendation_panels($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $has_health_card;
	if ($panel_is_requested->('health_card')
		and feature_enabled('health_card'))
	{
		$has_health_card = create_health_card_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $has_product_card;
	if ($panel_is_requested->('product_card')) {
		$has_product_card = create_product_card_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $has_environment_card;
	if ($panel_is_requested->('environment_card')) {
		$has_environment_card
			= create_environment_card_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $has_reuse_card;
	if ($panel_is_requested->('reuse_card')) {
		$has_reuse_card = create_reuse_card_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $has_report_problem_card;
	if (not $options_ref->{producers_platform} and $panel_is_requested->('report_problem_card')) {
		$has_report_problem_card
			= create_report_problem_card_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $has_contribution_card;
	if ($panel_is_requested->('contribution_card')) {
		$has_contribution_card
			= create_contribution_card_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $has_secondhand_card;
	if ($panel_is_requested->('secondhand_card')) {
		$has_secondhand_card
			= create_secondhand_card_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	# Create the root panel that contains the panels we want to show directly on the product page
	create_panel_from_json_template(
		"root",
		"api/knowledge-panels/root.tt.json",
		{
			has_health_card => $has_health_card,
			has_report_problem_card => $has_report_problem_card,
			has_contribution_card => $has_contribution_card,
			has_environment_card => $has_environment_card,
			has_reuse_card => $has_reuse_card,
			has_secondhand_card => $has_secondhand_card,
			has_product_card => $has_product_card,
		},
		$product_ref,
		$target_lc,
		$target_cc,
		$options_ref,
		$request_ref
	);

	# If requested, create simplified knowledge panels for mobile app

	if ($knowledge_panels_options_ref->{activate_knowledge_panels_simplified}) {

		# Create the simplified root panel that contains simplified versions of the health and environment cards
		# (used on mobile app)
		create_panel_from_json_template(
			"simplified_root",
			"api/knowledge-panels/simplified_root.tt.json",
			{
				has_health_card => $has_health_card,
				has_environment_card => $has_environment_card,
			},
			$product_ref,
			$target_lc,
			$target_cc,
			$options_ref,
			$request_ref
		);
		# Create the simplified cards
		if ($has_health_card) {
			create_panel_from_json_template("health_card_simplified",
				"api/knowledge-panels/health/health_card_simplified.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}
		if ($has_environment_card) {
			create_panel_from_json_template("environment_card_simplified",
				"api/knowledge-panels/environment/environment_card_simplified.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
			# Simplified environmental panels
			create_panel_from_json_template(
				"origins_of_ingredients_simplified",
				"api/knowledge-panels/environment/origins_of_ingredients_simplified.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref
			);
			create_panel_from_json_template(
				"threatened_species_simplified",
				"api/knowledge-panels/environment/threatened_species_simplified.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref
			);
			create_panel_from_json_template("packaging_simplified",
				"api/knowledge-panels/environment/packaging_simplified.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
			create_panel_from_json_template(
				"environmental_labels_simplified",
				"api/knowledge-panels/environment/environmental_labels_simplified.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref
			);
		}

	}

	return;
}

=head2 convert_multiline_string_to_singleline($line)

Helper function to allow to enter multiline strings in JSON templates.
The function converts the multiline string into a single line string.

New lines are converted to \n, and quotes " and \ are escaped if not escaped already.

=cut

sub convert_multiline_string_to_singleline ($line) {

	# Escape " and \ unless they have been escaped already
	# negative look behind to not convert \n to \\n or \" to \\" or \\ to \\\\
	$line =~ s/(?<!\\)("|\\)/\\$1/g;

	# \R will match all Unicode newline sequence
	$line =~ s/\R/\\n/sg;

	return '"' . $line . '"';
}

=head2 convert_multiline_string_to_singleline_without_line_breaks_and_extra_spaces($line)

Helper function to allow to enter multiline strings in JSON templates.
The function converts the multiline string into a single line string.

Line breaks are converted to spaces, and multiple spaces are converted to a single space.

This function is useful in templates where we use IF statements etc. to generate a single value like a title.

=cut

sub convert_multiline_string_to_singleline_without_line_breaks_and_extra_spaces ($line) {

	# Escape " and \ unless they have been escaped already
	# negative look behind to not convert \n to \\n or \" to \\" or \\ to \\\\
	$line =~ s/(?<!\\)("|\\)/\\$1/g;

	$line =~ s/\s+/ /g;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;

	return '"' . $line . '"';
}

=head2 create_panel_from_json_template ( $panel_id, $panel_template, $panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel from a JSON template.
The template is passed both the full product data + optional panel specific data.
The template is thus responsible for all the display logic (what to display and how to display it).

Some special features that are not included in the JSON format are supported:

1. Relative links are converted to absolute links using the requested country / language subdomain

2. Multiline strings can be included using backticks ` at the start and end of the multiline strings.
- The multiline strings will be converted to a single string.
- Quotes " are automatically escaped unless they are already escaped

Using two backticks at the start and end of the string removes line breaks and extra spaces.

3. Comments can be included by starting a line with //
- Comments will be removed in the resulting JSON, they are only intended to make the source template easier to understand.

4. Trailing commas are removed
- For each loops in templates can result in trailing commas when separating items in a list with a comma
(e.g. if want to generate a list of labels)

=head3 Arguments

=head4 panel id $panel_id

=head4 panel template $panel_template

Relative path to the the template panel file, from the "/templates" directory.
e.g. "api/knowledge-panels/environment/environmental_score/agribalyse.tt.json"

=head4 panel data reference $panel_data_ref (optional, can be an empty hash)

Used to pass data that is necessary for the panel but is not contained in the product data.

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Environmental-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_panel_from_json_template ($panel_id, $panel_template, $panel_data_ref, $product_ref, $target_lc, $target_cc,
	$options_ref, $request_ref)
{

	my $panel_json;

	# We pass several structures to the template:
	# - panel: this panel data
	# - panels: the hash of all panels created so far (useful for panels that include previously created panels
	# only if they have indeed been created)
	# - product: the product data

	if (
		not process_template(
			$panel_template,
			{
				panel => $panel_data_ref,
				panels => $product_ref->{"knowledge_panels_" . $target_lc},
				product => $product_ref,
				knowledge_panels_options => $options_ref,
			},
			\$panel_json,
			$request_ref
		)
		)
	{
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

		# Turn relative links to absolute links using the requested country / language subdomain
		my $formatted_subdomain = $request_ref->{formatted_subdomain};
		$panel_json =~ s/href="\//href="$formatted_subdomain\//g;

		# Convert multilines strings between backticks `` into single line strings
		# We use two backticks `` to remove line breaks and extra spaces
		# In the template, we use multiline strings for readability
		# e.g. when we want to generate HTML

		# Also escape quotes " to \"

		$panel_json
			=~ s/\`\`([^\`]*)\`\`/convert_multiline_string_to_singleline_without_line_breaks_and_extra_spaces($1)/seg;
		$panel_json =~ s/\`([^\`]*)\`/convert_multiline_string_to_singleline($1)/seg;

		# Remove trailing commas at the end of a string delimited by quotes
		# Useful when using a foreach loop to generate a list of comma separated elements
		# The negative look-behind is used in order not to remove commas after quotes, ] and } and digits
		# (e.g. we want to keep the comma in "field1": "value1", "field2": "value2", and in "percent: 8, ")
		# Note: this will fail if the string ends with a digit.
		# As it is a trailing comma inside a string, it's not a terrible issue, the string will be valid,
		# but it will have an unneeded trailing comma.
		# The group (\W) at the end is to avoid removing commas before an opening quote (e.g. for "field": true, "other_field": ..)
		$panel_json =~ s/(?<!("|'|\]|\}|\d))\s*,\s*"(\W)/"$2/sg;

		# Remove trailing commas after the last element of a array or hash, as they will make the JSON invalid
		# It makes things much simpler in templates if they can output a trailing comma though
		# e.g. in FOREACH loops.
		# So we remove them here.

		$panel_json =~ s/,(\s*)(\]|\})/$2/sg;

		# Transform the JSON in a Perl structure

		$panel_json = encode('UTF-8', $panel_json);

		eval {
			$product_ref->{"knowledge_panels_" . $target_lc}{$panel_id} = decode_json($panel_json);
			1;
		} or do {
			# The JSON generated by the template is invalid
			my $json_decode_error = $@;

			# Save the JSON file so that it can be more easily debugged, and that we can monitor issues
			my $target_dir = "$BASE_DIRS{PUBLIC_FILES}/debug/knowledge_panels/";
			my $filename = $panel_id . $product_ref->{code} . ".json";
			my $target_file = "$target_dir/" . $filename;
			my $url = "/files/debug/knowledge_panels/" . $filename;
			ensure_dir_created_or_die($target_dir);
			open(my $out, ">:encoding(UTF-8)", $target_file) or die "cannot open $target_file";
			print $out $panel_json;
			close($out);

			$product_ref->{"knowledge_panels_" . $target_lc}{$panel_id} = {
				"template" => $panel_template,
				"json_error" => $json_decode_error,
				"json" => $panel_json,
				"json_debug_url" => $static_subdomain . $url
			};
		}
	}
	return;
}

=head2 create_environmental_score_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel to describe the Environmental-Score, including sub-panels
for the different components of the Environmental-Score.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Environmental-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_environmental_score_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create environmental_score panel",
		{code => $product_ref->{code}, environmental_score_data => $product_ref->{environmental_score_data}})
		if $log->is_debug();

	my $cc = $request_ref->{cc};

	# 2024/12: If we do not have yet environmental_score_data, we use ecoscore_data
	# (or possibly for older revisions)
	# TBD: remove this code once all products have been updated (but we won't show the score for old revisions)
	if ((not defined $product_ref->{environmental_score_data}) and (defined $product_ref->{ecoscore_data})) {
		$product_ref->{environmental_score_data} = $product_ref->{ecoscore_data};
	}

	if (    (defined $product_ref->{environmental_score_data})
		and ($product_ref->{environmental_score_data}{status} eq "known"))
	{

		my $score = $product_ref->{environmental_score_data}{score};
		my $grade = $product_ref->{environmental_score_data}{grade};
		my $transportation_warning = undef;

		if (defined $product_ref->{environmental_score_data}{scores}{$cc}) {
			$score = $product_ref->{environmental_score_data}{scores}{$cc};
			$grade = $product_ref->{environmental_score_data}{grades}{$cc};
			if ($cc eq "world") {
				$transportation_warning
					= lang_in_other_lc($target_lc, "environmental_score_warning_transportation_world");
			}
		}
		else {
			$transportation_warning = lang_in_other_lc($target_lc, "environmental_score_warning_transportation");
		}

		$log->debug("create environmental_score panel - known",
			{code => $product_ref->{code}, score => $score, grade => $grade})
			if $log->is_debug();

		# Agribalyse part of the Environmental-Score

		my $agribalyse_category_name = $product_ref->{environmental_score_data}{agribalyse}{name_en};
		if (defined $product_ref->{environmental_score_data}{agribalyse}{"name_" . $target_lc}) {
			$agribalyse_category_name = $product_ref->{environmental_score_data}{agribalyse}{"name_" . $target_lc};
		}

		# Agribalyse grade
		my $agribalyse_score = $product_ref->{environmental_score_data}{agribalyse}{score};
		my $agribalyse_grade;

		if ($agribalyse_score >= 90) {
			$agribalyse_grade = "a-plus";
		}
		elsif ($agribalyse_score >= 75) {
			$agribalyse_grade = "a";
		}
		elsif ($agribalyse_score >= 60) {
			$agribalyse_grade = "b";
		}
		elsif ($agribalyse_score >= 45) {
			$agribalyse_grade = "c";
		}
		elsif ($agribalyse_score >= 30) {
			$agribalyse_grade = "d";
		}
		elsif ($agribalyse_score >= 15) {
			$agribalyse_grade = "e";
		}
		else {
			$agribalyse_grade = "f";
		}

		my $letter_grade = uc($grade);    # A+, A, B, C, D, E, F
		my $grade_underscore = $grade;
		$grade_underscore =~ s/\-/_/;    # a-plus -> a_plus
		if ($grade eq "a-plus") {
			$letter_grade = "A+";
		}

		my $agribalyse_letter_grade = uc($agribalyse_grade);    # A+, A, B, C, D, E, F
		my $agribalyse_grade_underscore = $agribalyse_grade;
		$agribalyse_grade_underscore =~ s/\-/_/;    # a-plus -> a_plus
		if ($agribalyse_grade eq "a-plus") {
			$agribalyse_letter_grade = "A+";
		}

		# cap the score to 100 as we display it /100
		if ($score > 100) {
			$score = 100;
		}
		if ($score < 0) {
			$score = 0;
		}

		# We can reuse some strings from the Environmental-Score attribute
		my $title = sprintf(lang_in_other_lc($target_lc, "attribute_environmental_score_grade_title"), $letter_grade);
		my $subtitle
			= lang_in_other_lc($target_lc, "attribute_environmental_score_" . $grade_underscore . "_description_short");

		my $panel_data_ref = {
			"agribalyse_category_name" => $agribalyse_category_name,
			"agribalyse_score" => $agribalyse_score,
			"agribalyse_grade" => $agribalyse_grade,
			"agribalyse_grade_underscore" => $agribalyse_grade_underscore,
			"agribalyse_letter_grade" => $agribalyse_letter_grade,
			"name" => lang_in_other_lc($target_lc, "attribute_environmental_score_name"),
			"score" => $score,
			"grade" => $grade,
			"grade_underscore" => $grade_underscore,
			"letter_grade" => $letter_grade,
			"title" => $title,
			"subtitle" => $subtitle,
			"transportation_warning" => $transportation_warning,
		};

		create_panel_from_json_template("environmental_score",
			"api/knowledge-panels/environment/environmental_score/environmental_score.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		# Add an Agribalyse panel to show the impact of the different steps for the category on average

		create_panel_from_json_template(
			"environmental_score_agribalyse",
			"api/knowledge-panels/environment/environmental_score/agribalyse.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref
		);

		create_panel_from_json_template("carbon_footprint",
			"api/knowledge-panels/environment/carbon_footprint_food.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		# Add panels for the different bonuses and maluses

		foreach my $adjustment ("production_system", "origins_of_ingredients", "threatened_species", "packaging") {

			my $adjustment_panel_data_ref = {};

			create_panel_from_json_template(
				"environmental_score_" . $adjustment,
				"api/knowledge-panels/environment/environmental_score/" . $adjustment . ".tt.json",
				$adjustment_panel_data_ref,
				$product_ref,
				$target_lc,
				$target_cc,
				$options_ref,
				$request_ref
			);
		}

		# Add panel for the final Environmental-Score of the product
		create_panel_from_json_template("environmental_score_total",
			"api/knowledge-panels/environment/environmental_score/total.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		# Add environmental_score_adjustments panel group (used in simplified environment card)
		create_panel_from_json_template(
			"environmental_score_adjustments",
			"api/knowledge-panels/environment/environmental_score/environmental_score_adjustments.tt.json",
			{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref
		);
	}
	# Environmental-Score is not applicable
	elsif ( (defined $product_ref->{environmental_score_grade})
		and ($product_ref->{environmental_score_grade} eq "not-applicable"))
	{
		my $panel_data_ref = {};
		$panel_data_ref->{subtitle} = f_lang_in_lc(
			$target_lc,
			"f_attribute_environmental_score_not_applicable_description",
			{
				category => display_taxonomy_tag_name(
					$target_lc,
					"categories",
					deep_get(
						$product_ref, qw/environmental_score_data environmental_score_not_applicable_for_category/
					)
				)
			}
		);
		create_panel_from_json_template("environmental_score",
			"api/knowledge-panels/environment/environmental_score/environmental_score_not_applicable.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	# Environmental-Score is unknown
	else {
		my $panel_data_ref = {};
		create_panel_from_json_template("environmental_score",
			"api/knowledge-panels/environment/environmental_score/environmental_score_unknown.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	# Add panels for environmental Environmental-Score labels
	if (    (defined $product_ref->{environmental_score_data})
		and (defined $product_ref->{environmental_score_data}{adjustments})
		and (defined $product_ref->{environmental_score_data}{adjustments}{production_system})
		and (defined $product_ref->{environmental_score_data}{adjustments}{production_system}{labels}))
	{

		foreach my $labelid (@{$product_ref->{environmental_score_data}{adjustments}{production_system}{labels}}) {
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
				if (!(defined $property_value) && ($target_lc ne "en")) {
					# fallback to english
					$property_value = get_inherited_property("labels", $labelid, $property . ":" . "en");
				}
				if (defined $property_value) {
					$label_panel_data_ref->{$property} = $property_value;
				}
			}

			create_panel_from_json_template(
				"environment_label_" . $labelid,
				"api/knowledge-panels/environment/label.tt.json",
				$label_panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref
			);
		}
	}

	return;
}

=head2 create_environment_card_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel card that contains all knowledge panels related to the environment.

Created for all products (with at least a packaging panel).

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Environmental-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_environment_card_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create environment card panel", {code => $product_ref->{code}}) if $log->is_debug();

	my $panel_data_ref = {};

	# Create Environmental-Score related panels
	if ($options{product_type} eq "food") {
		create_environmental_score_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		if (
				(defined $product_ref->{environmental_score_data})
			and (defined $product_ref->{environmental_score_data}{adjustments})
			and (defined $product_ref->{environmental_score_data}{adjustments}{threatened_species})
			and (defined $product_ref->{environmental_score_data}{adjustments}{threatened_species}{value}
				&& $product_ref->{environmental_score_data}{adjustments}{threatened_species}{value} != 0)
			)
		{

			create_panel_from_json_template("threatened_species",
				"api/knowledge-panels/environment/threatened_species.tt.json",
				$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}
	}

	# Create panel for carbon footprint (non-food products, for food products, it is added by create_environmental_score_panel)
	if ($options{product_type} ne "food") {
		create_carbon_footprint_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	# Create panel for packaging components, and packaging materials
	create_panel_from_json_template("packaging", "api/knowledge-panels/environment/packaging.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	create_panel_from_json_template("packaging_materials",
		"api/knowledge-panels/environment/packaging_materials.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	create_panel_from_json_template("packaging_components",
		"api/knowledge-panels/environment/packaging_components.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Create panel for manufacturing place
	create_manufacturing_place_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Origins of ingredients for the environment card, for food, pet food and beauty products
	if (feature_enabled("ingredients")) {
		create_panel_from_json_template("origins_of_ingredients",
			"api/knowledge-panels/environment/origins_of_ingredients.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	# Forest footprint
	if (defined $product_ref->{forest_footprint_data}) {
		create_panel_from_json_template("forest_footprint", "api/knowledge-panels/environment/forest_footprint.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	# Create the environment_card panel
	$panel_data_ref->{packaging_image} = data_to_display_image($product_ref, "packaging", $target_lc);
	create_panel_from_json_template("environment_card", "api/knowledge-panels/environment/environment_card.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	return 1;
}

=head2 create_reuse_card_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel card that contains information about circular economy solutions for reuse

It's a container for specific knowledge panels.

=head3 Arguments

=head4 product reference $product_ref

Created knowledge panels will be added to product_ref

=head4 language code $target_lc

=head4 country code $target_cc

=head4 options configuration reference $options_ref

=head4 request reference $request_ref

=cut

sub create_reuse_card_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create reuse card panel", {code => $product_ref->{code}}) if $log->is_debug();

	my $sub_panels = 0;

	$sub_panels += create_qfdmo_fr_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	if ($sub_panels == 0) {
		return 0;
	}

	my $panel_data_ref = {};
	# Create the reuse_card panel
	create_panel_from_json_template("reuse_card", "api/knowledge-panels/reuse/reuse_card.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	return 1;
}

=head2 create_qfdmo_fr_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel card that contains information about circular economy solutions
through QFDMO (Où et comment donner, réparer et recycler).

Only created for:
- Products on Open Products Facts (product_type "product")
- Products with a category that has a qfdmo_name_fr property
- Users in France (target_cc = "fr")

=head3 Arguments

=head4 product reference $product_ref

Created knowledge panels will be added to product_ref

=head4 language code $target_lc

=head4 country code $target_cc

=head4 options configuration reference $options_ref

=head4 request reference $request_ref

=head

=cut

sub create_qfdmo_fr_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {
	my $panel_data_ref = {};

	# Only available for the product_type "product" (Open Products Facts)
	if ($options_ref->{product_type} ne "product") {
		return 0;
	}

	# Only show for France
	if ($target_cc ne 'fr') {
		return 0;
	}

	# Check if any category in the hierarchy has a qfdmo_name_fr property
	my ($qfdmo_name_fr, $category_id) = get_inherited_property_from_categories_tags($product_ref, "qfdmo_id:fr");

	# Don't create the panel if no category has QFDMO info
	if (not defined $qfdmo_name_fr) {
		return 0;
	}

	# Get the French name of the category with QFDMO info
	my $category_name_fr = display_taxonomy_tag_name("fr", "categories", $category_id);

	# Add QFDMO info to panel data
	$panel_data_ref->{qfdmo_name_fr} = $qfdmo_name_fr;
	$panel_data_ref->{category_name_fr} = $category_name_fr;

	# Create QFDMO solutions panel
	create_panel_from_json_template("qfdmo_solutions", "api/knowledge-panels/reuse/qfdmo_solutions.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	return 1;
}

=head2 create_secondhand_card_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel card that contains all knowledge panels related to the circular economy:
- sharing, buying, selling etc.

Created for products in specific categories, for users in specific countries.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

Used to select secondhand options (e.g. classified ads sites) that are relevant for the user.

=cut

sub create_secondhand_card_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create secondhand card panel", {code => $product_ref->{code}}) if $log->is_debug();

	my $panel_data_ref = {};

	# Only available for the product_type "product"
	if ($options{product_type} ne "product") {
		return 0;
	}

	# Add the name of the most specific category (last in categories_hierarchy) to the panel data
	my $category_id = $product_ref->{categories_hierarchy}[-1];
	$panel_data_ref->{category_name} = display_taxonomy_tag_name($target_lc, "categories", $category_id);

	# Create paneld for donations

	create_panel_from_json_template("donated_products_fr_geev",
		"api/knowledge-panels/secondhand/donated_products_fr_geev.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	create_panel_from_json_template("donated_products", "api/knowledge-panels/secondhand/donated_products.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Created panels for buying used products
	create_panel_from_json_template("used_products_fr_backmarket",
		"api/knowledge-panels/secondhand/used_products_fr_backmarket.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	create_panel_from_json_template("used_products", "api/knowledge-panels/secondhand/used_products.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Create the secondhand_card panel

	create_panel_from_json_template("secondhand_card", "api/knowledge-panels/secondhand/secondhand_card.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	return 1;
}

sub create_carbon_footprint_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	# Find the first category that has a carbon_impact_fr_impactco2:en: property
	my ($value, $category_id)
		= get_inherited_property_from_categories_tags($product_ref, "carbon_impact_fr_impactco2:en");

	$log->debug("create carbon footprint panel",
		{code => $product_ref->{code}, category_id => $category_id, value => $value})
		if $log->is_debug();

	if (defined $value) {

		my $panel_data_ref = {
			category_id => $category_id,
			category_name => display_taxonomy_tag_name($target_lc, "categories", $category_id),
			co2_kg_per_unit => $value,
			unit_name => get_property_with_fallbacks("categories", $category_id, "unit_name:$target_lc"),
			link => get_property("categories", $category_id, "carbon_impact_fr_impactco2_link:en"),
		};

		create_panel_from_json_template("carbon_footprint",
			"api/knowledge-panels/environment/carbon_footprint_product.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	return;
}

=head2 create_manufacturing_place_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel when we know the location of the manufacturing place,
usually through a packaging code.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Environmental-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=cut

sub create_manufacturing_place_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create_manufacturing_place_panel", {code => $product_ref->{code}}) if $log->is_debug();

	# Go through the product packaging codes, keep the first one with associated geo coordinates
	if (defined $product_ref->{emb_codes_tags}) {
		foreach my $packager_code_tagid (@{$product_ref->{emb_codes_tags}}) {
			# we will create a panel for the first known location
			if (exists $packager_codes{$packager_code_tagid}) {
				$log->debug("packager code found for the canon_tagid",
					{cc => $packager_codes{$packager_code_tagid}{cc}})
					if $log->is_debug();
				my ($lat, $lng) = get_packager_code_coordinates($packager_code_tagid);
				if ((defined $lat) and (defined $lng)) {

					my $panel_data_ref = {
						packager_code_data => $packager_codes{$packager_code_tagid},
						lat => $lat + 0.0,
						lng => $lng + 0.0,
					};

					create_panel_from_json_template("manufacturing_place",
						"api/knowledge-panels/environment/manufacturing_place.tt.json",
						$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
				}
			}
		}
	}
	return;
}

=head2 create_health_card_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel card that contains all knowledge panels related to health.

This panel card is created for food, pet food, and beauty products.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

We may display country specific recommendations from health authorities, or country specific scores.

=head4 options reference $options_ref

=cut

sub create_health_card_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create health card panel", {code => $product_ref->{code}}) if $log->is_debug();

	# All food, pet food and beauty products have ingredients
	if (feature_enabled("ingredients")) {
		create_ingredients_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		create_ingredients_list_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	# Show additives only for food and pet food
	if (feature_enabled("additives")) {
		create_additives_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	create_ingredients_analysis_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	create_ingredients_rare_crops_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	create_ingredients_added_sugars_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Scores for food products
	if (feature_enabled("nova")) {
		create_nova_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	if (feature_enabled("nutriscore")) {

		# For moderators, admins, and on the producers platform: we show the old Nutri-Score
		# in addition to the new Nutri-Score

		if (   $options_ref->{admin}
			|| $options_ref->{moderator}
			|| $options_ref->{producers_platform})
		{
			create_nutriscore_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}

		create_nutriscore_2023_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		create_nutrient_levels_panels($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		if ($options_ref->{activate_knowledge_panel_physical_activities}) {
			create_physical_activities_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}
	}

	# Nutrition facts for food and pet food
	if (feature_enabled("nutrition")) {
		create_serving_size_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		create_nutrition_facts_table_panel($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	my $panel_data_ref = {
		ingredients_image => data_to_display_image($product_ref, "ingredients", $target_lc),
		nutrition_image => data_to_display_image($product_ref, "nutrition", $target_lc),
	};

	$log->debug("create health card panel - data", {code => $product_ref->{code}, panel_data => $panel_data_ref})
		if $log->is_debug();

	create_panel_from_json_template("health_card", "api/knowledge-panels/health/health_card.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	return 1;
}

=head2 create_nutriscore_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates knowledge panels to describe the Nutri-Score.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_nutriscore_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create nutriscore panel",
		{code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data}})
		if $log->is_debug();

	my $panel_data_ref = data_to_display_nutriscore($product_ref);

	# Nutri-Score panel

	if ($panel_data_ref->{nutriscore_grade} eq "not-applicable") {
		$panel_data_ref->{title} = lang_in_other_lc($target_lc, "attribute_nutriscore_not_applicable_title");
	}
	else {
		$panel_data_ref->{title} = lang_in_other_lc($target_lc,
			"attribute_nutriscore_" . $panel_data_ref->{nutriscore_grade} . "_description_short");
	}
	$panel_data_ref->{name} = lang_in_other_lc($target_lc, "attribute_nutriscore_name");

	# Nutri-Score panel: score + details
	create_panel_from_json_template("nutriscore", "api/knowledge-panels/health/nutriscore/nutriscore.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	return;
}

sub create_nutriscore_2023_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	my $version = "2023";

	$log->debug("create nutriscore_2023 panel",
		{code => $product_ref->{code}, nutriscore_data => deep_get($product_ref, qw/nutriscore 2023 data/)})
		if $log->is_debug();

	my $panel_data_ref = data_to_display_nutriscore($product_ref, $version);

	# Nutri-Score panel
	my $grade = deep_get($product_ref, "nutriscore", $version, "grade");

	# Title
	if ($grade eq "not-applicable") {
		$panel_data_ref->{title} = lang_in_other_lc($target_lc, "attribute_nutriscore_not_applicable_title");
	}
	elsif ($grade eq 'unknown') {
		$panel_data_ref->{title} = lang_in_other_lc($target_lc, "attribute_nutriscore_unknown_title");
	}
	else {
		$panel_data_ref->{title}
			= sprintf(lang_in_other_lc($target_lc, "attribute_nutriscore_grade_title"), uc($grade));
	}

	# Subtitle
	if ($panel_data_ref->{nutriscore_unknown_reason_short}) {
		$panel_data_ref->{subtitle} = $panel_data_ref->{nutriscore_unknown_reason_short};
	}
	else {
		$panel_data_ref->{subtitle} = lang_in_other_lc($target_lc,
			"attribute_nutriscore_" . $panel_data_ref->{nutriscore_grade} . "_description_short");
	}

	# Nutri-Score computed
	if (($grade ne "not-applicable") and ($grade ne "unknown")) {

		# Nutri-Score sub-panels for each positive or negative component
		foreach my $type (qw/positive negative/) {
			my $components_ref = deep_get($product_ref, "nutriscore", $version, "data", "components", $type) // [];
			foreach my $component_ref (@$components_ref) {

				my $value = $component_ref->{value};

				# Specify if there is a space between the value and the unit
				my $space_before_unit = '';

				my $unit = $component_ref->{unit};

				# If the value is not defined (e.g. fiber or fruits_vegetables_legumes), display "unknown" with no unit
				if (not defined $value) {
					$value = lc(lang_in_other_lc($target_lc, "unknown"));
					$unit = '';
				}
				else {
					# Localize the unit for the number of non-nutritive sweeteners
					if ($component_ref->{id} eq "non_nutritive_sweeteners") {
						$space_before_unit = ' ';
						if ($value > 1) {
							$unit = lang_in_other_lc($target_lc, "sweeteners");
						}
						else {
							$unit = lang_in_other_lc($target_lc, "sweetener");
						}
					}
				}

				my $component_panel_data_ref = {
					"type" => $type,
					"id" => $component_ref->{id},
					"value" => $value,
					"unit" => $unit,
					"space_before_unit" => $space_before_unit,
					"points" => $component_ref->{points},
					"points_max" => $component_ref->{points_max},
				};
				create_panel_from_json_template(
					"nutriscore_component_" . $component_ref->{id},
					"api/knowledge-panels/health/nutriscore/nutriscore_component.tt.json",
					$component_panel_data_ref,
					$product_ref,
					$target_lc,
					$target_cc,
					$options_ref,
					$request_ref
				);
			}

			create_panel_from_json_template("nutriscore_details",
				"api/knowledge-panels/health/nutriscore/nutriscore_details.tt.json",
				$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}
	}

	# Nutri-Score panel: parent panel
	create_panel_from_json_template("nutriscore_2023", "api/knowledge-panels/health/nutriscore/nutriscore_2023.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Nutri-Score new computation
	create_panel_from_json_template("nutriscore_new_computation",
		"api/knowledge-panels/health/nutriscore/nutriscore_new_computation.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Nutri-Score description
	create_panel_from_json_template("nutriscore_description",
		"api/knowledge-panels/health/nutriscore/nutriscore_description.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	return;
}

=head2 create_nutrient_levels_panels ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates knowledge panels for nutrient levels for fat, saturated fat, sugars and salt.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_nutrient_levels_panels ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create nutriscore panel",
		{code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data}})
		if $log->is_debug();

	my $nutrient_levels_ref = data_to_display_nutrient_levels($product_ref);

	# Nutrient levels panels
	if (not $nutrient_levels_ref->{do_not_display}) {
		foreach my $nutrient_level_ref (@{$nutrient_levels_ref->{nutrient_levels}}) {
			my $nid = $nutrient_level_ref->{nid};
			create_panel_from_json_template(
				"nutrient_level_" . $nid,
				"api/knowledge-panels/health/nutrition/nutrient_level.tt.json",
				$nutrient_level_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref,
			);
		}

		create_panel_from_json_template("nutrient_levels",
			"api/knowledge-panels/health/nutrition/nutrient_levels.tt.json",
			{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	return;
}

=head2 create_nutrition_facts_table_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel with the nutrition facts table.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_nutrition_facts_table_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create nutrition facts panel",
		{code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data}})
		if $log->is_debug();

	# Generate a panel only for food products that have a nutrition table
	if (    (not((defined $options{no_nutrition_table}) and ($options{no_nutrition_table})))
		and (not((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on'))))
	{

		# Compare the product nutrition facts to the most specific category
		my $comparisons_ref = compare_product_nutrition_facts_to_categories($product_ref, $target_cc, 1);
		my $panel_data_ref = data_to_display_nutrition_table($product_ref, $comparisons_ref, $request_ref);

		create_panel_from_json_template("nutrition_facts_table",
			"api/knowledge-panels/health/nutrition/nutrition_facts_table.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	return;
}

=head2 create_serving_size_panel( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates a knowledge panel with portion size.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_serving_size_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create serving size panel",
		{code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data}})
		if $log->is_debug();

	# Generate a panel only for food products that have a serving size
	if (defined $product_ref->{serving_size}) {
		my $serving_warning = undef;
		if (    (defined $product_ref->{serving_quantity} && $product_ref->{serving_quantity} <= 5)
			and ($product_ref->{nutrition_data_per} eq 'serving'))
		{
			$serving_warning = lang_in_other_lc($target_lc, "serving_too_small_for_nutrition_analysis");
		}
		my $panel_data_ref = {"serving_warning" => $serving_warning,};
		create_panel_from_json_template("serving_size", "api/knowledge-panels/health/nutrition/serving_size.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	return;
}

=head2 create_physical_activities_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

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
	'walking' => 3.5,    # walking, 2.8 to 3.2 mph, level, moderate pace, firm surface
	'swimming' => 5.8,    # swimming laps, freestyle, front crawl, slow, light or moderate effort
	'bicycling' => 7.5,    # bicycling, general
	'running' => 10,    # running, 6 mph (10 min/mile)
);

my @sorted_activities = sort ({$activities_met{$a} <=> $activities_met{$b}} keys %activities_met);

sub create_physical_activities_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create physical_activities panel",
		{code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data}})
		if $log->is_debug();

	# Generate a panel only for food products that have an energy per 100g value
	if (    (defined $product_ref->{nutriments})
		and (defined $product_ref->{nutriments}{energy_100g})
		and ($product_ref->{nutriments}{energy_100g} > 0))
	{

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

		create_panel_from_json_template("physical_activities",
			"api/knowledge-panels/health/nutrition/physical_activities.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	return;
}

sub remove_latex_sequences ($string) {

	# Some wikipedia abstracts have chemical formulas like {\\displaystyle \\mathrm {NaNO_{3}} +\\mathrm {Pb} \\to \\mathrm {NaNO_{2}} +\\mathrm {PbO} }
	# In practice, we remove everything between { }

	$string =~ s/
        (                   
        {                   # match an opening {
            (?:
                [^{}]++     # one or more non angle brackets, non backtracking
                  |
                (?1)        # found { or }, so recurse to capture group 1
            )*
        }                   # match a closing }
        )                   
        //xg;

	return $string;
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

sub add_taxonomy_properties_in_target_languages_to_object ($object_ref, $tagtype, $tagid, $properties_ref,
	$target_lcs_ref)
{

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
			$object_ref->{$property} = remove_latex_sequences($property_value);
			$object_ref->{$property . "_lc"} = $property_lc;
			$object_ref->{$property . "_language"}
				= display_taxonomy_tag($target_lcs_ref->[0], "languages", $language_codes{$property_lc});
		}
	}
	return;
}

=head2 create_recommendation_panels ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

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

sub create_recommendation_panels ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create health recommendation panels", {code => $product_ref->{code},}) if $log->is_debug();

	# New recommendation panels are specified in taxonomies such as the category taxonomy
	# with properties like:

	# recommendation_panel_id:en: recommendation_health
	# recommendation_panel_evaluation:en: bad
	# recommendation_panel_icon:en: arrow-bottom-right-thick.svg
	# recommendation_panel_msgctxt_prefix:en: recommendation_eu_tobacco_health_warning
	# recommendation_panel_source_url:en: European Union
	# recommendation_panel_source_language:en: en
	# recommendation_panel_source_url:en: https://health.ec.europa.eu/tobacco/product-regulation/health-warnings_en#combined-health-warnings-in-the-eu

	# The value of the property recommendation_panel_msgctxt_prefix:en: is used to find the displayable strings in the .po files:

	# msgctxt "recommendation_eu_tobacco_health_warning_title"
	# msgid "Smoking kills"
	# msgstr "Smoking kills"

	# msgctxt "recommendation_eu_tobacco_health_warning_subtitle"
	# msgid "Tobacco seriously damages health. Don't start or quit now."
	# msgstr "Tobacco seriously damages health. Don't start or quit now."

	# msgctxt "recommendation_eu_tobacco_health_warning_text"
	# msgid "Smoking is highly addictive. Don't start. Smoking kills – quit now. Smoking clogs the arteries and causes heart attacks and strokes. Smoking causes fatal lung cancer. Smoking when pregnant harms your baby. Protect children: don't make them breathe your smoke. Your doctor or your pharmacist can help you stop smoking. Smoking may reduce the blood flow and causes impotence. Smoking causes ageing of the skin. Smoking can damage the sperm and decreases fertility. Smoke contains benzene, nitrosamines, formaldehyde and hydrogen cyanide."
	# msgstr "Smoking is highly addictive. Don't start. Smoking kills – quit now. Smoking clogs the arteries and causes heart attacks and strokes. Smoking causes fatal lung cancer. Smoking when pregnant harms your baby. Protect children: don't make them breathe your smoke. Your doctor or your pharmacist can help you stop smoking. Smoking may reduce the blood flow and causes impotence. Smoking causes ageing of the skin. Smoking can damage the sperm and decreases fertility. Smoke contains benzene, nitrosamines, formaldehyde and hydrogen cyanide."

	# In order to have specific recommendations for specific countries, we can suffix the property name with the country code:
	# recommendation_panel_msgctxt_prefix_fr:en: recommendation_eu_tobacco_health_warning_fr
	# recommendation_panel_source_url_fr:en: https://www.tabac-info-service.fr/
	# recommendation_panel_source_language_fr:en: fr

	my ($recommendation_panel_id, $category_id)
		= get_inherited_property_from_categories_tags($product_ref, "recommendation_panel_id:en");

	if (defined $recommendation_panel_id) {
		# Make sure the recommendation_panel_id contains only alphanumeric characters and underscores
		if ($recommendation_panel_id !~ m/^[a-zA-Z0-9_]+$/) {
			$log->error("Invalid recommendation_panel_id",
				{code => $product_ref->{code}, id => $recommendation_panel_id, category_id => $category_id,});
			return;
		}

		# The properties for the evaluation, icon, msgctxt_prefix, source and source_url can be suffixed by the target country
		# If those properties exist for the target country, we use them instead of the generic ones

		my $panel_data_ref = {};

		foreach my $property (
			qw/recommendation_panel_evaluation recommendation_panel_icon
			recommendation_panel_msgctxt_prefix recommendation_panel_source recommendation_panel_source_language
			recommendation_panel_source_url/
			)
		{
			my ($property_value, $property_category_id)
				= get_inherited_property_from_categories_tags($product_ref, $property . "_" . $target_cc . ":en");
			if (not defined $property_value) {
				($property_value, $property_category_id)
					= get_inherited_property_from_categories_tags($product_ref, $property . ":en");
			}
			if (defined $property_value) {
				my $field = $property;
				$field =~ s/^recommendation_panel_//;

				# The msgctxt_prefix property is used to get the title, subtitle, and text from the .po files
				if ($field eq "msgctxt_prefix") {
					$panel_data_ref->{title} = lang_in_other_lc($target_lc, $property_value . "_title");
					$panel_data_ref->{subtitle} = lang_in_other_lc($target_lc, $property_value . "_subtitle");
					$panel_data_ref->{text} = lang_in_other_lc($target_lc, $property_value . "_text");
				}
				else {
					$panel_data_ref->{$field} = $property_value;
				}
			}
		}

		$log->debug("create recommendation panel - data",
			{code => $product_ref->{code}, id => $recommendation_panel_id, panel_data => $panel_data_ref})
			if $log->is_debug();

		create_panel_from_json_template($recommendation_panel_id,
			"api/knowledge-panels/recommendations/from_taxonomies/" . $recommendation_panel_id . ".tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	}

	# Panels below are legacy harcoded panels. Some of them could be moved to taxonomies at some point and use the logic above.
	# A limitation of the taxonomy based approach is that the format of the recommendation panel is fixed and basic (e.g no images)
	# so we may want to keep some harcoded panels for more complex recommendations.

	# The code below defines the conditions to show recommendations (which recommendation for which product and which user)
	# Those conditions could be implemented at some point in a configuration file, once we have a better idea of usage and the types of conditions.

	# Note: in order to simplify the display logic, we can use the same panel id (e.g. "recommendation_health") for different panels.
	# If there are multiple panels matching with the same id, only the last one will be kept.
	# This can be used for instance if we want to have a default worldwide recommendation, and the more precise or relevant recommendations
	# at the country level.

	# Health

	# Alcohol
	if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {

		create_panel_from_json_template("recommendation_health",
			"api/knowledge-panels/recommendations/health/world/who_alcohol.tt.json",
			{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}

	# France - Santé publique France

	if (($target_cc eq 'fr') and ($target_lc eq 'fr')) {

		# Alcohol

		if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {

			create_panel_from_json_template("recommendation_health",
				"api/knowledge-panels/recommendations/health/fr/spf_alcohol.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}

		# Pulses (légumes secs)

		if (has_tag($product_ref, "categories", "en:pulses")) {

			create_panel_from_json_template("recommendation_health",
				"api/knowledge-panels/recommendations/health/fr/spf_pulses.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}

		# Tobacco

		if (has_tag($product_ref, "categories", "en:tobacco-products")) {

			create_panel_from_json_template("recommendation_health2",
				"api/knowledge-panels/recommendations/health/fr/tabac-info-service.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}
	}

	# NOVA 4 ultra-processed foods
	if ((defined $product_ref->{nova_groups}) and ($product_ref->{nova_groups} eq "4")) {

		create_panel_from_json_template(
			"recommendation_ultra_processed_foods",
			"api/knowledge-panels/recommendations/health/world/ultra_processed_foods.tt.json",
			{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref
		);
	}

	return;
}

=head2 create_nova_panel ( $product_ref, $target_lc, $target_cc, $options_ref, $request_ref)

Creates knowledge panels to describe the NOVA groups / processing / ultra-processing

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_nova_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create nova panel", {code => $product_ref->{code}}) if $log->is_debug();

	my $panel_data_ref = {};

	# Do not display the NOVA panel if it is not applicable
	if (    (feature_enabled("nova"))
		and (exists $product_ref->{nova_groups_tags})
		and (not $product_ref->{nova_groups_tags}[0] eq "not-applicable"))
	{

		$panel_data_ref->{nova_group_tag} = $product_ref->{nova_groups_tags}[0];
		$panel_data_ref->{nova_group_name}
			= display_taxonomy_tag($target_lc, "nova_groups", $product_ref->{nova_groups_tags}[0]);

		# NOVA panel: score + details
		create_panel_from_json_template("nova", "api/knowledge-panels/health/ingredients/nova.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	}
	return;
}

1;
