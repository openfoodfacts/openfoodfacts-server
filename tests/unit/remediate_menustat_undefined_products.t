#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;

do './scripts/remediate_menustat_undefined_products.pl' or die($@ || $!);

{

	package FakeCursor;

	sub new ($class, @items) {
		return bless {items => \@items, idx => 0}, $class;
	}

	sub immortal ($self, $val = undef) {
		return 1;
	}

	sub next ($self) {
		return if $self->{idx} >= scalar(@{$self->{items}});
		return $self->{items}[$self->{idx}++];
	}
}

sub make_menustat_product (%overrides) {
	return {
		code => '987654321098765432',
		product_name => 'Wawa Turkey Club',
		brands => 'Wawa',
		categories => 'Sandwiches',
		ingredients_text => 'undefined',
		creator => 'openfoodfacts-contributors',
		created_t => 1740050000,
		last_modified_by => 'openfoodfacts-contributors',
		rev => 1,
		editors_tags => ['openfoodfacts-contributors'],
		%overrides,
	};
}

# 1. Correct MenuStat identification
{
	my $p = make_menustat_product();
	my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p);
	is($match, 1, '18-digit MenuStat record matches');
	is($reason, 'matched_menustat_undefined_import', 'matched reason returned');

	my $p_case = make_menustat_product(
		code => '123456789012345',
		ingredients_text => '  Undefined ',
	);
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_case);
	is($match, 1, '15-digit record with whitespace/mixed-case undefined matches');

	my $p_bad_13 = make_menustat_product(code => '4006381333932');    # invalid check digit
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_bad_13);
	is($match, 1, '13-digit MenuStat record failing GTIN check digit matches');
}

# 2. Incorrect creator exclusion
{
	my $p = make_menustat_product(creator => 'alice-contributor');
	my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p);
	is($match, 0, 'non-bulk creator is excluded');
	is($reason, 'creator_mismatch', 'exclusion reason is creator_mismatch');
}

# 3. Timestamp exclusion
{
	my $p_before = make_menustat_product(created_t => 1740009599);    # 1s before Feb 20 UTC
	my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_before);
	is($match, 0, 'record before Feb 20 2025 UTC window is excluded');
	is($reason, 'timestamp_out_of_window', 'exclusion reason is timestamp_out_of_window');

	my $p_after = make_menustat_product(created_t => 1740182400);    # 1s after Feb 21 UTC
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_after);
	is($match, 0, 'record after Feb 21 2025 UTC window is excluded');
	is($reason, 'timestamp_out_of_window', 'exclusion reason is timestamp_out_of_window');
}

# 4. Valid GTIN exclusion (GTIN-8, GTIN-12, GTIN-13, GTIN-14)
{
	for my $gtin (qw(96385074 036000291452 4006381333931 10012345678902)) {
		my $p = make_menustat_product(code => $gtin);
		my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p);
		is($match, 0, "valid GTIN $gtin is excluded");
		is($reason, 'valid_gtin', "valid GTIN $gtin reports valid_gtin");
	}
}

# 5. User-edited product exclusion
{
	my $p_rev = make_menustat_product(rev => 2);
	my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_rev);
	is($match, 0, 'product with rev > 1 is excluded');
	is($reason, 'user_edited', 'rev > 1 reports user_edited');

	my $p_editor = make_menustat_product(editors_tags => ['openfoodfacts-contributors', 'human-reviewer']);
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_editor);
	is($match, 0, 'product with human editor in editors_tags is excluded');
	is($reason, 'user_edited', 'human editor reports user_edited');

	my $p_last_mod = make_menustat_product(last_modified_by => 'human-reviewer');
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_last_mod);
	is($match, 0, 'product last modified by another user is excluded');
	is($reason, 'user_edited', 'last_modified_by reports user_edited');
}

