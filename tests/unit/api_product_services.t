#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Cpanel::JSON::XS;
use ProductOpener::APIProductServices;

my $blessed_value = bless(\"1", "Test::BlessedScalar");
my $payload = {
	product => {
		packaging_recycling => $blessed_value,
		ingredients => [{is_in_taxonomy => $blessed_value}],
	},
};

my $json = Cpanel::JSON::XS->new->decode(
	Cpanel::JSON::XS->new->encode(ProductOpener::APIProductServices::_plain_data_for_json($payload))
);

is(
	$json,
	{
		product => {
			packaging_recycling => "1",
			ingredients => [{is_in_taxonomy => "1"}],
		}
	},
	"blessed scalar values are normalized before JSON encoding",
);

done_testing();
