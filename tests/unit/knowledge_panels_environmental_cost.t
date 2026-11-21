#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::EnvironmentalImpact qw/format_ecs_value get_environmental_cost_label_path/;
use ProductOpener::LoadData qw/load_data/;
use Scalar::Util qw/looks_like_number/;

load_data();

# Rounding to integers, as on the label image
is(format_ecs_value(3.67526), "4");
is(format_ecs_value(99.94), "100");
is(format_ecs_value(452.694), "453");
is(format_ecs_value(0.2), "0");
is(format_ecs_value(-0.2), "0", "no negative zero");
is(format_ecs_value("null"), "");
is(format_ecs_value(undef), "");

# Path of the label image: both values rounded, from 0 to 99999
is(get_environmental_cost_label_path(359.6, 153.5, "g"), "/images/environmental-cost/v1/360-154-g.svg");
is(get_environmental_cost_label_path(0.2, 0.04, "ml"), "/images/environmental-cost/v1/0-0-ml.svg");
is(get_environmental_cost_label_path(99999.4, 12345, "g"), "/images/environmental-cost/v1/99999-12345-g.svg");
is(get_environmental_cost_label_path(99999.5, 12345, "g"), undef, "more than 5 digits");
is(get_environmental_cost_label_path(-1, 12, "g"), undef, "negative value");
is(get_environmental_cost_label_path(undef, 12, "g"), undef, "missing value");
is(get_environmental_cost_label_path("null", 12, "g"), undef, "non numeric value");
is(get_environmental_cost_label_path(100, 12, "kg"), undef, "unknown unit");

# Product with an Ecobalyse food2 result for a reference quantity of product
sub product_with_ecs (%args) {
	my $reference_quantity = $args{reference_quantity} // 500;
	my $unit = $args{unit} // "g";
	my $source = $args{source} // "product_quantity";
	my $ecs = exists $args{ecs} ? $args{ecs} : 200;
	my $complements = $args{complements} // -20;
	my @ingredients = @{
		$args{ingredients} // [
			# name, mass, ecs, complements
			["sugar", 300, 40, 0],
			["beef", 100, 75, $complements],
			["water", 150, 5, 0],
		]
	};
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
				ingredients =>
					[map {{name => $_->[0], ecobalyse_name => "Ecobalyse $_->[0]", mass => $_->[1]}} @ingredients],
				ingredients_total_mass => $args{ingredients_total_mass} // $reference_quantity,
			},
			ecobalyse_response => {
				score => {ecs => $ecs, complements => $complements},
				# no usage value in the results
				stages => {
					materials => 100,
					transform => 20,
					packaging => 40,
					transports => 60,
					distribution => "null",    # invalid value from the API
				},
				complements => {hedges => $complements / 2, plotSize => $complements / 2},
				composition => [
					map {{name => $_->[0], mass => $_->[1] / 1000, score => {ecs => $_->[2], complements => $_->[3]}}}
						@ingredients
				],
			}
		}
	};
}

sub get_panel ($product_ref, $options_ref, $panel_id = "environmental_cost") {
	ProductOpener::KnowledgePanels::create_environmental_cost_panel($product_ref, "en", "fr", $options_ref, {});
	return $product_ref->{knowledge_panels_en}{$panel_id};
}