# 6. Image-bearing product exclusion
{
	my $p_last_img = make_menustat_product(last_image_t => 1740050100);
	my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_last_img);
	is($match, 0, 'product with last_image_t is excluded');
	is($reason, 'has_images', 'last_image_t reports has_images');

	my $p_uploaded = make_menustat_product(images => {uploaded => {'1' => {uploader => 'openfoodfacts-contributors'}}});
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_uploaded);
	is($match, 0, 'product with uploaded images hash is excluded');
	is($reason, 'has_images', 'uploaded images reports has_images');

	my $p_selected = make_menustat_product(images => {selected => {front_en => {rev => 1}}});
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_selected);
	is($match, 0, 'product with selected images hash is excluded');
	is($reason, 'has_images', 'selected images reports has_images');

	my $p_legacy_img = make_menustat_product(images => {'1' => {sizes => {}}});
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_legacy_img);
	is($match, 0, 'product with legacy images key is excluded');
	is($reason, 'has_images', 'legacy images reports has_images');

	my $p_photog = make_menustat_product(photographers_tags => ['openfoodfacts-contributors']);
	($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_photog);
	is($match, 0, 'product with photographers_tags is excluded');
	is($reason, 'has_images', 'photographers_tags reports has_images');
}

# 7. Unrelated undefined-ingredient product exclusion (simulating the 3 unrelated records)
{
	my $p_unrelated_1 = make_menustat_product(
		code => '3017620422003',    # valid EAN-13 Nutella
		ingredients_text => 'undefined',
		creator => 'some-user',
		created_t => 1700000000,
	);
	my $p_unrelated_2 = make_menustat_product(
		code => '111122223333444455',
		ingredients_text => 'Water, Sugar, Undefined extract',
	);
	my $p_unrelated_3 = make_menustat_product(
		code => '012345678905',    # valid UPC-12
		ingredients_text => 'undefined',
	);

	for my $unrelated ($p_unrelated_1, $p_unrelated_2, $p_unrelated_3) {
		my ($match, undef) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($unrelated);
		is($match, 0, "unrelated record $unrelated->{code} is strictly excluded");
	}
}

# 8. Already-deleted product handling
{
	my $p_del = make_menustat_product(deleted => 'on');
	my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_del);
	is($match, 0, 'already-deleted product is skipped');
	is($reason, 'already_deleted', 'reason is already_deleted');
}

# 9 & 10. Dry-run write prevention vs Explicit execution safeguards + store_product contract
{
	my %db = (
		'900000000000000001' => make_menustat_product(code => '900000000000000001'),
		'900000000000000002' => make_menustat_product(code => '900000000000000002'),
		'4006381333931' => make_menustat_product(code => '4006381333931'),    # valid GTIN -> protected
	);
	my @store_calls = ();
	my $mock_store = sub ($user_id, $prod, $comment) {
		push @store_calls,
			{user_id => $user_id, code => $prod->{code}, deleted => $prod->{deleted}, comment => $comment};
		return 1;
	};
	my $mock_retrieve = sub ($code) {
		my $p = $db{$code};
		return if !$p || $p->{deleted};
		return $p;
	};

	# Dry-run default (execute => 0)
	my $dry_cursor = FakeCursor->new(map {{code => $_}} sort keys %db);
	my $dry_stats = ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 0},
		{cursor => $dry_cursor, retrieve_fn => $mock_retrieve, store_fn => $mock_store},
	);
	is(scalar(@store_calls), 0, 'dry-run mode performs zero store_product writes');
	is($dry_stats->{matched}, 2, 'dry-run counts 2 matching MenuStat items');
	is($dry_stats->{excluded}, 1, 'dry-run counts 1 excluded valid GTIN item');
	is($dry_stats->{dry_run_candidates}, 2, 'dry-run records 2 candidates');
	is($dry_stats->{remediated}, 0, 'dry-run records 0 remediated');
	ok(!$db{'900000000000000001'}{deleted}, 'dry-run does not mutate product deleted flag');

	# Explicit execution mode (execute => 1)
	my $exec_cursor = FakeCursor->new(map {{code => $_}} sort keys %db);
	my $exec_stats = ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 1},
		{cursor => $exec_cursor, retrieve_fn => $mock_retrieve, store_fn => $mock_store},
	);
	is(scalar(@store_calls), 2, 'execute mode calls store_product only for the 2 matched candidates');
	is($exec_stats->{remediated}, 2, 'execute mode reports 2 remediated');
	is($exec_stats->{excluded}, 1, 'execute mode preserves excluded count');
	is($store_calls[0]{user_id}, 'remediate-menustat-bot', 'uses dedicated remediation bot user');
	is($store_calls[0]{deleted}, 'on', 'sets deleted => on before calling store_product');
	like($store_calls[0]{comment}, qr/issue #14863/, 'audit comment references issue #14863');
	ok(!$db{'4006381333931'}{deleted}, 'protected valid GTIN remains untouched');

	# 12. Repeated execution safety (idempotence)
	@store_calls = ();
	my $repeat_cursor = FakeCursor->new(map {{code => $_}} sort keys %db);
	my $repeat_stats = ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 1},
		{cursor => $repeat_cursor, retrieve_fn => $mock_retrieve, store_fn => $mock_store},
	);
	is(scalar(@store_calls), 0, 'repeated execution makes zero store_product calls');
	is($repeat_stats->{remediated}, 0, 'repeated execution remediates 0 already-deleted items');
	is($repeat_stats->{not_found_or_del}, 2, 'repeated execution skips already-deleted items safely');
}

