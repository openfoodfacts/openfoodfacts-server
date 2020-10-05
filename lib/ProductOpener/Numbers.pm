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

=head1 NAME

ProductOpener::Numbers - normalize numbers sent as strings in various formats
with different sets of separators for digit grouping and to indicate decimals.

=head1 DESCRIPTION

=cut

package ProductOpener::Numbers;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&remove_insignificant_digits
		&convert_string_to_number

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

=head1 FUNCTIONS

=head2 remove_insignificant_digits($)

Some apps send us nutrient values that they have stored internally as
floating point numbers.

So we get values like:

2.9000000953674
1.6000000238419
0.89999997615814
0.359999990463256
2.5999999046326

On the other hand, when we get values like 2.0, 2.50 or 2.500,
we want to keep the trailing 0s.

The goal is to keep the precision if it makes sense. The tricky part
is that we do not know in advance how many significant digits we can have,
it varies from products to products, and even nutrients to nutrients.

The desired output is thus:

2.9000000953674 -> 2.9
1.6000000238419 -> 1.6
0.89999997615814 -> 0.9
0.359999990463256 -> 0.36
2.5999999046326 -> 2.6
2 -> 2
2.0 -> 2.0
2.000 -> 2.000
2.0001 -> 2
0.0001 -> 0.0001

=cut


sub remove_insignificant_digits($) {

	my $value = shift;
	
	# Make the value a string
	$value .= '';
	
	# Very small values may have been converted to scientific notation
	
	if ($value =~ /\.(\d*?[1-9]\d*?)0{3}/) {
		$value = $`. '.' . $1;
	}
	elsif ($value =~ /([1-9]0*)\.0{3}/) {
		$value = $`. $1;
	}
	elsif ($value =~ /\.(\d*)([0-8]+)9999/) {
		$value = $`. '.' . $1 . ($2 + 1);
	}
	elsif ($value =~ /\.9999/) {
		$value = $` + 1;
	}
	return $value;
}


=head2 convert_string_to_number($)

Try to convert a number represented as a string to the actual number,
by guessing which characters (spaces, commas, dots) are used as
digit grouping separators or used to indicate decimals.

=cut

sub convert_string_to_number($) {
	
	my $value = shift;
	
	$value =~ s/(\d) (\d)/$1$2/g;
	
	# In some languages like French, a comma is used instead of a dot to indicate decimals
	# If we have 1 and only 1 comma, and no dot, change the comma to a dot
	if (($value !~ /\./) and ($value !~ /,.*,/)) {
		$value =~ s/,/\./;
	}
	# Number sent by a Spanish producer: 3,697,00 -> 3697
	# consider the last comma is the decimal separator if we have exactly 2 digits after
	elsif ($value =~ /,\d\d$/) {
		$value =~ s/,(\d\d)$/.$1/;
	}
	# Remove remaining commas that can be used as separators
	$value =~ s/,//g;
	$value += 0;
	
	return $value;
}


1;

