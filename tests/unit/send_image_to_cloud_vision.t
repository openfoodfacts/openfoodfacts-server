use ProductOpener::PerlStandards;

use Test::More;
use Test::MockModule;
use File::Temp ();
use HTTP::Headers;
use HTTP::Response;
use File::Basename "dirname";
use File::Slurp;
use JSON;

use ProductOpener::Test qw/:all/;
use ProductOpener::Images qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Default OCR response, containing a single response element
my $ocr_default_response = '{"responses": [{}]}';

my @ua_requests = ();
# put responses for call to requests here, we will pop first
my @ua_responses = ();
# fake request for User-Agent module
sub fake_ua_request ($ua, $request_ref) {
	push(@ua_requests, $request_ref);
	return shift @ua_responses;
}

# a very small image to avoid having too large request json object
my $image_path = dirname(__FILE__) . "/inputs/small-img.jpg";

{
	my $user_agent_module = Test::MockModule->new('LWP::UserAgent');
	# mock request
	$user_agent_module->mock('request', \&fake_ua_request);
	my $tmp_dir = File::Temp->newdir();
	my $gv_logs_path = $tmp_dir->dirname . "gv.log";

	# normal test
	open(my $gv_logs, ">:encoding(UTF-8)", $gv_logs_path);
	my $json_path = $tmp_dir . "/small-img.json.gz";
	# expected response
	my $response = HTTP::Response->new("200", "OK", HTTP::Headers->new(), $ocr_default_response);
	push @ua_responses, $response;
	send_image_to_cloud_vision($image_path, $json_path, \@CLOUD_VISION_FEATURES_FULL, $gv_logs);
	close($gv_logs);
	is(scalar @ua_requests, 1, "Normal test - One request issued to cloud vision");
	my $issued_request = shift @ua_requests;
	my $request_json_body = decode_json($issued_request->content());
	compare_to_expected_results($request_json_body, "$expected_result_dir/request_body.json", $update_expected_results);
	my $ocr_content = read_gzip_file($json_path);
	ok($ocr_content, "normal test - OCR file is not empty");
	my $ocr_data = decode_json($ocr_content);
	check_ocr_result($ocr_data);
	my $logs = read_file($gv_logs_path);
	like($logs, qr/cloud vision success/, "normal test - cloud vision success in logs");

	# test new request updates
	open($gv_logs, ">:encoding(UTF-8)", $gv_logs_path);
	$response = HTTP::Response->new("200", "OK", HTTP::Headers->new(), $ocr_default_response);
	push @ua_responses, $response;
	send_image_to_cloud_vision($image_path, $json_path, \@CLOUD_VISION_FEATURES_FULL, $gv_logs);
	close($gv_logs);
	is(scalar @ua_requests, 1, "test request update - One request issued to cloud vision");
	$issued_request = shift @ua_requests;
	$request_json_body = decode_json($issued_request->content());
	compare_to_expected_results($request_json_body, "$expected_result_dir/request_body_2.json",
		$update_expected_results);
	$ocr_content = read_gzip_file($json_path);
	$ocr_data = decode_json($ocr_content);
	check_ocr_result($ocr_data);
	$logs = read_file($gv_logs_path);
	like($logs, qr/cloud vision success/, "test request update - cloud vision success in logs");

	# test with different feature set \@CLOUD_VISION_FEATURES_TEXT
	open($gv_logs, ">:encoding(UTF-8)", $gv_logs_path);
	$response = HTTP::Response->new("200", "OK", HTTP::Headers->new(), $ocr_default_response);
	push @ua_responses, $response;
	send_image_to_cloud_vision($image_path, $json_path, \@CLOUD_VISION_FEATURES_TEXT, $gv_logs);
	close($gv_logs);
	is(scalar @ua_requests, 1, "test request features text - One request issued to cloud vision");
	$issued_request = shift @ua_requests;
	$request_json_body = decode_json($issued_request->content());
	compare_to_expected_results($request_json_body, "$expected_result_dir/request_body_3.json",
		$update_expected_results);
	$ocr_content = read_gzip_file($json_path);
	$ocr_data = decode_json($ocr_content);
	check_ocr_result($ocr_data);
	$logs = read_file($gv_logs_path);
	like($logs, qr/cloud vision success/, "test request features text - cloud vision success in logs");

	# test with bad json path
	open($gv_logs, ">:encoding(UTF-8)", $gv_logs_path);
	$response = HTTP::Response->new("200", "OK", HTTP::Headers->new(), $ocr_default_response);
	push @ua_responses, $response;
	send_image_to_cloud_vision(
		$image_path,
		"/var/lib/not-a-directory/not-writable.json.gz",
		\@CLOUD_VISION_FEATURES_FULL, $gv_logs
	);
	close($gv_logs);
	is(scalar @ua_requests, 1, "non writable json - One request issued to cloud vision");
	$issued_request = shift @ua_requests;
	# log issued
	$logs = read_file($gv_logs_path);
	like($logs, qr|Cannot write /var/lib/not-a-directory/not-writable.json|, "non writable json - error logged");
	unlike($logs, qr/cloud vision success/, "non writable json - no cloud vision success in logs");

	# test bad request
	open($gv_logs, ">:encoding(UTF-8)", $gv_logs_path);
	$json_path = $tmp_dir . "/small-img2.json.gz";
	$response = HTTP::Response->new("403", "Not authorized", HTTP::Headers->new(), $ocr_default_response);
	push @ua_responses, $response;
	send_image_to_cloud_vision($image_path, $json_path, \@CLOUD_VISION_FEATURES_FULL, $gv_logs);
	close($gv_logs);
	is(scalar @ua_requests, 1, "request error - one request issued to cloud vision");
	$issued_request = shift @ua_requests;
	# log issued
	$logs = read_file($gv_logs_path);
	like($logs, qr|error\ttests/unit/inputs/small-img.jpg\t403\tNot authorized|, "request not successfull logged");
	unlike($logs, qr/cloud vision success/, "request error - no cloud vision success in logs");
	# no json path
	ok(!(-e $json_path), "request error - json file not created");

}

done_testing();