# 11. Limit handling
{
	my %db = (
		'900000000000000011' => make_menustat_product(code => '900000000000000011'),
		'900000000000000012' => make_menustat_product(code => '900000000000000012'),
		'900000000000000013' => make_menustat_product(code => '900000000000000013'),
	);
	my @calls = ();
	my $cursor = FakeCursor->new(map {{code => $_}} sort keys %db);
	my $stats = ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 1, limit => 2},
		{
			cursor => $cursor,
			retrieve_fn => sub ($c) {return $db{$c};},
			store_fn => sub ($u, $p, $cmt) {push @calls, $p->{code}; return 1;},
		},
	);
	is(scalar(@calls), 2, 'limit => 2 stops after processing exactly 2 matched candidates');
	is($stats->{remediated}, 2, 'stats reflects bounded limit count');
	ok(!$db{'900000000000000013'}{deleted}, '3rd item beyond limit is untouched');

	# limit => 0 scans zero items
	my $zero_cursor = FakeCursor->new(map {{code => $_}} sort keys %db);
	my $zero_stats = ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 1, limit => 0},
		{cursor => $zero_cursor, retrieve_fn => sub ($c) {return $db{$c};}, store_fn => sub {return 1;}},
	);
	is($zero_stats->{scanned}, 0, 'limit => 0 scans zero items');
}

# 13. Private/owner product exclusion & GTIN edge cases & Mongo query
{
	my $p_owner = make_menustat_product(owner => 'org-acme');
	my ($match, $reason) = ProductOpener::Scripts::RemediateMenuStat::evaluate_menustat_product($p_owner);
	is($match, 0, 'private product with owner is excluded');
	is($reason, 'has_owner', 'exclusion reason is has_owner');

	is(ProductOpener::Scripts::RemediateMenuStat::is_valid_gtin('00000000'),
		0, 'all-zero 8-digit code is not valid GTIN');
	is(ProductOpener::Scripts::RemediateMenuStat::is_valid_gtin('0000000000000'),
		0, 'all-zero 13-digit code is not valid GTIN');
	is(ProductOpener::Scripts::RemediateMenuStat::is_valid_gtin('abc12345'), 0, 'non-numeric code is not valid GTIN');
	is(ProductOpener::Scripts::RemediateMenuStat::is_valid_gtin('96385075'),
		0, 'invalid GTIN-8 check digit is rejected');
	is(ProductOpener::Scripts::RemediateMenuStat::is_valid_gtin('036000291453'),
		0, 'invalid GTIN-12 check digit is rejected');
	is(ProductOpener::Scripts::RemediateMenuStat::is_valid_gtin('10012345678903'),
		0, 'invalid GTIN-14 check digit is rejected');

	my $q = ProductOpener::Scripts::RemediateMenuStat::build_mongo_query();
	is($q->{creator}, 'openfoodfacts-contributors', 'Mongo query filters by expected creator');
	is($q->{created_t}{'$gte'}, 1740009600, 'Mongo query sets numeric $gte bound');
	is($q->{created_t}{'$lte'}, 1740182399, 'Mongo query sets numeric $lte bound');
}

