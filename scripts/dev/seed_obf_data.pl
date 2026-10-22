#!/usr/bin/perl

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
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

use utf8;
use Modern::Perl '2017';
use open ':std', ':encoding(UTF-8)';

use ProductOpener::Config qw/:all/;
use ProductOpener::Products qw/init_product store_product analyze_and_enrich_product_data retrieve_product/;
use ProductOpener::ProductsTags qw/set_field_input_tags_for_source/;
use ProductOpener::BeautyProducts qw/specific_processes_for_beauty_product/;

my @sample_products = (
	{
		code => "3600523712345",
		product_name => "Gentle Hydrating Shampoo",
		product_name_en => "Gentle Hydrating Shampoo",
		product_name_fr => "Shampooing Hydratant Doux",
		product_type => "beauty",
		brands => "Garnier",
		categories => "en:shampoos,en:hair-care",
		ingredients_text => "Aqua, Sodium Laureth Sulfate, Cocamidopropyl Betaine, Glycerin, Parfum, Citric Acid.",
		quantity => "250 ml",
		countries => "en:france",
	},
	{
		code => "3337871321234",
		product_name => "Soothing Moisturizing Cream",
		product_name_en => "Soothing Moisturizing Cream",
		product_name_fr => "Crème Hydratante Apaisante",
		product_type => "beauty",
		brands => "La Roche-Posay",
		categories => "en:body-creams,en:moisturizers",
		ingredients_text => "Aqua, Glycerin, Dimethicone, Hydrogenated Polyisobutene, Cetearyl Alcohol, Niacinamide.",
		quantity => "200 ml",
		countries => "en:france",
	},
	{
		code => "8001090123456",
		product_name => "Complete Protection Toothpaste",
		product_name_en => "Complete Protection Toothpaste",
		product_name_fr => "Dentifrice Protection Complète",
		product_type => "beauty",
		brands => "Oral-B",
		categories => "en:toothpastes,en:oral-care",
		ingredients_text => "Aqua, Sorbitol, Hydrated Silica, Sodium Lauryl Sulfate, Aroma, Sodium Fluoride.",
		quantity => "75 ml",
		countries => "en:france",
	},
	{
		code => "3052503123456",
		product_name => "Nourishing Lip Balm",
		product_name_en => "Nourishing Lip Balm",
		product_name_fr => "Baume à Lèvres Nourrissant",
		product_type => "beauty",
		brands => "Dove",
		categories => "en:lip-balms,en:lip-care",
		ingredients_text =>
			"Octyldodecanol, Ricinus Communis Seed Oil, Cera Alba, Butyrospermum Parkii Butter, Tocopherol.",
		quantity => "4.8 g",
		countries => "en:france",
	},
);

say "🥫 Seeding sample OBF cosmetic products into MongoDB...";
for my $p (@sample_products) {
	my $code = $p->{code};
	if (defined retrieve_product($code, 1)) {
		say "  -> Product $code already exists, skipping...";
		next;
	}
	say "  -> Seeding product $code ($p->{product_name})...";
	my $product_ref = init_product("off-dev", "org-none", $code, "world");
	for my $k (keys %$p) {
		$product_ref->{$k} = $p->{$k};
	}

	# Canonicalize tag fields using standard tags pipeline
	for my $tag_field (qw(categories brands countries)) {
		if (defined $p->{$tag_field} && $p->{$tag_field} ne '') {
			set_field_input_tags_for_source($product_ref, "en", $tag_field, "off-dev", $p->{$tag_field});
		}
	}

	# Run beauty-specific processing (ingredient parsing and extraction)
	specific_processes_for_beauty_product($product_ref);

	# Run standard enrichment and analysis pipeline
	analyze_and_enrich_product_data($product_ref, {});

	store_product("off-dev", $product_ref, "Seed sample OBF data");
}
say "🥫 Sample OBF products seeded successfully.";
