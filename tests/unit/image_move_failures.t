#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Images qw/process_image_move/;

is(ProductOpener::Images::_image_is_too_small(400, 120), 1, 'reject a new small image');
is(ProductOpener::Images::_image_is_too_small(400, 120, 1), 0, 'allow a small image when moving it');
ok(!ProductOpener::Images::_image_is_too_small(400, 160), "allow an image at the height limit");

sub move_result ($upload_result) {
	my $source_code = '0900000000139';
	my $target_code = '0900000000146';
	my $source_product = {
		images => {
			uploaded => {
				1 => {uploader => 'original-contributor', uploaded_t => 1234567890}
			}
		}
	};
	my $target_product = {images => {}};
	my ($delete_calls, $allow_small_image) = (0, undef);

	my $images_mock = mock 'ProductOpener::Images' => (
		override => [
			can_delete_image => sub {1},
			is_valid_code => sub {1},
			product_id_for_owner => sub ($owner_id, $code) {
				return $code eq $source_code ? 'source-id' : 'target-id';
			},
			product_path_from_id => sub ($product_id) {'source-path'},
			retrieve_product => sub ($product_id) {
				return $product_id eq 'source-id' ? $source_product : $target_product;
			},
			process_image_upload =>
				sub ($product, $path, $user_id, $time, $comment, $imgid_ref, $debug_ref, $allow_small) {
				$allow_small_image = $allow_small;
				return $upload_result;
				},
			delete_uploaded_image_and_associated_selected_images => sub ($product, $imgid) {$delete_calls++;},
			store_product => sub {return;},
		],
	);

	process_image_move('moderator', $source_code, '1', $target_code, '');
	$images_mock = undef;

	return ($delete_calls, $allow_small_image);
}

my ($delete_calls, $allow_small_image) = move_result(-4);
is($allow_small_image, 1, 'image moves bypass the minimum-size check');
is($delete_calls, 0, 'a rejected move keeps the source image');

($delete_calls, $allow_small_image) = move_result(2);
is($allow_small_image, 1, 'successful moves also allow existing small images');
is($delete_calls, 1, 'a successful move removes the source image');

done_testing();
