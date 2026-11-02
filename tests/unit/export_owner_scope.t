#!/usr/bin/perl -w

# Check that ProductOpener::Export::export_csv() refuses to run a query that selects products
# belonging to a different owner than the one the export was requested for.
#
# On the producers platform, the products of each organization are private and unpublished:
# an export query that is not scoped to the requesting owner reads another organization's data.
# cgi/export_products.pl builds that query partly from request parameters, so the check is
# enforced here, where the query reaches MongoDB, and not only in the CGI.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP', filter => "info";

use ProductOpener::Config qw/:all/;
use ProductOpener::Export qw/export_csv/;

# Minimal stand-in for the MongoDB collection and cursor used by export_csv(), which records
# the queries it is asked to run. The tests assert both that a cross-tenant query is never
# handed to MongoDB, and that a legitimate export still is, still scoped to its own owner.

our @queries_seen;

{

	package Local::FakeCollection;

	sub new {return bless({}, 'Local::FakeCollection');}

	sub count_documents {
		my ($self, $query_ref) = @_;
		push @queries_seen, $query_ref;
		return 0;
	}

	sub find {
		my ($self, $query_ref) = @_;
		push @queries_seen, $query_ref;
		return bless({}, 'Local::FakeCursor');
	}

	package Local::FakeCursor;

	sub immortal {return;}
	sub reset {return;}
	sub next {return;}
}

sub run_export ($args_ref) {
	@queries_seen = ();

	my $csv = "";
	open(my $filehandle, ">", \$csv) or die("Could not open in-memory filehandle: $!\n");

	$args_ref->{filehandle} = $filehandle;
	$args_ref->{filename} = "test.csv";
	$args_ref->{fields_ref} = ["code"];

	my $ok = eval {
		export_csv($args_ref);
		1;
	};
	my $error = $@;
	close($filehandle);

	return ($ok, $error, [@queries_seen]);
}

# export_csv() calls get_products_collection() unqualified, through the symbol its own
# package imported, so that is what has to be replaced.
{
	no warnings 'redefine';
	local *ProductOpener::Export::get_products_collection = sub {return Local::FakeCollection->new()};

	my $private_products_previous = $server_options{private_products};

	# 1. Cross-tenant query: refused, and never handed to MongoDB.

	$server_options{private_products} = 1;

	my ($ok, $error, $queries_ref)
		= run_export({query => {owner => 'org-victim', code => '3017620422003'}, owner_id => 'user-attacker'});

	ok(!$ok, "export_csv refuses to export the products of another owner");
	like($error, qr/does not match the requested owner/, "...and says why");
	is(scalar @{$queries_ref}, 0, "...without running any query against MongoDB");

	# 2. Matching owner: the export runs, and the query keeps the requested owner.

	($ok, $error, $queries_ref)
		= run_export({query => {owner => 'org-attacker', code => '3017620422003'}, owner_id => 'org-attacker'});

	ok($ok, "export_csv runs when the query owner matches the requested owner") or diag($error);
	ok(scalar @{$queries_ref} > 0, "...and queries MongoDB");
	# export_csv counts the documents before it opens the cursor, so it queries MongoDB more than once
	ok(
		scalar(grep {(defined $_->{owner}) and ($_->{owner} eq 'org-attacker')} @{$queries_ref})
			== scalar @{$queries_ref},
		"...keeping the requested owner in every query"
	);

	# 3. On the public platform there is no tenant scope, so any query is allowed.

	$server_options{private_products} = 0;

	($ok, $error, $queries_ref) = run_export({query => {owner => 'org-anything'}, owner_id => 'user-someone'});

	ok($ok, "export_csv runs on the public platform, where products are not private") or diag($error);

	# 4. Exports that do not declare an owner_id (operator scripts, public CSV export)
	#    are not restricted, as they were before.

	$server_options{private_products} = 1;

	($ok, $error, $queries_ref) = run_export({query => {code => '3017620422003'}});

	ok($ok, "export_csv runs for an export without owner_id") or diag($error);

	$server_options{private_products} = $private_products_previous;
}

done_testing();
