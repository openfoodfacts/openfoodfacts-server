#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Lang qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

print STDERR "Build \%Lang - data_root: $data_root\n";


# This script is used a stored Lang.sto file with %Lang that contains:
# - strings from the .po files (loaded by Lang.pm and I18N.pm - Lang::build_lang())
# - English values for all missing values for all languages (done by Lang::build_lang() )
# - HTML code for the select_country_options dropdown $Lang{select_country_options} (generated from countries taxonomy)

# Tags.pm builds the %Languages hash of languages from the languages taxonomy

ProductOpener::Lang::build_lang(\%Languages);

ProductOpener::Tags::init_select_country_options(\%Lang);

# use $server_domain in part of the name so that we have different files
# when 2 instances of Product Opener share the same $data_root
# as is the case with world.openfoodfacts.org and world.preprod.openfoodfacts.org
store("$data_root/Lang.${server_domain}.sto",\%Lang);

exit(0);

