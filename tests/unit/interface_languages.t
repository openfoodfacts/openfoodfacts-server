#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use File::Path qw/make_path/;
use File::Temp qw/tempdir/;
use JSON::MaybeXS qw/decode_json/;
use Test2::V0;
use Test2::Plugin::UTF8;
use Log::Any::Adapter 'TAP';

use ProductOpener::APIProductWrite qw/update_product_field_api_v2_and_cgi/;
use ProductOpener::Config qw/$server_domain %options/;
use ProductOpener::Display qw/init_request process_template display_date display_page/;
use ProductOpener::I18N;
use ProductOpener::Lang qw/$lc $interface_lc %Lang %Langs %InterfaceLangs %lang_lc interface_languages lang f_lang/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/store/;
use ProductOpener::Tags qw/init_languages %Languages %language_codes %country_codes %country_languages/;
use ProductOpener::Web qw/get_languages_options_list/;

# Use the real taxonomy initializer and the same activation function as build_lang.pl.
init_languages();
my %product_languages = map {$_ => $Languages{$_}} qw/en pt/;
my $registry_ref = interface_languages(\%product_languages);
is([sort keys %{$registry_ref}], [qw/en pt pt_BR/], 'The activation list adds Brazilian Portuguese');
is($registry_ref->{pt_BR}{pt_BR}, 'Português (Brasil)', 'The variant has its native name');
ok(
	!exists $Languages{pt_BR} && !exists $language_codes{pt_BR},
	'A variant is not added as an ISO 639-1 product language'
);
is(
	interface_languages({en => $Languages{en}}),
	{en => $Languages{en}},
	'Do not activate a variant without its base language'
);

{
	# The activation list is configuration: enabling a variant does not change the code.
	local $options{interface_language_variants} = {zh_TW => 'Chinese (Taiwan)', 'not a code' => 'Ignored'};
	my $configured_ref = interface_languages({map {$_ => $Languages{$_}} qw/en zh/});
	is([sort keys %{$configured_ref}], [qw/en zh zh_TW/], 'Variants come from the configuration');
	is($configured_ref->{zh_TW}{zh_TW}, 'Chinese (Taiwan)', 'The configured native name is used');
}

my $dir = tempdir(CLEANUP => 1);
make_path("$dir/po/common", "$dir/public", "$dir/private");
my %english = (
	add => 'Add',
	base_only => 'Base fallback',
	english_only => 'English fallback',
	formatted => 'Hello {name}',
	footer_join_us_on => 'Join us on %s'
);
my %catalogs = (
	en => \%english,
	pt => {add => 'Adicionar', base_only => 'Texto português', formatted => 'Olá {name}'},
	pt_BR => {add => 'Adicionar Brasil', base_only => ''},
	pt_PT => {add => 'Unregistered'},
);

foreach my $catalog (sort keys %catalogs, 'common') {
	my $extension = $catalog eq 'common' ? 'pot' : 'po';
	open(my $fh, '>:encoding(UTF-8)', "$dir/po/common/$catalog.$extension") or die "Cannot write catalog: $!";
	print {$fh} "msgid \"\"\nmsgstr \"\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"\n\n";
	my $strings_ref = $catalog eq 'common' ? \%english : $catalogs{$catalog};
	foreach my $key (sort keys %{$strings_ref}) {
		my $translation = $catalog eq 'common' ? '' : $strings_ref->{$key};
		print {$fh} "msgctxt \"$key\"\nmsgid \"$english{$key}\"\nmsgstr \"$translation\"\n\n";
	}
	close($fh) or die "Cannot close catalog: $!";
}
local $ProductOpener::Lang::data_root = $dir;
local $BASE_DIRS{PUBLIC_DATA} = "$dir/public";
ProductOpener::Lang::build_lang($registry_ref);
is($Lang{add}{pt_BR}, 'Adicionar Brasil', 'Compile the enabled regional catalog');
is($Lang{base_only}{pt_BR}, 'Texto português', 'Missing regional strings fall back to Portuguese');
is($Lang{english_only}{pt_BR}, 'English fallback', 'Missing Portuguese strings fall back to English');
is($InterfaceLangs{pt_BR}, 'Português (Brasil)', 'The variant is selectable in the interface');
is([sort keys %Langs], [qw/en pt/], 'Product language names still contain only the base languages');
is([sort keys %lang_lc], [qw/en pt/], 'API and export language codes exclude the interface variant');
my $product_options = get_languages_options_list('pt');
is([sort map {$_->{value}} @{$product_options}], [qw/en pt/], 'Product forms do not offer a regional data language');
like($Lang{months}{pt_BR}, qr/janeiro/, 'Months use the Portuguese calendar');
like($Lang{weekdays}{pt_BR}, qr/segunda-feira/, 'Weekdays use the Portuguese calendar');

