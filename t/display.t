#!/usr/bin/perl -w

use Modern::Perl '2017';

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Display qw/:all/;
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
