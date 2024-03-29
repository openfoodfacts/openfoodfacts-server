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

ProductOpener::Response - builder for the HTTP response

=cut

package ProductOpener::Response;
use ProductOpener::PerlStandards;




sub new ($class) {

	my $self = bless {}, $class;

	$self->{styles} = '';
	$self->{scripts} = '';
	$self->{initjs} = '';
	$self->{header} = '';
	$self->{bodyabout} = '';
	$self->{admin} = 0;





	$self->set_header(Server => "Product Opener");
	# temporarily remove X-Frame-Options: DENY, needed for graphs - 2023/11/23
	#$self->set_header("X-Frame-Options" => "DENY");
	$self->set_header("X-Content-Type-Options" => "nosniff");
	$self->set_header("X-Download-Options" => "noopen");
	$self->set_header("X-XSS-Protection" => "1; mode=block");
	$self->set_header("X-Request-ID" => $log->context->{request});




	return $self;
}



sub set_header($self, $header, $value) {
	die "TODO";
}



1;

