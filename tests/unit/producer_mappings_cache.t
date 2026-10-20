#!/usr/bin/perl

use ProductOpener::PerlStandards;
use Test::More;
use File::Path qw/make_path/;
use File::Temp qw/tempdir/;
use File::Basename qw/dirname/;
use Cwd qw/abs_path/;
use IPC::Open3;
use Symbol qw/gensym/;
use ProductOpener::ProducerMappingsCache qw/mappings_cache_valid write_mappings_cache_manifest/;

my $directory = tempdir(CLEANUP => 1);
make_path("$directory/fields_column_names");
my @languages = qw/en fr/;
my $key = 'source-image-configuration-key';

sub write_mapping ($language, $content) {
	open(my $file, '>:raw', "$directory/fields_column_names/$language.json") or die $!;
	print {$file} $content or die $!;
	close($file) or die $!;
	return;
}

ok(!mappings_cache_valid($directory, $key, \@languages), 'a missing cache is a miss');
write_mapping('en', '{"name":"product_name"}');
eval {write_mappings_cache_manifest($directory, $key, \@languages)};
like($@, qr/incomplete/, 'a partial language set cannot be marked complete');

write_mapping('fr', '{"nom":"product_name"}');
write_mappings_cache_manifest($directory, $key, \@languages);
ok(mappings_cache_valid($directory, $key, \@languages), 'a complete unchanged set is reusable');
ok(mappings_cache_valid($directory, $key, [reverse @languages]), 'language ordering does not matter');
ok(!mappings_cache_valid($directory, 'new-source-key', \@languages), 'changed inputs invalidate the set');
ok(!mappings_cache_valid($directory, '', \@languages), 'an absent opt-in key never reuses the cache');
ok(!mappings_cache_valid($directory, $key, []), 'an empty language set is rejected');
ok(!mappings_cache_valid($directory, $key, [@languages, 'es']), 'a new current language invalidates the set');
ok(!mappings_cache_valid($directory, $key, ['en']), 'a removed current language invalidates the set');

write_mapping('en', '{"name":"wrong_field"}');
ok(!mappings_cache_valid($directory, $key, \@languages), 'modified mapping contents invalidate the set');
write_mapping('en', '{"name":"product_name"}');
ok(mappings_cache_valid($directory, $key, \@languages), 'validation does not modify the mapping files');

write_mapping('es', '{}');
ok(!mappings_cache_valid($directory, $key, \@languages), 'an extra mapping invalidates the set');
unlink("$directory/fields_column_names/es.json") or die $!;
write_mapping('fr', '');
ok(!mappings_cache_valid($directory, $key, \@languages), 'an empty mapping invalidates the set');
unlink("$directory/fields_column_names/fr.json") or die $!;
ok(!mappings_cache_valid($directory, $key, \@languages), 'a deleted mapping invalidates the set');

write_mapping('fr', '{"nom":"product_name"}');
write_mappings_cache_manifest($directory, $key, \@languages);
open(my $manifest, '>>:raw', "$directory/manifest.sha256") or die $!;
print {$manifest} "truncated-or-corrupt-manifest\n" or die $!;
close($manifest) or die $!;
ok(!mappings_cache_valid($directory, $key, \@languages), 'a malformed manifest is a miss');

