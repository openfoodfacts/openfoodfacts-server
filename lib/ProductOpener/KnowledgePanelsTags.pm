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
use ProductOpener::Tags
	qw(canonicalize_taxonomy_tag display_taxonomy_tag_name get_tag_with_parents get_tag_direct_children cmp_taxonomy_tags_alphabetically);
use ProductOpener::Packaging qw(load_categories_packagings_materials_stats);
use ProductOpener::Stats qw(%categories_stats_per_country);
use ProductOpener::ProductsFeatures qw/feature_enabled/;
use ProductOpener::Display qw/data_to_display_nutrition_table generate_query_cache_key/;
use ProductOpener::Data qw/can_use_off_query execute_aggregate_tags_query/;
use ProductOpener::Cache qw/get_cache_results set_cache_results/;
use ProductOpener::RequestStats qw/set_request_stats_time_start set_request_stats_time_end/;
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
- activate_[panel_id] : create an on demand panel -- currently only for physical_activities and related_categories panels

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

		if ($options_ref->{activate_knowledge_panel_related_categories}) {
			$created
				= create_category_related_categories_panel($tag_ref, $target_lc, $target_cc, $options_ref,
				$canon_tagid, $request_ref);
			push(@panels, $created) if $created;
		}
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

=head2 create_category_related_categories_panel ($tag_ref, $target_lc, $target_cc, $options_ref, $category_id, $request_ref)

Creates a panel listing the parents of the category, and its direct children with their number of products.

The panel is not created if the category has neither parents nor children with products,
or if the product counts could not be retrieved.

=cut

sub create_category_related_categories_panel ($tag_ref, $target_lc, $target_cc, $options_ref, $category_id,
	$request_ref)
{

	my @parents = get_tag_with_parents("categories", $category_id);
	shift @parents;

	my %children = map {$_ => 1} get_tag_direct_children("categories", $category_id);

	my @children = ();
	if (%children) {
		my $counts_ref = get_children_product_counts($category_id, \%children, $request_ref);
		if (not defined $counts_ref) {
			return;
		}
		@children = map {{id => $_, count => $counts_ref->{$_}}} sort {
			($counts_ref->{$b} <=> $counts_ref->{$a})
				|| cmp_taxonomy_tags_alphabetically("categories", $target_lc, $a, $b)
		} keys %{$counts_ref};
	}

	if (not(@parents or @children)) {
		return;
	}

	create_panel_from_json_template(
		"related_categories",
		"api/knowledge-panels/tags/categories/related_categories.tt.json",
		{parents => \@parents, children => \@children},
		$tag_ref, $target_lc, $target_cc, $options_ref, $request_ref
	);

	return "related_categories";
}

sub get_children_product_counts ($category_id, $children_ref, $request_ref) {

	my %match = (categories_tags => $category_id);
	if ((defined $request_ref->{country}) and ($request_ref->{cc} ne 'world')) {
		$match{countries_tags} = $request_ref->{country};
	}

	my $aggregate_parameters = [
		{"\$match" => \%match},
		{"\$unwind" => "\$categories_tags"},
		{"\$group" => {"_id" => "\$categories_tags", "count" => {"\$sum" => 1}}}
	];

	my $key = generate_query_cache_key("related_categories", $aggregate_parameters, $request_ref);
	my $data_debug = '';
	my $counts_ref = get_cache_results($key, \$data_debug);
	if (defined $counts_ref) {
		return $counts_ref;
	}

	my $results;
	if (can_use_off_query(\$data_debug)) {
		set_request_stats_time_start($request_ref->{stats}, "off_query_related_categories");
		$results = eval {execute_aggregate_tags_query($aggregate_parameters)};
		set_request_stats_time_end($request_ref->{stats}, "off_query_related_categories");
	}

	if (ref($results) ne 'ARRAY') {
		$log->warn("related categories: no aggregate results", {category_id => $category_id, error => $@})
			if $log->is_warn();
		return;
	}

	$counts_ref = select_children_counts($results, $children_ref);
	set_cache_results($key, $counts_ref, \$data_debug);

	return $counts_ref;
}

sub select_children_counts ($results_ref, $children_ref) {

	return {map {$_->{_id} => $_->{count}} grep {$children_ref->{$_->{_id}}} @{$results_ref}};
}

1;
