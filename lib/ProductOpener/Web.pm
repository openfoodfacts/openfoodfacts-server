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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Web - contains display functions for the website.

=head1 SYNOPSIS

C<ProductOpener::Web> consists of functions used only in OpenFoodFacts website for different tasks.

=head1 DESCRIPTION

The module implements the functions that are being used by the OpenFoodFacts website.
This module consists of different functions for displaying the different parts of home page, creating and saving products, etc

=cut

package ProductOpener::Web;

use ProductOpener::PerlStandards;
use Exporter qw(import);

use ProductOpener::Store qw(:all);
use ProductOpener::Display qw(:all);
use ProductOpener::Config qw(:all);
use ProductOpener::Tags qw(:all);
use ProductOpener::Users qw(:all);
use ProductOpener::Orgs qw(:all);
use ProductOpener::Lang qw(:all);
use ProductOpener::Images qw(:all);

use Template;
use Log::Log4perl;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&display_login_register
		&display_blocks
		&display_my_block
		&display_field
		&display_data_quality_issues_and_improvement_opportunities
		&display_data_quality_description
		&display_knowledge_panel
		&get_languages_options_list
	);    #the fucntions which are called outside this file
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

=head1 FUNCTIONS

# TODO: 2022/10/12 - in the new website design, we removed the side column where we displayed blocks
# Those blocks need to be migrated to the new design (if we want to keep them)
# and the corresponding code needs to be removed

=head2 display_blocks( $request_ref )

The sidebar of home page consists of blocks. It displays some of those blocks in the sidebar.

=cut

sub display_blocks ($request_ref) {
	my $html = '';
	my $template_data_ref_blocks->{blocks} = $request_ref->{blocks_ref};

	process_template('web/common/includes/display_blocks.tt.html', $template_data_ref_blocks, \$html)
		|| return "template error: " . $tt->error();
	return $html;
}

=head2 display_my_block ( $blocks_ref )

The sidebar of home page consists of blocks. This function is used to to display one block with information and links related to the logged in user.

=cut

sub display_my_block ($blocks_ref) {

	if (defined $User_id) {

		my $content = '';
		my $template_data_ref_block = {};

		$template_data_ref_block->{org_name} = $Org{name};
		$template_data_ref_block->{server_options_private_products} = $server_options{private_products};

		if ((defined $server_options{private_products}) and ($server_options{private_products})) {

			my $pro_moderator_message;

			if (defined $User{pro_moderator_owner}) {
				$pro_moderator_message = sprintf(lang("pro_moderator_owner_set"), $User{pro_moderator_owner});
			}
			else {
				$pro_moderator_message = lang("pro_moderator_owner_not_set");
			}

			$template_data_ref_block->{pro_moderator_message} = $pro_moderator_message;
			$template_data_ref_block->{user_pro_moderator}
				= $User{pro_moderator};    #can be removed after changes in Display.pm get merged
		}
		else {
			$template_data_ref_block->{edited_products_url}
				= canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $User_id));
			$template_data_ref_block->{created_products_to_be_completed_url}
				= canonicalize_tag_link("users", get_string_id_for_lang("no_language", $User_id))
				. canonicalize_taxonomy_tag_link($lc, "states", "en:to-be-completed");
		}

		process_template('web/common/includes/display_my_block.tt.html', $template_data_ref_block, \$content)
			|| ($content .= 'template error: ' . $tt->error());

		push @{$blocks_ref},
			{
			'title' => lang("hello") . ' ' . $User{name},
			'content' => $content,
			'id' => 'my_block',
			};
	}

	return;
}

=head2 display_login_register( $blocks_ref )

This function displays the sign in block in the sidebar.

=cut

sub display_login_register ($blocks_ref) {
	if (not defined $User_id) {

		my $content = '';
		my $template_data_ref_login = {};

		process_template('web/common/includes/display_login_register.tt.html', $template_data_ref_login, \$content)
			|| ($content .= 'template error: ' . $tt->error());

		push @{$blocks_ref}, {
			'title' => lang("login_register_title"),
			'content' => $content,

		};
	}

	return;
}

=head2 display_field ( $product_ref, $field )

This function is used to display the one characteristic in the product's characteristics section on the product page.

=cut

# itemprop="description"
my %itemprops = (
	"generic_name" => "description",
	"brands" => "brand",
);

