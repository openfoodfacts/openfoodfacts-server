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

# Warning note only for stale results (computed before the latest changes to the product)
sub get_warnings ($panel_ref) {
	return [
		map {$_->{text_element}{html}}
		grep {$_->{element_type} eq "text" and ($_->{text_element}{type} // '') eq "warning"} @{$panel_ref->{elements}}
	];
}
is(get_warnings(get_panel(product_with_ecs(), {moderator => 1})), [], "no warning for up to date results");
my $stale_product_ref = product_with_ecs();
$stale_product_ref->{environmental_impact}{ecobalyse_stale} = 1;
is(
	get_warnings(get_panel($stale_product_ref, {moderator => 1})),
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
is(
	get_rows($panel_ref),
	{
		Ingredients => ["100", "20"],
		Processing => ["20", "4"],
		Packaging => ["40", "8"],
		Transport => ["40", "8"],
		Distribution => ["", ""],    # non numeric value from the API
		Preparation => ["0", "0"],    # missing value
		Total => ["200", "40"],
	},
	"breakdown values for the product and for 100 g"
);

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
is(get_rows($panel_ref)->{Total}, ["50"], "breakdown values for 100 g only");
is($panel_ref->{title_element}{icon_url}, undef, "no label icon without the value for the product");
is([grep {$_->{element_type} eq "image"} @{$panel_ref->{elements}}],
	[], "no label image without the value for the product");

# No panel if the ECS is missing or not a number
is(get_panel(product_with_ecs(ecs => undef), {moderator => 1}), undef, "no panel without ECS");
is(get_panel(product_with_ecs(ecs => "null"), {moderator => 1}), undef, "no panel with non numeric ECS");

done_testing();
