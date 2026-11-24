#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use File::Temp ();
use File::Path qw/make_path/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;
use ProductOpener::Products qw/product_path store_product/;
use ProductOpener::Images qw/delete_all_product_images/;

# Test edge cases and parameter validation
subtest "delete_all_product_images - parameter validation" => sub {
	is(delete_all_product_images(undef), 0, "undef returns 0");
	is(delete_all_product_images([]), 0, "arrayref returns 0");
	is(delete_all_product_images("string"), 0, "scalar returns 0");
	is(delete_all_product_images({}), 0, "hash without code returns 0");

	my $product_no_images = {code => "9999999999991"};
	is(delete_all_product_images($product_no_images), 1, "product without images returns 1 safely");
};

# Test moving uploaded, selected, and leftover images to deleted.images
subtest "delete_all_product_images - moves files and cleans up directories" => sub {
	my $tmp_dir = File::Temp->newdir();
	local $BASE_DIRS{PRODUCTS_IMAGES} = "$tmp_dir/product_images";
	local $BASE_DIRS{DELETED_IMAGES} = "$tmp_dir/deleted_images";

	my $code = "9999999999992";
	my $product_ref = {
		code => $code,
		images => {
			uploaded => {
				"1" => {uploader => "user1"},
				"2" => {uploader => "user2"},
			},
			selected => {
				front => {
					en => {
						imgid => "1",
						rev => "1",
					},
				},
			},
		},
	};

	my $path = product_path($product_ref);
	my $product_img_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	make_path($product_img_dir);

	# Create dummy image files on disk
	my @test_files = qw(
		1.jpg
		1.400.jpg
		1.jpg.orig
		2.jpg
		front_en.1.jpg
		front_en.1.400.jpg
		leftover_photo.jpg
	);

	foreach my $file (@test_files) {
		open my $fh, ">:encoding(UTF-8)", "$product_img_dir/$file" or die "Cannot create test file $file: $!";
		print $fh "dummy content for $file\n";
		close $fh;
	}

	# Verify files were created
	foreach my $file (@test_files) {
		ok(-f "$product_img_dir/$file", "test file $file initially exists");
	}

	my $result = delete_all_product_images($product_ref);
	is($result, 1, "delete_all_product_images returns 1 on success");

	my $deleted_dir = "$BASE_DIRS{DELETED_IMAGES}/$path";
	ok(-d $deleted_dir, "deleted images directory was created");

	# Verify all files were moved to deleted.images and removed from product image dir
	foreach my $file (@test_files) {
		ok(-f "$deleted_dir/$file", "file $file moved to deleted directory");
		ok(!-f "$product_img_dir/$file", "file $file removed from product image directory");
	}

	# Verify product images dir was cleaned up (or empty)
	ok(!-d $product_img_dir || scalar(glob("$product_img_dir/*")) == 0, "product image directory is removed or empty");

	# Verify metadata structures were cleared
	is($product_ref->{images}{uploaded}, {}, "uploaded images metadata cleared");
	ok(!defined $product_ref->{images}{selected} || keys %{$product_ref->{images}{selected}} == 0,
		"selected images metadata unselected/cleared");
};

