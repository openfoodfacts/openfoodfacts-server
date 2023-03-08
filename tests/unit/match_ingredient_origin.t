use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Ingredients qw/match_ingredient_origin init_origins_regexps/;

my @tests = (

	{
		desc => "Empty",
		lc => "en",
		text => "",
		expected => {},
	},
	{
		desc => "Just a country",
		lc => "en",
		text => "Italy",
		expected => {},
	},
	{
		desc => "Rubish entry",
		lc => "en",
		text => "NNSTeia nauns",
		expected => {},
	},
	{
		desc => "simple en extraction",
		lc => "en",
		text => "Sugar from Italy.",
		expected => {
			ingredient => 'Sugar',
			matched_text => 'Sugar from Italy.',
			origins => 'Italy'
		},
	},
	{
		desc => "simple fr extraction",
		lc => "fr",
		text => "Sucre France.",
		expected => {
			ingredient => 'Sucre',
			matched_text => 'Sucre France.',
			origins => 'France'
		},
	},
	{
		desc => "Real well written case in fr",
		lc => "fr",
		text =>
			"amandes d’Espagne. Chocolat noir de Côte d’Ivoire. Huile de noisette d’Italie. sucre de France. noisettes d’Italie. fèves de cacao de Côte d’Ivoire. Framboises lyophilisées d’Espagne. arôme naturel de framboise fabriqué en France.",
		expected => {
			"amandes" => "Espagne",
			"Chocolat noir" => "Côte d’Ivoire",
			"Huile de noisette" => "Italie",
			"sucre" => "France",
			"noisettes" => "Italie",
			"fèves de cacao" => "Côte d’Ivoire",
			"Framboises lyophilisées" => "Espagne" . "arôme naturel de framboise" => "France",
		},
	}
);

init_origins_regexps();

foreach my $test_ref (@tests) {
	my $matched_ingredients_ref = {};
	my $result = 1;
	while ($result) {
		$result = match_ingredient_origin($test_ref->{lc}, \$test_ref->{text}, $matched_ingredients_ref);
	}
	my $expected = $test_ref->{expected};
	is_deeply($matched_ingredients_ref, $expected, $test_ref->{desc})
		|| diag(explain({matched => $matched_ingredients_ref, expected => $expected}));
}

done_testing();
