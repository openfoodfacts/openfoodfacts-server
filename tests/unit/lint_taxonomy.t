#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use FindBin qw($Bin);
use Encode qw(encode_utf8 decode_utf8);

# load the lint script functions (the script only runs its main part when called directly)
# lint_taxonomy.pl is a script, not a module, so it cannot be loaded with a bareword include
require "$Bin/../../scripts/taxonomies/lint_taxonomy.pl";    ## no critic (Modules::RequireBarewordIncludes)

# lint a taxonomy given as a string, return the linted text and the list of errors / warnings
sub lint_string ($input, $warn_missing_en = 0) {
	my $input_bytes = encode_utf8($input);
	open(my $in, "<:encoding(UTF-8)", \$input_bytes) or die("can't open input string");
	my $output = "";
	open(my $out, ">:encoding(UTF-8)", \$output) or die("can't open output string");
	my $entries_iterator = iter_taxonomy_entries(iter_taxonomy_lines($in));
	my $errors_ref = lint_taxonomy($entries_iterator, $out, 0, 1, 1, 1, $warn_missing_en);
	close($in);
	close($out);
	return (decode_utf8($output), $errors_ref);
}

my @tests = (
	[
		"en line is moved first (issue #14963)",
		"< en:Pasta sauces\nbg: Аматричана\nfr: Amatriciana\nen: Amatriciana\nit: Amatriciana\n\n",
		"< en: Pasta sauces\nen: Amatriciana\nbg: Аматричана\nfr: Amatriciana\nit: Amatriciana\n\n",
	],
	["en first, xx second", "fr: Truc\nxx: Truc\nen: Thing\n\n", "en: Thing\nxx: Truc\nfr: Truc\n\n",],
	[
		"comments above the first line stay at the top",
		"# about this entry\nde: Kuchen\n# english name\nen: Cake\n\n",
		"# about this entry\n# english name\nen: Cake\nde: Kuchen\n\n",
	],
	[
		"no en line: first line is kept, xx second",
		"it: Pasta\nde: Nudeln\nxx: Pasta\n\n",
		"it: Pasta\nxx: Pasta\nde: Nudeln\n\n",
	],
	[
		"xx first line is never moved (e.g. units)",
		"xx: kg\nen: kilogram\nfr: kilogramme\n\n",
		"xx: kg\nen: kilogram\nfr: kilogramme\n\n",
	],
	[
		"zz first line is never moved (e.g. nutrients)",
		"zz: energy-kcal\nxx: Energy (kcal)\nen: Energy (kcal)\n\n",
		"zz: energy-kcal\nxx: Energy (kcal)\nen: Energy (kcal)\n\n",
	],
	["stopwords are untouched", "stopwords:fr: le, la\n\n", "stopwords:fr: le, la\n\n",],
);

foreach my $test (@tests) {
	my ($name, $input, $expected) = @$test;
	my ($output, $errors_ref) = lint_string($input);
	is($output, $expected, $name);
	is(scalar @$errors_ref, 0, "$name - no errors");
}

# warning for entries without en: (only with the option)
my ($output, $errors_ref) = lint_string("zh: 某物\nfr: truc\n\nxx: CE\nfr: CE\n\n", 1);
is(scalar @$errors_ref, 1, "one missing en: warning (xx: entries do not need en:)");
is($errors_ref->[0]{severity}, "Warning", "missing en: is a warning, not an error");
($output, $errors_ref) = lint_string("zh: 某物\nfr: truc\n\n", 0);
is(scalar @$errors_ref, 0, "no missing en: warning without the option");

done_testing();
