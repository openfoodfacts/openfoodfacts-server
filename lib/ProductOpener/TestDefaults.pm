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

package ProductOpener::TestDefaults;

use utf8;
use Modern::Perl '2017';
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		%default_product_form
		%default_user_form
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

%default_user_form = (
	email => 'test@test.com',
	userid => "tests",
	name => "Test",
	password => "testtest",
	confirm_password => "testtest",
	pro_checkbox => 0,
	requested_org => "",
	team_1 => "",
	team_2 => "",
	team_3 => "",
	action => "process",
	type => "add"
);

%default_product_form = (
	code => '2000000000001',
	lang => "en",
	product_name => "test_default",
	generic_name => "default_name",
	quantity => "100 g",
	link => "http://world.openfoodfacts.org/",
	ingredients_text => "water, test_ingredient",
	origin => "Germany",
	categories => "snacks",
	serving_size => "10 g",
	action => "process",
	type => "add",
	".submit" => "submit"
);

1;
