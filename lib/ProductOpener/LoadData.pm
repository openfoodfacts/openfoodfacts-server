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
use ProductOpener::Tags qw/init_emb_codes init_taxonomies load_knowledge_content/;
use ProductOpener::PackagerCodes qw/init_geocode_addresses init_packager_codes/;
use ProductOpener::Packaging qw/init_packaging_taxonomies_regexps/;
use ProductOpener::ForestFootprint qw/load_forest_footprint_data/;
use ProductOpener::EnvironmentalScore qw(load_agribalyse_data load_environmental_score_data);
use ProductOpener::MainCountries qw(load_scans_data);
use ProductOpener::NutritionCiqual qw(load_ciqual_data);
use ProductOpener::Routing qw(load_routes);
use ProductOpener::CRM qw(init_crm_data);

=head1 FUNCTIONS

=head2 load_data()

loads and initializes data needed by Product Opener.

It needs to be called once at startup:
- in lib/startup_apache2.pl for Apache
- in script files

=cut

sub load_data() {
	# this is only to avoid loading data when we check compilation
	return if ($ENV{PO_NO_LOAD_DATA});

	$log->debug("loading data - start") if $log->is_debug();
	print STDERR "load_data - start\n";

	init_crm_data();    # Die if CRM is configured and, required data cannot be loaded from cache or fetched from CRM
	init_taxonomies(1);    # Die if some taxonomies cannot be loaded
	init_emb_codes();
	init_packager_codes();
	init_geocode_addresses();
	init_packaging_taxonomies_regexps();
	load_scans_data();
	load_routes();
	load_knowledge_content();

	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		load_agribalyse_data();
		load_environmental_score_data();
		load_forest_footprint_data();
		load_ciqual_data();
	}

	$log->debug("loading data - done") if $log->is_debug();
	print STDERR "load_data - done\n";

	return;
}

if ($ENV{PO_EAGER_LOAD_DATA}) {
	# in test we want to be sure to load data eagerly
	load_data();
}

1;
