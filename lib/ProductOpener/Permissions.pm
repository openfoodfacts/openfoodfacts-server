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

ProductOpener::Permissions - defines user permissions and provide a has_permission function to check them

=head1 DESCRIPTION


=cut

package ProductOpener::Permissions;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&has_permission
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;

=head2 is_admin_or_moderator ($request_ref)

Check if the user is an admin or moderator.

=cut

sub is_admin_or_moderator ($request_ref) {

	return ($request_ref->{admin} or $request_ref->{moderator});

}

=head2 has_permission_product_revert ($request_ref)

Check if the user has permission to revert a product.

True for moderators, admins, and logged in users of the pro platform.

=cut

sub has_permission_product_revert ($request_ref) {

	return ($request_ref->{admin} or $request_ref->{moderator} or $request_ref->{owner_id});
}

# Map permissions string_id to functions to check if the user has the permission
my %permissions = (
	"product_revert" => \&has_permission_product_revert,
	"product_change_code" => \&is_admin_or_moderator,
	"product_change_product_type" => \&is_admin_or_moderator,
);

=head2 has_permission ($request_ref, $permission)

Check if the user has a specific permission.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head4 $permission (input)

Permission to check.

=head3 Return value

1 if the user has the permission, 0 otherwise.

=cut

sub has_permission ($request_ref, $permission) {

	# Check if the user has permission
	my $has_permission = 0;

	if (defined $permissions{$permission}) {
		$has_permission = $permissions{$permission}->($request_ref);
	}
	else {
		$log->error("has_permission - unknown permission", {permission => $permission}) if $log->is_error();
	}

	return $has_permission;
}

1;
