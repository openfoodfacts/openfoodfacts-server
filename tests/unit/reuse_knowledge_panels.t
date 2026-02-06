#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::KnowledgePanels qw/create_reuse_card_panel/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Config qw/:all/;

# Save original options to restore at the end
my %saved_options;
BEGIN {
	# Save current product_type setting
	$saved_options{product_type} = $ProductOpener::Config::options{product_type};
	
	# Set product_type to "product" for Open Products Facts taxonomy
	$ProductOpener::Config::options{product_type} = 'product';
}

# Load data with the product taxonomy
load_data();

# Test 1: Panel should be created for French user with QFDMO category
{
	my $product_ref = {
		lc => "fr",
		categories => "en:dog-houses",
		categories_tags => ["en:dog-houses"],
		categories_hierarchy => ["en:dog-houses"],
	};
	
	my $result = create_reuse_card_panel($product_ref, 'fr', 'fr', {product_type => 'product'}, {});
	is($result, 1, 'Panel created for French user with QFDMO category (dog-houses)');
	ok(exists $product_ref->{knowledge_panels_fr}, 'knowledge_panels_fr exists');
	ok(exists $product_ref->{knowledge_panels_fr}{reuse_card}, 'reuse_card panel exists');
	ok(exists $product_ref->{knowledge_panels_fr}{qfdmo_solutions}, 'qfdmo_solutions panel exists');
}

# Test 2: Panel should NOT be created for product without QFDMO category
{
	my $product_ref = {
		lc => "fr",
		categories => "en:chairs",
		categories_tags => ["en:chairs"],
		categories_hierarchy => ["en:chairs"],
	};
	
	my $result = create_reuse_card_panel($product_ref, 'fr', 'fr', {product_type => 'product'}, {});
	is($result, 0, 'Panel not created for product without QFDMO category');
}

# Test 3: Panel should NOT be created for user outside France
{
	my $product_ref = {
		lc => "en",
		categories => "en:dog-houses",
		categories_tags => ["en:dog-houses"],
		categories_hierarchy => ["en:dog-houses"],
	};
	
	my $result = create_reuse_card_panel($product_ref, 'en', 'en', {product_type => 'product'}, {});
	is($result, 0, 'Panel not created for user outside France (cc=en)');
}

# Test 4: Panel should NOT be created for food products
{
	my $product_ref = {
		lc => "fr",
		categories => "en:dog-houses",
		categories_tags => ["en:dog-houses"],
		categories_hierarchy => ["en:dog-houses"],
	};
	
	my $result = create_reuse_card_panel($product_ref, 'fr', 'fr', {product_type => 'food'}, {});
	is($result, 0, 'Panel not created for food products (product_type=food)');
}

# Restore original options using END block to ensure it runs even on test failure
END {
	$ProductOpener::Config::options{product_type} = $saved_options{product_type} if defined $saved_options{product_type};
}

done_testing();

