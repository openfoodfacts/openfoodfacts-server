#!/usr/bin/perl -w

# The recent changes list is served to anonymous callers, and both the page and the page size come
# from the request. MongoDB walks over every skipped document on a $natural sort, so a request for
# a deep offset is expensive to serve and trivial to ask for; the page and the page size are capped
# separately, so their product has to be capped too.
#
# The json response returns the page, page size and skip that were actually served, which is what
# we check here: the changes themselves depend on what the other tests have written.

use ProductOpener::PerlStandards;

use Test2::V0;
use JSON::MaybeXS;
use ProductOpener::APITest qw/construct_test_url new_client wait_application_ready/;
use ProductOpener::Config qw/:all/;

wait_application_ready(__FILE__);

my $ua = new_client();

# Returns the page, page size and skip of the json response
sub served_paging ($query) {

	my $response = $ua->get(construct_test_url("/cgi/recent_changes.pl?json=1&$query"));
	is($response->code, 200, "$query - the page is served");

	if ($response->code != 200) {
		return {};
	}

	my $response_ref = decode_json($response->decoded_content);

	return {page => $response_ref->{page}, page_size => $response_ref->{page_size}, skip => $response_ref->{skip}};
}

# The first pages are served as they are asked for

is(served_paging("page=1"), {page => 1, page_size => 20, skip => 0}, "the first page is served");
is(served_paging("page=2&page_size=20"), {page => 2, page_size => 20, skip => 20}, "the second page is served");
is(served_paging("page_size=5"), {page => 1, page_size => 5, skip => 0}, "the page size is used");

# A page beyond the maximum is the first page

is(
	served_paging("page=1001&page_size=20"),
	{page => 1, page_size => 20, skip => 0},
	"a page above the maximum is the first page"
);
is(served_paging("page=0"), {page => 1, page_size => 20, skip => 0}, "page 0 is the first page");
is(served_paging("page=-1"), {page => 1, page_size => 20, skip => 0}, "a negative page is the first page");

# A page size that is not a positive number does not make the script fail, and does not stay 0:
# MongoDB reads a limit of 0 as "no limit" (every change of the collection), and the pagination
# divides by the page size. An empty or "0" page size falls back to the default.

is(served_paging("page_size=0"), {page => 1, page_size => 20, skip => 0}, "a page size of 0 is the default page size");
is(
	served_paging("page_size=abc"),
	{page => 1, page_size => 1, skip => 0},
	"a page size that is not a number is a page size of 1"
);
is(served_paging("page_size=-1"), {page => 1, page_size => 1, skip => 0}, "a negative page size is a page size of 1");

# The product of page and page size is bounded: both are capped separately, so without a bound on
# the product the largest allowed page of the largest allowed page size asks for a skip of 999,000

my $max_skip = $options{max_recent_changes_skip};
is($max_skip, 10_000, "the maximum skip is configured");

my $max_page_size = $options{max_recent_changes_page_size};

my $deep_paging_ref = served_paging("page=1000&page_size=$max_page_size");
ok($deep_paging_ref->{skip} <= $max_skip, "the skip of the deepest allowed page is bounded");
is($deep_paging_ref->{page_size}, $max_page_size, "the page size is not reduced");
is($deep_paging_ref->{skip}, $max_skip - ($max_page_size - 1), "the skip is the last one that is served");
is(
	$deep_paging_ref->{page},
	int(($max_skip - ($max_page_size - 1)) / $max_page_size) + 1,
	"the page reported is the page that is served"
);

# A deep offset with the default page size is bounded too

my $deep_default_paging_ref = served_paging("page=1000");
ok($deep_default_paging_ref->{skip} <= $max_skip, "the skip of a deep page with the default page size is bounded");

# The first pages are not affected by the bound

my $paging_ref = served_paging("page=100&page_size=20");
is($paging_ref->{skip}, 1980, "a page below the bound keeps its offset");

done_testing();
