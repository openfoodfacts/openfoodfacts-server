use ProductOpener::PerlStandards;


use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Ingredients qw/match_ingredient_origin init_origins_regexps/;

my @tests = (
    {
        desc => "simple fr extraction",
        lc => "fr",
        text => "Sucre France.",
        expected => {
            "sucre" => "france",
        },
    }
);

init_origins_regexps();

foreach my $test_ref (@tests) {
    my $matched_ingredients_ref = {};
    match_ingredient_origin($test_ref->{lc}, \{$test_ref->{text}}, $matched_ingredients_ref);
	my $expected = $test_ref->{expected};
	is_deeply($matched_ingredients_ref, $expected, $test_ref->{desc}) || diag(explain({matched => $matched_ingredients_ref, expected => $expected}));
}

done_testing();