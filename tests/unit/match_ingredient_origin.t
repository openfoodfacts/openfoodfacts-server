use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Ingredients qw/match_ingredient_origin init_origins_regexps/;

my @tests = (

	{
		desc => "Empty",
		lc => "en",
		text => "",
		expected => [],
	},
	{
		desc => "Just a country",
		lc => "en",
		text => "Italy",
		expected => [],
	},
	{
		desc => "Rubish entry",
		lc => "en",
		text => "NNSTeia nauns",
		expected => [],
	},
	{
		desc => "simple en extraction",
		lc => "en",
		text => "Sugar from Italy.",
		expected => [
			{
				ingredient => 'Sugar',
				matched_text => 'Sugar from Italy.',
				origins => 'Italy'
			}
		],
	},
	{
		desc => "simple fr extraction",
		lc => "fr",
		text => "Sucre France.",
		expected => [
			{
				ingredient => 'Sucre',
				matched_text => 'Sucre France.',
				origins => 'France'
			}
		],
	},
	{
		desc => "Real well written case in fr",
		lc => "fr",
		text =>
			"amandes d'Espagne. Chocolat noir de Côte d'Ivoire. Huile de noisette d'Italie. sucre de France. noisettes d'Italie. fèves de cacao de Côte d'Ivoire. Framboises lyophilisées d'Espagne. arôme naturel de framboise fabriqué en France.",
		expected => [
			{
				'ingredient' => 'amandes',
				'matched_text' => 'amandes d\'Espagne.',
				'origins' => 'Espagne'
			},
			{
				'ingredient' => 'Chocolat noir',
				'matched_text' => "  Chocolat noir de Côte d'Ivoire.",
				'origins' => "Côte d'Ivoire"
			},
			{
				'ingredient' => 'Huile de noisette',
				'matched_text' => '  Huile de noisette d\'Italie.',
				'origins' => 'Italie'
			},
			{
				'ingredient' => 'sucre',
				'matched_text' => '  sucre de France.',
				'origins' => 'France'
			},
			{
				'ingredient' => 'noisettes',
				'matched_text' => '  noisettes d\'Italie.',
				'origins' => 'Italie'
			},
			{
				'ingredient' => "fèves de cacao",
				'matched_text' => "  fèves de cacao de Côte d'Ivoire.",
				'origins' => "Côte d'Ivoire"
			},
			{
				'ingredient' => "Framboises lyophilisées",
				'matched_text' => "  Framboises lyophilisées d'Espagne.",
				'origins' => 'Espagne'
			}
		],
	},
	{
		desc => 'German ingredient aus origin',
		lc => 'de',
		text => 'Zucker aus Deutschland, Bio natives Olivenöl extra aus Spanien',
		expected => [
			{
				'ingredient' => 'Zucker',
				'matched_text' => 'Zucker aus Deutschland,',
				'origins' => 'Deutschland'
			},
			{
				'ingredient' => 'Bio natives Olivenöl extra',
				'matched_text' => '  Bio natives Olivenöl extra aus Spanien',
				'origins' => 'Spanien'
			}
		]
	}
);

init_origins_regexps();

foreach my $test_ref (@tests) {
	my $matched_ingredients_ref = [];
	my $result = 1;
	my $input_text = $test_ref->{text};
	while ($result) {
		my $matched_ingredient_ref = {};
		$result = match_ingredient_origin($test_ref->{lc}, \$test_ref->{text}, $matched_ingredient_ref);
		if ($result) {
			push @$matched_ingredients_ref, $matched_ingredient_ref;
		}
	}
	my $expected = $test_ref->{expected};
	is_deeply($matched_ingredients_ref, $expected, $test_ref->{desc})
		|| diag(
		explain(
			{
				lc => $test_ref->{lc},
				input_text => $input_text,
				remaining_text => $test_ref->{text},
				matched => $matched_ingredients_ref,
				expected => $expected
			}
		)
		);
}

done_testing();