subtest 'generator cache lifecycle' => sub {
	my $fixture = tempdir(CLEANUP => 1);
	make_path("$fixture/ProductOpener");
	my %stubs = (
		Config => <<'STUB',
package ProductOpener::Config;
use Exporter qw/import/;
our $server_domain = $ENV{CACHE_TEST_DOMAIN} // 'openfoodfacts.localhost';
our %server_options = (producers_platform => $ENV{CACHE_TEST_PLATFORM} // 0);
our @EXPORT_OK = qw/$server_domain %server_options/;
our %EXPORT_TAGS = (all => \@EXPORT_OK);
1;
STUB
		Lang => <<'STUB',
package ProductOpener::Lang;
use Exporter qw/import/;
our @Langs = $ENV{CACHE_TEST_NO_LANGUAGES} ? () : qw/en fr/;
our @EXPORT_OK = qw/@Langs/;
1;
STUB
		Paths => <<'STUB',
package ProductOpener::Paths;
use Exporter qw/import/;
our %BASE_DIRS = (CACHE_BUILD => "$ENV{CACHE_TEST_ROOT}/build-cache");
our @EXPORT_OK = qw/%BASE_DIRS/;
1;
STUB
		Producers => <<'STUB',
package ProductOpener::Producers;
use ProductOpener::PerlStandards;
use Exporter qw/import/;
use File::Path qw/make_path/;
our @EXPORT_OK = qw/build_fields_columns_names_for_lang/;
our %EXPORT_TAGS = (all => \@EXPORT_OK);
sub build_fields_columns_names_for_lang ($language) {
    die "forced failure\n" if $language eq ($ENV{CACHE_TEST_FAIL_LANGUAGE} // '');
    my $directory = "$ENV{CACHE_TEST_ROOT}/build-cache/pro/fields_column_names";
    make_path($directory);
    open(my $file, '>:raw', "$directory/$language.json") or die $!;
    print {$file} '{"field":"product_name"}' or die $!;
    close($file) or die $!;
    return;
}
1;
STUB
	);
	foreach my $module (keys %stubs) {
		open(my $file, '>:raw', "$fixture/ProductOpener/$module.pm") or die $!;
		print {$file} $stubs{$module} or die $!;
		close($file) or die $!;
	}

	my $root = abs_path(dirname(__FILE__) . '/../..');
	local $ENV{CACHE_TEST_ROOT} = $fixture;
	local $ENV{PRODUCT_OPENER_FLAVOR_SHORT} = 'off';
	local $ENV{PRODUCER_MAPPINGS_CACHE_KEY} = 'first-inputs';
	local $ENV{CACHE_TEST_FAIL_LANGUAGE};
	local $ENV{CACHE_TEST_NO_LANGUAGES};
	local $ENV{CACHE_TEST_DOMAIN};
	local $ENV{CACHE_TEST_PLATFORM};
	my $run_builder = sub {
		my $errors = gensym();
		my $pid = open3(undef, my $output, $errors, $^X, "-I$fixture", "-I$root/lib",
			"$root/scripts/build_pro_platform_fields_columns_names.pl");
		local $/;
		my $text = (<$output> // '') . (<$errors> // '');
		close($output);
		close($errors);
		waitpid($pid, 0);
		return ($? >> 8, $text);
	};
	my ($status, $text) = $run_builder->();
	is($status, 0, 'cold generation compiles and succeeds with the Config public exports');
	like($text, qr/All producer column mappings built successfully/, 'cold generation builds mappings');
	ok(-f "$fixture/build-cache/pro/manifest.sha256", 'cold generation installs a completion manifest');
	$ENV{CACHE_TEST_FAIL_LANGUAGE} = 'en';
	($status, $text) = $run_builder->();
	is($status, 0, 'warm generation succeeds');
	like($text, qr/Using cached producer column mappings for 2 languages/, 'warm generation skips building');
	unlike($text, qr/Building \(\d/, 'no language generation occurs on a hit');
	delete $ENV{CACHE_TEST_FAIL_LANGUAGE};

	foreach my $change (
		['PRODUCT_OPENER_FLAVOR_SHORT', 'opff', 'flavor'],
		['CACHE_TEST_DOMAIN', 'other.openfoodfacts.localhost', 'domain'],
		['CACHE_TEST_PLATFORM', '1', 'producer platform'],
		['PRODUCER_MAPPINGS_CACHE_KEY', 'changed-inputs', 'source key'],
		)
	{
		$ENV{$change->[0]} = $change->[1];
		($status, $text) = $run_builder->();
		is($status, 0, "generation succeeds after a changed $change->[2]");
		unlike($text, qr/Using cached/, "a changed $change->[2] rebuilds the mappings");
	}

	$ENV{PRODUCER_MAPPINGS_CACHE_KEY} = 'failed-inputs';
	$ENV{CACHE_TEST_FAIL_LANGUAGE} = 'fr';
	($status, $text) = $run_builder->();
	is($status, 1, 'a failed language makes generation fail');
	ok(!-e "$fixture/build-cache/pro/manifest.sha256", 'failure removes the previous completion manifest');
	ok(!-e "$fixture/build-cache/pro/fields_column_names/fr.json", 'failure cannot retain an old language mapping');
	delete $ENV{CACHE_TEST_FAIL_LANGUAGE};
	($status, $text) = $run_builder->();
	is($status, 0, 'a subsequent attempt rebuilds the failed set');
	unlike($text, qr/Using cached/, 'a partial failed build is never reused');
	($status, $text) = $run_builder->();
	is($status, 0, 'the recovered build is reusable');
	like($text, qr/Using cached/, 'recovery installs a new completion manifest');

	delete $ENV{PRODUCER_MAPPINGS_CACHE_KEY};
	($status, $text) = $run_builder->();
	is($status, 0, 'the local developer invocation still succeeds');
	unlike($text, qr/Using cached/, 'the local developer invocation always rebuilds');
	$ENV{CACHE_TEST_FAIL_LANGUAGE} = 'en';
	($status, $text) = $run_builder->();
	is($status, 1, 'the local developer invocation attempts generation even with complete cached mappings');
	delete $ENV{CACHE_TEST_FAIL_LANGUAGE};

	$ENV{PRODUCER_MAPPINGS_CACHE_KEY} = 'failed-inputs';
	$ENV{CACHE_TEST_NO_LANGUAGES} = 1;
	($status, $text) = $run_builder->();
	is($status, 1, 'missing language preparation fails even with an existing cache');
	like($text, qr/No languages found/, 'missing language preparation has an actionable message');
	done_testing();
};

done_testing();
