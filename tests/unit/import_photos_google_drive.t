#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;

use HTTP::Headers;
use HTTP::Response;

use ProductOpener::Producers qw/:all/;

# Import of the photos of a Google Drive folder, with the Drive API, the downloads and
# the processing of each image mocked

my @images = (
	{id => "id1", name => "IMG_0001.HEIC", path => "IMG_0001.HEIC", mime_type => "image/heif"},
	{id => "id2", name => "IMG_0002.HEIC", path => "IMG_0002.HEIC", mime_type => "image/heif"},
	{id => "id3", name => "IMG_0003.HEIC", path => "IMG_0003.HEIC", mime_type => "image/heif"},
	{
		id => "id4",
		name => "3001234567890.front_fr.jpg",
		path => "sub/3001234567890.front_fr.jpg",
		mime_type => "image/jpeg"
	},
	{
		id => "id5",
		name => "IMG_0005.HEIC",
		path => "sub/IMG_0005.HEIC",
		mime_type => "image/heif",
		resource_key => "0-k"
	},
);

my %id_for_name = map {$_->{name} => $_->{id}} @images;

my $listing_ref = {images => \@images, skipped => 2};
my @downloaded_urls;
my @import_calls;
my %import_exceptions;
# id => list of HTTP status codes returned by successive downloads (200 by default)
my %download_statuses = (id5 => [404]);

# Do not wait before retrying downloads
$ProductOpener::Producers::GOOGLE_DRIVE_DOWNLOAD_RETRY_DELAY = 0;

# id => response of import_product_image_file()
my %import_responses = (
	id1 => {
		status => 'status ok',
		code => '1234567890128',
		image => {imgid => 1},
		files => [
			{
				filename => "IMG_0001.HEIC",
				code => "1234567890128",
				scanned_code => "1234567890128",
				url => "/product/1234567890128",
				thumbnailUrl => "/images/products/1.100.jpg"
			}
		],
	},
	id2 => {
		status => 'status ok',
		code => '1234567890128',
		image => {imgid => 2},
		files => [{filename => "IMG_0002.HEIC", code => "1234567890128", using_previous_code => "1234567890128"}],
	},
	id3 => {
		status => 'status not ok',
		code => '1234567890128',
		files => [
			{
				filename => "IMG_0003.HEIC",
				code => "1234567890128",
				using_previous_code => "1234567890128",
				info => "already uploaded"
			}
		],
	},
	id4 => {
		status => 'status ok',
		code => '3001234567890',
		image => {imgid => 1},
		files => [
			{filename => "3001234567890.front_fr.jpg", code => "3001234567890", code_from_file_name => "3001234567890"}
		],
	},
);

