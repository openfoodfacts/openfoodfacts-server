#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::LoadData qw/load_data/;

load_data();

# Product with an Ecobalyse result (ingredients quantities sent for 100 g of product)
sub product_with_ecs ($ecs = 80) {
	return {
		code => "1234567890123",
		lc => "en",
		environmental_impact => {
			ecs => $ecs,
			ecobalyse_input => {ingredients => [{mass => 50}, {mass => 30}]},
			ecobalyse_response => {
				# no preparation value in the results
				results => {
					recipe => {ingredientsTotal => {ecs => 40}, transform => {ecs => 8}},
					packaging => {ecs => 16},
					transports => {impacts => {ecs => 4}},
					distribution => {total => {ecs => "null"}},    # invalid value from the API
				}
			}
		}
	};
}

sub get_panel ($product_ref, $options_ref) {
	ProductOpener::KnowledgePanels::create_environmental_cost_panel($product_ref, "en", "fr", $options_ref, {});
	return $product_ref->{knowledge_panels_en}{environmental_cost};
}

# Not shown to regular users
is(get_panel(product_with_ecs(), {}), undef, "panel not shown to regular users");

# Shown to moderators and admins
foreach my $role (qw(moderator admin)) {
	ok(defined get_panel(product_with_ecs(), {$role => 1}), "panel shown to $role");
}

# Values are not scaled (ingredients quantities are sent for 100 g of product), only rounded
my $panel_ref = get_panel(product_with_ecs(), {moderator => 1});
like($panel_ref->{title_element}{title}, qr/: 80\.00 /, "total ECS in title");

my %rows = map {$_->{values}[0]{text} => $_->{values}[1]{text}} @{$panel_ref->{elements}[1]{table_element}{rows}};
is(
	\%rows,
	{
		Ingredients => "40.00",
		Processing => "8.00",
		Packaging => "16.00",
		Transport => "4.00",
		Distribution => "",    # non numeric value from the API
		Preparation => "0.00",    # missing value
		Total => "80.00",
	},
	"breakdown values"
);

# No panel if the total ECS is missing or not a number
is(get_panel(product_with_ecs(undef), {moderator => 1}), undef, "no panel without ECS");
is(get_panel(product_with_ecs("null"), {moderator => 1}), undef, "no panel with non numeric ECS");

done_testing();