# Test store_product integration when product is deleted
subtest "store_product - deletes images when product is flagged as deleted" => sub {
	my $tmp_dir = File::Temp->newdir();
	local $BASE_DIRS{PRODUCTS_IMAGES} = "$tmp_dir/product_images";
	local $BASE_DIRS{DELETED_IMAGES} = "$tmp_dir/deleted_images";
	local $BASE_DIRS{PRODUCTS} = "$tmp_dir/products";

	my $code = "9999999999993";
	my $product_ref = {
		_id => $code,
		code => $code,
		deleted => "on",
		images => {
			uploaded => {
				"1" => {uploader => "test_user"},
			},
			selected => {
				front => {
					en => {
						imgid => "1",
						rev => "1",
					},
				},
			},
		},
	};

	my $path = product_path($product_ref);
	my $product_img_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	make_path($product_img_dir);

	open my $fh1, ">:encoding(UTF-8)", "$product_img_dir/1.jpg" or die "Cannot create test file: $!";
	print $fh1 "image 1 data\n";
	close $fh1;

	open my $fh2, ">:encoding(UTF-8)", "$product_img_dir/front_en.1.jpg" or die "Cannot create test file: $!";
	print $fh2 "front image data\n";
	close $fh2;

	my $deleted_doc_id;
	my $mock_collection = mock 'MongoDB::Collection' => (
		override => [
			delete_one => sub {
				my ($self, $query) = @_;
				$deleted_doc_id = $query->{_id};
				return;
			},
			replace_one => sub {return;},
		]
	);

	my $mock_data = mock 'ProductOpener::Data' => (
		override => [
			get_products_collection => sub {return $mock_collection;},
		]
	);

	my $noop = sub {return;};
	my $mock_products = mock 'ProductOpener::Products' => (
		override => [
			add_user_teams => $noop,
			compute_codes => $noop,
			compute_data_sources => $noop,
			compute_keywords => $noop,
			compute_languages => $noop,
			compute_main_countries => $noop,
			compute_product_history_and_completeness => $noop,
			compute_sort_keys => $noop,
			log_change => $noop,
			push_product_update_to_redis => $noop,
		]
	);

	my $res = store_product("admin_user", $product_ref, "Deleting product");
	is($res, 1, "store_product succeeded");

	my $deleted_dir = "$BASE_DIRS{DELETED_IMAGES}/$path";
	ok(-f "$deleted_dir/1.jpg", "image 1 was moved to deleted folder by store_product");
	ok(-f "$deleted_dir/front_en.1.jpg", "front image was moved to deleted folder by store_product");
	ok(!-f "$product_img_dir/1.jpg", "image 1 removed from product image directory");
	ok(!-f "$product_img_dir/front_en.1.jpg", "front image removed from product image directory");
	is($deleted_doc_id, $code, "MongoDB collection delete_one called for product _id");
};

# Test deleting product with invalid code does not sweep shared invalid directory
subtest "delete_all_product_images - skips directory sweep when path is invalid" => sub {
	my $tmp_dir = File::Temp->newdir();
	local $BASE_DIRS{PRODUCTS_IMAGES} = "$tmp_dir/product_images";
	local $BASE_DIRS{DELETED_IMAGES} = "$tmp_dir/deleted_images";

	my $invalid_product = {
		code => "invalid_barcode_test",
		images => {
			uploaded => {
				"1" => {uploader => "user1"},
			},
		},
	};

	my $path = product_path($invalid_product);
	is($path, "invalid", "product_path returns 'invalid' for invalid barcode");
	my $invalid_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	make_path($invalid_dir);

	# Create the product's image and another product's file in the shared invalid directory
	open my $fh1, ">:encoding(UTF-8)", "$invalid_dir/1.jpg" or die "Cannot create file: $!";
	print $fh1 "product 1 image\n";
	close $fh1;

	open my $fh2, ">:encoding(UTF-8)", "$invalid_dir/other_product_file.jpg" or die "Cannot create file: $!";
	print $fh2 "other product image\n";
	close $fh2;

	my $result = delete_all_product_images($invalid_product);
	is($result, 1, "delete_all_product_images succeeded");

	# Verified that uploaded image 1 was moved to deleted
	my $deleted_dir = "$BASE_DIRS{DELETED_IMAGES}/$path";
	ok(-f "$deleted_dir/1.jpg", "product's image 1 was moved to deleted");
	# Crucial: other_product_file.jpg was NOT moved, and invalid directory was NOT deleted
	ok(-f "$invalid_dir/other_product_file.jpg", "other product's file remained in shared invalid directory");
	ok(-d $invalid_dir, "shared invalid directory was preserved");
};

done_testing();
