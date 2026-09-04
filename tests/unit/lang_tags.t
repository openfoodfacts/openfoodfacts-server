#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use File::Path qw/make_path/;
use File::Temp qw/tempdir/;
use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Lang;

sub write_tag_catalog ($dir, $language, $singular, $plural) {

	open(my $fh, '>:encoding(UTF-8)', "$dir/po/tags/$language.po") or die "Cannot write catalog: $!";
	print {$fh} <<PO;
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\\n"

msgctxt ":langname"
msgid "Language name"
msgstr "$language"

msgctxt ":langtag"
msgid "Language code"
msgstr "$language"

msgctxt "categories:singular"
msgid "category"
msgstr "$singular"

msgctxt "categories:plural"
msgid "categories"
msgstr "$plural"

PO
	close($fh) or die "Cannot close catalog: $!";
	return;
}

my $dir = tempdir(CLEANUP => 1);
make_path("$dir/po/tags");
write_tag_catalog($dir, 'en', 'category', 'categories');
write_tag_catalog($dir, 'pt_BR', 'categoria', 'categorias');

local $ProductOpener::Lang::data_root = $dir;
local @ProductOpener::Lang::Langs = ();
local %ProductOpener::Lang::Langs = ();
local %ProductOpener::Lang::tag_type_singular;
local %ProductOpener::Lang::tag_type_plural;
local %ProductOpener::Lang::tag_type_from_singular;
local %ProductOpener::Lang::tag_type_from_plural;

my $tags_ref = ProductOpener::Lang::build_lang_tags({en => {}, pt_BR => {}});
is(
	$tags_ref->{tag_type_singular}{categories},
	{en => 'category', pt_BR => 'categoria'},
	'Build singular paths from the explicit registry without calling build_lang first'
);
is(
	$tags_ref->{tag_type_plural}{categories},
	{en => 'categories', pt_BR => 'categorias'},
	'Build plural paths from the same explicit registry'
);
is(
	$tags_ref->{tag_type_from_singular},
	{en => {category => 'categories'}, pt_BR => {categoria => 'categories'}},
	'Reverse singular paths include both registered languages'
);
is(
	$tags_ref->{tag_type_from_plural},
	{en => {categories => 'categories'}, pt_BR => {categorias => 'categories'}},
	'Reverse plural paths include both registered languages'
);

$tags_ref = ProductOpener::Lang::build_lang_tags({en => {}});
is($tags_ref->{tag_type_singular}{categories}, {en => 'category'}, 'Only load catalogs from the new registry');
is(
	$tags_ref->{tag_type_from_singular},
	{en => {category => 'categories'}},
	'Rebuilding does not keep singular paths for languages from a previous build'
);
is(
	$tags_ref->{tag_type_from_plural},
	{en => {categories => 'categories'}},
	'Rebuilding does not keep plural paths for languages from a previous build'
);

foreach my $case_ref (
	{
		name => 'Missing regional singular falls back to pt while the regional plural is kept',
		regional => ['', 'categorias-regionais'],
		expected => ['categoria-base', 'categorias-regionais'],
	},
	{
		name => 'Missing regional plural falls back to pt while the regional singular is kept',
		regional => ['categoria-regional', ''],
		expected => ['categoria-regional', 'categorias-base'],
	},
	{
		name => 'Both missing regional paths fall back to pt',
		regional => ['', ''],
		expected => ['categoria-base', 'categorias-base'],
	},
	)
{
	subtest $case_ref->{name} => sub {
		my $case_dir = tempdir(CLEANUP => 1);
		make_path("$case_dir/po/tags");
		write_tag_catalog($case_dir, 'en', 'category', 'categories');
		write_tag_catalog($case_dir, 'pt', 'categoria-base', 'categorias-base');
		write_tag_catalog($case_dir, 'pt_BR', @{$case_ref->{regional}});
		local $ProductOpener::Lang::data_root = $case_dir;
		my $tags_ref = ProductOpener::Lang::build_lang_tags({en => {}, pt => {}, pt_BR => {}});
		my ($singular, $plural) = @{$case_ref->{expected}};
		is($tags_ref->{tag_type_singular}{categories}{pt_BR}, $singular, 'Resolve the singular path');
		is($tags_ref->{tag_type_plural}{categories}{pt_BR}, $plural, 'Resolve the plural path');
		is(
			$tags_ref->{tag_type_from_singular}{pt_BR},
			{$singular => 'categories'},
			'Reverse lookup uses the resolved singular'
		);
		is(
			$tags_ref->{tag_type_from_plural}{pt_BR},
			{$plural => 'categories'},
			'Reverse lookup uses the resolved plural'
		);
		done_testing();
	};
}

write_tag_catalog($dir, 'pt', 'categoria-base', 'categorias-base');
write_tag_catalog($dir, 'pt_BR', '', '');
$tags_ref = ProductOpener::Lang::build_lang_tags({en => {}, pt_BR => {}});
is($tags_ref->{tag_type_singular}{categories}{pt_BR},
	'category', 'Use English when the base language is not registered');
is($tags_ref->{tag_type_plural}{categories}{pt_BR},
	'categories', 'Use English for the plural when the base language is not registered');

done_testing();
