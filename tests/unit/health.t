use Modern::Perl '2017';
use utf8;

use Test2::V0;
use HTTP::Response;
use HTTP::Headers;
use JSON qw/encode_json/;

use ProductOpener::APIHealth qw/read_health_api/;
use ProductOpener::Config qw/$health_check_api_key/;

subtest 'api call without correct API key fails' => sub {
	# Arrange
	my $apache_util_module = mock 'Apache2::RequestUtil' => (
		add => [
			'request' => sub {
				# Return a mock Apache request object
				my $r = {};
				bless $r, 'Apache2::RequestRec';

				return $r;
			},
		]
	);

	$health_check_api_key = "random_api_key";

	my $headers_in = {};
	my $request_rec_module = mock 'Apache2::RequestRec' => (
		add => [
			'rflush' => sub {
				# Do nothing, am just mocking the method
			},
			'status' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_out' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_in' => sub {
				return $headers_in;
			},
		]
	);

	my $request_ref = {
		api_response => {
			errors => [],
		},
	};

	# Act
	read_health_api($request_ref);

	# Assert
	my $response = $request_ref->{api_response};
	is($response->{status_code}, 401, 'read_health_api returns 401 status code on invalid API key');
	is(scalar @{$response->{errors}}, 1, 'read_health_api adds one error to the response on invalid API key');
	my $error_ref = $response->{errors}->[0];
	is($error_ref->{message}->{id}, 'invalid_api_key', 'read_health_api adds error with correct message id on invalid API key');
	is($error_ref->{impact}->{id}, 'failure', 'read_health_api adds error with correct impact id on invalid API key');
};

subtest 'api call with correct API key succeeds' => sub {
	# Arrange
	my $apache_util_module = mock 'Apache2::RequestUtil' => (
		add => [
			'request' => sub {
				# Return a mock Apache request object
				my $r = {};
				bless $r, 'Apache2::RequestRec';

				return $r;
			},
		]
	);

	$health_check_api_key = "random_api_key";

	my $headers_in = {'API-Key' => $health_check_api_key};
	my $request_rec_module = mock 'Apache2::RequestRec' => (
		add => [
			'rflush' => sub {
				# Do nothing, am just mocking the method
			},
			'status' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_out' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_in' => sub {
				return $headers_in;
			},
		]
	);

	my $request_ref = {
		api_response => {
			errors => [],
		},
	};

	# Act
	read_health_api($request_ref);

	# Assert
	my $response = $request_ref->{api_response};
	is($response->{status_code}, 503, 'read_health_api returns 503 status code on valid API key'); # Note: the health check is expected to fail in the test environment without further mocks, so we check for 503 status code here
	is(scalar @{$response->{errors}}, 0, 'read_health_api adds no errors to the response on valid API key');
};

subtest 'api call returns data from %checks - pass' => sub {
	# Arrange
	my $apache_util_module = mock 'Apache2::RequestUtil' => (
		add => [
			'request' => sub {
				# Return a mock Apache request object
				my $r = {};
				bless $r, 'Apache2::RequestRec';

				return $r;
			},
		]
	);

	$health_check_api_key = undef;

	my $headers_in = {};
	my $request_rec_module = mock 'Apache2::RequestRec' => (
		add => [
			'rflush' => sub {
				# Do nothing, am just mocking the method
			},
			'status' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_out' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_in' => sub {
				return $headers_in;
			},
		]
	);

	my $request_ref = {
		api_response => {
			errors => [],
		},
	};

	# This is a bit of a heavy white-box test, but we want to check that the data from the checks is correctly included in the response. We mock the checks to return a known value and check for that value in the response.
	# Note that we don't check for the exact structure of the response here, just that the data from the checks is included in the response in some form, as the exact structure is tested in the integration tests.
	my %checks = (
		check1 => sub {
			return [
				{
					status => "pass",
					componentType => 'system',
					observedValue => 42,
					observedUnit => 'ms',
					time => "2025-01-01T00:00:00Z",
					links => [],
				}
			];
		},
		check2 => sub {
			return [
				{
					status => "pass",
					componentType => 'system',
					observedValue => 69,
					observedUnit => 'ms',
					time => "2026-01-01T00:00:00Z",
					links => [],
				}
			];
		},
	);
	
	my $health_mock = mock 'ProductOpener::APIHealth' => (
		override => [
			'_get_checks' => sub {
				return \%checks;
			},
		]
	);

	# Act
	read_health_api($request_ref);

	# Assert
	my $response = $request_ref->{api_response};
	is($response->{status_code}, 200, 'read_health_api returns 200 status code');
	is($response->{content_type}, 'application/health+json', 'read_health_api returns correct content type');
	is(scalar @{$response->{errors}}, 0, 'read_health_api adds no errors');
	is($response->{body}->{status}, 'pass', 'read_health_api returns pass status when all checks pass');
	is($response->{body}->{description}, 'health of Product Opener API', 'read_health_api returns correct description');
	is($response->{body}->{checks}->{check1}->[0]->{observedValue}, 42, 'read_health_api includes data from checks in the response');
};

