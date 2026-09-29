#!/usr/bin/perl -w

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::EnvironmentalImpact qw/filter_ecobalyse_response_for_open_data/;

my $json = JSON->new->allow_nonref->canonical;

# Build a representative Ecobalyse response that covers all the cases:
# - top-level keys that should be removed (description, webUrl)
# - query that should be removed
# - results with various nested structures containing ecs + other impacts
# - results with hashes that have NO ecs (like scoring, totalBonusImpact)
# - scalar values that should pass through (totalMass, road, etc.)
my $raw_response = $json->decode(<<'JSON');
{
   "description": "TODO",
   "query": {
      "distribution": "ambient",
      "ingredients": [
         {"id": "abc", "mass": 50}
      ],
      "packaging": [
         {"amount": 1, "id": "def"}
      ]
   },
   "results": {
      "distribution": {
         "total": {
            "acd": 7.6e-06,
            "cch": 0.001,
            "ecs": 0.253,
            "etf": 0.009,
            "wtu": 0.003
         },
         "transports": {
            "air": 0,
            "impacts": {
               "acd": 0.0002,
               "cch": 0.047,
               "ecs": 4.91,
               "etf": 0.49
            },
            "road": 600,
            "roadCooled": 0,
            "sea": 0,
            "seaCooled": 0
         }
      },
      "packaging": {
         "acd": 0.002,
         "cch": 0.455,
         "ecs": 38.66,
         "etf": 4.638
      },
      "perKg": {
         "acd": 0.057,
         "ecs": 973.181,
         "etf": 118.704
      },
      "preparation": {
         "acd": 0,
         "ecs": 0,
         "etf": 0
      },
      "preparedMass": 0.1,
      "recipe": {
         "ingredientsTotal": {
            "acd": 0.003,
            "ecs": 49.38,
            "etf": 6.318
         },
         "total": {
            "acd": 0.003,
            "ecs": 53.49,
            "etf": 6.73
         },
         "totalBonusImpact": {
            "cropDiversity": 0,
            "hedges": 0,
            "plotSize": 0
         },
         "transform": {
            "acd": 0,
            "ecs": 0,
            "etf": 0
         },
         "transports": {
            "air": 18000,
            "impacts": {
               "acd": 0.0002,
               "cch": 0.04,
               "ecs": 4.11,
               "etf": 0.41
            },
            "road": 9800,
            "sea": 36000
         }
      },
      "scoring": {
         "all": 973.181,
         "biodiversity": 451.194,
         "climate": 157.121,
         "health": 96.1446,
         "resources": 268.723
      },
      "total": {
         "acd": 0.006,
         "cch": 0.564,
         "ecs": 97.318,
         "etf": 11.87
      },
      "totalMass": 0.5296,
      "transports": {
         "air": 0,
         "impacts": {
            "acd": 0.0004,
            "cch": 0.087,
            "ecs": 9.025,
            "etf": 0.905
         },
         "road": 10400,
         "sea": 36000
      }
   },
   "webUrl": "https://example.com"
}
JSON

# Run the filter
my $filtered_ref = filter_ecobalyse_response_for_open_data($raw_response);

# 1. The query must be removed
ok(!exists $filtered_ref->{query}, "query key removed");

# 2. Only results is kept at the top level
ok(exists $filtered_ref->{results}, "results key present");
is([sort keys %$filtered_ref], ['results'], "only results key at top level");

# 3. Hashes with ecs keep only ecs
is($filtered_ref->{results}{packaging}, {ecs => 38.66}, "packaging keeps only ecs");
is($filtered_ref->{results}{perKg}, {ecs => 973.181}, "perKg keeps only ecs");
is($filtered_ref->{results}{total}, {ecs => 97.318}, "total keeps only ecs");
is($filtered_ref->{results}{preparation}, {ecs => 0}, "preparation keeps only ecs");

# 4. Nested hashes inside results with ecs are also filtered
is(
	$filtered_ref->{results}{distribution}{total},
	{ecs => 0.253},
	"distribution.total keeps only ecs"
);
is(
	$filtered_ref->{results}{distribution}{transports},
	{
		air         => 0,
		impacts     => {ecs => 4.91},
		road        => 600,
		roadCooled  => 0,
		sea         => 0,
		seaCooled   => 0,
	},
	"distribution.transports keeps non-impact scalars and filters impacts"
);
is(
	$filtered_ref->{results}{recipe}{ingredientsTotal},
	{ecs => 49.38},
	"recipe.ingredientsTotal keeps only ecs"
);
is(
	$filtered_ref->{results}{recipe}{total},
	{ecs => 53.49},
	"recipe.total keeps only ecs"
);
is(
	$filtered_ref->{results}{recipe}{transform},
	{ecs => 0},
	"recipe.transform keeps only ecs"
);

# 5. Hashes without ecs are kept as-is (scoring, totalBonusImpact)
is(
	$filtered_ref->{results}{scoring},
	{
		all         => 973.181,
		biodiversity => 451.194,
		climate     => 157.121,
		health      => 96.1446,
		resources   => 268.723,
	},
	"scoring kept as-is (no ecs key)"
);
is(
	$filtered_ref->{results}{recipe}{totalBonusImpact},
	{
		cropDiversity      => 0,
		hedges             => 0,
		plotSize            => 0,
	},
	"totalBonusImpact kept as-is (no ecs key)"
);

# 6. Scalar values pass through
is($filtered_ref->{results}{preparedMass}, 0.1, "preparedMass scalar kept");
is($filtered_ref->{results}{totalMass}, 0.5296, "totalMass scalar kept");

# 7. Original response is not modified
ok(exists $raw_response->{query}, "original query still present");
ok(exists $raw_response->{description}, "original description still present");
ok(exists $raw_response->{webUrl}, "original webUrl still present");
is(
	[sort keys %{$raw_response->{results}{packaging}}],
	['acd', 'cch', 'ecs', 'etf'],
	"original packaging still has all keys"
);

# 8. Non-hash input returns undef
is(filter_ecobalyse_response_for_open_data(undef), undef, "undef input returns undef");
is(filter_ecobalyse_response_for_open_data("not a hash"), undef, "non-hash input returns undef");

done_testing();
