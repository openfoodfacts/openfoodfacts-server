#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests login new_client wait_application_ready/;
use ProductOpener::Paths qw/%BASE_DIRS/;
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

# Restore the translations that were there before the test

if ($existing_translations ne "") {
	write_file($translation_file, $existing_translations);
}
else {
	unlink($translation_file);
}

done_testing();