# Returns a hash of the rows of a table: first value => [other values]
sub get_rows ($panel_ref, $table_id = "environmental_cost_stages") {
	my ($table_ref)
		= grep {$_->{element_type} eq "table" and $_->{table_element}{id} eq $table_id} @{$panel_ref->{elements}};
	return unless defined $table_ref;
	return {
		map {
			$_->{values}[0]{text} => [map {$_->{text}} @{$_->{values}}[1 .. $#{$_->{values}}]]
		} @{$table_ref->{table_element}{rows}}
	};
}

# Returns the texts of the text elements of a panel, of a given type
sub get_texts ($panel_ref, $type = undef) {
	return [
		map {$_->{text_element}{html}}
		grep {$_->{element_type} eq "text" and (($_->{text_element}{type} // '') eq ($type // ''))}
			@{$panel_ref->{elements}}
	];
}

# Not shown to regular users
is(get_panel(product_with_ecs(), {}), undef, "panel not shown to regular users");

# Shown to moderators and admins
foreach my $role (qw(moderator admin)) {
	ok(defined get_panel(product_with_ecs(), {$role => 1}), "panel shown to $role");
}

# Warning note only for stale results (computed before the latest changes to the product)
is(get_texts(get_panel(product_with_ecs(), {moderator => 1}), "warning"), [], "no warning for up to date results");
my $stale_product_ref = product_with_ecs();
$stale_product_ref->{environmental_impact}{ecobalyse_stale} = 1;
is(
	get_texts(get_panel($stale_product_ref, {moderator => 1}), "warning"),
	["This environmental cost was computed before the latest changes to the product and may not be up to date."],
	"warning for stale results"
);

# Known product quantity: values for the whole product and for 100 g
my $panel_ref = get_panel(product_with_ecs(), {moderator => 1});
is(
	$panel_ref->{title_element}{subtitle},
	"200 points for the product (500 g) - 40 points for 100 g",
	"subtitle with values for the product and for 100 g"
);

# Calculation: impacts before the positive impact of the complements
is(
	get_texts($panel_ref),
	[
		"Total environmental impact score from Ecobalyse",
		"<strong>How the environmental cost is calculated</strong><br>Impacts: 220 points - Positive impact: 20 points = Environmental cost: 200 points",
	],
	"calculation of the environmental cost"
);

# Stages: values for the product and for 100 g, and share of the impacts
is(
	get_rows($panel_ref),
	{
		Ingredients => ["100", "20", "45 %"],
		Processing => ["20", "4.0", "9 %"],
		Packaging => ["40", "8.0", "18 %"],
		Transport => ["60", "12", "27 %"],
		Distribution => ["", "", ""],    # non numeric value from the API
		Use => ["0.0", "0.0", "0 %"],    # missing value
		"Total impacts" => ["220", "44", "100 %"],
	},
	"stages values for the product and for 100 g"
);

# Ingredients: sorted by impacts (before the positive impact of the complements)
is(
	get_rows($panel_ref, "environmental_cost_ingredients"),
	{
		beef => ["Ecobalyse beef", "100", "95", "19", "43 %"],
		sugar => ["Ecobalyse sugar", "300", "40", "8.0", "18 %"],
		water => ["Ecobalyse water", "150", "5.0", "1.0", "2 %"],
	},
	"ingredients values for the product and for 100 g"
);
my ($ingredients_table_ref)
	= grep {$_->{element_type} eq "table" and $_->{table_element}{id} eq "environmental_cost_ingredients"}
	@{$panel_ref->{elements}};
is([map {$_->{values}[0]{text}} @{$ingredients_table_ref->{table_element}{rows}}],
	[qw(beef sugar water)], "ingredients sorted by impacts");
is(
	get_texts($panel_ref, "notes"),
	[
		"Production, processing and transport of each ingredient. Packaging, distribution and use are counted for the whole product."
	],
	"note on the impacts of ingredients"
);

# Positive impact of ecosystem services, in a sub-panel
is($panel_ref->{elements}[-1]{panel_element}{panel_id}, "environmental_cost_ecosystem_services", "sub-panel included");
my $ecosystem_services_panel_ref
	= get_panel(product_with_ecs(), {moderator => 1}, "environmental_cost_ecosystem_services");
is($ecosystem_services_panel_ref->{evaluation}, "good", "sub-panel with a good evaluation");
is($ecosystem_services_panel_ref->{title_element}{subtitle}, "-20 points", "sub-panel subtitle");
is(
	get_rows($ecosystem_services_panel_ref, "environmental_cost_ecosystem_services"),
	{Hedges => ["-10", "-2.0"], "Plot size" => ["-10", "-2.0"]},
	"points of each ecosystem service"
);
is(
	get_texts($ecosystem_services_panel_ref)->[-1],
	"Ingredients concerned: beef (-20)",
	"ingredients with a positive impact"
);

# Ingredient names with special characters (user provided values) keep the panels valid,
# and they are HTML escaped in html fields
my $special_name = 'beef "<b>\\';
my $special_product_ref = product_with_ecs(ingredients => [["sugar", 300, 40, 0], [$special_name, 100, 75, -20]]);
is(
	get_rows(get_panel($special_product_ref, {moderator => 1}), "environmental_cost_ingredients")->{$special_name},
	['Ecobalyse beef "<b>\\', "100", "95", "19", "43 %"],
	"ingredient name with special characters"
);
is(
	get_texts(get_panel($special_product_ref, {moderator => 1}, "environmental_cost_ecosystem_services"))->[-1],
	'Ingredients concerned: beef &quot;&lt;b&gt;\\ (-20)',
	"ingredient name with special characters HTML escaped"
);

# No positive impact: no calculation and no sub-panel
$panel_ref = get_panel(product_with_ecs(complements => 0), {moderator => 1});
is(get_texts($panel_ref), ["Total environmental impact score from Ecobalyse"],
	"no calculation without positive impact");
ok(!(grep {$_->{element_type} eq "panel"} @{$panel_ref->{elements}}), "no sub-panel without positive impact");

# Many ingredients: the ingredients with the lowest impacts are grouped
$panel_ref = get_panel(
	product_with_ecs(
		complements => 0,
		ingredients => [map {["ingredient $_", 50, $_, 0]} (1 .. 10)]
	),
	{moderator => 1}
);
is(
	[
		map {$_->{values}[0]{text}}
			@{(grep {$_->{element_type} eq "table"} @{$panel_ref->{elements}})[1]{table_element}{rows}}
	],
	[
		"ingredient 10",
		"ingredient 9",
		"ingredient 8",
		"ingredient 7",
		"ingredient 6",
		"ingredient 5",
		"Other ingredients (4)"
	],
	"ingredients with the lowest impacts grouped"
);
is(
	get_rows($panel_ref, "environmental_cost_ingredients")->{"Other ingredients (4)"},
	["ingredient 4, ingredient 3, ingredient 2, ingredient 1", "200", "10", "2.0", "5 %"],
	"values of the grouped ingredients"
);

# Ingredients that do not match the response: no table of ingredients
my $product_ref = product_with_ecs();
$product_ref->{environmental_impact}{ecobalyse_response}{composition}[0]{name} = "something else";
is(get_rows(get_panel($product_ref, {moderator => 1}), "environmental_cost_ingredients"),
	undef, "no table of ingredients if the ingredients do not match");

# Ingredients before cooking: more ingredients than product, as water evaporates during cooking
is(
	get_texts(get_panel(product_with_ecs(complements => 0, ingredients_total_mass => 550), {moderator => 1}))->[-1],
	"550 g of ingredients before cooking, including 50 g of water that evaporates during cooking (estimate), for 500 g of product.",
	"water evaporated during cooking"
);

$panel_ref = get_panel(product_with_ecs(), {moderator => 1});
like(
	$panel_ref->{title_element}{icon_url},
	qr{/images/environmental-cost/v1/200-40-g\.svg$},
	"label image with the values for the product and for 100 g as icon"
);
my ($image_ref) = grep {$_->{element_type} eq "image"} @{$panel_ref->{elements}};
like($image_ref->{image_element}{url}, qr{/200-40-g\.svg$}, "label image displayed in the panel");
is([@{$image_ref->{image_element}}{qw(width height)}], [308, 154], "label image displayed at twice its size");
is(
	$image_ref->{image_element}{alt},
	"200 points for the product (500 g) - 40 points for 100 g",
	"alt text of the label image in the panel"
);

# Product sold by volume: values for 100 ml, product quantity as entered
$panel_ref = get_panel(product_with_ecs(reference_quantity => 750, unit => "ml", quantity => "0.75 l", ecs => 150),
	{moderator => 1});
is(
	$panel_ref->{title_element}{subtitle},
	"150 points for the product (0.75 l) - 20 points for 100 ml",
	"subtitle with values for the product and for 100 ml"
);
like($panel_ref->{title_element}{icon_url}, qr{/150-20-ml\.svg$}, "label image for 100 ml");

# No product quantity: values for 100 g only
$panel_ref = get_panel(product_with_ecs(source => "default", reference_quantity => 100, ecs => 50), {moderator => 1});
is($panel_ref->{title_element}{subtitle}, "50 points for 100 g", "subtitle with values for 100 g only");
is(get_rows($panel_ref)->{"Total impacts"}, ["70", "100 %"], "stages values for 100 g only");
is($panel_ref->{title_element}{icon_url}, undef, "no label icon without the value for the product");
is([grep {$_->{element_type} eq "image"} @{$panel_ref->{elements}}],
	[], "no label image without the value for the product");

# No panel if the ECS is missing or not a number
is(get_panel(product_with_ecs(ecs => undef), {moderator => 1}), undef, "no panel without ECS");
is(get_panel(product_with_ecs(ecs => "null"), {moderator => 1}), undef, "no panel with non numeric ECS");

done_testing();
