# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2021 Association Open Food Facts
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


use Modern::Perl '2017';
use utf8;
use Exporter qw(import);

use ProductOpener::Display qw/:all/;
use ProductOpener::Store qw(:all);
use ProductOpener::Config qw(:all);
use ProductOpener::Tags qw(:all);
use ProductOpener::TagsEntries qw(:all);
use ProductOpener::Users qw(:all);
use ProductOpener::Index qw(:all);
use ProductOpener::Lang qw(:all);
use ProductOpener::Images qw(:all);
use ProductOpener::Food qw(:all);
use ProductOpener::Ingredients qw(:all);
use ProductOpener::Products qw(:all);
use ProductOpener::Missions qw(:all);
use ProductOpener::MissionsConfig qw(:all);
use ProductOpener::URL qw(:all);
use ProductOpener::Data qw(:all);
use ProductOpener::Text qw(:all);
use ProductOpener::Nutriscore qw(:all);
use ProductOpener::Ecoscore qw(:all);
use ProductOpener::Attributes qw(:all);
use ProductOpener::Orgs qw(:all);

use Template;
use Log::Log4perl;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&display_blocks
		&display_my_block
		); #the fucntions which are called outside this file
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;


=head1 FUNCTIONS

=head2 display_blocks( $request_ref )

The sidebar of home page consists of blocks. It displays some of those blocks in the sidebar.

=cut

sub display_blocks($)
{
	my $request_ref = shift;

	my $html = '';
	my $template_data_ref_blocks->{blocks} = $request_ref->{blocks_ref};

	process_template('web/common/includes/display_blocks.tt.html', $template_data_ref_blocks, \$html) || return "template error: " . $tt->error();
	return $html;
}

=head1 FUNCTIONS

=head2 display_my_block ( $request_ref )

The sidebar of home page consists of blocks. This function is used to to display one block.

=cut

sub display_my_block($)
{
	my $blocks_ref = shift;

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
			$template_data_ref_block->{user_pro_moderator} = $User{pro_moderator}; #can be removed after changes in Display.pm get merged
		}
		else {
			$template_data_ref_block->{edited_products_url} = canonicalize_tag_link("editors", get_string_id_for_lang("no_language",$User_id));
			$template_data_ref_block->{created_products_to_be_completed_url} = canonicalize_tag_link("users", get_string_id_for_lang("no_language",$User_id)) . canonicalize_taxonomy_tag_link($lc,"states", "en:to-be-completed")
		}

		process_template('web/common/includes/display_my_block.tt.html', $template_data_ref_block, \$content) || ($content .= 'template error: ' . $tt->error());

		push @{$blocks_ref}, {
			'title'=> lang("hello") . ' ' . $User{name},
			'content'=>$content,
			'id'=>'my_block',
		};
	}

	return;
}

1;