ProductOpener::Lang::build_json();
open(my $json_fh, '<:raw', "$dir/public/i18n/pt-BR/lang.json") or die "Cannot read JSON: $!";
my $json_ref = decode_json(do {local $/; <$json_fh>});
close($json_fh);
is($json_ref->{add}, 'Adicionar Brasil', 'JSON includes the regional translation');
is($json_ref->{base_only}, 'Texto português', 'JSON includes the Portuguese fallback');
ok(!-d "$dir/public/i18n/pt-PT", 'An unregistered catalog is not exported');
store("$dir/private/Lang.$server_domain.sto", \%Lang);
my $reload_script = <<'PERL';
$ProductOpener::Paths::BASE_DIRS{PRIVATE_DATA} = shift;
require ProductOpener::Lang;
require JSON::MaybeXS;
print JSON::MaybeXS::encode_json({
    interface => \%ProductOpener::Lang::InterfaceLangs,
    product => \%ProductOpener::Lang::Langs,
    codes => \%ProductOpener::Lang::lang_lc,
    add => $ProductOpener::Lang::Lang{add}{pt_BR},
});
PERL
open(my $reload_fh, '-|', $^X, '-MProductOpener::Paths', '-e', $reload_script, "$dir/private")
	or die "Cannot reload: $!";
my $reloaded_ref = decode_json(do {local $/; <$reload_fh>});
ok(close($reload_fh), 'Reload the compiled catalog in a new process');
is(
	$reloaded_ref,
	{interface => \%InterfaceLangs, product => \%Langs, codes => \%lang_lc, add => 'Adicionar Brasil'},
	'Reloading preserves translations and the separation of interface and product languages'
);

