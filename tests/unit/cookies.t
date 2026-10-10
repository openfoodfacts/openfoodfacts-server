use Modern::Perl '2017';
use utf8;

use Test2::V0;

use B ();

use ProductOpener::Auth ();
use ProductOpener::Config qw/%server_options/;
use ProductOpener::URL qw/is_https_request should_use_secure_cookies/;
use ProductOpener::Users qw/generate_session_cookie clear_session_cookie/;

# The session cookie value is the authentication credential itself: it is accepted as proof of
# identity by init_user and check_session, and it is never revoked. It must therefore never be
# readable by scripts running under the cookie domain, and must never travel over plaintext HTTP.
# The oidc cookie holds the OIDC nonce that binds the callback to the browser: same requirements.

my $session_cookie = sub {return generate_session_cookie('bob', 'user-session-token');};
my $oidc_cookie = sub {return ProductOpener::Auth::generate_oidc_cookie('oidc-nonce', '/after-sign-in');};
my $clear_cookie = sub {return clear_session_cookie();};

# Run a block with $server_options{secure_cookies} forced to a value, and restore it afterwards
sub with_secure_cookies {
	my ($secure, $code_ref) = @_;
	my $saved = $server_options{secure_cookies};
	$server_options{secure_cookies} = $secure;
	eval {$code_ref->()};
	my $error = $@;
	$server_options{secure_cookies} = $saved;
	die $error if $error;
	return;
}

subtest 'cookies are HttpOnly even when the deployment serves plain HTTP' => sub {
	with_secure_cookies(
		0,
		sub {
			like($session_cookie->(), qr/HTTPOnly/i, 'session cookie is HttpOnly');
			like($oidc_cookie->(), qr/HTTPOnly/i, 'oidc cookie is HttpOnly');
			like($clear_cookie->(), qr/HTTPOnly/i, 'cookie clearing the session is HttpOnly');
		}
	);
};

subtest 'cookies are not Secure on a deployment that serves plain HTTP' => sub {
	with_secure_cookies(
		0,
		sub {
			# A Secure cookie is never sent back over plain HTTP, so flagging it here would make
			# sign-in fail silently: the browser discards the cookie.
			unlike($session_cookie->(), qr/(^|;)\s*Secure\s*(;|$)/i, 'session cookie is not Secure');
			unlike($oidc_cookie->(), qr/(^|;)\s*Secure\s*(;|$)/i, 'oidc cookie is not Secure');
		}
	);
};

subtest 'cookies are Secure when the deployment is configured for HTTPS' => sub {
	with_secure_cookies(
		1,
		sub {
			like($session_cookie->(), qr/(^|;)\s*Secure\s*(;|$)/i, 'session cookie is Secure');
			like($oidc_cookie->(), qr/(^|;)\s*Secure\s*(;|$)/i, 'oidc cookie is Secure');
		}
	);
};

subtest 'cookies are Secure when the current request came over HTTPS' => sub {
	with_secure_cookies(
		0,
		sub {
			# An instance served over HTTPS must behave like production even if it was configured
			# for plain HTTP, e.g. a preview deployment or local development behind a certificate
			local $ENV{HTTPS} = 'on';
			like($session_cookie->(), qr/(^|;)\s*Secure\s*(;|$)/i, 'session cookie is Secure');
			like($oidc_cookie->(), qr/(^|;)\s*Secure\s*(;|$)/i, 'oidc cookie is Secure');
		}
	);
};

subtest 'the cookie clearing a session carries the same attributes as the cookie it replaces' => sub {
	# Browsers only overwrite an existing cookie when name, domain and path match, so the clearing
	# cookie must repeat the security attributes of the cookie it replaces, otherwise logging out
	# would leave a credential behind.
	for my $secure (0, 1) {
		with_secure_cookies(
			$secure,
			sub {
				my $set = $session_cookie->();
				my $clear = $clear_cookie->();

				like($clear, qr/Path=\//i, "clearing cookie has the same path (secure=$secure)");
				like($clear, qr/Domain=/i, "clearing cookie has the same domain (secure=$secure)");
				like($clear, qr/SameSite=Lax/i, "clearing cookie has the same samesite (secure=$secure)");
				like($clear, qr/HTTPOnly/i, "clearing cookie is HttpOnly (secure=$secure)");
				if ($secure) {
					like($clear, qr/(^|;)\s*Secure\s*(;|$)/i, "clearing cookie is Secure (secure=$secure)");
				}
				else {
					unlike($clear, qr/(^|;)\s*Secure\s*(;|$)/i, "clearing cookie is not Secure (secure=$secure)");
				}
			}
		);
	}
};

subtest 'should_use_secure_cookies and is_https_request return real booleans' => sub {
	# Callers must be able to use these in boolean context without any risk of a string or a number
	# leaking out, so we check that both functions return an SvIsBOOL, that is an SV with both
	# SVf_IOK and SVf_POK set: it numifies to 1 or 0 and stringifies to "1" or "".
	# Note that a bare 1 or 0 is *not* a boolean, only !!1, !!0, builtin::true and builtin::false are.
	my $is_boolean = sub {
		my ($value) = @_;
		my $flags = B::svref_2object(\$value)->FLAGS;

		return ($flags & B::SVf_IOK()) && ($flags & B::SVf_POK());
	};

	with_secure_cookies(
		1,
		sub {
			my $value = should_use_secure_cookies();
			ok($is_boolean->($value), 'true branch returns an SvIsBOOL');
			is(0 + $value, 1, 'true branch numifies to 1');
			is("$value", 1, 'true branch stringifies to "1"');
		}
	);

	with_secure_cookies(
		0,
		sub {
			my $value = should_use_secure_cookies();
			ok($is_boolean->($value), 'false branch returns an SvIsBOOL');
			is(0 + $value, 0, 'false branch numifies to 0');
			is("$value", '', 'false branch stringifies to ""');
		}
	);

	with_secure_cookies(
		0,
		sub {
			my $value = is_https_request();
			ok($is_boolean->($value), 'is_https_request returns an SvIsBOOL');
		}
	);
};

done_testing();
