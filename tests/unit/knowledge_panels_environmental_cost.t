#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::EnvironmentalImpact qw/format_ecs_value/;
use ProductOpener::LoadData qw/load_data/;
use Scalar::Util qw/looks_like_number/;

load_data();

# Rounding: 1 decimal below 100, no decimals from 100
is(format_ecs_value(3.67526), "3.7");
is(format_ecs_value(99.94), "99.9");
is(format_ecs_value(99.96), "100");
is(format_ecs_value(452.694), "453");
is(format_ecs_value("null"), "");
is(format_ecs_value(undef), "");

# Product with an Ecobalyse result for a reference quantity of product
sub product_with_ecs (%args) {
	my $reference_quantity = $args{reference_quantity} // 500;
	my $unit = $args{unit} // "g";
	my $source = $args{source} // "product_quantity";
	my $ecs = exists $args{ecs} ? $args{ecs} : 200;
	return {
		code => "1234567890123",
		lc => "en",
		quantity => $args{quantity} // "500 g",
		environmental_impact => {
			($source ne "default" ? (ecs_per_product => $ecs) : ()),
			ecs_per_100g_or_100ml => (looks_like_number($ecs) ? $ecs * 100 / $reference_quantity : $ecs),
			ecs_per => "100$unit",
			ecobalyse_input => {
				reference_quantity => $reference_quantity,
				reference_quantity_unit => $unit,
				reference_quantity_source => $source,
			},
			ecobalyse_response => {
				# no preparation value in the results
				results => {
					recipe => {ingredientsTotal => {ecs => 100}, transform => {ecs => 20}},
					packaging => {ecs => 40},
					transports => {impacts => {ecs => 40}},
					distribution => {total => {ecs => "null"}},    # invalid value from the API
					total => {ecs => $ecs},
				}
			}
		}
	};
}

sub get_panel ($product_ref, $options_ref) {
	ProductOpener::KnowledgePanels::create_environmental_cost_panel($product_ref, "en", "fr", $options_ref, {});
	return $product_ref->{knowledge_panels_en}{environmental_cost};
}

# Returns a hash of the table rows: label => [values]
sub get_rows ($panel_ref) {
	my ($table_ref) = grep {$_->{element_type} eq "table"} @{$panel_ref->{elements}};
	return {
		map {
			$_->{values}[0]{text} => [map {$_->{text}} @{$_->{values}}[1 .. $#{$_->{values}}]]
		} @{$table_ref->{table_element}{rows}}
	};
}

# Not shown to regular users
is(get_panel(product_with_ecs(), {}), undef, "panel not shown to regular users");

# Shown to moderators and admins
foreach my $role (qw(moderator admin)) {
	ok(defined get_panel(product_with_ecs(), {$role => 1}), "panel shown to $role");
}

# Known product quantity: values for the whole product and for 100 g
my $panel_ref = get_panel(product_with_ecs(), {moderator => 1});
is(
	$panel_ref->{title_element}{subtitle},
	"200 points for the product (500 g) - 40.0 points for 100 g",
	"subtitle with values for the product and for 100 g"
);
is(
	get_rows($panel_ref),
	{
		Ingredients => ["100", "20.0"],
		Processing => ["20.0", "4.0"],
		Packaging => ["40.0", "8.0"],
		Transport => ["40.0", "8.0"],
		Distribution => ["", ""],    # non numeric value from the API
		Preparation => ["0.0", "0.0"],    # missing value
		Total => ["200", "40.0"],
	},
	"breakdown values for the product and for 100 g"
);

# Product sold by volume: values for 100 ml, product quantity as entered
$panel_ref = get_panel(product_with_ecs(reference_quantity => 750, unit => "ml", quantity => "0.75 l", ecs => 150),
	{moderator => 1});
is(
	$panel_ref->{title_element}{subtitle},
	"150 points for the product (0.75 l) - 20.0 points for 100 ml",
	"subtitle with values for the product and for 100 ml"
);

# No product quantity: values for 100 g only
$panel_ref = get_panel(product_with_ecs(source => "default", reference_quantity => 100, ecs => 50), {moderator => 1});
is($panel_ref->{title_element}{subtitle}, "50.0 points for 100 g", "subtitle with values for 100 g only");
is(get_rows($panel_ref)->{Total}, ["50.0"], "breakdown values for 100 g only");

# No panel if the ECS is missing or not a number
is(get_panel(product_with_ecs(ecs => undef), {moderator => 1}), undef, "no panel without ECS");
is(get_panel(product_with_ecs(ecs => "null"), {moderator => 1}), undef, "no panel with non numeric ECS");

done_testing();
