#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use File::Temp qw/tempdir/;
use Test2::V0;
use Test2::Plugin::UTF8;
use Log::Any::Adapter 'TAP';

use ProductOpener::I18N;

sub write_po_file ($path, $translation) {

	open(my $fh, '>:encoding(UTF-8)', $path) or die "Cannot write $path: $!";
	print {$fh} <<PO;
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\\n"
"Language: ignored\\n"

msgctxt "greeting"
msgid "Hello"
msgstr "$translation"

msgctxt "untranslated"
msgid "Not translated yet"
msgstr ""

PO
	close($fh) or die "Cannot close $path: $!";
	return;
}

subtest 'Load regional catalogs without merging their translations' => sub {
	my $dir = tempdir(CLEANUP => 1);
	my %translations = (
		ast => 'Asturian translation',
		en => 'Hello',
		en_GB => 'Hello from the UK',
		es => 'Hola',
		es_419 => 'Latin American Spanish translation',
		kmr_TR => 'Kurdish translation',
		pt => 'Olá',
		pt_PT => 'Olá de Portugal',
		pt_BR => 'Olá do Brasil',
		zh => '你好',
		zh_CN => '简体中文',
		zh_TW => '繁體中文',
		zh_HK => '香港繁體中文',
	);
	foreach my $language (sort keys %translations) {
		write_po_file("$dir/$language.po", $translations{$language});
	}

	my $terms_ref = ProductOpener::I18N::read_po_files($dir);
	foreach my $language (sort keys %translations) {
		is(
			$terms_ref->{greeting}{$language},
			$translations{$language},
			"Keep the $language translation under its own code"
		);
	}
	is($terms_ref->{greeting}, \%translations, 'Catalog names determine the language, not the PO header');
	is($terms_ref->{untranslated}, {}, 'Empty translations stay absent so the caller can apply a fallback');
	is([sort keys %{$terms_ref}], ['greeting', 'untranslated'], 'Gettext metadata is not exposed as translations');
	is(ProductOpener::I18N::read_po_files("$dir/"), $terms_ref, 'A trailing slash does not change the result');
	is(
		ProductOpener::I18N::read_po_files($dir, {pt => {}, zh => {}})->{greeting},
		{pt => $translations{pt}, zh => $translations{zh}},
		'Loading catalogs for a language registry does not implicitly enable variants'
	);
	is(
		ProductOpener::I18N::read_po_files($dir, {ast => {}, es_419 => {}, kmr_TR => {}, pt_BR => {}, zh_TW => {}})
			->{greeting},
		{map {$_ => $translations{$_}} qw/ast es_419 kmr_TR pt_BR zh_TW/},
		'Explicitly registered variants retain their full language codes'
	);
	is(ProductOpener::I18N::read_po_files($dir, {pt_br => {}}), {}, 'Registry keys must match the catalog code case');
	is(ProductOpener::I18N::read_po_files($dir, {}), {}, 'An empty language registry loads no catalogs');
	done_testing();
};

subtest 'Validate the complete catalog filename' => sub {
	my $dir = tempdir(CLEANUP => 1);
	foreach my $filename (
		'ptXpo.po', 'pt.po.backup.po', 'pt_BR_extra.po', 'invalid.po', 'abcd.po', 'ast_TR_extra.po',
		'es_41.po', 'es_4190.po', 'es_4A9.po'
		)
	{
		write_po_file("$dir/$filename", 'Not a language catalog');
	}
	is(ProductOpener::I18N::read_po_files($dir), {}, 'Ignore filenames that only partially match a language code');
	done_testing();
};

subtest 'Use the filename, not a parent directory, as the language code' => sub {
	my $dir = tempdir(CLEANUP => 1);
	mkdir("$dir/fr.po") or die "Cannot create nested directory: $!";
	write_po_file("$dir/fr.po/pt_BR.po", 'Olá do Brasil');
	is(
		ProductOpener::I18N::read_po_files($dir),
		{greeting => {pt_BR => 'Olá do Brasil'}, untranslated => {}},
		'A directory that looks like a catalog does not change the language'
	);
	done_testing();
};

done_testing();
