#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;

use ProductOpener::Config qw/%options %server_options $mongodb/;
use ProductOpener::Products qw/get_server_for_product/;

subtest "get_server_for_product resolves server flavor from product_type" => sub {
	local $server_options{private_products} = 0;

	is(get_server_for_product({product_type => 'beauty'}), 'obf', 'beauty maps to obf');
	is(get_server_for_product({product_type => 'petfood'}), 'opff', 'petfood maps to opff');
	is(get_server_for_product({product_type => 'product'}), 'opf', 'generic product maps to opf');
	is(get_server_for_product({product_type => 'food'}), 'off', 'food maps to off');
	is(get_server_for_product({}), 'off', 'default product_type maps to off');
};

subtest "get_server_for_product handles old_product_type during server migrations" => sub {
	local $server_options{private_products} = 0;

	is(get_server_for_product({old_product_type => 'beauty', product_type => 'food'}),
		'obf', 'old_product_type takes precedence to target previous server');
};

subtest "target server database maps correctly in other_servers configuration" => sub {
	is($options{other_servers}{obf}{mongodb}, 'obf', 'obf server maps to obf database');
	is($options{other_servers}{off}{mongodb}, 'off', 'off server maps to off database');
	is($options{other_servers}{opff}{mongodb}, 'opff', 'opff server maps to opff database');
	is($options{other_servers}{opf}{mongodb}, 'opf', 'opf server maps to opf database');
};

done_testing();
