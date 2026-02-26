use strict;
use warnings;
use Test::More;

use ProductOpener::Display qw(add_params_to_query);

my %params = (
    'sugars_100g_serving' => '>=0.2,<10'
);

my %query;

add_params_to_query(\%params, \%query);

ok(exists $query{'nutriments.sugars_100g'}, 'nutrient field created');

ok(exists $query{'nutriments.sugars_100g'}{'$gte'}, 'gte exists');
ok(exists $query{'nutriments.sugars_100g'}{'$lt'}, 'lt exists');

is($query{'nutriments.sugars_100g'}{'$gte'}, 0.2, 'gte parsed correctly');
is($query{'nutriments.sugars_100g'}{'$lt'}, 10, 'lt parsed correctly');

done_testing();
