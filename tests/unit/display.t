#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::APIAttributeGroups qw/display_preferences_api display_attribute_groups_api/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Food qw/check_nutriscore_categories_exist_in_taxonomy/;
use ProductOpener::Web qw/display_field/;
use ProductOpener::Lang qw/$lc lang separator_before_colon/;
use ProductOpener::HTTP qw/request_param/;
use ProductOpener::Tags qw/build_tags_taxonomy build_all_taxonomies/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# date tests
my $t = 1472292529;
$lc = 'en';
is(display_date($t), 'August 27, 2016, 12:08:49 PM CEST');
is(display_date_tag($t), '<time datetime="2016-08-27T12:08:49">August 27, 2016, 12:08:49 PM CEST</time>');
$lc = 'de';
is(display_date($t), '27. August 2016, 12:08:49 CEST');
is(display_date_tag($t), '<time datetime="2016-08-27T12:08:49">27. August 2016, 12:08:49 CEST</time>');

# is(
#	display_field({link => "https://www.brouwerijdebrabandere.be/fr/marques/bavik-super-pils"}, "link"),
#	'<p><span class="field">Link to the product page on the official site of the producer:</span> <a href="https://www.brouwerijdebrabandere.be/fr/marques/bavik-super-pils">https://www.brouwerijdebrabandere.be/fr/...</a></p>'
# );
#
#	is(
#	display_field({link => "producer.com"}, "link"),
#	'<p><span class="field">Link to the product page on the official site of the producer:</span> <a href="http://producer.com">http://producer.com</a></p>'
# );

$lc = 'en';

#test search query
my $request_ref = {
	lc => "en",
	current_link => '/cgi/search.pl?action=process&sort_by=unique_scans_n&page_size=24',
	cc => 'world',
};

my $count = 25;
my $limit = 24;
my $page = 1;
is(
	display_pagination($request_ref, $count, $limit, $page),
	'<ul id="pages" class="pagination"><li class="unavailable">Pages:</li><li class="current"><a href="">1</a></li><li><a href="/cgi/search.pl?action=process&sort_by=unique_scans_n&page_size=24&page=2">2</a></li><li><a href="/cgi/search.pl?action=process&sort_by=unique_scans_n&page_size=24&page=2" rel="next$nofollow">Next</a></li><li class="unavailable">(24 products per page)</li></ul>'
		. "\n"
);

#test label query
$request_ref->{current_link} = '/label/organic';
is(
	display_pagination($request_ref, $count, $limit, $page),
	'<ul id="pages" class="pagination"><li class="unavailable">Pages:</li><li class="current"><a href="">1</a></li><li><a href="/label/organic/2">2</a></li><li><a href="/label/organic/2" rel="next$nofollow">Next</a></li><li class="unavailable">(24 products per page)</li></ul>'
		. "\n"
);

# check integrity of display_preferences_api json structure
eval {display_preferences_api($request_ref, 'en');};
print("\n");
is($request_ref->{structured_response}[0]{name}, 'Not important');
is($request_ref->{structured_response}[0]{id}, 'not_important');
is($request_ref->{structured_response}[1]{name}, 'Important');
is($request_ref->{structured_response}[1]{id}, 'important');
is($request_ref->{structured_response}[1]{factor}, 1);
is($request_ref->{structured_response}[2]{name}, 'Very important');
is($request_ref->{structured_response}[2]{id}, 'very_important');
is($request_ref->{structured_response}[2]{factor}, 2);
is($request_ref->{structured_response}[3]{name}, 'Mandatory');
is($request_ref->{structured_response}[3]{id}, 'mandatory');
is($request_ref->{structured_response}[3]{factor}, 4);
is($request_ref->{structured_response}[3]{minimum_match}, 20);

# should not loose the second facet at the end of the url on redirection
my $facets_ref = {
	tags => [
		{
			'tagtype' => 'categories',
			'tagid' => 'en:bread'
		}
	],
	'tagtype' => 'categories',
	'groupby_tagtype' => 'data_quality',
	'tagid' => 'en:bread'
};

my $apache_util_module = mock 'Apache2::RequestUtil' => (
	add => [
		'request' => sub {
			# Return a mock Apache request object
			my $r = {};
			bless $r, 'Apache2::RequestRec';

			return $r;
		},
	]
);

my $request_rec_module = mock 'Apache2::RequestRec' => (
	add => [
		'rflush' => sub {
			# Do nothing, am just mocking the method
		},
		'status' => sub {
			# Do nothing, am just mocking the method
		},
		'headers_out' => sub {
			# Do nothing, am just mocking the method

		},
	]
);

