#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test;
use Test::More;

use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;

remove_all_products();
wait_dynamic_front();
my $ua = new_client();

create_product($ua, {});

# edit preference accessible
my $response = $ua->get("http://frontend/cgi/product.pl?type=edit&code=2000000000099");

#$DB::single = 1;
is $response->{_rc}, 200;

done_testing();