local %country_codes = (world => 'en:world', br => 'en:brazil');
local %country_languages = (world => ['en'], br => ['pt']);
local $ENV{SCRIPT_NAME} = '/cgi/display.pl';
local $ENV{QUERY_STRING} = '';
local $ENV{REMOTE_ADDR} = '127.0.0.1';
my $hostname;
my %params;
my @mocks = (
	mock('Apache2::RequestUtil' => (add => [request => sub {return bless {}, 'Local::LanguageRequest';}])),
	mock(
		'Local::LanguageRequest' => (
			add => [
				method => sub {return 'GET';},
				hostname => sub {return $hostname;},
				rflush => sub {return;},
				status => sub {return;},
				headers_out => sub {return bless {}, 'Local::LanguageHeaders';},
			]
		)
	),
	mock('Local::LanguageHeaders' => (add => [set => sub {return;}])),
	mock(
		'ProductOpener::Display' => (
			override => [
				single_param => sub {return $params{$_[0]};},
				log_request_stats => sub {return;},
				# Run real language and URL initialization, stopping before authentication.
				process_auth_header => sub {die "language initialized\n";},
			]
		)
	),
);
foreach my $case_ref (
	{host => 'world', param => 'PT-br', ui => 'pt_BR', lc => 'pt', lcs => ['pt'], subdomain => 'world-pt-br'},
	{host => 'world', param => 'pt_br', ui => 'pt_BR', lc => 'pt', lcs => ['pt'], subdomain => 'world-pt-br'},
	{host => 'world-pt-br', ui => 'pt_BR', lc => 'pt', lcs => ['pt'], subdomain => 'world-pt-br'},
	{host => 'br-pt-br', ui => 'pt_BR', lc => 'pt', lcs => ['pt'], subdomain => 'br-pt-br'},
	{
		host => 'world',
		param => 'pt-BR,pt,en,invalid',
		ui => 'pt_BR',
		lc => 'pt',
		lcs => ['pt', 'en'],
		subdomain => 'world-pt-br'
	},
	{host => 'world', param => 'pt-PT', ui => 'en', lc => 'en', lcs => ['en'], subdomain => 'world'},
	{host => 'world', param => 'pt-BR-extra', ui => 'en', lc => 'en', lcs => ['en'], subdomain => 'world'},
	{host => 'world', param => 'pt', ui => 'pt', lc => 'pt', lcs => ['pt'], subdomain => 'world-pt'},
	{host => 'br', ui => 'pt', lc => 'pt', lcs => ['pt'], subdomain => 'br'},
	{host => 'world', ui => 'en', lc => 'en', lcs => ['en'], subdomain => 'world'},
	)
{
	subtest $case_ref->{host} . ' lc=' . ($case_ref->{param} // '(none)') => sub {
		$hostname = "$case_ref->{host}.openfoodfacts.localhost";
		%params = defined $case_ref->{param} ? (lc => $case_ref->{param}) : ();
		my $request_ref = {};
		like(
			dies {init_request($request_ref);},
			qr/^language initialized\n/,
			'Reach authentication after language resolution'
		);
		is($request_ref->{interface_lc}, $case_ref->{ui}, 'Resolve the registered interface locale');
		is($request_ref->{lc}, $case_ref->{lc}, 'Product and taxonomy operations keep the base language');
		is($request_ref->{lcs}, $case_ref->{lcs}, 'Ordered product languages use base codes without duplicates');
		is($lc, $case_ref->{lc}, 'Legacy product operations keep the base language too');
		is($request_ref->{subdomain}, $case_ref->{subdomain}, 'Links use lowercase hyphens');
		my $html = '';
		my $template = '<button>[% lang("add") %]</button>';
		ok(process_template(\$template, {}, \$html, $request_ref), 'Render through the real template helper');
		is($html, '<button>' . $Lang{add}{$case_ref->{ui}} . '</button>', 'Templates use the interface translation');
		is(lang('add'), $Lang{add}{$case_ref->{ui}}, 'Perl interface helpers use the same translation');

		if ($case_ref->{host} eq 'br-pt-br' or $case_ref->{host} eq 'br') {
			my $product_ref = {};
			update_product_field_api_v2_and_cgi($product_ref, $request_ref->{lc}, 'product_name', 'Example',
				'packaging');
			is($product_ref->{product_name_pt}, 'Example', 'The CGI/API write helper writes the base-language field');
			ok(!exists $product_ref->{product_name_pt_BR},
				'Selecting the interface variant creates no regional product field');

			my $content = '<p>Example</p>';
			$request_ref->{content_ref} = \$content;
			$request_ref->{title} = 'Example';
			my $page = '';
			{
				open(my $output, '>', \$page) or die "Cannot capture rendered page: $!";
				local *STDOUT = $output;
				display_page($request_ref);
			}
			my $html_tag = $case_ref->{ui} eq 'pt_BR' ? 'pt-BR' : 'pt';
			like($page, qr/<html [^>]*lang="$html_tag"/, 'The real page layout emits the BCP-47 language tag');
			like(
				$page,
				qr{href="[^" ]*br-pt-br[^" ]*/" lang="pt-BR" hreflang="pt-BR"},
				'The interface selector links to the variant with BCP-47 attributes'
			);
			like($page, qr/Portugu.*?\(Brasil\)/, 'The interface selector includes the native variant name');
		}

	};
}
$lc = 'pt';
$interface_lc = 'pt_BR';
is(f_lang('formatted', {name => 'Alice'}), 'Olá Alice', 'Formatted helpers use the base-language fallback');
like(display_date(1472292529), qr/agosto/, 'Dates displayed in the interface use Portuguese');
$lc = 'en';
is(lang('add'), 'Add', 'An explicit switch to another base language takes priority over the interface variant');

done_testing();