# 14. Error handling, _id retrieval, and batch throttling
{
	my %db = (
		'id_1' => make_menustat_product(_id => 'id_1', code => '900000000000000021'),
		'id_2' => make_menustat_product(_id => 'id_2', code => '900000000000000022'),
		'id_3' => make_menustat_product(_id => 'id_3', code => '900000000000000023'),
		'id_4' => make_menustat_product(_id => 'id_4', code => '900000000000000024'),
	);
	my @slept = ();
	my $cursor = FakeCursor->new(map {{_id => $_, code => $db{$_}{code}}} sort keys %db);
	my $stats = ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 1, batch_size => 2, batch_sleep => 3},
		{
			cursor => $cursor,
			retrieve_fn => sub ($id) {return $db{$id};},
			store_fn => sub ($u, $p, $cmt) {
				die("simulated disk error\n") if $p->{code} eq '900000000000000022';
				return 0 if $p->{code} eq '900000000000000023';
				return 1;
			},
			sleep_fn => sub ($sec) {push @slept, $sec;},
		},
	);
	is($stats->{matched}, 4, 'all 4 candidates matched despite intermediate errors');
	is($stats->{remediated}, 2, '2 candidates succeeded');
	is($stats->{errors}, 2, '2 failures (exception + false return) recorded safely');
	is(\@slept, [3, 3], 'sleep triggered once after each successful remediation (not on failures)');

	# Default non-zero batch_sleep, dry-run exclusion, and explicit 0 override
	my @default_slept = ();
	my $default_exec_cursor = FakeCursor->new({code => '900000000000000021'}, {code => '900000000000000024'});
	ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 1},
		{
			cursor => $default_exec_cursor,
			retrieve_fn => sub ($c) {return make_menustat_product(code => $c);},
			store_fn => sub {return 1;},
			sleep_fn => sub ($sec) {push @default_slept, $sec;},
		},
	);
	is(\@default_slept, [1, 1], 'default batch_sleep is 1s per successful write during execute');

	my @dry_slept = ();
	my $dry_cursor = FakeCursor->new({code => '900000000000000021'});
	ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 0},
		{
			cursor => $dry_cursor,
			retrieve_fn => sub ($c) {return make_menustat_product(code => $c);},
			store_fn => sub {return 1;},
			sleep_fn => sub ($sec) {push @dry_slept, $sec;},
		},
	);
	is(\@dry_slept, [], 'dry-run does not sleep even with non-zero default batch_sleep');

	my @override_slept = ();
	my $override_cursor = FakeCursor->new({code => '900000000000000021'});
	ProductOpener::Scripts::RemediateMenuStat::run_remediation(
		{execute => 1, batch_sleep => 0},
		{
			cursor => $override_cursor,
			retrieve_fn => sub ($c) {return make_menustat_product(code => $c);},
			store_fn => sub {return 1;},
			sleep_fn => sub ($sec) {push @override_slept, $sec;},
		},
	);
	is(\@override_slept, [0], 'explicit batch_sleep => 0 overrides default delay');
}

# 15. CLI validation safeguards in main()
{
	my $help_out = '';
	open my $help_fh, '>', \$help_out or die($!);
	my $help_rc;
	{
		local *STDOUT = $help_fh;
		$help_rc = ProductOpener::Scripts::RemediateMenuStat::main('--help');
	}
	close $help_fh;
	is($help_rc, 0, '--help exits with 0');
	like($help_out, qr/--batch-sleep SEC.*\(default: 1\)/, '--help advertises default batch_sleep of 1s');
	like($help_out, qr/--batch-size N.*\(default: 100\)/, '--help preserves default batch_size of 100');

	eval {ProductOpener::Scripts::RemediateMenuStat::main('--dry-run', '--execute');};
	like($@, qr/Conflicting options/, 'conflicting --dry-run and --execute flags are rejected');

	eval {ProductOpener::Scripts::RemediateMenuStat::main('--limit', '-1');};
	like($@, qr/Invalid --limit/, 'negative --limit is rejected');

	eval {ProductOpener::Scripts::RemediateMenuStat::main('--min-created-t', '2000', '--max-created-t', '1000');};
	like($@, qr/Invalid timestamp window/, 'inverted timestamp window is rejected');
}

done_testing();
