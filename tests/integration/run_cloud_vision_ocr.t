use ProductOpener::PerlStandards;

use Test::More;
use Test::MockModule;
use HTTP::Headers;
use HTTP::Response;
use File::Basename "dirname";
use File::Slurp;
use JSON;
use File::Temp ();
use File::Copy::Recursive qw(dircopy fcopy);
use Test::Fake::HTTPD qw/run_http_server/;
use URL::Encode qw/url_params_mixed/;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

remove_all_products();
wait_application_ready();

# a very small image to avoid having too large request json object
my $sample_products_path = dirname(__FILE__) . "/inputs/sample-products/";
my $sample_products_images_path = dirname(__FILE__) . "/inputs/sample-products-images/";
my $product_code_path = "300/000/000/0001";
my $input_image_path = dirname(__FILE__) . "/inputs/small-img.jpg";

# Note: we can't use a full test uploading an image through the server right now,
# because I don't have the time :-D
# add a sample product
dircopy("$sample_products_path/$product_code_path", "$data_root/products/$product_code_path");
my $image_dir = "$www_root/images/products/$product_code_path";
dircopy("$sample_products_images_path/$product_code_path", $image_dir);
# add an image
fcopy($input_image_path, "$image_dir/2.jpg");
# fake responses for OCR and robtoff
my @responses = (
	HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"responses": [{}]}'),
	HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"robotoff": "success"}'),
);
my $dump_path = File::Temp->newdir();
# start fake server
my $httpd = fake_http_server(8881, $dump_path, \@responses);
# link image - this should trigger the script
symlink("$image_dir/2.jpg", "$data_root/new_images/" . time() . "." . "3000000000001.other.2.jpg");
# wait until we got a response or fail
ok(wait_for(sub {return (-e "$dump_path/req-1.sto");}, 5), "OCR and robotoff called");
$httpd = undef;    # stop server
# verify it's done
my @requests = glob("$dump_path/req-*.sto");
is(scalar @requests, 2, "Two request issued");
my $ocr_request = retrieve("$dump_path/req-0.sto");
my $request_json_body = decode_json($ocr_request->content());
compare_to_expected_results($request_json_body, "$expected_result_dir/ocr_request_body.json", $update_expected_results);
my $ocr_content = read_gzip_file("$image_dir/2.json.gz");
ok($ocr_content, "OCR file is not empty");
my $ocr_data = decode_json($ocr_content);
check_ocr_result($ocr_data);
my $robotoff_request = retrieve("$dump_path/req-1.sto");
# we have url encoded parameters, and order might change --> convert to hash
my $request_content = url_params_mixed($robotoff_request->content());
compare_to_expected_results($request_content, "$expected_result_dir/robotoff_request_body.json",
	$update_expected_results);

done_testing();

