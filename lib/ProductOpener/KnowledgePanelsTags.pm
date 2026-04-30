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

ProductOpener::KnowledgePanelsContribution - Generate knowledge panels around contribution

=head1 SYNOPSIS

This is a subpart of Knowledge Panels where we concentrate around contribution information

=cut

package ProductOpener::KnowledgePanelsTags;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&create_tag_knowledge_panels
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::KnowledgePanels qw(create_panel_from_json_template);
use ProductOpener::Tags qw(canonicalize_taxonomy_tag display_taxonomy_tag_name);
use ProductOpener::Packaging qw(load_categories_packagings_materials_stats);
use ProductOpener::Stats qw(%categories_stats_per_country);
use ProductOpener::ProductsFeatures qw/feature_enabled/;
use ProductOpener::Display qw/data_to_display_nutrition_table/;
use ProductOpener::Lang qw/lang_in_other_lc/;

use Encode;
use Data::DeepAccess qw(deep_get deep_exists);

=head2 create_tag_knowledge_panels ($tag_ref, $target_lc, $target_cc, $options_ref, $tagtype, $canon_tagid)

Create all knowledge panels for a tag, with strings (descriptions, recommendations etc.)
in a specific language, and return them in an array of panels.

=head3 Arguments

=head4 tag reference $tag_ref

Hash structure for the tag. Can be empty. Will be used to return the panels.

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

=head4 tag type $tagtype

=head4 canonical tagid $canon_tagid

=head3 Return values

Panels are returned in the "knowledge_panels_[$target_lc]" hash of the tag reference
passed as input.

=cut

sub create_tag_knowledge_panels ($tag_ref, $target_lc, $target_cc, $options_ref, $tagtype, $canon_tagid, $request_ref) {

	$log->debug("create knowledge panels for tag",
		{tagtype => $tagtype, tagid => $canon_tagid, target_lc => $target_lc})
		if $log->is_debug();

	# Initialize panels

	$tag_ref->{"knowledge_panels_" . $target_lc} = {};

	my @panels = ();
	if ($tagtype eq "categories") {
		if (feature_enabled("nutrition")) {
			my $created
				= create_category_nutrition_stats_panel($tag_ref, $target_lc, $target_cc, $options_ref, $canon_tagid,
				$request_ref);
			push(@panels, $created) if $created;
		}

		my $created
			= create_category_packagings_materials_panel($tag_ref, $target_lc, $target_cc, $options_ref, $canon_tagid,
			$request_ref);
		push(@panels, $created) if $created;
	}
	if (@panels) {
		my $panel_data_ref = {tags_panels => \@panels};
		# Create the root panel that contains the panels we want to show directly on the tag page
		create_panel_from_json_template("root", "api/knowledge-panels/tags/root.tt.json",
			$panel_data_ref, $tag_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		$log->debug("created tag knowledge panels",
			{tagtype => $tagtype, tagid => $canon_tagid, target_lc => $target_lc, panels => \@panels})
			if $log->is_debug();
	}

	return !!@panels;
}

sub create_category_nutrition_stats_panel ($tag_ref, $target_lc, $target_cc, $options_ref, $category_id, $request_ref) {

	my $created;

	my $categories_stats_ref = $categories_stats_per_country{$request_ref->{cc}};

	$log->debug("checking if this category has stored statistics",
		{cc => $request_ref->{cc}, category_id => $category_id})
		if $log->is_debug();

	if ((defined $categories_stats_ref) and (deep_exists($categories_stats_ref, $category_id, "stats"))) {

		$log->debug(
			"statistics found for the tag, adding stats to description",
			{cc => $request_ref->{cc}, category_id => $category_id}
		) if $log->is_debug();

		my $panel_data_ref
			= data_to_display_nutrition_table($categories_stats_ref->{$category_id}, undef, $request_ref);
		$panel_data_ref->{subtitle} = sprintf(
			lang_in_other_lc($target_lc, "nutrition_data_average"),
			$categories_stats_ref->{$category_id}{n},
			display_taxonomy_tag_name($target_lc, "categories", $category_id),
			$categories_stats_ref->{$category_id}{count}
		);

		create_panel_from_json_template("nutrition_facts_table",
			"api/knowledge-panels/health/nutrition/nutrition_facts_table.tt.json",
			$panel_data_ref, $tag_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		$created = "nutrition_facts_table";
	}
	return $created;
}

=head2 create_category_packagings_materials_panel ($tag_ref, $target_lc, $target_cc, $options_ref, $category_idf, $request_ref)

Creates a knowledge panel to show the packagings materials stats of a category

=head3 Arguments

=head4 category id $category_id

Canonical category id.

=head4 tag reference $tag_ref

Data about the tag, will store the knowledge panel.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_category_packagings_materials_panel ($tag_ref, $target_lc, $target_cc, $options_ref, $category_id,
	$request_ref)
{

	my $created;

	my $categories_packagings_materials_stats_ref = load_categories_packagings_materials_stats();
	my $country = canonicalize_taxonomy_tag("en", "countries", $target_cc);

	$log->debug("create_category_packagings_materials_panel - start",
		{target_lc => $target_lc, target_cc => $target_cc, country => $country, category_id => $category_id})
		if $log->is_debug();

	my $categories_ref
		= deep_get($categories_packagings_materials_stats_ref, "countries", $country, "categories", $category_id);
	if ($categories_ref) {
		my $panel_data_ref = {
			category_id => $category_id,
			materials => $categories_ref->{materials},
		};
		create_panel_from_json_template("packagings_materials",
			"api/knowledge-panels/tags/categories/packagings_materials.tt.json",
			$panel_data_ref, $tag_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		$created = "packagings_materials";
	}

	$log->debug("create_category_packagings_materials_panel - end", {created => $created})
		if $log->is_debug();

	return $created;
}

1;
