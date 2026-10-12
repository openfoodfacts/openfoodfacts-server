#!/usr/bin/perl -w

# Tests for the language selector at the top of web pages:
# it should link to the same page in the other languages, not to the home page
# https://github.com/openfoodfacts/openfoodfacts-server/issues/376

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/construct_test_url create_user edit_product new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form %empty_product_form/;

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();
create_user($ua, \%default_user_form);

# 13 digits barcode, so that it is not normalized in urls
my $code = '2000000000376';
# products need to be sold in France to be listed on the French subdomains
edit_product(
	$ua,
	{
		%{dclone(\%empty_product_form)},
		(
			code => $code,
			lang => 'en',
			product_name => "Organic carrots",
			labels => "en:organic",
			countries => "en:france",
		)
	}
);
# a product without the organic label, for the facet page with a negative tag
edit_product(
	$ua,
	{
		%{dclone(\%empty_product_form)},
		(
			code => '2000000000377',
			lang => 'en',
			product_name => "Carrots",
			categories => "en:carrots",
			countries => "en:france",
		)
	}
);

# client that does not follow redirects, to check where the language selector links lead
my $ua_no_redirect = new_client();
$ua_no_redirect->max_redirect(0);

# Return the path of the link to the $target_subdomain in the language selector of a page
sub get_language_selector_link ($path, $subdomain, $target_subdomain) {
	my $response = $ua->get(construct_test_url($path, $subdomain));
	ok($response->is_success, "GET $path on $subdomain") or diag $response->status_line;
	# only look at the links in the country and language selection menu
	my ($menu) = $response->decoded_content =~ /class="country_language_selection">(.*?)<\/ul>\s*<\/li>\s*<\/ul>/s;
	# links have a scheme (http://) in the actual pages (it is removed in the stored expected results)
	if ((defined $menu) and ($menu =~ /<a href="(?:https?:)?\/\/\Q$target_subdomain\E\.[^\/"]+([^"]*)">/)) {
		return $1;
	}
	diag("no link to $target_subdomain found in the language selection menu");
	return;
}

subtest 'Facet page' => sub {
	my $link = get_language_selector_link('/facets/labels/en:organic', 'fr-en', 'fr');
	is($link, '/facets/labels/en:organic', 'link to the French version of the facet page');

	my $response = $ua_no_redirect->get(construct_test_url($link, 'fr'));
	is($response->code, 302, 'the French subdomain redirects to its canonical url');
	like($response->header('Location'), qr{/facets/labels/}, 'redirect to the labels facet');
	unlike($response->header('Location'), qr{en:organic}, 'redirect to the French name of the label');
};

subtest 'Facet page with a negative tag and a group by' => sub {
	my $link = get_language_selector_link('/facets/labels/-en:organic/categories', 'fr-en', 'fr');
	is($link, '/facets/labels/-en:organic/categories', 'link keeps the negative tag and the group by');
};

subtest 'Product page' => sub {
	my $link = get_language_selector_link("/product/$code", 'fr', 'fr-en');
	is($link, "/product/$code", 'link to the English version of the product page');

	my $response = $ua_no_redirect->get(construct_test_url($link, 'fr-en'));
	is($response->code, 302, 'the English subdomain redirects to the canonical product url');
	like($response->header('Location'), qr{/product/$code/organic-carrots}, 'redirect to the English product url');
};

subtest 'Search page keeps the query parameters' => sub {
	my $link = get_language_selector_link('/search?search_terms=carrots&page_size=5', 'fr', 'fr-en');
	is($link, '/search?search_terms=carrots&amp;page_size=5', 'link keeps the (HTML escaped) query parameters');
};

subtest 'Home page' => sub {
	my $link = get_language_selector_link('/', 'fr', 'fr-en');
	is($link, '/', 'link to the home page');
};

done_testing();
