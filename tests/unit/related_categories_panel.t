#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Display;
use ProductOpener::KnowledgePanelsTags qw/create_tag_knowledge_panels/;

my $category_id = "en:breakfast-cereals";

# counts as returned by the Query aggregate: the category itself, a parent, a child with a tie, a non child
my @aggregate_results = (
	{_id => "en:breakfast-cereals", count => 27595},
	{_id => "en:breakfasts", count => 27595},
	{_id => "en:flakes", count => 6150},
	{_id => "en:cereal-flakes", count => 5960},
	{_id => "en:mueslis", count => 8605},
	{_id => "en:puffed-cereals", count => 100},
	{_id => "en:porridge", count => 100},
);

my @queries = ();
my $aggregate_response;
my %form = ();
my %cache = ();
my $can_use_off_query = 1;

my $tags_module = mock 'ProductOpener::KnowledgePanelsTags' => (
	override => [
		execute_aggregate_tags_query => sub ($query) {
			push @queries, $query;
			if (ref($aggregate_response) eq "CODE") {
				return $aggregate_response->();
			}
			return $aggregate_response;
		},
		can_use_off_query => sub ($data_debug_ref) {
			return $can_use_off_query;
		},
	]
);

my $data_module = mock 'ProductOpener::Data' => (
	override => [
		single_param => sub ($name) {
			return scalar $form{$name};
		}
	]
);

my $memcached_module = mock 'Cache::Memcached::Fast' => (
	override => [
		get => sub ($memd, $key) {
			return $cache{$key};
		},
		set => sub ($memd, $key, $value, $ttl) {
			$cache{$key} = $value;
			return 1;
		},
	]
);

sub build_panel ($tagtype, $tagid, $options_ref, $request_ref = {}) {
	$ProductOpener::Display::lc = "en";
	my $tag_ref = {};
	$request_ref->{cc} //= "world";
	create_tag_knowledge_panels($tag_ref, "en", $request_ref->{cc}, $options_ref, $tagtype, $tagid, $request_ref);
	return $tag_ref->{knowledge_panels_en};
}

sub reset_state () {
	@queries = ();
	%cache = ();
	%form = ();
	$can_use_off_query = 1;
	$aggregate_response = [@aggregate_results];
	return;
}

my %on = (activate_knowledge_panel_related_categories => 1);

# default off: no panel, no query
reset_state();
my $panels_ref = build_panel("categories", $category_id, {});
ok(!exists $panels_ref->{related_categories}, "default off - no related_categories panel");
is(scalar @queries, 0, "default off - no query");

# happy path
reset_state();
$panels_ref = build_panel("categories", $category_id, {%on});
is(scalar @queries, 1, "happy path - exactly one query");
is($panels_ref->{root}{elements}[-1]{panel_element}{panel_id},
	"related_categories", "happy path - listed in the root panel");
my $tables_ref = $panels_ref->{related_categories}{elements};
is(
	[map {$_->{table_element}{id}} @$tables_ref],
	["related_categories_parents", "related_categories_children"],
	"happy path - parents then children"
);
my @parents = map {$_->{values}[0]{text}} @{$tables_ref->[0]{table_element}{rows}};
ok((grep {$_ eq "Breakfasts"} @parents), "happy path - parent listed") or diag explain \@parents;
my @children_rows = @{$tables_ref->[1]{table_element}{rows}};
is(
	[map {$_->{values}[1]{text}} @children_rows],
	["8605", "5960", "100", "100"],
	"children sorted by count, biggest first"
);
is(
	[map {$_->{values}[0]{text}} @children_rows],
	["Mueslis", "Cereal flakes", "Porridge", "Puffed cereals"],
	"children names, tie sorted by name; non children and the category itself are not listed"
) or diag explain \@children_rows;
like($children_rows[0]{values}[0]{url}, qr/\/mueslis$/, "child links to its page");

# the query matches on the category only for the world
is($queries[0][0], {'$match' => {categories_tags => $category_id}}, "world - match on the category only");

# country
reset_state();
build_panel("categories", $category_id, {%on}, {cc => "fr", country => "en:france"});
is($queries[0][0]{'$match'}{countries_tags}, "en:france", "country - match includes the country");

# not a category
reset_state();
$panels_ref = build_panel("labels", "en:organic", {%on});
ok(!exists $panels_ref->{related_categories}, "labels - no related_categories panel");
is(scalar @queries, 0, "labels - no query");

# unknown category
reset_state();
$panels_ref = build_panel("categories", "en:not-a-category", {%on});
ok(!exists $panels_ref->{related_categories}, "unknown category - no panel");
is(scalar @queries, 0, "unknown category - no query");

# failures: no panel, other panels unaffected, no die
foreach my $failure (
	["query unavailable", sub {$can_use_off_query = 0}],
	["no response", sub {$aggregate_response = undef}],
	["invalid response", sub {$aggregate_response = sub {die "malformed JSON"}}],
	)
{
	reset_state();
	$failure->[1]->();
	my $failure_panels_ref;
	ok(lives {$failure_panels_ref = build_panel("categories", $category_id, {%on})}, "$failure->[0] - does not die");
	ok(!exists $failure_panels_ref->{related_categories}, "$failure->[0] - no related_categories panel");
}

# cache
reset_state();
build_panel("categories", $category_id, {%on});
build_panel("categories", $category_id, {%on});
is(scalar @queries, 1, "cache - second build does not query");
$form{no_cache} = 1;
build_panel("categories", $category_id, {%on});
is(scalar @queries, 2, "cache - no_cache queries again");

done_testing();
