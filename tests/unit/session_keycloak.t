#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;

use ProductOpener::Config qw/$server_domain/;
use ProductOpener::Auth qw/
	access_to_protected_resource
	checked_return_url
	get_oidc_implementation_level
	is_allowed_return_url
	/;
use ProductOpener::Users qw/$User_id %User/;

package MockTable {
	sub new {my ($class, $hash) = @_; return bless $hash // {}, $class;}
	sub get {my ($self, $k) = @_; return $self->{$k};}
	sub set {my ($self, $k, $v) = @_; $self->{$k} = $v; return;}
	sub add {my ($self, $k, $v) = @_; $self->{$k} = $v; return;}
}

my $headers_in = MockTable->new();
my $headers_out = MockTable->new();
my $err_headers_out = MockTable->new();
my $last_status;

my $r_mock = bless {
	method => 'GET',
	hostname => "world.$server_domain",
	headers_in => $headers_in,
	headers_out => $headers_out,
	err_headers_out => $err_headers_out,
	},
	'Apache2::RequestRec';

my $apache_util = mock 'Apache2::RequestUtil' => (
	add => [
		request => sub {return $r_mock;},
	],
);

my $req_rec = mock 'Apache2::RequestRec' => (
	add => [
		method => sub {$r_mock->{method} // 'GET'},
		hostname => sub {$r_mock->{hostname} // "world.$server_domain"},
		headers_in => sub {$headers_in},
		headers_out => sub {$headers_out},
		err_headers_out => sub {$err_headers_out},
		status => sub {my ($self, $code) = @_; $last_status = $code if defined $code; return $last_status;},
	],
);

my $current_oidc_level = 5;
my $protected_resource_called = 0;
my $captured_request;
my $rendered_template;
my $rendered_data;
my $mock_user_id;

my $mock_users = mock 'ProductOpener::Users' => (
	override => [
		init_user => sub {
			if (defined $mock_user_id) {
				$ProductOpener::Users::User_id = $mock_user_id;
				%ProductOpener::Users::User = (name => 'Test User');
			}
			else {
				$ProductOpener::Users::User_id = undef;
				%ProductOpener::Users::User = ();
			}
			return;
		},
	],
);

my $mock_auth = mock 'ProductOpener::Auth' => (
	override => [
		get_oidc_implementation_level => sub {$current_oidc_level},
		access_to_protected_resource => sub {
			my ($req) = @_;
			$protected_resource_called = 1;
			$captured_request = $req;
			return;
		},
	],
);

my $mock_display = mock 'ProductOpener::Display' => (
	override => [
		process_template => sub {
			my ($template, $data, $out_ref) = @_;
			$rendered_template = $template;
			$rendered_data = $data;
			$$out_ref = "<html>rendered $template</html>";
			return 1;
		},
		display_page => sub {
			return 1;
		},
	],
);

sub run_session_pl {
	my (%args) = @_;

	# Reset state
	$protected_resource_called = 0;
	$captured_request = undef;
	$rendered_template = undef;
	$rendered_data = undef;
	$last_status = undef;
	%$headers_out = ();
	%$err_headers_out = ();
	%$headers_in = ();

	$current_oidc_level = $args{oidc_level} // 5;
	$mock_user_id = $args{user_id};
	$User_id = $args{user_id};
	%User = $args{user_id} ? (name => 'Test User') : ();

	$headers_in->{Referer} = $args{referer} if defined $args{referer};

	$ENV{SCRIPT_NAME} = '/cgi/session.pl';
	$ENV{HTTP_HOST} = "world.$server_domain";
	$ENV{SERVER_NAME} = "world.$server_domain";
	$ENV{REQUEST_METHOD} = $args{method} // 'GET';
	$ENV{QUERY_STRING} = $args{query_string} // '';

	CGI::initialize_globals();

	do './cgi/session.pl';
	return;
}

subtest 'Test 1 & 2: Facet page login preserves destination and uses Keycloak' => sub {
	my $facet_url = "https://world.$server_domain/facets/brands/Coca-Cola";

	run_session_pl(
		referer => $facet_url,
		oidc_level => 5,
	);

	is($protected_resource_called, 1, 'access_to_protected_resource called for unauthenticated user');
	is($captured_request->{return_url}, $facet_url, 'Original facet destination is preserved in return_url');
	is($rendered_template, undef, 'Classic sign_in_form is NOT rendered when Keycloak is enabled');
};

subtest 'Test 3: Multiple facet types preserved correctly' => sub {
	my @facets = (
		"https://world.$server_domain/facets/brands/Coca-Cola",
		"https://world.$server_domain/facets/categories/Breads",
		"https://world.$server_domain/facets/labels/organic",
		"https://world.$server_domain/facets/countries/france",
		"https://world.$server_domain/facets/ingredients/sugar",
		"https://world.$server_domain/facets/categories/Breads/2",
	);

	for my $url (@facets) {
		run_session_pl(
			referer => $url,
			oidc_level => 5,
		);

		is($protected_resource_called, 1, "access_to_protected_resource called for $url");
		is($captured_request->{return_url}, $url, "return_url correctly set to $url");
	}
};

subtest 'Test 2b: Destination passed via query parameters' => sub {
	my $target = "https://world.$server_domain/facets/brands/Coca-Cola";

	# Via return_url param
	run_session_pl(
		query_string => "return_url=$target",
		oidc_level => 5,
	);
	is($protected_resource_called, 1, 'Keycloak auth called via return_url parameter');
	is($captured_request->{return_url}, $target, 'return_url preserved from return_url param');

	# Via redirect param (legacy compatibility)
	run_session_pl(
		query_string => "redirect=$target",
		oidc_level => 5,
	);
	is($protected_resource_called, 1, 'Keycloak auth called via redirect parameter');
	is($captured_request->{return_url}, $target, 'return_url preserved from redirect param');

	# Via relative path
	my $expected_relative_target = ProductOpener::Display::format_subdomain('world') . '/facets/brands/Coca-Cola';
	run_session_pl(
		query_string => 'return_url=/facets/brands/Coca-Cola',
		oidc_level => 5,
	);
	is($protected_resource_called, 1, 'Keycloak auth called via relative return_url');
	is($captured_request->{return_url},
		$expected_relative_target, 'Relative return_url normalized with formatted_subdomain');

	# Via root relative path
	my $expected_root_target = ProductOpener::Display::format_subdomain('world') . '/';
	run_session_pl(
		query_string => 'return_url=/',
		oidc_level => 5,
	);
	is($protected_resource_called, 1, 'Keycloak auth called via root relative return_url');
	is($captured_request->{return_url},
		$expected_root_target, 'Root relative return_url normalized with formatted_subdomain');
};

subtest 'Test 4: Backward compatibility - classic login when Keycloak level < 3' => sub {
	my $facet_url = "https://world.$server_domain/facets/brands/Coca-Cola";

	run_session_pl(
		referer => $facet_url,
		oidc_level => 2,
	);

	is($protected_resource_called, 0, 'access_to_protected_resource NOT called when level < 3');
	is($rendered_template, 'web/pages/session/sign_in_form.tt.html', 'Legacy sign_in_form template rendered');
	is($rendered_data->{redirect}, $facet_url, 'Redirect destination passed to legacy template');
};

subtest 'Test 5: Existing authentication behaviour (logout and already authenticated)' => sub {
	# Logout action
	run_session_pl(
		query_string => 'length=logout',
		oidc_level => 5,
	);
	is($protected_resource_called, 0, 'access_to_protected_resource not called on logout');
	is($rendered_template, 'web/pages/session/signed_out.tt.html', 'signed_out template rendered on logout');

	# Already authenticated with facet return destination
	my $target = "https://world.$server_domain/facets/brands/Coca-Cola";
	run_session_pl(
		user_id => 'test_user',
		referer => $target,
		oidc_level => 5,
	);
	is($protected_resource_called, 0, 'access_to_protected_resource not called for signed-in user');
	is($headers_out->{Location}, $target, 'Redirected directly to facet page when already signed in');
	is($last_status, 302, 'HTTP 302 redirect issued for signed-in user');

	# Already authenticated without return destination
	run_session_pl(
		user_id => 'test_user',
		oidc_level => 5,
	);
	is($rendered_template, 'web/pages/session/signed_in.tt.html', 'signed_in template rendered when no return URL');
};

subtest 'Test 6: Redirect security - untrusted destinations rejected' => sub {
	my @untrusted = (
		'https://evil.example.com/phish',
		'https://world.' . $server_domain . '.evil.example/steal',
		'http://evil.example.com/',
		'//evil.example.com/steal',
		'/\\evil.example/steal',
		'https://world.' . $server_domain . '\@evil.example/steal',
		'https://world.' . $server_domain . '%2eevil.example/steal',
		'https://pro.' . $server_domain . '/facets/brands/Coca-Cola',
		'javascript:alert(1)',
		"https://world.$server_domain/cgi/session.pl",
		"https://world.$server_domain/cgi/login.pl",
		"https://world.$server_domain/cgi/oidc_signin.pl",
	);

	for my $bad_url (@untrusted) {
		run_session_pl(
			referer => $bad_url,
			oidc_level => 5,
		);

		is($protected_resource_called, 1, "Keycloak auth triggered for bad referer: $bad_url");
		is($captured_request->{return_url}, undef, "Untrusted return URL refused: $bad_url");
	}
};

subtest 'Test 7: JQM AJAX request compatibility' => sub {
	# Unauthenticated JQM request: returns JSON error without Keycloak redirect
	my $unauth_output = '';
	{
		local *STDOUT;
		open STDOUT, '>', \$unauth_output;
		run_session_pl(
			query_string => 'jqm=1',
			referer => "https://world.$server_domain/facets/brands/Coca-Cola",
			oidc_level => 5,
		);
	}
	is($protected_resource_called, 0, 'Keycloak auth NOT called for unauthenticated JQM request');
	is($last_status, undef, 'No 302 redirect status for unauthenticated JQM request');
	like($unauth_output, qr/undefined user/, 'Unauthenticated JQM returns JSON error');

	# Authenticated JQM request: returns JSON user data without 302 redirect even if Referer is set
	my $auth_output = '';
	{
		local *STDOUT;
		open STDOUT, '>', \$auth_output;
		run_session_pl(
			user_id => 'test_user',
			query_string => 'jqm=1',
			referer => "https://world.$server_domain/facets/brands/Coca-Cola",
			oidc_level => 5,
		);
	}
	is($protected_resource_called, 0, 'Keycloak auth NOT called for authenticated JQM request');
	is($last_status, undef, 'No 302 redirect status for authenticated JQM request');
	is($headers_out->{Location}, undef, 'No Location header set for JQM request');
	like($auth_output, qr/test_user/, 'Authenticated JQM returns JSON with user_id');
};

done_testing();
