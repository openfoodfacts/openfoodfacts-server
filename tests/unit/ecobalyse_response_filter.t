#!/usr/bin/perl -w

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::EnvironmentalImpact qw/filter_ecobalyse_response_for_open_data/;

my $json = JSON->new->allow_nonref->canonical;

# Representative Ecobalyse food2 API response (shortened) that covers all the cases:
# - scores in points that should be kept (score, stages, complements, composition scores)
# - subscores and physical impacts that should be removed (we are not allowed to redistribute them)
# - top-level keys that should be removed (query, webUrl, description)
# - an unknown field that should be removed (whitelist)
my $raw_response = $json->decode(<<'JSON');
{
   "complements": {
      "hedges": -8.32894,
      "permanentPasture": -10.3011,
      "plotSize": -7.97893
   },
   "composition": [
      {
         "complements": {},
         "impacts": {"acd": 0.0003, "cch": 0.11, "ecs": 33.404},
         "mass": 0.093,
         "name": "Riz long",
         "quantity": 1,
         "score": {"complements": 0, "ecs": 33.404}
      },
      {
         "complements": {"hedges": -8.30587, "permanentPasture": -10.3011, "plotSize": -7.88826},
         "impacts": {"acd": 0.002, "cch": 0.9, "ecs": 102.293},
         "mass": 0.03675,
         "name": "viande de boeuf",
         "quantity": 1,
         "score": {"complements": -26.4953, "ecs": 102.293}
      }
   ],
   "description": "Simulation",
   "impacts": {"acd": 0.004, "cch": 1.6, "etf": 21.2, "ldu": 120.3, "wtu": 2.1},
   "productMass": 0.2898,
   "query": {"components": [{"quantity": 1, "name": "Riz long"}]},
   "score": {"complements": -26.609, "ecs": 264.944},
   "someNewField": {"ecs": 1},
   "stages": {
      "assembly": 0,
      "distribution": 1.4875,
      "endOfLife": 0,
      "materials": 159.068,
      "packaging": 29.33,
      "transform": 13.8191,
      "transports": 86.696,
      "usage": 1.15289
   },
   "subscores": {
      "biodiversity": 129.437,
      "climate": 80.4175,
      "complements": -26.609,
      "health": 36.3735,
      "resources": 45.3342
   },
   "webUrl": "https://example.com"
}
JSON

my $filtered_ref = filter_ecobalyse_response_for_open_data($raw_response);

is(
	$filtered_ref,
	{
		score => {ecs => 264.944, complements => -26.609},
		stages => {
			materials => 159.068,
			transform => 13.8191,
			assembly => 0,
			packaging => 29.33,
			transports => 86.696,
			distribution => 1.4875,
			usage => 1.15289,
			endOfLife => 0,
		},
		complements => {hedges => -8.32894, permanentPasture => -10.3011, plotSize => -7.97893},
		productMass => 0.2898,
		composition => [
			{name => "Riz long", mass => 0.093, score => {ecs => 33.404, complements => 0}, complements => {}},
			{
				name => "viande de boeuf",
				mass => 0.03675,
				score => {ecs => 102.293, complements => -26.4953},
				complements => {hedges => -8.30587, permanentPasture => -10.3011, plotSize => -7.88826},
			},
		],
	},
	"only the scores in points are kept"
);

ok(!exists $filtered_ref->{subscores}, "subscores removed");
ok(!exists $filtered_ref->{impacts}, "physical impacts removed");
ok(!(grep {exists $_->{impacts}} @{$filtered_ref->{composition}}), "physical impacts of ingredients removed");
ok(!exists $filtered_ref->{$_}, "$_ removed") for qw(query webUrl description someNewField);

# Non numeric values are removed
is(
	filter_ecobalyse_response_for_open_data({score => {ecs => "null", complements => 0}, stages => {materials => {}}}),
	{score => {complements => 0}, stages => {}},
	"non numeric values removed"
);

# Error responses
is(
	filter_ecobalyse_response_for_open_data(
		{error => {general => "Invalid request"}, documentation => "https://ecobalyse.beta.gouv.fr/#/api"}
	),
	{error => {general => "Invalid request"}},
	"error kept"
);

# Original response is not modified
ok(exists $raw_response->{subscores}, "original subscores still present");
ok(exists $raw_response->{composition}[0]{impacts}, "original impacts of ingredients still present");

# Non-hash input returns undef
is(filter_ecobalyse_response_for_open_data(undef), undef, "undef input returns undef");
is(filter_ecobalyse_response_for_open_data("not a hash"), undef, "non-hash input returns undef");

done_testing();
