use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Test qw/:all/;

use ProductOpener::Ingredients qw/parse_origins_from_text init_origins_regexps/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	{
		id => "empty",
		desc => "Empty",
		product => {
			lc => "en",
			origin_en => "",
		}
	},
	{
		id => "just-a-country",
		desc => "Just a country",
		product => {
			lc => "en",
			origin_en => "Italy",
		}
	},
	{
		id => "rubish-entry",
		desc => "Rubish entry",
		product => {
			lc => "en",
			origin_en => "NNSTeia nauns",
		}
	},
	{
		id => "simple-extraction-en",
		desc => "simple en extraction",
		product => {
			lc => "en",
			origin_en => "Sugar from Italy.",
		}
	},
	{
		id => "simple-extraction-fr",
		desc => "simple fr extraction",
		product => {
			lc => "fr",
			origin_fr => "Sucre France."
		},
	},
	{
		id => "real-list-fr",
		desc => "Real well written case in fr",
		product => {
			lc => "fr",
			origin_fr =>
				"amandes d’Espagne. Chocolat noir de Côte d’Ivoire. Huile de noisette d’Italie. sucre de France. noisettes d’Italie. fèves de cacao de Côte d’Ivoire. Framboises lyophilisées d’Espagne. arôme naturel de framboise fabriqué en France.",
		},
	}
);

init_origins_regexps();

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->{id};
	my $product_ref = $test_ref->{product};
	my $text = $product_ref->{"origin_" . $product_ref->{lc}};

	parse_origins_from_text($product_ref, $text);

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results, $test_ref);

}

done_testing();
