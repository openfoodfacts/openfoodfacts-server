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

ProductOpener::LoadData - Load and initialize data

=head1 DESCRIPTION

This module provides a load_data() module that loads and initializes data needed by Product Opener.

=cut

package ProductOpener::LoadData;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&load_data

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Ecoscore qw(:all);
use ProductOpener::MainCountries qw(:all);
use ProductOpener::NutritionCiqual qw(:all);

=head1 FUNCTIONS

=head2 load_data()

loads and initializes data needed by Product Opener.

It needs to be called once at startup:
- in lib/startup_apache2.pl for Apache
- in script files

=cut

sub load_data() {

	$log->debug("loading data - start") if $log->is_debug();

	init_emb_codes();
	init_packager_codes();
	init_geocode_addresses();
	init_packaging_taxonomies_regexps();
	load_scans_data();

	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		load_agribalyse_data();
		load_ecoscore_data();
		load_forest_footprint_data();
		load_ciqual_data();
	}

	$log->debug("loading data - done") if $log->is_debug();

	return;
}

1;
