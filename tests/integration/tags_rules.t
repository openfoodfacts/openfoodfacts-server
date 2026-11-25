#!/usr/bin/perl -w

# Tags rules (rules/food/categories/*.yml) are applied when a product is saved:
# the tags they add are stored in tags_sources.[field].rules

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::APITest qw/construct_test_url create_user new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;

use HTTP::Request;
use JSON::MaybeXS;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();
create_user($ua, {%default_user_form, (email => 'bob@example.com')});

# Anonymous client to read the product
my $read_ua = new_client();

my $json = JSON::MaybeXS->new->utf8->canonical;
my $code = "2000000000017";

sub patch_product ($product_ref) {
	my $request = HTTP::Request->new(PATCH => construct_test_url("/api/v3.6/product/$code"));
	$request->header('Content-Type' => 'application/json');
	$request->content($json->encode({product => $product_ref}));
	my $response = $ua->request($request);
	is($response->code, 200, "PATCH product") or diag($response->decoded_content);
	return;
}

sub get_product () {
	my $response = $read_ua->get(
		construct_test_url(
			"/api/v3.6/product/$code?fields=tags_sources,categories_tags,misc_tags,data_quality_warnings_tags")
	);
	is($response->code, 200, "GET product") or diag($response->decoded_content);
	return $json->decode($response->decoded_content)->{product};
}

# A cola: the colas-caffeinated rule adds en:caffeinated-colas
patch_product({lang => "en", product_name_en => "Test cola", categories_tags => ["en:colas"]});

my $product_ref = get_product();
is($product_ref->{tags_sources}{categories}{rules}{tags}, ["en:caffeinated-colas"], "rules source: tags");
is(
	$product_ref->{tags_sources}{categories}{rules}{rules},
	{"en:caffeinated-colas" => ["colas-caffeinated"]},
	"rules source: rule ids"
);
ok((grep {$_ eq "en:caffeinated-colas"} @{$product_ref->{categories_tags}}), "categories_tags has the rule category");
ok((grep {$_ eq "en:tags-rule-colas-caffeinated"} @{$product_ref->{misc_tags}}), "misc tag for the rule");
ok((grep {$_ eq "en:tags-added-by-rules"} @{$product_ref->{misc_tags}}), "misc tag for tags added by rules");

my $last_updated_t = $product_ref->{tags_sources}{categories}{rules}{last_updated_t};
ok($last_updated_t, "rules source: last_updated_t");

# Second save, with another change: the rules source does not change
sleep(2);
patch_product({product_name_en => "Test cola 2"});

$product_ref = get_product();
is($product_ref->{tags_sources}{categories}{rules}{tags}, ["en:caffeinated-colas"], "second save: same tags");
is($product_ref->{tags_sources}{categories}{rules}{last_updated_t},
	$last_updated_t, "second save: last_updated_t unchanged");

# The contributor says the cola is caffeine-free: the rule would conflict, the rules source is removed,
# and the product does not get a conflict warning since the rule does not match anymore (unless: name, label)
patch_product({product_name_en => "Caffeine free cola"});

$product_ref = get_product();
is($product_ref->{tags_sources}{categories}{rules}, undef, "caffeine free: no rules source");
ok(!(grep {$_ eq "en:caffeinated-colas"} @{$product_ref->{categories_tags}}),
	"caffeine free: no rule category in categories_tags");
ok(!(grep {/^en:tags-rule/} @{$product_ref->{misc_tags}}), "caffeine free: no rule misc tag");

# Conflict: the product is tagged as a cola without caffeine, but the name does not say so
patch_product({product_name_en => "Test cola", categories_tags => ["en:cola-sodas-without-caffeine"]});

$product_ref = get_product();
is($product_ref->{tags_sources}{categories}{rules}, undef, "conflict: no rules source");
ok((grep {$_ eq "en:category-rules-conflict"} @{$product_ref->{data_quality_warnings_tags}}),
	"conflict: data quality warning");

done_testing();
