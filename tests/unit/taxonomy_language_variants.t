#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use File::Basename qw/dirname/;
use File::Path qw/make_path/;
use File::Temp qw/tempdir/;
use JSON::MaybeXS qw/decode_json/;
use Test2::V0;
use Test2::Plugin::UTF8;
use Log::Any::Adapter 'TAP';

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Tags qw/build_tags_taxonomy retrieve_tags_taxonomy canonicalize_taxonomy_tag
	display_taxonomy_tag display_taxonomy_tag_name get_property is_a sanitize_taxonomy_line/;

my $dir = tempdir(CLEANUP => 1);
make_path("$dir/cache/taxonomies", "$dir/public");
local $BASE_DIRS{TAXONOMIES_SRC} = dirname(__FILE__) . '/inputs/taxonomy_language_variants';
local $BASE_DIRS{CACHE_BUILD} = "$dir/cache";
local $BASE_DIRS{PUBLIC_DATA} = "$dir/public";
local $ENV{TAXONOMY_NO_GET_FROM_CACHE} = 1;
local $ENV{GITHUB_TOKEN} = '';

is([build_tags_taxonomy('regional_test', 1)], [], 'Compile regional prefixes without taxonomy errors');
retrieve_tags_taxonomy('regional_test', 1);

subtest 'Regional matching and base-language fallback' => sub {
	foreach my $case_ref (
		['pt', 'Cuscuz', 'en:wheat-couscous'],
		['pt_BR', 'Cuscuz', 'en:corn-couscous'],
		['pt-br', 'Cuscuz', 'en:corn-couscous'],
		['pt_br', 'Cuscuz', 'en:corn-couscous'],
		['pt_PT', 'Cuscuz', 'en:wheat-couscous'],
		['en', 'pt-br:Cuscuz', 'en:corn-couscous'],
		['pt_BR', 'pt:Cuscuz', 'en:wheat-couscous'],
		['pt_BR', 'Sal', 'en:salt'],
		['pt_BR', 'de Sal', 'en:salt'],
		['pt_BR', 'Creme leite', 'en:cream'],
		['fr_CA', 'specialite regionale', 'en:french-specialty'],
		['zh_Hant_HK', '繁體', 'en:chinese-label'],
		['zh_Hant_HK', '中文', 'en:chinese-label'],
		['pt_BR', 'Universal name', 'xx:universal-name'],
		['pt_BR', 'English only', 'en:english-only'],
		['pt_br', 'Especialidade regional', 'pt_BR:especialidade-regional'],
		)
	{
		my ($language, $text, $expected) = @{$case_ref};
		my $exists;
		is(canonicalize_taxonomy_tag($language, 'regional_test', $text, \$exists), $expected, "$language: $text");
		is($exists, 1, 'The match exists in the taxonomy');
	}
	my $exists;
	is(canonicalize_taxonomy_tag('pt-br', 'regional_test', 'Desconhecido', \$exists),
		'pt_BR:Desconhecido', 'An unknown term retains its regional context');
	is($exists, 0, 'Fallback does not invent a match');
};

subtest 'Regional display names' => sub {
	foreach my $case_ref (
		['pt', 'en:cream', 'Natas'],
		['pt_BR', 'en:cream', 'Creme de leite'],
		['pt-br', 'en:cream', 'Creme de leite'],
		['pt_PT', 'en:cream', 'Natas'],
		['pt_BR', 'en:salt', 'Sal'],
		['zh_Hant_TW', 'en:chinese-label', '臺灣'],
		['zh_Hant_HK', 'en:chinese-label', '繁體'],
		['zh_Hans', 'en:chinese-label', '中文'],
		['pt_BR', 'xx:universal-name', 'Universal name'],
		['pt_BR', 'en:english-only', 'en:English only'],
		['pt_BR', 'pt:Desconhecido', 'Desconhecido'],
		['pt_BR', 'pt_br:especialidade-regional', 'Especialidade regional'],
		)
	{
		my ($language, $tag, $expected) = @{$case_ref};
		is(display_taxonomy_tag($language, 'regional_test', $tag), $expected, "$language: $tag");
	}
	is(
		display_taxonomy_tag_name('en', 'regional_test', 'pt_BR:especialidade-regional'),
		'Especialidade regional',
		'Remove the full regional prefix for display'
	);
};

subtest 'Hierarchy, properties and exports' => sub {
	ok(is_a('regional_test', 'en:regional-child', 'pt_BR:especialidade-regional'),
		'A parent reference accepts a regional prefix');
	is(
		get_property('regional_test', 'en:cream', 'description:pt_BR'),
		'Nome regional',
		'Normalize property language codes'
	);
	is(get_property('regional_test', 'en:cream', 'url:en'),
		'https://example.org/cream', 'Do not confuse a three-letter property name with a language');
	is(
		get_property('regional_test', 'pt_BR:especialidade-regional', 'description:pt_BR'),
		'Propriedade regional',
		'Load regional entries from the separate properties file'
	);
	foreach my $suffix ('', '.full', '.extended') {
		open(my $fh, '<:raw', "$dir/public/taxonomies/regional_test$suffix.json") or die $!;
		my $export_ref = decode_json(do {local $/; <$fh>});
		close($fh);
		is(
			$export_ref->{'en:cream'}{name},
			{en => 'Cream', pt => 'Natas', pt_BR => 'Creme de leite'},
			"Names survive the $suffix JSON export"
		);
		is($export_ref->{'en:chinese-label'}{name}{zh_Hant_TW}, '臺灣', 'Preserve script and region');
		is($export_ref->{'en:numeric-region'}{name}{es_419}, 'Nombre regional', 'Preserve numeric regions');
		is($export_ref->{'en:three-letter-language'}{name}{kmr_TR}, 'Navê herêmî', 'Preserve three-letter codes');
	}
};

subtest 'Prefix normalization leaves values alone' => sub {
	is(sanitize_taxonomy_line('synonyms:pt-br: Nome'), 'synonyms:pt_BR: Nome', 'Normalize a synonym prefix');
	is(sanitize_taxonomy_line('stopwords:pt-br: de'), 'stopwords:pt_BR: de', 'Normalize a stopword prefix');
	is(
		sanitize_taxonomy_line('description:en: pt_br: is an example'),
		'description:en: pt_br: is an example',
		'Do not rewrite a property value'
	);
	is(sanitize_taxonomy_line('pt_BR_extra: Invalid'), 'pt_BR_extra: Invalid', 'Reject unsupported suffixes');
};

done_testing();
