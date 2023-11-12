#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::Test qw/:all/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/:all/;

# index in mongo
my $test_collection = get_collection($mongodb, 'test_coll');
# clean
$test_collection->delete_many({});

# create some data
my @data = ();
for (my $i = 0; $i < 100; $i++) {
	push @data, {_id => "$i", "name" => "element $i"};
}
$test_collection->insert_many(\@data);

is($test_collection->count_documents({}), 100);

# now remove lot of documents, last are non existing
my @ids = map {"$_"} (0 .. 9, 20 .. 49, 60 .. 79, 81 .. 99, 110 .. 120);
my $result = remove_documents_by_ids(\@ids, $test_collection, 10);
is($result->{removed}, 79);
is(scalar @{$result->{errors}}, 0);
is($test_collection->count_documents({}), 21);

@ids = ();    # no removal
$result = remove_documents_by_ids(\@ids, $test_collection, 1000);
is($result->{removed}, 0);
is(scalar @{$result->{errors}}, 0);
is($test_collection->count_documents({}), 21);

# remove all remaining but one
@ids = map {"$_"} (0 .. 19, 50 .. 59, "a");
$result = remove_documents_by_ids(\@ids, $test_collection, 1000);
is($result->{removed}, 20);
is(scalar @{$result->{errors}}, 0);
is($test_collection->count_documents({}), 1);

# clean
$test_collection->delete_many({});

done_testing();
