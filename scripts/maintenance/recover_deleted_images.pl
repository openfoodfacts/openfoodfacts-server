#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

use FindBin;
use lib "$FindBin::Bin/../../lib";

use ProductOpener::PerlStandards;

use Getopt::Long;
use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use Digest::MD5 qw(md5_hex);
use Image::Magick;

use ProductOpener::Config qw(:all);
use ProductOpener::Products qw(retrieve_product store_product product_path product_path_from_id is_valid_code);
use ProductOpener::Images qw(generate_resized_images);
use ProductOpener::Store qw(retrieve_object store_object);
use ProductOpener::Display qw(get_product_history_revisions);

my $help;
my $dry_run = 1; # Default is dry-run for safety
my $apply;
my $barcode_filter;
my $mode = 'all'; # 'failed-moves', 'orphans', 'phantoms', 'all'
my $report_file;
my $verbose;

GetOptions(
	'help|h'          => \$help,
	'apply'           => \$apply,
	'dry-run'         => \$dry_run,
	'code|barcode=s'  => \$barcode_filter,
	'mode=s'          => \$mode,
	'report=s'        => \$report_file,
	'verbose|v'       => \$verbose,
);

if ($apply) {
	$dry_run = 0;
}

if ($help) {
	print <<TXT;
Usage: $0 [options]

Recover lost or deleted images from deleted.images or orphaned files on disk.

Options:
  --dry-run             Run in simulation mode without writing changes (default).
  --apply               Actually apply recovery changes to products.
  --code=BARCODE        Process only a specific product barcode (e.g. 0278691220015).
  --mode=MODE           Mode to run:
                          'failed-moves' : recover images lost during barcode move bug (default).
                          'orphans'      : recover orphaned images on disk (issue #12039).
                          'phantoms'     : recover phantom selected images (issue #1866).
                          'all'          : all of the above.
  --report=FILE.csv     Output a CSV report of scanned and recoverable images.
  --verbose             Display extra debug output.
  --help                Show this help message.

TXT
	exit 0;
}

my $csv_fh;
if ($report_file) {
	open($csv_fh, '>', $report_file) or die "Cannot open report file $report_file: $!\n";
	print $csv_fh "type,source_code,target_code,imgid,file_path,uploader,uploaded_t,width,height,status\n";
}

say "=== Open Food Facts - Image Recovery Tool ===";
say "Mode: $mode | Execution: " . ($dry_run ? "DRY-RUN (no changes applied)" : "APPLY (modifications will be written)");
say "Filter: " . ($barcode_filter // "all barcodes");

my $deleted_dir = $BASE_DIRS{DELETED_IMAGES};
unless (-d $deleted_dir) {
	die "Deleted images directory not found at $deleted_dir\n";
}

my %stats = (
	scanned_dirs        => 0,
	failed_moves_found  => 0,
	failed_moves_fixed  => 0,
	orphans_found       => 0,
	orphans_fixed       => 0,
	phantoms_found      => 0,
	phantoms_fixed      => 0,
	errors              => 0,
);

# -------------------------------------------------------------------------
# 1. Recover Failed Moves (images lost during process_image_move)
# -------------------------------------------------------------------------
if ($mode eq 'failed-moves' || $mode eq 'all') {
	say "\n[1] Scanning for images lost during product moves...";

	my @source_dirs;
	if (defined $barcode_filter) {
		push @source_dirs, "$deleted_dir/$barcode_filter" if -d "$deleted_dir/$barcode_filter";
	}
	else {
		opendir(my $dh, $deleted_dir) or die "Cannot read $deleted_dir: $!\n";
		@source_dirs = map { "$deleted_dir/$_" } grep { !/^\./ && -d "$deleted_dir/$_" } readdir($dh);
		closedir($dh);
	}

	foreach my $dir (@source_dirs) {
		$stats{scanned_dirs}++;
		my $source_code = basename($dir);

		# Scan files in deleted.images/$source_code/
		opendir(my $dh, $dir) or next;
		my @files = grep { /\.jpe?g$/i } readdir($dh);
		closedir($dh);
		next unless @files;

		# Find unique numeric imgids among files (e.g. 3.jpg, 3.400.jpg, 3.orig)
		my %deleted_imgids;
		foreach my $f (@files) {
			if ($f =~ /^(\d+)(?:\.|$)/) {
				$deleted_imgids{$1} = "$dir/$1.jpg" if -e "$dir/$1.jpg";
			}
		}
		next unless keys %deleted_imgids;

		# Check revision history of source product to find where they were supposed to move
		my $source_product_ref = retrieve_product($source_code);
		my $path = product_path_from_id($source_code);
		my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes") // [];

		# Find "Moved images <list> to <target>"
		foreach my $change (@{$changes_ref}) {
			my $comment = $change->{comment} // '';
			if ($comment =~ /Moved images ([\d,]+) to (\d+)/i) {
				my @moved_ids = split(/,/, $1);
				my $target_code = $2;

				foreach my $imgid (@moved_ids) {
					next unless exists $deleted_imgids{$imgid};

					$stats{failed_moves_found}++;
					my $img_path = $deleted_imgids{$imgid};

					# Check if target product received this image
					my $target_product_ref = retrieve_product($target_code);
					unless ($target_product_ref) {
						say "  [!] Target product $target_code not found for moved image $imgid from $source_code";
						next;
					}

					# Inspect target's uploaded images to see if it is already present
					my $already_present = 0;
					my $target_images = $target_product_ref->{images}{uploaded} // {};

					# Also calculate MD5 of source file for duplicate comparison
					my $source_md5 = file_md5($img_path);

					# Extract original uploader and uploaded_t from source history if possible
					my ($orig_uploader, $orig_time) = find_original_uploader_and_time($source_code, $imgid, $changes_ref);

					foreach my $tid (keys %{$target_images}) {
						my $tinfo = $target_images->{$tid};
						if (defined $orig_time && defined $tinfo->{uploaded_t} && $orig_time == $tinfo->{uploaded_t}) {
							$already_present = 1;
							last;
						}
					}

					if ($already_present) {
						say "  [-] $source_code image $imgid: already on target $target_code" if $verbose;
						next;
					}

					# Get dimensions
					my ($width, $height) = get_image_dimensions($img_path);

					say "  [*] FOUND LOST IMAGE: $source_code (imgid $imgid, ${width}x${height}) was meant for $target_code";

					if ($csv_fh) {
						print $csv_fh "failed_move,$source_code,$target_code,$imgid,$img_path," .
							($orig_uploader // '') . "," . ($orig_time // '') . ",$width,$height," .
							($dry_run ? "detected" : "recovered") . "\n";
					}

					if ($dry_run) {
						say "      [DRY-RUN] Would recover to $target_code as new image (preserving uploader: " .
							($orig_uploader // 'unknown') . ", time: " . ($orig_time // 'unknown') . ")";
					}
					else {
						# Apply recovery
						my $recovered_imgid = recover_image_to_product(
							$target_product_ref,
							$img_path,
							$orig_uploader // 'recovered',
							$orig_time // time(),
							"Recovered image $imgid from product $source_code (previously lost during move)"
						);

						if ($recovered_imgid > 0) {
							say "      [SUCCESS] Recovered into $target_code as image $recovered_imgid!";
							$stats{failed_moves_fixed}++;
						}
						else {
							say "      [ERROR] Failed to recover into $target_code: error code $recovered_imgid";
							$stats{errors}++;
						}
					}
				}
			}
		}
	}
}

# -------------------------------------------------------------------------
# 2. Recover Orphaned Images on Disk (Issue #12039 sto race condition)
# -------------------------------------------------------------------------
if ($mode eq 'orphans' || $mode eq 'all') {
	say "\n[2] Scanning for orphaned image files on disk (issue #12039)...";

	# If barcode is specified, check only that barcode
	if (defined $barcode_filter) {
		check_orphaned_images_for_product($barcode_filter);
	}
	else {
		say "  Note: Full scan of orphaned images across all products requires traversing products_images directory.";
	}
}

# -------------------------------------------------------------------------
# 3. Recover Phantom Selected Images (Issue #1866 selected without uploaded)
# -------------------------------------------------------------------------
if ($mode eq 'phantoms' || $mode eq 'all') {
	say "\n[3] Scanning for phantom selected images (issue #1866)...";

	# If barcode is specified, check only that barcode
	if (defined $barcode_filter) {
		check_phantom_images_for_product($barcode_filter);
	}
	else {
		say "  Note: Full scan of phantom images requires filtering by product.";
	}
}

say "\n=== Summary ===";
say "Directories scanned:        $stats{scanned_dirs}";
say "Failed moves detected:      $stats{failed_moves_found}";
say "Failed moves recovered:     $stats{failed_moves_fixed}";
say "Orphaned images detected:   $stats{orphans_found}";
say "Orphaned images recovered:  $stats{orphans_fixed}";
say "Phantom images detected:    $stats{phantoms_found}";
say "Phantom images recovered:   $stats{phantoms_fixed}";
say "Errors:                     $stats{errors}";

if ($report_file) {
	close($csv_fh);
	say "Report saved to $report_file";
}

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------

sub get_image_dimensions {
	my ($file) = @_;
	my $image = Image::Magick->new;
	my $err = $image->Read($file);
	return (0, 0) if $err;
	return ($image->Get('width') // 0, $image->Get('height') // 0);
}

sub file_md5 {
	my ($file) = @_;
	open(my $fh, '<', $file) or return '';
	binmode($fh);
	my $ctx = Digest::MD5->new;
	$ctx->addfile($fh);
	close($fh);
	return $ctx->hexdigest;
}

sub find_original_uploader_and_time {
	my ($code, $imgid, $changes_ref) = @_;

	# Search backwards in revision changes for when image was added
	foreach my $c (@{$changes_ref}) {
		my $comment = $c->{comment} // '';
		if ($comment =~ /new image $imgid/i || $comment =~ /Uploaded images.*Added:\s*$imgid/i) {
			my $uploader = $c->{userid} // $c->{user_id};
			my $time = $c->{t};
			return ($uploader, $time);
		}
	}
	return (undef, undef);
}

sub check_orphaned_images_for_product {
	my ($code) = @_;
	my $product_ref = retrieve_product($code);
	return unless $product_ref;

	my $path = product_path_from_id($code);
	my $img_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	return unless -d $img_dir;

	opendir(my $dh, $img_dir) or return;
	my @files = grep { /^\d+\.jpg$/ } readdir($dh);
	closedir($dh);

	my $uploaded = $product_ref->{images}{uploaded} // {};
	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes") // [];

	foreach my $f (@files) {
		if ($f =~ /^(\d+)\.jpg$/) {
			my $id = $1;
			if (!exists $uploaded->{$id}) {
				$stats{orphans_found}++;
				say "  [*] Orphaned image file on disk: $img_dir/$f (missing in product $code metadata)";

				my ($orig_uploader, $orig_time) = find_original_uploader_and_time($code, $id, $changes_ref);
				my $mtime = (stat("$img_dir/$f"))[9] // time();
				my ($w, $h) = get_image_dimensions("$img_dir/$f");

				if ($csv_fh) {
					print $csv_fh "orphan,$code,$code,$id,$img_dir/$f," .
						($orig_uploader // '') . "," . ($orig_time // $mtime) . ",$w,$h," .
						($dry_run ? "detected" : "recovered") . "\n";
				}

				if ($dry_run) {
					say "      [DRY-RUN] Would restore orphan $id into product $code metadata (uploader: " .
						($orig_uploader // 'recovered') . ", time: " . ($orig_time // $mtime) . ", size: ${w}x${h})";
				}
				else {
					# Re-attach into product metadata
					# Generate thumbnails if missing
					my $size_ref = {};
					if (-e "$img_dir/$id.400.jpg") {
						my ($w400, $h400) = get_image_dimensions("$img_dir/$id.400.jpg");
						$size_ref->{400} = { w => $w400, h => $h400 };
					}
					if (-e "$img_dir/$id.100.jpg") {
						my ($w100, $h100) = get_image_dimensions("$img_dir/$id.100.jpg");
						$size_ref->{100} = { w => $w100, h => $h100 };
					}
					if (!keys %$size_ref) {
						my $source = Image::Magick->new;
						$source->Read("$img_dir/$f");
						generate_resized_images($img_dir, $id, $source, $size_ref, 400, 100);
					}

					$product_ref->{images}{uploaded}{$id} = {
						uploader   => $orig_uploader // 'recovered_orphan',
						uploaded_t => $orig_time // $mtime,
						sizes      => $size_ref,
					};
					$product_ref->{max_imgid} = $id if (!defined $product_ref->{max_imgid} || $id > $product_ref->{max_imgid});
					store_product('recovery-bot', $product_ref, "Restored orphaned image $id from disk (issue #12039)");
					say "      [SUCCESS] Restored orphan $id into product $code metadata";
					$stats{orphans_fixed}++;
				}
			}
		}
	}
}

sub check_phantom_images_for_product {
	my ($code) = @_;
	my $product_ref = retrieve_product($code);
	return unless $product_ref;

	my $selected = $product_ref->{images}{selected} // {};
	my $uploaded = $product_ref->{images}{uploaded} // {};
	my $path = product_path_from_id($code);
	my $img_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes") // [];

	foreach my $type (keys %$selected) {
		next unless ref($selected->{$type}) eq 'HASH';
		foreach my $lc (keys %{$selected->{$type}}) {
			my $info = $selected->{$type}{$lc};
			next unless ref($info) eq 'HASH';
			my $id = $info->{imgid};
			next unless defined $id && $id =~ /^\d+$/;

			if (!exists $uploaded->{$id}) {
				$stats{phantoms_found}++;
				say "  [*] Phantom selected image: product $code ${type}_${lc} references image $id (missing in uploaded metadata)";

				my ($orig_uploader, $orig_time) = find_original_uploader_and_time($code, $id, $changes_ref);
				my $img_file = "$img_dir/$id.jpg";
				my $mtime = -e $img_file ? ((stat($img_file))[9] // time()) : time();
				my ($w, $h) = -e $img_file ? get_image_dimensions($img_file) : (0, 0);

				if ($csv_fh) {
					print $csv_fh "phantom,$code,$code,$id," . ($img_file // '') . "," .
						($orig_uploader // '') . "," . ($orig_time // $mtime) . ",$w,$h," .
						($dry_run ? "detected" : "recovered") . "\n";
				}

				if ($dry_run) {
					say "      [DRY-RUN] Would restore phantom selected image $id (${type}_${lc}) into product $code uploaded list";
				}
				else {
					my $size_ref = $info->{sizes} // {};
					if (!keys %$size_ref && -e $img_file) {
						if (-e "$img_dir/$id.400.jpg") {
							my ($w400, $h400) = get_image_dimensions("$img_dir/$id.400.jpg");
							$size_ref->{400} = { w => $w400, h => $h400 };
						}
						if (-e "$img_dir/$id.100.jpg") {
							my ($w100, $h100) = get_image_dimensions("$img_dir/$id.100.jpg");
							$size_ref->{100} = { w => $w100, h => $h100 };
						}
					}

					$product_ref->{images}{uploaded}{$id} = {
						uploader   => $orig_uploader // 'recovered_phantom',
						uploaded_t => $orig_time // $mtime,
						sizes      => $size_ref,
					};
					$product_ref->{max_imgid} = $id if (!defined $product_ref->{max_imgid} || $id > $product_ref->{max_imgid});
					store_product('recovery-bot', $product_ref, "Restored phantom selected image $id (${type}_${lc}) into uploaded images list (issue #1866)");
					say "      [SUCCESS] Restored phantom selected image $id into product $code metadata";
					$stats{phantoms_fixed}++;
				}
			}
		}
	}
}

sub recover_image_to_product {
	my ($product_ref, $source_file, $uploader, $uploaded_t, $comment) = @_;

	my $product_id = $product_ref->{id};
	my $path = product_path($product_ref);
	my $target_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
	
	unless (-d $target_dir) {
		mkdir($target_dir, 0755) or return -1;
	}

	# Allocate new imgid safely
	my $new_imgid = ($product_ref->{max_imgid} || 0) + 1;
	while (-e "$target_dir/$new_imgid.jpg" || -e "$target_dir/$new_imgid.lock") {
		$new_imgid++;
	}

	# Copy original file
	my $dest_file = "$target_dir/$new_imgid.jpg";
	unless (copy($source_file, $dest_file)) {
		return -2;
	}

	# Generate resized versions
	my $source = Image::Magick->new;
	my $err = $source->Read($dest_file);
	if ($err) {
		unlink($dest_file);
		return -5;
	}

	$source->AutoOrient();
	$source->Strip();

	my $size_ref = {};
	my $thumb_size = 100;
	my $crop_size = 400;
	my $res_err = generate_resized_images($target_dir, $new_imgid, $source, $size_ref, $thumb_size, $crop_size);
	if ($res_err) {
		unlink($dest_file);
		return -5;
	}

	# Save metadata
	$product_ref->{images}{uploaded}{$new_imgid} = {
		uploader   => $uploader,
		uploaded_t => $uploaded_t,
		sizes      => $size_ref,
	};
	if (!defined $product_ref->{max_imgid} || $new_imgid > $product_ref->{max_imgid}) {
		$product_ref->{max_imgid} = $new_imgid;
	}

	store_product('recovery-bot', $product_ref, $comment);
	return $new_imgid;
}
