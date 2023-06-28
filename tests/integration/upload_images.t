#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);


my $tests_ref = [
    {
        test_case => 'upload_image_nonexistent_product',
        method => 'POST',
        path => '/cgi/product_image_upload.pl',
        form => {
            code => 'nonexistent_product_code',
            imgupload_front_en => ['/path/to/image.jpg', 'image.jpg']
        }
    },
    {
        test_case => 'upload_image_existing_product',
        method => 'POST',
        path => '/cgi/product_image_upload.pl',
        form => {
            code => 'existing_product_code',
            imgupload_front_en => ['/path/to/image.jpg', 'image.jpg']
        }
    },
    {
        test_case => 'upload_image_too_small',
        method => 'POST',
        path => '/cgi/product_image_upload.pl',
        form => {
            code => 'existing_product_code',
            imgupload_front_en => ['/path/to/small_image.jpg', 'small_image.jpg']
        }
    },
    {
        test_case => 'upload_same_image_twice',
        method => 'POST',
        path => '/cgi/product_image_upload.pl',
        form => {
            code => 'existing_product_code',
            imgupload_front_en => ['/path/to/image.jpg', 'image.jpg']
        }
    }
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
