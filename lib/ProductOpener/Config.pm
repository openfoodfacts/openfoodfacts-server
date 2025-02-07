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

# %options will be redefined by autoload below
# but we need it to avoid Perl complaining
%ProductOpener::Config:: % options = ();

use Module::Load;

autoload("ProductOpener::Config_$flavor");

# Add values common to all flavors

# define the normalization applied to change a string to a tag id (in particular for taxonomies)
# tag ids are also used in URLs.

# unaccent:
# - useful when accents are sometimes ommited (e.g. in French accents are often not present on capital letters),
# either in print, or when typed by users.
# - dangerous if different words (in the same context like ingredients or category names) have the same unaccented form
# lowercase:
# - useful when the same word appears in lowercase, with a first capital letter, or in all caps.

# IMPORTANT: if you change it, you need to change $BUILD_TAGS_VERSION in Tags.pm

%ProductOpener::Config::string_normalization_for_lang = (
	# no_language is used for strings that are not in a specific language (e.g. user names)
	no_language => {
		unaccent => 1,
		lowercase => 1,
	},
	# default is used for languages that do not have specified values
	default => {
		unaccent => 0,
		lowercase => 1,
	},
	# German umlauts should not be converted (e.g. ä -> ae) as there are many conflicts
	de => {
		unaccent => 0,
		lowercase => 1,
	},
	# French has very few actual conflicts caused by unaccenting (one counter example is "pâtes" and "pâtés")
	# Accents or often not present in capital letters (beginning of word, or in all caps text).
	fr => {
		unaccent => 1,
		lowercase => 1,
	},
	# Same for Spanish, Italian and Portuguese
	ca => {
		unaccent => 1,
		lowercase => 1,
	},
	es => {
		unaccent => 1,
		lowercase => 1,
	},
	it => {
		unaccent => 1,
		lowercase => 1,
	},
	nl => {
		unaccent => 1,
		lowercase => 1,
	},
	pt => {
		unaccent => 1,
		lowercase => 1,
	},
	sk => {
		unaccent => 1,
		lowercase => 1,
	},
	# English has very few accented words, and they are very often not accented by users or in ingredients lists etc.
	en => {
		unaccent => 1,
		lowercase => 1,
	},
	# xx: language less entries, also deaccent
	xx => {
		unaccent => 1,
		lowercase => 1,
	},
);

%ProductOpener::Config::admins = map {$_ => 1} qw(
	alex-off
	cha-delh
	charlesnepote
	gala-nafikova
	hangy
	manoncorneille
	raphael0202
	stephane
	tacinte
	teolemon
	g123k
	valimp
);

=head2 Available product types and flavors

=cut

$ProductOpener::Config::options{product_types} = [qw(food petfood beauty product)];
$ProductOpener::Config::options{product_types_flavors} = {
	food => "off",
	petfood => "opff",
	beauty => "obf",
	product => "opf"
};

$ProductOpener::Config::options{flavors_product_types}
	= {reverse %{$ProductOpener::Config::options{product_types_flavors}}};

$ProductOpener::Config::options{product_types_domains} = {
	food => "openfoodfacts.org",
	petfood => "openpetfoodfacts.org",
	beauty => "openbeautyfacts.org",
	product => "openproductsfacts.org"
};

$ProductOpener::Config::options{other_servers} = {
	obf => {
		name => "Open Beauty Facts",
		mongodb => "obf",
		domain => "openbeautyfacts.org",
	},
	off => {
		name => "Open Food Facts",
		mongodb => "off",
		domain => "openfoodfacts.org",
	},
	opf => {
		name => "Open Products Facts",
		mongodb => "opf",
		domain => "openproductsfacts.org",
	},
	opff => {
		name => "Open Pet Food Facts",
		mongodb => "opff",
		domain => "openpetfoodfacts.org",
	},
	'off-pro' => {
		name => "Open Food Facts Pro",
		mongodb => "off-pro",
		domain => "pro.openfoodfacts.org",
	}
};

=head2 Rate limiting options

=cut

# Number of requests per minutes for the search API
$ProductOpener::Config::options{rate_limit_search} = 10;
# Number of requests per minutes for all facets for anonymous users
$ProductOpener::Config::options{rate_limit_facet_products_unregistered} = 5;
# Number of requests per minutes for facets for registered users
$ProductOpener::Config::options{rate_limit_facet_products_registered} = 10;
# Number of requests per minutes for facets for bots
$ProductOpener::Config::options{rate_limit_facet_products_crawl_bot} = 10;
# Number of requests per minutes for facet tags (list of tags with count) for anonymous users
$ProductOpener::Config::options{rate_limit_facet_tags_unregistered} = 5;
$ProductOpener::Config::options{rate_limit_facet_tags_registered} = 10;
$ProductOpener::Config::options{rate_limit_facet_tags_crawl_bot} = 10;
$ProductOpener::Config::options{rate_limit_product} = 100;

# Rate limit allow list
$ProductOpener::Config::options{rate_limit_allow_list} = {
	'146.59.148.140' => 1,    # OVH1
	'51.210.154.203' => 1,    # OVH2
	'51.210.32.79' => 1,    # OVH3
	'46.105.72.120' => 1,    # proxy ovh1
	'213.36.253.215' => 1,    # proxy off1
	'213.36.253.214' => 1,    # proxy off2
	'213.36.253.206' => 1,    # off1
	'213.36.253.208' => 1,    # off2
	'45.147.209.254' => 1,    # Moji server (actually OSM proxy, Moji only has ipv6)
};

1;
