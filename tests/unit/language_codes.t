#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use Test2::Plugin::UTF8;

use ProductOpener::I18N qw/$language_code_re normalize_language_code language_tag base_language
	language_fallbacks lookup_with_language_fallback/;
use ProductOpener::Lang qw/language_locale/;
use ProductOpener::Store qw/get_string_id_for_lang/;

foreach my $case_ref (
	['pt_BR', 'pt_BR', 'pt-BR', 'pt'],
	['PT-br', 'pt_BR', 'pt-BR', 'pt'],
	['pt_br', 'pt_BR', 'pt-BR', 'pt'],
	['EN', 'en', 'en', 'en'],
	['es-419', 'es_419', 'es-419', 'es'],
	['kmr-tr', 'kmr_TR', 'kmr-TR', 'kmr'],
	['zh-hant-tw', 'zh_Hant_TW', 'zh-Hant-TW', 'zh'],
	['zh_HANS', 'zh_Hans', 'zh-Hans', 'zh'],
	)
{
	my ($input, $normalized, $tag, $base) = @{$case_ref};
	like($input, qr/\A$language_code_re\z/, "Shared grammar accepts $input");
	is(normalize_language_code($input), $normalized, 'Normalize the code');
	is(language_tag($input), $tag, 'Format a BCP-47 tag');
	is(base_language($input), $base, 'Return the root language');
}

foreach my $invalid (undef, '', 'pt-BR-extra', "pt_BR\n", '../pt', 'pt_4A9', 'pt_KK') {
	is(normalize_language_code($invalid), undef, 'Reject invalid language syntax');
	is(language_tag($invalid), undef, 'No BCP-47 tag for invalid input');
	is(base_language($invalid), undef, 'No base language for invalid input');
	is([language_fallbacks($invalid)], [], 'No fallback chain for invalid input');
}

is([language_fallbacks('zh-hant-tw')], [qw/zh_Hant_TW zh_Hant zh/], 'Keep the script before the root language');
is([language_fallbacks('pt-br')], [qw/pt_BR pt/], 'Region falls back to root');
is([language_fallbacks('en')], ['en'], 'A base language has no implicit English or other fallback');

my %values = (zh => 'base', zh_Hant => 'script', zh_Hans => 'other script', en => 'English');
my $matched;
is(lookup_with_language_fallback(\%values, 'zh-hant-tw', \$matched), 'script', 'Choose the closest defined value');
is($matched, 'zh_Hant', 'Report the language of the value');
is(lookup_with_language_fallback(\%values, 'pt_BR', \$matched), undef, 'Do not add an English fallback');
is($matched, undef, 'Clear a previous match on a miss');
is(lookup_with_language_fallback({pt_PT => 'Portugal'}, 'pt_BR'), undef, 'Do not cross into a sibling region');
is(lookup_with_language_fallback({zh_Hans => 'Simplified'}, 'zh_Hant_TW'), undef, 'Do not cross into another script');
is(lookup_with_language_fallback({pt_BR => undef, pt => 'base'}, 'pt_BR'), 'base', 'Skip undefined values');
is(lookup_with_language_fallback({pt_BR => 0, pt => 1}, 'pt_BR'), 0, 'Preserve zero');
is(lookup_with_language_fallback({pt_BR => '', pt => 'base'}, 'pt_BR'), '', 'Preserve an explicit empty value');
is(lookup_with_language_fallback({no_language => 'special', no => 'Norwegian'}, 'no_language'),
	'special', 'Preserve exact non-language configuration keys');
is(lookup_with_language_fallback({no => 'Norwegian'}, 'no_language'),
	undef, 'Do not derive a language from a special key');
is(lookup_with_language_fallback(undef, 'pt_BR'), undef, 'Accept an absent dictionary');
is(lookup_with_language_fallback(\%values, undef), undef, 'Accept an absent language');
is(
	\%values,
	{zh => 'base', zh_Hant => 'script', zh_Hans => 'other script', en => 'English'},
	'Lookups leave the dictionary unchanged'
);

is(language_locale('pt_br')->id, 'pt-BR', 'Normalize before mapping the calendar locale');
is(language_locale('pt_ZZ')->id, 'pt', 'Use a Portuguese calendar when a region is unavailable');
is(language_locale('zh-TW')->id, 'zh-Hant-TW', 'Keep the traditional Chinese calendar mapping');
is(language_locale('zh_HK')->id, 'zh-Hant-HK', 'Keep the Hong Kong calendar mapping');
is(language_locale('zh_CN')->id, 'zh-Hans-CN', 'Keep the simplified Chinese calendar mapping');
is(language_locale('invalid')->id, 'en', 'Unknown calendar locales retain English fallback');
is(get_string_id_for_lang('fr_CA', 'Café crème'), 'cafe-creme', 'Inherit French accent normalization');
is(get_string_id_for_lang('de_AT', 'Äpfel'), 'äpfel', 'Inherit German accent normalization');
is(get_string_id_for_lang('no_language', 'Café crème'), 'cafe-creme', 'Keep special normalization settings');

done_testing();
