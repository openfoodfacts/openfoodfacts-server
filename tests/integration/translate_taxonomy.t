#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests login new_client wait_application_ready/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Tags qw/add_user_translation/;
use File::Slurp;

wait_application_ready(__FILE__);

# cgi/translate_taxonomy.pl appends a translation to
# $BASE_DIRS{USERS_TRANSLATIONS}/$tagtype.$tag_lc.txt: an unauthenticated caller must not be able
# to write anything, and neither must a logged in caller be able to direct the write outside of
# the translations directory.

my $translation_file = "$BASE_DIRS{USERS_TRANSLATIONS}/categories.en.txt";
my $traversal_file = "$BASE_DIRS{USERS_TRANSLATIONS}/../poc_translate_taxonomy.en.txt";

# Keep the translations that are already there, and put them back at the end of the test
my $existing_translations = (-e $translation_file) ? read_file($translation_file) : "";

unlink($translation_file);
unlink($traversal_file);

# 1. Anonymous caller: the translation is refused and no file is created

my $anonymous_ua = new_client();

my $tests_ref = [
	{
		test_case => 'translate-taxonomy-not-authenticated',
		method => 'POST',
		path => '/cgi/translate_taxonomy.pl',
		form => {
			lc => 'en',
			tagtype => 'categories',
			from => 'en:poc-source-tag',
			to => 'poc translation',
		},
		expected_type => 'json',
	},
];

execute_api_tests(__FILE__, $tests_ref, $anonymous_ua);

ok(not(-e $translation_file), "no translation file is created for an anonymous caller");

# 2. Logged in caller: a known taxonomy is translated, anything else is refused

my $ua = new_client();
login($ua, "tests", 'testtest');

$tests_ref = [
	{
		test_case => 'translate-taxonomy-authenticated',
		method => 'POST',
		path => '/cgi/translate_taxonomy.pl',
		form => {
			lc => 'en',
			tagtype => 'categories',
			from => 'en:poc-source-tag',
			to => 'poc translation',
		},
		expected_type => 'json',
	},
	{
		test_case => 'translate-taxonomy-unknown-tagtype',
		method => 'POST',
		path => '/cgi/translate_taxonomy.pl',
		form => {
			lc => 'en',
			tagtype => 'not_a_taxonomy',
			from => 'en:poc-source-tag',
			to => 'poc translation',
		},
		expected_type => 'json',
	},
	{
		test_case => 'translate-taxonomy-path-traversal-in-tagtype',
		method => 'POST',
		path => '/cgi/translate_taxonomy.pl',
		form => {
			lc => 'en',
			tagtype => '../poc_translate_taxonomy',
			from => 'en:poc-source-tag',
			to => 'poc translation',
		},
		expected_type => 'json',
	},
	{
		# A record is one line of tab separated values: a newline in the value would append a
		# second record, attributed to a user of the caller's choosing
		test_case => 'translate-taxonomy-newline-in-value',
		method => 'POST',
		path => '/cgi/translate_taxonomy.pl',
		form => {
			lc => 'en',
			tagtype => 'categories',
			from => 'en:poc-source-tag',
			to => "poc translation\n1700000000\tpoc-forged-user\ten:poc-forged-tag\tpoc forged translation",
		},
		expected_type => 'json',
	},
	{
		# A tab in the value would shift the columns of the record
		test_case => 'translate-taxonomy-tab-in-value',
		method => 'POST',
		path => '/cgi/translate_taxonomy.pl',
		form => {
			lc => 'en',
			tagtype => 'categories',
			from => 'en:poc-source-tag',
			to => "poc\ttranslation",
		},
		expected_type => 'json',
	},
	{
		test_case => 'translate-taxonomy-missing-parameter',
		method => 'POST',
		path => '/cgi/translate_taxonomy.pl',
		form => {
			lc => 'en',
			tagtype => 'categories',
			from => 'en:poc-source-tag',
		},
		expected_type => 'json',
	},
];

execute_api_tests(__FILE__, $tests_ref, $ua);

ok(-e $translation_file, "the translation file is created for a logged in caller");
like(read_file($translation_file), qr/poc translation/, "the translation is written to the file");
ok(not(-e $traversal_file), "no file is created outside of the translations directory");

# cgi/translate_taxonomy.pl is not the only caller add_user_translation() has to refuse: it is the
# only writer of the file, so check that it refuses a value with a control character itself, rather
# than relying on each caller to have checked.

foreach
	my $value_ref (["poc\tforged", 'a tab'], ["poc\n1700000000\tpoc-forged\ten:poc-forged\tpoc forged", 'a newline'],)
{
	my ($value, $desc) = @{$value_ref};
	is(add_user_translation('en', 'categories', 'tests', 'en:poc-source-tag', $value),
		0, "add_user_translation refuses a value with $desc");
}

# Only the one translation that was allowed was written: a value with a control character must not
# have added a record of its own, or one attributed to another user.

unlike(read_file($translation_file), qr/forged/, "no forged record is written to the file");

my @records = grep {$_ ne ''} split(/\n/, read_file($translation_file));
is(scalar(@records), 1, "the file holds exactly the one record that was allowed");

# Restore the translations that were there before the test

if ($existing_translations ne "") {
	write_file($translation_file, $existing_translations);
}
else {
	unlink($translation_file);
}

done_testing();