subtest 'api call returns data from %checks - warn' => sub {
	# Arrange
	my $apache_util_module = mock 'Apache2::RequestUtil' => (
		add => [
			'request' => sub {
				# Return a mock Apache request object
				my $r = {};
				bless $r, 'Apache2::RequestRec';

				return $r;
			},
		]
	);

	$health_check_api_key = undef;

	my $headers_in = {};
	my $request_rec_module = mock 'Apache2::RequestRec' => (
		add => [
			'rflush' => sub {
				# Do nothing, am just mocking the method
			},
			'status' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_out' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_in' => sub {
				return $headers_in;
			},
		]
	);

	my $request_ref = {
		api_response => {
			errors => [],
		},
	};

	# This is a bit of a heavy white-box test, but we want to check that the data from the checks is correctly included in the response. We mock the checks to return a known value and check for that value in the response.
	# Note that we don't check for the exact structure of the response here, just that the data from the checks is included in the response in some form, as the exact structure is tested in the integration tests.
	my %checks = (
		check1 => sub {
			return [
				{
					status => "pass",
					componentType => 'system',
					observedValue => 42,
					observedUnit => 'ms',
					time => "2025-01-01T00:00:00Z",
					links => [],
				}
			];
		},
		check2 => sub {
			return [
				{
					status => "warn",
					componentType => 'system',
					observedValue => 69,
					observedUnit => 'ms',
					time => "2026-01-01T00:00:00Z",
					links => [],
				}
			];
		},
	);
	
	my $health_mock = mock 'ProductOpener::APIHealth' => (
		override => [
			'_get_checks' => sub {
				return \%checks;
			},
		]
	);

	# Act
	read_health_api($request_ref);

	# Assert
	my $response = $request_ref->{api_response};
	is($response->{status_code}, 200, 'read_health_api returns 200 status code');
	is($response->{content_type}, 'application/health+json', 'read_health_api returns correct content type');
	is(scalar @{$response->{errors}}, 0, 'read_health_api adds no errors');
	is($response->{body}->{status}, 'warn', 'read_health_api returns warn status when any check warns');
	is($response->{body}->{description}, 'health of Product Opener API', 'read_health_api returns correct description');
	is($response->{body}->{checks}->{check1}->[0]->{observedValue}, 42, 'read_health_api includes data from checks in the response');
};

subtest 'api call returns data from %checks - fail' => sub {
	# Arrange
	my $apache_util_module = mock 'Apache2::RequestUtil' => (
		add => [
			'request' => sub {
				# Return a mock Apache request object
				my $r = {};
				bless $r, 'Apache2::RequestRec';

				return $r;
			},
		]
	);

	$health_check_api_key = undef;

	my $headers_in = {};
	my $request_rec_module = mock 'Apache2::RequestRec' => (
		add => [
			'rflush' => sub {
				# Do nothing, am just mocking the method
			},
			'status' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_out' => sub {
				# Do nothing, am just mocking the method
			},
			'headers_in' => sub {
				return $headers_in;
			},
		]
	);

	my $request_ref = {
		api_response => {
			errors => [],
		},
	};

	# This is a bit of a heavy white-box test, but we want to check that the data from the checks is correctly included in the response. We mock the checks to return a known value and check for that value in the response.
	# Note that we don't check for the exact structure of the response here, just that the data from the checks is included in the response in some form, as the exact structure is tested in the integration tests.
	my %checks = (
		check1 => sub {
			return [
				{
					status => "fail",
					componentType => 'system',
					observedValue => 42,
					observedUnit => 'ms',
					time => "2025-01-01T00:00:00Z",
					links => [],
				}
			];
		},
		check2 => sub {
			return [
				{
					status => "pass",
					componentType => 'system',
					observedValue => 69,
					observedUnit => 'ms',
					time => "2026-01-01T00:00:00Z",
					links => [],
				}
			];
		},
	);
	
	my $health_mock = mock 'ProductOpener::APIHealth' => (
		override => [
			'_get_checks' => sub {
				return \%checks;
			},
		]
	);

	# Act
	read_health_api($request_ref);

	# Assert
	my $response = $request_ref->{api_response};
	is($response->{status_code}, 503, 'read_health_api returns 503 status code');
	is($response->{content_type}, 'application/health+json', 'read_health_api returns correct content type');
	is(scalar @{$response->{errors}}, 0, 'read_health_api adds no errors');
	is($response->{body}->{status}, 'fail', 'read_health_api returns fail status when any check fails');
	is($response->{body}->{description}, 'health of Product Opener API', 'read_health_api returns correct description');
	is($response->{body}->{checks}->{check1}->[0]->{observedValue}, 42, 'read_health_api includes data from checks in the response');
};

done_testing();