my $producers_module = mock 'ProductOpener::Producers' => (
	override => [
		list_google_drive_folder_images => sub ($folder_id, $resource_key = undef) {
			return $listing_ref;
		},
		download_image => sub ($url) {
			push @downloaded_urls, $url;
			my ($id) = $url =~ /id=(id\d)/;
			my $status = shift(@{$download_statuses{$id} // []}) // 200;
			if ($status != 200) {
				return HTTP::Response->new($status, "Error $status");
			}
			return HTTP::Response->new(200, "OK", HTTP::Headers->new(Content_Type => "image/heic"), "image data");
		},
		import_product_image_file => sub ($args_ref) {
			my $id = $id_for_name{$args_ref->{filename}};
			push @import_calls, {%$args_ref, id => $id, file_exists => (-e $args_ref->{file_path}) ? 1 : 0};
			die $import_exceptions{$id} if exists $import_exceptions{$id};
			return $import_responses{$id};
		},
	]
);

my @progress;

my $results_ref = import_photos_from_google_drive_folder(
	{
		folder_id => "folder",
		user_id => "producer",
		org_id => "org",
		owner_id => "org-org",
		lc => "fr",
		country => "en:france",
		add_field_values => [{field => "brands", value => "Brand"}],
	},
	sub ($progress_ref) {push @progress, $progress_ref->{processed};}
);

is($results_ref->{status}, "done", "import done");
is($results_ref->{images_in_folder}, 5, "images in folder");
is($results_ref->{skipped_files}, 2, "skipped files");
is($results_ref->{total}, 5, "images to import");
is($results_ref->{processed}, 5, "images processed");
is(\@progress, [0, 1, 2, 3, 4, 5], "progress reported after the listing and after each image");

is(
	\@downloaded_urls,
	[
		"https://drive.google.com/uc?export=download&id=id1",
		"https://drive.google.com/uc?export=download&id=id2",
		"https://drive.google.com/uc?export=download&id=id3",
		"https://drive.google.com/uc?export=download&id=id4",
		"https://drive.google.com/uc?export=download&id=id5&resourcekey=0-k",
	],
	"images downloaded in order, a 404 is not retried"
);

is(scalar @import_calls, 4, "the image that could not be downloaded is not processed");
is([map {$_->{filename}} @import_calls], [map {$_->{name}} @images[0 .. 3]], "original file names");
like($import_calls[0]{file_path}, qr/\.heic$/, "extension of the file name is kept");
like($import_calls[3]{file_path}, qr/\.jpg$/, "extension of the file name is kept");
is($import_calls[0]{file_exists}, 1, "the image is saved before being processed");
ok(!-e $import_calls[0]{file_path}, "the downloaded image is deleted after being processed");
is($import_calls[0]{owner_id}, "org-org", "owner");
is($import_calls[0]{lc}, "fr", "language");
is($import_calls[0]{add_field_values}, [{field => "brands", value => "Brand"}], "field values");

# The code of the last photo with a scanned barcode is used for the next photos
is($import_calls[0]{previous_code}, undef, "no previous code for the first photo");
is($import_calls[1]{previous_code}, "1234567890128", "previous code is the scanned code");
is($import_calls[1]{previous_imgid}, 1, "previous imgid is the image with the scanned code");
is($import_calls[2]{previous_code}, "1234567890128", "previous code is kept");
is($import_calls[2]{previous_imgid}, "", "previous imgid is reset");
is($import_calls[3]{previous_code}, "1234567890128", "a code from the file name does not change the previous code");

is(
	$results_ref->{results},
	[
		{
			file => "IMG_0001.HEIC",
			code => "1234567890128",
			code_source => "scan",
			product_url => "/product/1234567890128",
			thumbnail_url => "/images/products/1.100.jpg"
		},
		{
			file => "IMG_0002.HEIC",
			code => "1234567890128",
			code_source => "previous_photo",
			product_url => undef,
			thumbnail_url => undef
		},
		{
			file => "IMG_0003.HEIC",
			code => "1234567890128",
			code_source => "previous_photo",
			product_url => undef,
			thumbnail_url => undef,
			info => "already uploaded"
		},
		{
			file => "sub/3001234567890.front_fr.jpg",
			code => "3001234567890",
			code_source => "file_name",
			product_url => undef,
			thumbnail_url => undef
		},
		{file => "sub/IMG_0005.HEIC", error => match qr/could not download the image: 404/},
	],
	"results for each file"
);

# Folder that cannot be listed

$listing_ref
	= {images => [], skipped => 0, error => "google_drive_folder_not_found", error_message => "File not found"};
$results_ref
	= import_photos_from_google_drive_folder({folder_id => "folder", user_id => "producer", owner_id => "org-org"});
is($results_ref->{status}, "error", "error status");
is($results_ref->{error}, "google_drive_folder_not_found", "listing error");

# Number of images imported at once is capped

@downloaded_urls = ();
@import_calls = ();
$listing_ref = {images => [@images[0 .. 2]], skipped => 0};
{
	local $ProductOpener::Producers::GOOGLE_DRIVE_IMPORT_MAX_IMAGES = 2;
	$results_ref
		= import_photos_from_google_drive_folder({folder_id => "folder", user_id => "producer", owner_id => "org-org"});
}
is($results_ref->{images_in_folder}, 3, "images in folder");
is($results_ref->{max_images}, 2, "max images");
is($results_ref->{total}, 2, "only the first images are imported");
is(scalar @downloaded_urls, 2, "only the first images are downloaded");

# A failed image import is reported without stopping the batch or leaking its file.

@import_calls = ();
@progress = ();
$listing_ref = {images => [@images[0 .. 3]], skipped => 0};
$import_exceptions{id2} = "image processing failed\n";
$results_ref = import_photos_from_google_drive_folder(
	{folder_id => "folder", user_id => "producer", owner_id => "org-org"},
	sub ($progress_ref) {push @progress, $progress_ref->{processed};}
);
is($results_ref->{status}, "done", "a per-image exception does not fail the batch");
is($results_ref->{processed}, 4, "all images are processed after an exception");
is(scalar @import_calls, 4, "later imports are attempted after an exception");
is(\@progress, [0, 1, 2, 3, 4], "progress advances for failed and successful images");
is($results_ref->{results}[1]{error}, "could not process the image",
	"a generic error is recorded for the failed image");
is($results_ref->{results}[3]{code}, "3001234567890", "a later image is imported successfully");
# We do not know if the failed photo had a barcode: the next photos are not added to the previous product
is($import_calls[2]{previous_code}, undef, "an exception resets the previous code");
is($import_calls[2]{previous_imgid}, undef, "an exception resets the previous image id");

foreach my $call_ref (@import_calls) {
	ok(!-e $call_ref->{file_path}, "the downloaded file is deleted for $call_ref->{id}");
}
delete $import_exceptions{id2};

# A photo that cannot be downloaded may be the photo of the barcode of a new product:
# the next photos are not added to the previous product

@import_calls = ();
@downloaded_urls = ();
$listing_ref = {images => [@images[0, 4, 1]], skipped => 0};
%download_statuses = (id5 => [404]);
$results_ref
	= import_photos_from_google_drive_folder({folder_id => "folder", user_id => "producer", owner_id => "org-org"});
is([map {$_->{id}} @import_calls], ["id1", "id2"], "the photo that could not be downloaded is not processed");
is($import_calls[1]{previous_code}, undef, "a failed download resets the previous code");
is($import_calls[1]{previous_imgid}, undef, "a failed download resets the previous image id");

# Temporary errors are retried once

@import_calls = ();
@downloaded_urls = ();
$listing_ref = {images => [@images[0, 1]], skipped => 0};
%download_statuses = (id1 => [503], id2 => [429, 503]);
$results_ref
	= import_photos_from_google_drive_folder({folder_id => "folder", user_id => "producer", owner_id => "org-org"});
is(scalar(grep {/id=id1/} @downloaded_urls), 2, "a 503 is retried");
is($results_ref->{results}[0]{error}, undef, "the retried download succeeded");
is(scalar(grep {/id=id2/} @downloaded_urls), 2, "a download is retried only once");
like($results_ref->{results}[1]{error}, qr/could not download the image: 503/, "the second error is reported");
is([map {$_->{id}} @import_calls], ["id1"], "only the downloaded photo is processed");

# Each import uses its own temporary directory

my ($tmp_dir_1) = $import_calls[0]{file_path} =~ m{^(.*)/[^/]+$};
@import_calls = ();
%download_statuses = ();
import_photos_from_google_drive_folder({folder_id => "folder", user_id => "producer", owner_id => "org-org"});
my ($tmp_dir_2) = $import_calls[0]{file_path} =~ m{^(.*)/[^/]+$};
isnt($tmp_dir_1, $tmp_dir_2, "two imports do not share a temporary directory");
like($tmp_dir_1, qr{/google_drive_import_\w+$}, "temporary directory name");

# Only one import at a time per owner

my @queued_jobs = ({id => 7, args => [{owner_id => "org-other"}]}, {id => 8, args => [{owner_id => "org-org"}]});
my @enqueued;
my $fake_minion = mock {} => (
	add => [
		jobs => sub ($self, $options_ref) {
			is($options_ref->{states}, ['inactive', 'active'], "only queued and running jobs are checked");
			my @jobs = @queued_jobs;
			return mock {} => (add => [next => sub {return shift @jobs}]);
		},
		enqueue => sub ($self, $task, $args_ref, $options_ref) {push @enqueued, $args_ref->[0]{owner_id}; return 9},
	]
);
$producers_module->override(get_minion => sub {return $fake_minion});
{
	local $ProductOpener::Config2::google_drive_api_key = "test-key";
	my $url = "https://drive.google.com/drive/folders/117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1";

	my $start_ref = start_google_drive_photos_import({folder_url => $url, owner_id => "org-org"});
	is(
		$start_ref,
		{error => "google_drive_import_already_running", job_id => 8},
		"an owner cannot start a second import"
	);

	$start_ref = start_google_drive_photos_import({folder_url => $url, owner_id => "org-new"});
	is($start_ref, {job_id => 9}, "another owner can start an import");
	is(\@enqueued, ["org-new"], "only the import of the other owner is queued");
}

done_testing();
