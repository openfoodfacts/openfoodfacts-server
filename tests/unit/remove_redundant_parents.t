use ProductOpener::PerlStandards;
use Test2::V0;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);

require(abs_path(dirname(__FILE__) . "/../../scripts/taxonomies/remove_redundant_parents.pl"));

my $tmp = tempdir(CLEANUP => 1);

sub write_file ($name, $text) {
	open(my $out, '>:encoding(UTF-8)', "$tmp/$name") or die $!;
	print $out $text;
	close($out) or die $!;
	return "$tmp/$name";
}

sub read_file ($path) {
	open(my $in, '<:encoding(UTF-8)', $path) or die $!;
	local $/;
	my $text = <$in>;
	close($in);
	return $text;
}

my $taxonomy = <<'TAXONOMY';
stopwords:fr: de, des

en: Foods
fr: Aliments

< en: Foods
en: Canned foods
fr: Conserves

< en: Canned foods
en: Canned seafood
fr: Conserves de produits de la mer

# grandparent listed as a parent
< en: Canned foods
< en: Canned seafood
en: Canned shrimps
fr: Crevettes en conserve
wikidata:en: Q1

# grandparent written with a synonym in another language, after the parent
< fr: Conserves de produits de la mer
# comment kept
< fr: conserve
en: Canned mussels
description:en: some text

# great-grandparent, and the same parent written twice
< en: Canned shrimps
< en: Foods
< fr: Crevettes en conserve
en: Canned shrimps in brine

< en: Foods
xx: Jamón ibérico
en: Iberian ham

# a parent written with an xx: name in another language
< fr: Jamón ibérico
< en: Foods
fr: Jamón ibérico de bellota

# cycle
< en: Cycle B
en: Cycle A

< en: Cycle A
en: Cycle B

< en: Cycle A
< en: Cycle B
en: Cycle child

< en: Unknown parent
< en: Foods
en: Orphan
TAXONOMY

my $file = write_file("sample.txt", $taxonomy);

my $taxonomy_ref = load_taxonomy([$file]);
my $redundant_ref = find_redundant_parents($taxonomy_ref);

is(
	[map {[$_->{entry}, $_->{parent}{line}, $_->{implied_by}{line}, join(" > ", @{$_->{path}})]} @$redundant_ref],
	[
		["en:canned-shrimps", "< en: Canned foods", "< en: Canned seafood", "en:canned-seafood > en:canned-foods"],
		[
			"en:canned-mussels",
			"< fr: conserve",
			"< fr: Conserves de produits de la mer",
			"en:canned-seafood > en:canned-foods"
		],
		[
			"en:canned-shrimps-in-brine", "< en: Foods",
			"< en: Canned shrimps",
			"en:canned-shrimps > en:canned-foods > en:foods"
		],
		["en:canned-shrimps-in-brine", "< fr: Crevettes en conserve", "< en: Canned shrimps", "en:canned-shrimps"],
		["fr:jamon-iberico-de-bellota", "< en: Foods", "< fr: Jamón ibérico", "xx:jamon-iberico > en:foods"],
	],
	"unnecessary parents"
);

is(
	[map {[$_->{entry}, $_->{line}]} @{$taxonomy_ref->{unknown_parents}}],
	[["en:orphan", "< en: Unknown parent"]],
	"unknown parents"
);

is([map {$_->{parent}{line_num}} @$redundant_ref], [15, 24, 30, 31, 40], "line numbers of unnecessary parents");

my $report = format_report($redundant_ref, $taxonomy_ref->{unknown_parents});
like($report, qr/^\Q$file\E:15: en:canned-shrimps \(en: Canned shrimps\)$/m, "report has file, line and entry");
like($report, qr/^\tunnecessary: < en: Canned foods$/m, "report has the unnecessary parent");
like(
	$report,
	qr/^\talready implied by: < en: Canned seafood \(line 16\) - en:canned-seafood > en:canned-foods$/m,
	"report has the parent that implies it"
);
like($report, qr/^\tsame entry as: < en: Canned shrimps \(line 29\)$/m, "report has duplicate parents");

# fix: only the unnecessary parent lines are removed
remove_redundant_parents($taxonomy_ref, $redundant_ref);
my %removed = map {$_ => 1} (15, 24, 30, 31, 40);
my $line_num = 0;
my $expected = join("", grep {not $removed{++$line_num}} split(/^/, $taxonomy));
is(read_file($file), $expected, "fixed taxonomy");

# running again finds nothing
is(find_redundant_parents(load_taxonomy([$file])), [], "no unnecessary parents after fix");

# several files are loaded as a single taxonomy, only the file with the entry is changed
my $file1 = write_file("first.txt", "en: Foods\n\n< en: Foods\nen: Canned foods\n");
my $file2 = write_file("second.txt", "< en: Foods\n< en: Canned foods\nen: Canned peas\n");
my $multi_ref = load_taxonomy([$file1, $file2]);
my $multi_redundant_ref = find_redundant_parents($multi_ref);
is([map {[$_->{file}, $_->{parent}{line_num}]} @$multi_redundant_ref], [[$file2, 1]], "parents across files");
remove_redundant_parents($multi_ref, $multi_redundant_ref);
is(read_file($file1), "en: Foods\n\n< en: Foods\nen: Canned foods\n", "other file unchanged");
is(read_file($file2), "< en: Canned foods\nen: Canned peas\n", "file fixed");

done_testing();
