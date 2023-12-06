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

package ProductOpener::TestDefaults;

use ProductOpener::PerlStandards;
use Exporter qw/import/;

use Clone qw/clone/;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		%admin_user_form
		%default_org_edit_form
		%default_org_edit_admin_form
		%default_product
		%default_product_form
		%empty_product_form
		%default_user_form
		%moderator_user_form
		%pro_moderator_user_form

		$test_password
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

=head2 $test_password
The default test password
=cut

$test_password = "!!!TestTest1!!!";

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
	preferred_language => "en",
	country => "en:united-states",
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

=head2 %moderator_user_form and %pro_moderator_user_form
a user which is a moderator, or a pro platform moderator

NB: must be created by an admin
=cut

%moderator_user_form = (
	%{clone(\%default_user_form)},
	email => 'moderator@openfoodfacts.org',
	userid => 'moderator',
	name => "Moderator",
);

%pro_moderator_user_form = (
	%{clone(\%default_user_form)},
	email => 'promoderator@openfoodfacts.org',
	userid => 'promoderator',
	name => "Pro Moderator",
);

%default_product = (
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
);

%empty_product_form = (
	action => "process",
	type => "add",
	".submit" => "submit"
);

%default_product_form = (%default_product, %empty_product_form,);

%default_org_edit_form = (
	orgid => "acme-inc",
	action => "process",
	type => "edit",
	name => "Acme Inc.",
	link => "",
	customer_service_name => "",
	customer_service_address => "",
	customer_service_mail => "",
	customer_service_link => "",
	customer_service_phone => "",
	customer_service_info => "",
	commercial_service_name => "",
	commercial_service_address => "",
	commercial_service_mail => "",
	commercial_service_link => "",
	commercial_service_phone => "",
	commercial_service_info => "",
);

%default_org_edit_admin_form = (list_of_gs1_gln => "",);

1;
