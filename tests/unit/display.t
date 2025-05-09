#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Display qw/:all/;
use ProductOpener::Web qw/display_field/;
use ProductOpener::Lang qw/$lc lang separator_before_colon/;
use ProductOpener::HTTP qw/request_param/;

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

my $product_nutriscore_data_ref = {
	nutriscore => {
		"2021" => {
			'score' => 6,
			'grade' => 'c',
			data => {
				'negative_points' => 8,
				'proteins_points' => 2,
				'proteins' => '3.9',
				'sodium_points' => 1,
				'sugars_value' => 15,
				'positive_points' => 2,
				'is_water' => 0,
				'fruits_vegetables_nuts_colza_walnut_olive_oils_points' => 0,
				'fruits_vegetables_nuts_colza_walnut_olive_oils' => 0,
				'energy_points' => 1,
				'fruits_vegetables_nuts_colza_walnut_olive_oils_value' => 0,
				'fiber_value' => 0,
				'sugars' => 15,
				'is_fat' => 0,
				'proteins_value' => '3.9',
				'is_beverage' => 0,
				'sodium' => 160,
				'saturated_fat_ratio' => 70,
				'energy' => 573,
				'fiber' => 0,
				'saturated_fat' => '3.5',
				'saturated_fat_ratio_value' => 70,
				'saturated_fat_value' => '3.5',
				'sugars_points' => 3,
				'sodium_value' => 160,
				'fiber_points' => 0,
				'is_cheese' => 0,
				'energy_value' => 573,
				'saturated_fat_ratio_points' => 10,
				'saturated_fat_points' => 3
			}
		}
	}
};

my $nutriscore_calculation_detail = display_nutriscore_calculation_details_2021($product_nutriscore_data_ref);
like($nutriscore_calculation_detail, qr/Nutritional score: 6/);
like($nutriscore_calculation_detail, qr/Proteins:\n2&nbsp;<\/strong>\/&nbsp;5/);
like($nutriscore_calculation_detail, qr/Positive points: 2/);
like($nutriscore_calculation_detail, qr/Negative points: 8/);
like($nutriscore_calculation_detail, qr/<strong>Nutri-Score: C<\/strong>/);

$lc = 'en';
my $product_ref = {
	states => ['en:front-photo-selected'],
	states_hierarchy => ['en:front-photo-selected']
};
my $expected = lang('done_status') . separator_before_colon($lc) . q{:};
like(display_field($product_ref, 'states'), qr/$expected/);

$lc = 'en';
$product_ref = {
	states => ['en:front-photo-to-be-selected'],
	states_hierarchy => ['en:front-photo-to-be-selected']
};
$expected = lang('to_do_status') . separator_before_colon($lc) . q{:};
like(display_field($product_ref, 'states'), qr/$expected/);

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

done_testing();