my $display_module = mock 'ProductOpener::Display' => (
	override => [
		'redirect_to_url',
		sub {
			# Do nothing, am just mocking the method
		}
	]
);

display_tag($facets_ref);

is($facets_ref->{'current_link'}, '/facets/categories/breads/data-quality');
is($facets_ref->{'redirect'}, '/facets/categories/breads/data-quality');

$request_ref->{body_json}{labels_tags} = 'en:organic';
is(request_param($request_ref, 'unexisting_field'), undef);
is(request_param($request_ref, 'labels_tags'), 'en:organic') or diag Dumper request_param($request_ref, 'labels_tags');

# tests of the display of products with the new nutrition schema (version 1003)
my @display_tests = (
	[
		"nutrition-facts-table",
		{
			nutrition_data => "on",
			serving_size => "100g",
			serving_quantity => 100,
			nutrition_data_per => "100g",
			product_type => "food",
			code => "0000109165808",
			id => "0000109165808",
			categories => "",
			categories_tags => [],
			nutrition => {
				aggregated_set => {
					nutrients => {
						caffeine => {
							unit => "g",
							value => 2
						},
						calcium => {
							unit => "g",
							value => 0.3
						},
						carbohydrates => {
							unit => "g",
							value => 0
						},
						energy => {
							unit => "kJ",
							value => 0
						},
						"energy-kcal" => {
							unit => "kcal",
							value => 0
						},
						fat => {
							unit => "g",
							value => 0
						},
						proteins => {
							unit => "g",
							value => 0
						},
						salt => {
							unit => "g",
							value => 3.75
						},
						sodium => {
							unit => "g",
							value => 1.5
						}
					},
					preparation => "as_sold",
					per => "100g"
				}
			}
		}
	],
	[
		"nutrition-facts-table-liquid",
		{
			nutrition_data => "on",
			serving_size => "100ml",
			serving_quantity => 100,
			nutrition_data_per => "100ml",
			product_type => "food",
			code => "0000109165808",
			id => "0000109165808",
			categories => "",
			categories_tags => [],
			nutrition => {
				aggregated_set => {
					nutrients => {
						caffeine => {
							unit => "g",
							value => 2
						},
						calcium => {
							unit => "g",
							value => 0.3
						},
						carbohydrates => {
							unit => "g",
							value => 0
						},
						energy => {
							unit => "kJ",
							value => 0
						},
						"energy-kcal" => {
							unit => "kcal",
							value => 0
						},
						fat => {
							unit => "g",
							value => 0
						},
						proteins => {
							unit => "g",
							value => 0
						},
						salt => {
							unit => "g",
							value => 3.75
						},
						sodium => {
							unit => "g",
							value => 1.5
						}
					},
					preparation => "as_sold",
					per => "100ml"
				}
			}
		}
	],
	[
		"nutrition-facts-table-no-nutrition-data",
		{
			nutrition_data => "on",
			serving_size => "100g",
			serving_quantity => 100,
			nutrition_data_per => "100g",
			product_type => "food",
			code => "0000109165808",
			id => "0000109165808",
			categories => "",
			categories_tags => [],
			nutrition => {
				aggregated_set => {
					nutrients => {},
					preparation => "as_sold"
				}
			}
		}
	],
	[
		"nutrition-facts-table-pet-food",
		{
			nutrition_data => "on",
			serving_size => "100g",
			serving_quantity => 100,
			nutrition_data_per => "100g",
			product_type => "petfood",
			code => "0000109165808",
			id => "0000109165808",
			categories => "",
			categories_tags => [],
			nutrition => {
				aggregated_set => {
					nutrients => {
						carbohydrates => {
							unit => "g",
							value => 0
						},
						energy => {
							unit => "kJ",
							value => 0
						},
						"energy-kcal" => {
							unit => "kcal",
							value => 0
						},
						fat => {
							unit => "g",
							value => 2
						},
						fiber => {
							unit => "g",
							value => 0.25
						}
					},
					preparation => "as_sold",
					per => "100g"
				}
			}
		}
	],
	[
		"nutrition-facts-table-with-comparisons",
		{
			nutrition_data => "on",
			serving_size => "100g",
			serving_quantity => 100,
			nutrition_data_per => "100g",
			product_type => "food",
			code => "0000109165808",
			id => "0000109165808",
			categories => "",
			categories_tags => [],
			nutrition => {
				aggregated_set => {
					nutrients => {
						carbohydrates => {
							unit => "g",
							value => 0
						},
						energy => {
							unit => "kJ",
							value => 0
						},
						fat => {
							unit => "g",
							value => 0
						},
						salt => {
							unit => "g",
							value => 3.75
						}
					},
					preparation => "as_sold",
					per => "100g"
				}
			}
		},
		[
			{
				name => "Spreads",
				n => 1,
				count => 100,
				values => {
					energy => {mean => 10},
					fat => {mean => 20},
					"saturated-fat" => {mean => 30},
					sugars => {mean => 40},
					salt => {mean => 50}
				},
				id => "en:spreads",
				show => 1,
				link => "/facets/categories/en:spreads"
			}
		]
	]
);

