use strict;
use warnings;
use Test::More;

use ProductOpener::Display qw(add_params_to_query);

my %params = (
    'sugars_100g_serving' => '>=0.2,<10'
);

my %query;

add_params_to_query(\%params, \%query);

ok(exists $query{'nutriments.sugars_100g'});
ok(exists $query{'nutriments.sugars_100g'}{'$gte'});
ok(exists $query{'nutriments.sugars_100g'}{'$lt'});

is($query{'nutriments.sugars_100g'}{'$gte'}, 0.2);
is($query{'nutriments.sugars_100g'}{'$lt'}, 10);

my %params_with_unit = (
    'sugars_100g_serving' => '>=0.2g,<10g'
);

my %query_with_unit;

add_params_to_query(\%params_with_unit, \%query_with_unit);

is($query_with_unit{'nutriments.sugars_100g'}{'$gte'}, 0.2);
is($query_with_unit{'nutriments.sugars_100g'}{'$lt'}, 10);

done_testing();