#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use File::Path qw/make_path/;
use File::Temp qw/tempdir/;
use JSON::MaybeXS qw/decode_json/;
use Test2::V0;
use Test2::Plugin::UTF8;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/$server_domain %options/;
use ProductOpener::Lang;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/store/;

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

subtest 'Compile, export and reload a registered variant with both fallback levels' => sub {
	my $case_dir = tempdir(CLEANUP => 1);
	make_path("$case_dir/po/common", "$case_dir/po/tags", "$case_dir/public", "$case_dir/data");
	my %english = (
		add => 'Add',
		base_only => 'Base fallback',
		english_only => 'English fallback',
		greeting => 'Welcome to <<site_name>>',
		formatted => 'Hello {name}',
	);
	my %catalogs = (
		en => \%english,
		pt => {
			add => 'Adicionar',
			base_only => 'Texto português',
			greeting => 'Bem-vindo a <<site_name>>',
			formatted => 'Olá {name}',
		},
		pt_BR => {add => 'Adicionar Brasil', base_only => ''},
		pt_PT => {add => 'Unregistered translation'},
	);
	foreach my $catalog (sort keys %catalogs, 'common') {
		my $extension = $catalog eq 'common' ? 'pot' : 'po';
		open(my $fh, '>:encoding(UTF-8)', "$case_dir/po/common/$catalog.$extension")
			or die "Cannot write catalog: $!";
		print {$fh} "msgid \"\"\nmsgstr \"\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"\n\n";
		my $strings_ref = $catalog eq 'common' ? \%english : $catalogs{$catalog};
		foreach my $key (sort keys %{$strings_ref}) {
			my $translation = $catalog eq 'common' ? '' : $strings_ref->{$key};
			print {$fh} "msgctxt \"$key\"\nmsgid \"$english{$key}\"\nmsgstr \"$translation\"\n\n";
		}
		close($fh) or die "Cannot close catalog: $!";
	}
	write_tag_catalog($case_dir, 'en', 'category', 'categories');
	write_tag_catalog($case_dir, 'pt', 'categoria-base', 'categorias-base');
	write_tag_catalog($case_dir, 'pt_BR', 'categoria-br', '');
	write_tag_catalog($case_dir, 'pt_PT', 'unregistered', 'unregistered');

	# The builders take an explicit registry. Normalizing the taxonomy-derived registry
	# and enabling regional request languages are separate from catalog compilation.
	my $languages_ref = {
		en => {en => 'English'},
		pt => {pt => 'Português'},
		pt_BR => {pt_BR => 'Português (Brasil)'},
	};
	local $ProductOpener::Lang::data_root = $case_dir;
	local $BASE_DIRS{PUBLIC_DATA} = "$case_dir/public";
	local %ProductOpener::Lang::Lang;
	ProductOpener::Lang::build_lang($languages_ref);
	my $lang_ref = \%ProductOpener::Lang::Lang;
	is($lang_ref->{add}{pt_BR}, 'Adicionar Brasil', 'Keep the regional translation');
	is($lang_ref->{base_only}{pt_BR}, 'Texto português', 'An empty regional translation falls back to Portuguese');
	is($lang_ref->{english_only}{pt_BR}, 'English fallback', 'Fall back to English when Portuguese is also missing');
	is($lang_ref->{greeting}{pt_BR}, "Bem-vindo a $options{site_name}", 'Resolve site placeholders after fallback');
	is(ProductOpener::Lang::f_lang_in_lc('pt_BR', 'formatted', {name => 'Alice'}),
		'Olá Alice', 'Formatted messages use the compiled base-language fallback');
	is([sort keys %{$lang_ref->{add}}], [qw/en pt pt_BR/], 'Only registered languages enter the compiled catalog');

	my $compiled_tags_ref = ProductOpener::Lang::build_lang_tags($languages_ref);
	is($compiled_tags_ref->{tag_type_singular}{categories}{pt_BR}, 'categoria-br', 'Compile the regional tag path');
	is($compiled_tags_ref->{tag_type_plural}{categories}{pt_BR},
		'categorias-base', 'Compile the base-language fallback for the tag path');

	ProductOpener::Lang::build_json();
	open(my $json_fh, '<:raw', "$case_dir/public/i18n/pt_BR/lang.json") or die "Cannot read JSON catalog: $!";
	my $json_ref = decode_json(do {local $/; <$json_fh>});
	close($json_fh) or die "Cannot close JSON catalog: $!";
	is($json_ref->{add}, 'Adicionar Brasil', 'Export the regional translation to JavaScript');
	is($json_ref->{base_only}, 'Texto português', 'Export the Portuguese fallback to JavaScript');
	is($json_ref->{english_only}, 'English fallback', 'Export the English fallback to JavaScript');
	ok(!-d "$case_dir/public/i18n/pt_PT", 'Do not export an unregistered locale');

	store("$case_dir/data/Lang.$server_domain.sto", $lang_ref);
	store("$case_dir/data/Lang_tags.$server_domain.sto", $compiled_tags_ref);
	my $reload_script = <<'PERL';
$ProductOpener::Config::data_root = shift;
$ProductOpener::Paths::BASE_DIRS{PRIVATE_DATA} = "$ProductOpener::Config::data_root/data";
require ProductOpener::Lang;
require JSON::MaybeXS;
print JSON::MaybeXS::encode_json({
    lang => \%ProductOpener::Lang::Lang,
    names => \%ProductOpener::Lang::Langs,
    languages => \@ProductOpener::Lang::Langs,
    tags => {
        tag_type_singular => \%ProductOpener::Lang::tag_type_singular,
        tag_type_plural => \%ProductOpener::Lang::tag_type_plural,
        tag_type_from_singular => \%ProductOpener::Lang::tag_type_from_singular,
        tag_type_from_plural => \%ProductOpener::Lang::tag_type_from_plural,
    },
});
PERL
	open(my $reload_fh, '-|', $^X, '-MProductOpener::Paths', '-e', $reload_script, $case_dir)
		or die "Cannot reload translations: $!";
	my $reloaded_ref = decode_json(do {local $/; <$reload_fh>});
	ok(close($reload_fh), 'Reload both compiled catalogs in a fresh process');
	is($reloaded_ref->{lang}, $lang_ref, 'All translations and fallbacks survive reloading');
	is($reloaded_ref->{tags}, $compiled_tags_ref, 'All tag paths and reverse indexes survive reloading');
	is($reloaded_ref->{languages}, [qw/en pt pt_BR/], 'Reloading does not activate an unregistered locale');
	is(
		$reloaded_ref->{names},
		{map {$_ => $languages_ref->{$_}{$_}} keys %{$languages_ref}},
		'Reloading preserves the registered language names'
	);
	done_testing();
};

done_testing();
