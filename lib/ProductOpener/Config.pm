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

package ProductOpener::Config;

use utf8;
use Modern::Perl '2017';

# Config.pm will dynamically load Config_off.pm or Config_obf.pm etc.
# based on the value of the PRODUCT_OPENER_FLAVOR_SHORT environment variable

my $flavor = $ENV{PRODUCT_OPENER_FLAVOR_SHORT};

if (not defined $flavor) {
	die("The PRODUCT_OPENER_FLAVOR_SHORT environment variable must be set.");
}

use Module::Load;
autoload("ProductOpener::Config_$flavor");

1;
