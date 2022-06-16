#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Display qw/:all/;
use ProductOpener::Web qw/:all/;
use ProductOpener::Lang qw/:all/;

# date tests
my $t = 1472292529;
$lc = 'en';
is( display_date($t), 'August 27, 2016 at 12:08:49 PM CEST' );
is( display_date_tag($t), '<time datetime="2016-08-27T12:08:49">August 27, 2016 at 12:08:49 PM CEST</time>' );
$lc = 'de';
is( display_date($t), '27. August 2016 um 12:08:49 CEST' );
is( display_date_tag($t), '<time datetime="2016-08-27T12:08:49">27. August 2016 um 12:08:49 CEST</time>' );

# is(
# 	display_field({link => "https://www.brouwerijdebrabandere.be/fr/marques/bavik-super-pils"}, "link"),
# 	'<p><span class="field">Link to the product page on the official site of the producer:</span> <a href="https://www.brouwerijdebrabandere.be/fr/marques/bavik-super-pils">https://www.brouwerijdebrabandere.be/fr/...</a></p>'
# );
#
# is(
# 	display_field({link => "producer.com"}, "link"),
# 	'<p><span class="field">Link to the product page on the official site of the producer:</span> <a href="http://producer.com">http://producer.com</a></p>'
# );

# paging tests

# issue # 1960 - negative query lost during pagination and in other links
my $link = "/country/spain";
my $tag_prefix = "-";
is ( add_tag_prefix_to_link($link,$tag_prefix),"/country/-spain");

$link = "/country/spain/city/madrid";
$tag_prefix = "-";
is ( add_tag_prefix_to_link($link,$tag_prefix),"/country/spain/city/-madrid");

$link = "/spain";
$tag_prefix = "-";
is ( add_tag_prefix_to_link($link,$tag_prefix),"/-spain");

#test search query
my $request_ref->{current_link} = '/cgi/search.pl?action=process&sort_by=unique_scans_n&page_size=24';
my $count = 25;
my $limit = 24;
my $page = 1;
is ( display_pagination( $request_ref , $count, $limit, $page), '</ul>' . "\n" . '<ul id="pages" class="pagination"><li class="unavailable">Pages:</li><li class="current"><a href="">1</a></li><li><a href="/cgi/search.pl?action=process&sort_by=unique_scans_n&page_size=24&page=2">2</a></li><li><a href="/cgi/search.pl?action=process&sort_by=unique_scans_n&page_size=24&page=2" rel="next$nofollow">Next</a></li><li class="unavailable">(24 products per page)</li></ul>' . "\n");

#test label query
$request_ref->{current_link} = '/label/organic';
is ( display_pagination( $request_ref , $count, $limit, $page), '</ul>' . "\n" . '<ul id="pages" class="pagination"><li class="unavailable">Pages:</li><li class="current"><a href="">1</a></li><li><a href="/label/organic/2">2</a></li><li><a href="/label/organic/2" rel="next$nofollow">Next</a></li><li class="unavailable">(24 products per page)</li></ul>' . "\n");


my $nutriscore_data_ref = {
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
          'score' => 6,
          'saturated_fat_ratio' => 70,
          'energy' => 573,
          'fiber' => 0,
          'saturated_fat' => '3.5',
          'grade' => 'c',
          'saturated_fat_ratio_value' => 70,
          'saturated_fat_value' => '3.5',
          'sugars_points' => 3,
          'sodium_value' => 160,
          'fiber_points' => 0,
          'is_cheese' => 0,
          'energy_value' => 573,
          'saturated_fat_ratio_points' => 10,
          'saturated_fat_points' => 3
        };

print("-----------\n");
like ( display_nutriscore_calculation_details($nutriscore_data_ref), qr/Score nutritionnel: 6/);
like ( display_nutriscore_calculation_details($nutriscore_data_ref), qr/Proteins:\n2&nbsp;<\/strong>\/&nbsp;5/);
like ( display_nutriscore_calculation_details($nutriscore_data_ref), qr/Positive points: 2/);
like ( display_nutriscore_calculation_details($nutriscore_data_ref), qr/Negative points: 8/);
like ( display_nutriscore_calculation_details($nutriscore_data_ref), qr/<strong>Nutri-Score: C<\/strong>/);
print("-----------\n");



$lc = 'en';
my $product_ref = {
	states           => ['en:front-photo-selected'],
	states_hierarchy => ['en:front-photo-selected']
};
my $expected = lang('done_status') . separator_before_colon($lc) . q{:};
like( display_field( $product_ref, 'states' ), qr/$expected/ );

$lc = 'en';
$product_ref = {
	states           => ['en:front-photo-to-be-selected'],
	states_hierarchy => ['en:front-photo-to-be-selected']
};
$expected = lang('to_do_status') . separator_before_colon($lc) . q{:};
like( display_field( $product_ref, 'states' ), qr/$expected/ );

done_testing();