sub display_field ($product_ref, $field) {

	my $html = '';
	my $template_data_ref_field = {};

	$template_data_ref_field->{field} = $field;

	if ($field eq 'br') {
		process_template('web/common/includes/display_field_br.tt.html', $template_data_ref_field, \$html)
			|| return "template error: " . $tt->error();
	}

	# We will split the states field in 2 different fields: "to do" fields and "done" fields
	elsif ($field eq 'states') {

		my %states = (
			to_do => [],
			done => [],
		);
		my $state_items = $product_ref->{$field . "_hierarchy"};
		foreach my $val (@{$state_items}) {
			if (index($val, 'empty') != -1 or $val =~ /(en:|-)to-be-/sxmn) {
				push(@{$states{to_do}}, $val);
			}
			else {
				push(@{$states{done}}, $val);
			}
		}

		foreach my $status ('done', 'to_do') {
			$template_data_ref_field->{field} = $status;
			$template_data_ref_field->{name} = lang($status . "_status");
			$template_data_ref_field->{value} = display_tags_hierarchy_taxonomy($lc, $field, $states{$status});
			if ($template_data_ref_field->{value} ne "") {
				my $html_status = '';
				process_template('web/common/includes/display_field.tt.html', $template_data_ref_field, \$html_status)
					|| return "template error: " . $tt->error();
				$html .= $html_status;
			}
		}
	}

	else {

		my $value = $product_ref->{$field};

		# fields in %language_fields can have different values by language

		if (defined $language_fields{$field}) {
			if ((defined $product_ref->{$field . "_" . $lc}) and ($product_ref->{$field . "_" . $lc} ne '')) {
				$value = $product_ref->{$field . "_" . $lc};
				$value =~ s/\n/<br>/g;
			}
		}
		elsif (defined $taxonomy_fields{$field}) {
			$value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
		}
		elsif ((defined $tags_fields{$field}) and (defined $value)) {
			$value = display_tags_list($field, $value);
		}

		if ((defined $value) and ($value ne '')) {
			# See https://stackoverflow.com/a/3809435
			if (
					($field eq 'link')
				and ($value =~ /[-a-zA-Z0-9\@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()\@:%_\+.~#?&\/\/=]*)/)
				)
			{
				if ($value !~ /https?:\/\//) {
					$value = 'http://' . $value;
				}
				my $link = $value;
				$link =~ s/"|<|>|'//g;
				my $link2 = $link;
				$link2 =~ s/^(.{40}).*$/$1\.\.\./;
				$value = "<a href=\"$link\">$link2</a>";
			}
			my $itemprop = '';
			if (defined $itemprops{$field}) {
				$itemprop = " itemprop=\"$itemprops{$field}\"";
				if ($value =~ /<a /) {
					$value =~ s/<a /<a$itemprop /g;
				}
				else {
					$value = "<span$itemprop>$value</span>";
				}
			}
			my $name = lang($field);
			if ($name eq '') {
				$name = ucfirst(lang($field . "_p"));
			}

			$template_data_ref_field->{name} = $name;
			$template_data_ref_field->{value} = $value;
			process_template('web/common/includes/display_field.tt.html', $template_data_ref_field, \$html)
				|| return "template error: " . $tt->error();
		}
	}

	return $html;
}

=head2 display_data_quality_issues_and_improvement_opportunities( $product_ref )

Display on the product page a list of data quality issues, and of improvement opportunities.
This is for the platform for producers.

=cut

sub display_data_quality_issues_and_improvement_opportunities ($product_ref) {

	my $html = "";
	my $template_data_ref_quality_issues = {};
	my @tagtypes;

	foreach my $tagtype ("data_quality_errors_producers", "data_quality_warnings_producers", "improvements") {

		my $tagtype_ref = {};

		if ((defined $product_ref->{$tagtype . "_tags"}) and (scalar @{$product_ref->{$tagtype . "_tags"}} > 0)) {

			$tagtype_ref->{tagtype_heading} = ucfirst(lang($tagtype . "_p"));
			my @tagids;
			my $description = '';

			foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {

				if ($tagtype =~ /^data_quality/) {
					$description = display_data_quality_description($product_ref, $tagid);
				}
				elsif ($tagtype eq "improvements") {
					$description = display_possible_improvement_description($product_ref, $tagid);
				}

				push(
					@tagids,
					{
						display_taxonomy_tag => display_taxonomy_tag($lc, $tagtype, $tagid),
						properties => $properties{$tagtype}{$tagid}{"description:$lc"},
						description => $description,
					}
				);

			}

			$tagtype_ref->{tagids} = \@tagids;
			push(@tagtypes, $tagtype_ref);
		}
	}

	$template_data_ref_quality_issues->{tagtypes} = \@tagtypes;
	process_template('web/common/includes/display_data_quality_issues_and_improvement_opportunities.tt.html',
		$template_data_ref_quality_issues, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

=head2 display_data_quality_description( $product_ref, $tagid )

Display an explanation of the data quality warning or error, using specific product data related to the warning.

=cut

sub display_data_quality_description ($product_ref, $tagid) {

	my $html = "";
	my $template_data_ref_quality = {};

	$template_data_ref_quality->{tagid} = $tagid;
	$template_data_ref_quality->{product_ref_nutriscore_score} = $product_ref->{nutriscore_score};
	$template_data_ref_quality->{product_ref_nutriscore_score_producer} = $product_ref->{nutriscore_score_producer};
	$template_data_ref_quality->{product_ref_nutriscore_grade_producer} = uc($product_ref->{nutriscore_grade_producer});
	$template_data_ref_quality->{product_ref_nutriscore_grade} = uc($product_ref->{nutriscore_grade});

	process_template('web/common/includes/display_data_quality_description.tt.html', $template_data_ref_quality, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

=head2 display_knowledge_panel( $product_ref, $panels_ref, $panel_id )

Generate HTML code corresponding to a specific panel.

The code is generated by the web/panels/panel.tt.html template.

=cut

sub display_knowledge_panel ($product_ref, $panels_ref, $panel_id) {

	my $html = '';

	my $template_data_ref = {
		product => $product_ref,
		panels => $panels_ref,
		panel_id => $panel_id,
	};

	process_template('web/panels/panel.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();
	return $html;
}

=head2 get_languages_options_list( $target_lc )

Generates a data structure containing the list of languages and their translation in a target language.
The data structured can be passed to HTML templates to construction a list of options for a select element.

=cut

sub get_languages_options_list ($target_lc) {

	my @lang_options = ();

	my %lang_labels = ();
	foreach my $l (@Langs) {
		$lang_labels{$l} = display_taxonomy_tag($target_lc, 'languages', $language_codes{$l});
	}

	my @lang_values = sort {$lang_labels{$a} cmp $lang_labels{$b}} @Langs;

	foreach my $l (@lang_values) {

		push(
			@lang_options,
			{
				value => $l,
				label => $lang_labels{$l},
			}
		);
	}

	return \@lang_options;
}

1;
