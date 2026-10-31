#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use ProductOpener::Config qw/%options/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;
use ProductOpener::Products qw/
	reconcile_phantom_selected_images
	normalize_product_data
	product_path
	product_path_from_id
	store_product
/;
use ProductOpener::Store qw/store_object retrieve_object/;

# Set up isolated temp base dirs
my $temp_dir = tempdir(CLEANUP => 1);
local $BASE_DIRS{PRODUCTS} = "$temp_dir/products";
local $BASE_DIRS{PRODUCTS_IMAGES} = "$temp_dir/products_images";
local $BASE_DIRS{DELETED_IMAGES} = "$temp_dir/deleted_images";

ensure_dir_created_or_die($BASE_DIRS{PRODUCTS});
ensure_dir_created_or_die($BASE_DIRS{PRODUCTS_IMAGES});
ensure_dir_created_or_die($BASE_DIRS{DELETED_IMAGES});

# =========================================================================
# Test 1: reconcile_phantom_selected_images (#1866)
# =========================================================================
subtest 'reconcile_phantom_selected_images detects and restores phantom images' => sub {
	my $code = '8436551865089';
	my $path = product_path_from_id($code);
	my $img_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	make_path($img_dir);

	# Case 1A: Normal product with no phantoms
	my $normal_product = {
		code => $code,
		images => {
			uploaded => {
				1 => { uploader => 'user1', uploaded_t => 1000, sizes => {} },
			},
			selected => {
				front => {
					en => { imgid => 1, rev => 1 },
				},
			},
		},
	};
	my $count = reconcile_phantom_selected_images($normal_product);
	is($count, 0, 'normal product has 0 phantoms reconciled');
	is([keys %{$normal_product->{images}{uploaded}}], [1], 'uploaded images unchanged');

	# Case 1B: Phantom selected image where file does NOT exist on disk
	my $missing_file_product = {
		code => $code,
		images => {
			uploaded => {},
			selected => {
				nutrition => {
					es => { imgid => 99, rev => 1 },
				},
			},
		},
	};
	$count = reconcile_phantom_selected_images($missing_file_product);
	is($count, 0, 'phantom without file on disk is not restored');
	is(exists $missing_file_product->{images}{uploaded}{99}, F(), 'uploaded 99 does not exist');

	# Case 1C: Phantom selected image where file DOES exist on disk (issue #1866)
	# Create simulated image file 3.jpg on disk
	my $img3_path = "$img_dir/3.jpg";
	open(my $fh, '>', $img3_path) or die "Cannot create $img3_path: $!";
	print $fh "dummy image data";
	close($fh);

	my $phantom_product = {
		code => $code,
		max_imgid => 2,
		images => {
			uploaded => {
				1 => { uploader => 'user1', uploaded_t => 1000 },
				2 => { uploader => 'user1', uploaded_t => 1010 },
			},
			selected => {
				nutrition => {
					es => {
						imgid => 3,
						rev => 2,
						sizes => { 400 => { w => 400, h => 200 } },
						uploader => 'stephane',
					},
				},
			},
		},
	};

	$count = reconcile_phantom_selected_images($phantom_product);
	is($count, 1, 'successfully reconciled 1 phantom selected image');
	ok(exists $phantom_product->{images}{uploaded}{3}, 'image 3 was restored to uploaded');
	is($phantom_product->{images}{uploaded}{3}{uploader}, 'stephane', 'preserved uploader');
	is($phantom_product->{images}{uploaded}{3}{sizes}, { 400 => { w => 400, h => 200 } }, 'preserved sizes');
	is($phantom_product->{max_imgid}, 3, 'max_imgid bumped to 3');

	# Case 1D: normalize_product_data automatically runs reconcile_phantom_selected_images
	my $test_norm_product = {
		code => $code,
		images => {
			uploaded => {},
			selected => {
				nutrition => {
					es => { imgid => 3, rev => 2 },
				},
			},
		},
	};
	normalize_product_data($test_norm_product);
	ok(exists $test_norm_product->{images}{uploaded}{3}, 'normalize_product_data auto-heals phantom selected images');
};

# =========================================================================
# Test 2: Concurrent image preservation in store_product (#12039)
# =========================================================================
subtest 'store_product preserves concurrently uploaded images on rev mismatch' => sub {
	my $code = '5059697394102';
	my $path = product_path_from_id($code);
	my $prod_dir = "$BASE_DIRS{PRODUCTS}/$path";
	my $img_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	make_path($prod_dir);
	make_path($img_dir);

	# Create files 1.jpg, 2.jpg, 3.jpg, 4.jpg, 5.jpg on disk
	foreach my $id (1 .. 5) {
		open(my $fh, '>', "$img_dir/$id.jpg") or die $!;
		print $fh "dummy $id";
		close($fh);
	}

	# Simulate disk state at rev 11 after upload 4 completed
	my $rev11_product = {
		_id => $code,
		code => $code,
		rev => 11,
		max_imgid => 4,
		images => {
			uploaded => {
				1 => { uploader => 'user1', uploaded_t => 100 },
				2 => { uploader => 'user1', uploaded_t => 200 },
				3 => { uploader => 'user1', uploaded_t => 300 },
				4 => { uploader => 'limendonca', uploaded_t => 400 },
			},
			selected => {},
		},
	};
	store_object("$prod_dir/11", $rev11_product);
	store_object("$prod_dir/product", $rev11_product);
	my $changes = [
		(map { { rev => $_, comment => "rev $_" } } 1 .. 10),
		{ rev => 11, comment => "new image 4 - image upload", userid => 'limendonca' },
	];
	store_object("$prod_dir/changes", $changes);

	# Simulate concurrent request B (upload 5), which was loaded at rev 10 before image 4 existed
	# Request B has images { 1, 2, 3 } and adds 5, so its in-memory product has { 1, 2, 3, 5 }
	my $request_b_product = {
		_id => $code,
		code => $code,
		rev => 10,  # Stale rev!
		max_imgid => 5,
		images => {
			uploaded => {
				1 => { uploader => 'user1', uploaded_t => 100 },
				2 => { uploader => 'user1', uploaded_t => 200 },
				3 => { uploader => 'user1', uploaded_t => 300 },
				5 => { uploader => 'limendonca', uploaded_t => 500 },
			},
			selected => {},
		},
	};

	# Update the product via store_product
	ProductOpener::Products::store_product('limendonca', $request_b_product, 'new image 5 - image upload');

	# Check the product saved at rev 12
	my $saved_product = retrieve_object("$prod_dir/product");
	ok(defined $saved_product, 'product was saved');
	is($saved_product->{rev}, 12, 'revision incremented to 12');

	# Verify Image 4 was PRESERVED and NOT deleted!
	ok(exists $saved_product->{images}{uploaded}{4}, 'CONCURRENCY FIX: image 4 was preserved in rev 12!');
	ok(exists $saved_product->{images}{uploaded}{5}, 'image 5 was also included in rev 12');
	is($saved_product->{max_imgid}, 5, 'max_imgid is 5');

	# Verify that images 1, 2, 3, 4, 5 are all present
	my @imgids = sort { $a <=> $b } keys %{$saved_product->{images}{uploaded}};
	is(\@imgids, [1, 2, 3, 4, 5], 'all uploaded images 1..5 are present without any data loss');
};

done_testing();
