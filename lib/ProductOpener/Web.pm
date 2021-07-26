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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


package ProductOpener::Web;


use Modern::Perl '2017';
use utf8;
use Exporter qw(import);

use ProductOpener::Display qw/:all/;
use Template;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&display_blocks
		);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

sub display_blocks($)
{
	my $request_ref = shift;

	my $html = '';
	my $template_data_ref_blocks->{blocks} = $request_ref->{blocks_ref};

	process_template('web/common/includes/display_blocks.tt.html', $template_data_ref_blocks, \$html) || return "template error: " . $tt->error();
	return $html;
}

1;