#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use JSON::MaybeXS;
use Data::Dumper;
$Data::Dumper::Terse = 1;

my $json = JSON::MaybeXS->new->allow_nonref->canonical;

use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Test qw/init_expected_results/;
use ProductOpener::API qw/get_initialized_response/;
use ProductOpener::Products qw/analyze_and_enrich_product_data/;

is(
	ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline('
test
muti-line string
a slash A / B and anti-slash \
HTML <a href="https://url.com">test</a>
'),
	'"\ntest\nmuti-line string\na slash A / B and anti-slash \\\\\nHTML <a href=\"https://url.com\">test</a>\n"'
);

is(
	ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline(
		'<a href="https://agribalyse.ademe.fr/app/aliments/[% product.environmental_score_data.agribalyse.code %]">'),
	'"<a href=\"https://agribalyse.ademe.fr/app/aliments/[% product.environmental_score_data.agribalyse.code %]\">"'
);

load_data();

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	{
		'id' => 'en-nutriscore-serving-size-error',
		'product' => {
			lc => "en",
			categories => "biscuits",
			categories_tags => ["en:biscuits"],
			nutrition_data_per => "serving",
			serving_size => "20",
			ingredients_text => "100% fruits",
			nutrition => {
				aggregated_set => {
					nutrients => {
						energy => {
							value => 2591
						},
						fat => {
							value => 50
						},
						"saturated-fat" => {
							value => 9.7
						},
						sugars => {
							value => 5.1
						},
						salt => {
							value => 0
						},
						sodium => {
							value => 0
						},
						proteins => {
							value => 29
						},
						fiber => {
							value => 5.5
						}
					}
				}
			}
		},
		target_lc => 'fr',
		target_cc => 'fr'
	},
	# added sugars tests
	# english test with "with added sugar" ingredient
	{
		'id' => 'en-ingredients-with-added-sugar',
		'product' => {
			lc => "en",
			ingredients_text => "Sugar, wheat flour, butter",
		},
		target_lc => 'en',
		target_cc => 'us'
	},
	# added sugars in input nutrition facts
	{
		'id' => 'en-nutrition-facts-added-sugars',
		'product' => {
			lc => "en",
			ingredients_text => "Sugar, wheat flour, butter",
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"added-sugars" => {
								value_string => "20",
								value => 20,
								unit => "g",
							},
						}
					}
				]
			},
		},
		target_lc => 'en',
		target_cc => 'us'
	},
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->{"id"};
	my $product_ref = $test_ref->{"product"};
	my $target_lc = $test_ref->{"target_lc"};
	my $target_cc = $test_ref->{"target_cc"};

	# Run the test

	# Response structure to keep track of warnings and errors
	# Note: currently some warnings and errors are added,
	# but we do not yet do anything with them
	my $response_ref = get_initialized_response();

	analyze_and_enrich_product_data($product_ref, $response_ref);
	my $options_ref = {};
	my $request_ref = {};
	initialize_knowledge_panels_options($options_ref, $request_ref);

	create_knowledge_panels($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	# Travis and docker has a different $server_domain, so we need to change the resulting URLs
	#          $got->{attribute_groups_fr}[0]{attributes}[0]{icon_url} = 'https://static.off.travis-ci.org/images/attributes/nutriscore-unknown.svg'
	#     $expected->{attribute_groups_fr}[0]{attributes}[0]{icon_url} = 'https://static.openfoodfacts.dev/images/attributes/nutriscore-unknown.svg'

	# code below from https://www.perlmonks.org/?node_id=1031287

	use Scalar::Util qw/reftype/;

	sub walk {
		my ($entry, $code) = @_;
		my $type = reftype($entry);
		$type //= "SCALAR";

		if ($type eq "HASH") {
			walk($_, $code) for values %$entry;
		}
		elsif ($type eq "ARRAY") {
			walk($_, $code) for @$entry;
		}
		elsif ($type eq "SCALAR") {
			$code->($_[0]);    # alias of entry
		}
		else {
			warn "unknown type $type";
		}
		return;
	}

	walk $product_ref, sub {return unless defined $_[0]; $_[0] =~ s/https?:\/\/([^\/]+)\//https:\/\/server_domain\//;};

	# Save the result

	if ($update_expected_results) {
		open(my $result, ">:encoding(UTF-8)", "$expected_result_dir/$testid.json")
			or die("Could not create $expected_result_dir/$testid.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close($result);
	}

	# Compare the result with the expected result

	if (open(my $expected_result, "<:encoding(UTF-8)", "$expected_result_dir/$testid.json")) {

		local $/;    #Enable 'slurp' mode
		my $expected_product_ref = $json->decode(<$expected_result>);
		print STDERR "testid: $testid\n";
		is($product_ref, $expected_product_ref) or diag Dumper($product_ref);
	}
	else {
		diag Dumper($product_ref);
		fail("could not load $expected_result_dir/$testid.json");
	}
}

done_testing();
