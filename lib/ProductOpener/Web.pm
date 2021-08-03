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
		&display_login_register
		&display_blocks
		);
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

=head2 display_login_register( $blocks_ref )

This function displays the sign in block in the sidebar.

=cut

sub display_login_register($)
{
	my $blocks_ref = shift;

	if (not defined $User_id) {

		my $content = '';
		my $template_data_ref_login = {};

		process_template('web/common/includes/display_login_register.tt.html', $template_data_ref_login, \$content) || ($content .= 'template error: ' . $tt->error());

		push @{$blocks_ref}, {
			'title'=>lang("login_register_title"),
			'content'=>$content,
		};
	}

	return;
}

1;