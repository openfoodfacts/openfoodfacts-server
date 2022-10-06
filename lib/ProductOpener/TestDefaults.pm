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

use ProductOpener::PerlStandards;
use Exporter qw/import/;

use Clone qw/clone/;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		%default_product_form
		%admin_user_form
		%default_user_form
		%pro_moderator_user_form

		$test_password
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

=head2 $test_password
The default test password
=cut

$test_password = "testtest";

=head2 %default_user_form
A basic user.
=cut

%default_user_form = (
	email => 'test@test.com',
	userid => "tests",
	name => "Test",
	password => $test_password,
	confirm_password => $test_password,
	pro_checkbox => 0,
	requested_org => "",
	team_1 => "",
	team_2 => "",
	team_3 => "",
	action => "process",
	type => "add"
);

=head2 %admin_user_form
a user which is an admin
=cut

%admin_user_form = (
	%{clone(\%default_user_form)},
	email => 'admin@openfoodfacts.org',
	userid => 'stephane',    # has to be part of %admins
	name => "Admin",
);

=head2 %pro_moderator_user_form
a user which is a producers moderator

NB: must be created by an admin
=cut

%pro_moderator_user_form = (
	%{clone(\%default_user_form)},
	email => 'moderator@openfoodfacts.org',
	userid => 'promoderator',
	name => "Pro Moderator",
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
