#!/usr/bin/perl -w

# Deleting or moving an uploaded image is a moderator action: the edit form renders the
# "Manage images" controls only for moderators ([% IF moderator %] in
# product_edit_form_display.tt.html), and the API v3 route to the same sink is gated by the
# "image_delete" permission, which ProductOpener::Permissions maps to admin-or-moderator.
#
# cgi/product_image_move.pl performed no such check, so any unauthenticated client could POST
# move_to_override=trash and strip the uploaded images of any product in the database.
#
# This test checks that the endpoint refuses anonymous and non-moderator callers, that the
# product keeps its image, and that a moderator can still do it.

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Products qw/retrieve_product/;
use ProductOpener::Test qw/remove_all_products remove_all_users get_base64_image_data_from_file/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form %admin_user_form %moderator_user_form/;

use File::Basename "dirname";
use Storable qw(dclone);
use JSON::MaybeXS qw/decode_json encode_json/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $sample_products_images_path = dirname(__FILE__) . "/inputs/upload_images";

# Create an admin, to be able to grant moderator status
my $admin_ua = new_client();
create_user($admin_ua, \%admin_user_form);

# Create a normal user
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

# Create a moderator user
my $moderator_ua = new_client();
create_user($moderator_ua, \%moderator_user_form);

# Admin gives moderator status to the moderator user
my %moderator_edit_form = (
	%moderator_user_form,
	user_group_moderator => "1",
	type => "edit",
);
my $resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp));

# An unauthenticated client
my $anon_ua = new_client();

my $code = '0900000000139';

# Create the product
my %product_form
	= (%{dclone(\%default_product_form)}, (code => $code), product_name => "A product with an image to move",);
edit_product($ua, \%product_form);

# Upload an image on it, through the API v3 route which any logged in user may use
my $upload_response = $ua->post(
	construct_test_url('/api/v3/product/' . $code . '/images'),
	'Content-Type' => 'application/json',
	Content => '{"image_data_base64":"' . get_base64_image_data_from_file("$sample_products_images_path/1.jpg") . '"}'
);
is($upload_response->code, 200, "uploaded an image on the test product");
diag("upload response: " . $upload_response->decoded_content);

# The image must be there, otherwise the checks below would pass for the wrong reason
my $product_ref = retrieve_product($code);
ok(defined $product_ref->{images}{uploaded}{1}, "test product has an uploaded image before the move is attempted")
	or diag("product images: " . encode_json($product_ref->{images} // {}));

sub image_is_still_uploaded ($code) {
	my $ref = retrieve_product($code);
	return ((defined $ref) and (defined $ref->{images}{uploaded}{1})) ? 1 : 0;
}

# post_form() dies on non 2xx responses, and we are specifically testing refused requests
my $move_url = construct_test_url('/cgi/product_image_move.pl');

sub post_move ($ua, $fields_ref) {
	return $ua->post($move_url, Content => $fields_ref);
}

sub try_to_trash_image ($ua, $test_case) {
	my $response = post_move(
		$ua,
		{
			code => $code,
			imgids => '1',
			move_to_override => 'trash',
		}
	);
	is($response->code, 403, "$test_case - move image request is refused");
	my $json_ref = eval {decode_json($response->decoded_content)};
	is($json_ref->{status}, 'status not ok', "$test_case - reports a failure status");
	is(image_is_still_uploaded($code), 1, "$test_case - the image is still on the product");
	return;
}

# An anonymous client must not be able to delete the image
try_to_trash_image($anon_ua, 'anonymous');

# Nor must a logged in user who is not a moderator
try_to_trash_image($ua, 'non-moderator');

# Nor via a GET: the request must not be able to smuggle the action through another method
my $get_response = $anon_ua->get($move_url . '?code=' . $code . '&imgids=1&move_to_override=trash');
is($get_response->code, 403, 'anonymous GET - move image request is refused');
is(image_is_still_uploaded($code), 1, 'anonymous GET - the image is still on the product');

# Moving an image onto another product must be refused as well: it can create the destination
# product, and it copies product data over when copy_data_override is set
foreach my $test_case ('anonymous', 'non-moderator') {
	my $move_ua = ($test_case eq 'anonymous') ? $anon_ua : $ua;
	my $response = post_move(
		$move_ua,
		{
			code => $code,
			imgids => '1',
			move_to_override => '0900000000146',
			copy_data_override => 'true',
		}
	);
	is($response->code, 403, "$test_case - move image to another product is refused");
}
ok((not image_is_still_uploaded('0900000000146')), "...and no image was moved to the other product");
is(image_is_still_uploaded($code), 1, "...and the image is still on the original product");

# A moderator can still do it, so the check did not break the moderator-only feature
my $moderator_response = post_move(
	$moderator_ua,
	{
		code => $code,
		imgids => '1',
		move_to_override => 'trash',
	}
);
is($moderator_response->code, 200, 'moderator - move image request is accepted');
is(image_is_still_uploaded($code), 0, 'moderator - the image was removed from the product');

done_testing();