# load the necessary taxonomy for the tests
build_all_taxonomies(0);
$ProductOpener::Display::nutriment_table = 'off_europe';

# populate the hash for the comparison column tests
%ProductOpener::Stats::categories_stats_per_country = (
	'fr' => {
		'fr:pates-a-tartiner' => {
			stats => 1,
			id => 'fr:pates-a-tartiner',
			count => 100,
			n => 1,
			values => {
				energy => {mean => 10},
				fat => {mean => 20},
				"saturated-fats" => {mean => 30},
				sugars => {mean => 40},
				salt => {mean => 50}
			},
		},
		'fr:boissons' => {
			stats => 1,
			id => 'fr:boissons',
			count => 50,
			n => 1,
			values => {
				energy => {mean => 50},
				fat => {mean => 0},
				'saturated-fat' => {mean => 0},
				sugars => {mean => 12},
				salt => {mean => 0},
			},
		},
	},
	'en' => {
		'en:snacks' => {
			stats => 1,
			id => 'en:snacks',
			count => 25,
			n => 1,
			values => {
				energy => {mean => 500},
				fat => {mean => 25},
				'saturated-fat' => {mean => 6},
				sugars => {mean => 35},
				salt => {mean => 1.5},
			},
		},
	},
);

foreach my $test_ref (@display_tests) {
	my $testid = $test_ref->[0];
	my $product_test_ref = $test_ref->[1];
	my $comparisons_ref = $test_ref->[2];
	my $request_ref = $test_ref->[3];

	my $nutrition_facts_panel = data_to_display_nutrition_table($product_test_ref, $comparisons_ref, $request_ref);

	compare_to_expected_results($nutrition_facts_panel, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});

}

# test the generation of the comparison column of products with the new nutrition schema (version 1003)
my @comparison_tests = (
	[
		"comparisons",
		{
			product => {
				nutrition_data => "on",
				serving_size => "100g",
				serving_quantity => 100,
				nutrition_data_per => "100g",
				product_type => "food",
				code => "0000109165808",
				id => "0000109165808",
				categories => "",
				categories_tags => [],
				nutrition => {
					aggregated_set => {
						nutrients => {
							"fat" => {
								value => 30.9
							},
							"salt" => {
								value => undef
							},
							"energy" => {
								value => 2252
							},
						},
						preparation => "as_sold",
						per => "100g",
					}
				},
				categories_tags => [
					"en:breakfasts", "en:spreads",
					"en:sweet-spreads", "fr:pates-a-tartiner",
					"en:hazelnut-spreads", "en:chocolate-spreads",
					"en:cocoa-and-hazelnuts-spreads"
				]
			},
			target_lc => "fr",
			target_cc => "fr",
			max_number_of_categories => 3
		},
	]
);

foreach my $test_ref (@comparison_tests) {
	my $testid = $test_ref->[0];
	my $product_test_ref = $test_ref->[1]{product};
	my $target_cc = $test_ref->[1]{target_cc};
	my $target_lc = $test_ref->[1]{target_lc};
	my $max_number_of_categories = $test_ref->[1]{max_number_of_categories};

	my $comparisons
		= compare_product_nutrition_facts_to_categories($product_test_ref, $target_lc, $target_cc,
		$max_number_of_categories);

	compare_to_expected_results($comparisons, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});

}

is([ProductOpener::Display::get_search_field_title_and_details("additives_n")],
	["Number of additives", "", "", "allowDecimals:false,\n"]);
is([ProductOpener::Display::get_search_field_title_and_details("nova_group")],
	["NOVA group", "", "", "allowDecimals:false,\n"]);
is([ProductOpener::Display::get_search_field_title_and_details("fat")], ["Fat", " (g for 100 g / 100 ml)", "g", ""]);

done_testing();
