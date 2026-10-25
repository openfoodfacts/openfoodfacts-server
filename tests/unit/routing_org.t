use ProductOpener::PerlStandards;

use Test2::V0;
use Test2::Tools::Mock qw/mock/;

use ProductOpener::Routing ();

subtest 'organization navigation only persists preferences on an origin-checked POST' => sub {
	local $ProductOpener::Config::server_options{private_products} = 1;
	local $ProductOpener::Routing::Owner_id = 'org-original';
	local %ProductOpener::Routing::User = (pro_moderator => 1);
	my $saved = 0;
	my %headers;
	my $headers_mock
		= mock 'ProductOpener::HTTP' => (override => [get_http_request_header => sub {return $headers{$_[0]}}]);
	my $routing_mock = mock 'ProductOpener::Routing' => (
		override => [
			retrieve_user => sub {return {}},
			set_owner_id => sub {$ProductOpener::Routing::Owner_id = 'org-selected'; return;},
			store_user_preferences => sub {$saved++; return;},
			match_route => sub {return 1;},
		]
	);
	my $users_mock = mock 'ProductOpener::Users' => (override => [check_edit_owner => sub {return;}]);

	for my $method ('GET', 'POST') {
		for my $fetch_site (undef, 'same-origin', 'cross-site') {
			$headers{'Sec-Fetch-Site'} = $fetch_site;
			$ProductOpener::Routing::Owner_id = 'org-original';
			$saved = 0;
			my $request_ref = {
				method => $method,
				user_id => 'moderator',
				param => {orgid => 'org-selected'},
				components => ['org', 'org-selected'],
			};
			ProductOpener::Routing::org_route($request_ref);
			my $expected = ($method eq 'POST') && (($fetch_site // '') ne 'cross-site') ? 1 : 0;
			is($saved, $expected, "$method with Sec-Fetch-Site=" . ($fetch_site // 'absent'));
			is($request_ref->{ownerid}, 'org-selected', 'the organization is used for the current request');
		}
	}
};

done_testing();
