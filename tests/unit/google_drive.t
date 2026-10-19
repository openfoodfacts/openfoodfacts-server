#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;

use HTTP::Headers;
use HTTP::Response;
use JSON::MaybeXS;
use URI;

use ProductOpener::GoogleDrive qw/:all/;

# Folder URLs

my @folder_urls = (
	[
		"https://drive.google.com/drive/folders/117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1",
		"117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1", undef
	],
	[
		"https://drive.google.com/drive/folders/117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1?usp=sharing",
		"117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1", undef
	],
	[
		" https://drive.google.com/drive/u/0/folders/117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1/ ",
		"117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1", undef
	],
	[
		"https://drive.google.com/drive/u/1/folders/0B4Ab-cDeFgHiJ?resourcekey=0-AbCdEf_GhIj-kL&usp=drive_link",
		"0B4Ab-cDeFgHiJ", "0-AbCdEf_GhIj-kL"
	],
	["drive.google.com/drive/folders/abc_DEF-123", "abc_DEF-123", undef],
	["https://drive.google.com/open?id=abc_DEF-123&resourcekey=0-key", "abc_DEF-123", "0-key"],
);

foreach my $test_ref (@folder_urls) {
	my ($url, $expected_id, $expected_key) = @$test_ref;
	my ($folder_id, $resource_key) = parse_google_drive_folder_url($url);
	is($folder_id, $expected_id, "folder id of $url");
	is($resource_key, $expected_key, "resource key of $url");
}

foreach my $url (
	undef,
	"",
	"https://drive.google.com/file/d/1cwIDauHR8svuiLDgzfxoW89TSMLm0Am0/view?usp=drive_link",
	"https://evil.example.com/drive/folders/117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1",
	"https://drive.google.com.evil.example.com/drive/folders/117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1",
	"ftp://drive.google.com/drive/folders/117ceLWnZ6Zyy4Zx9Klpr0Z2vaenwIAv1",
	"https://drive.google.com/drive/folders/",
	"https://drive.google.com/drive/folders/abc'%20or%20'x",
	)
{
	my @result = parse_google_drive_folder_url($url);
	is(\@result, [], "not a folder url: " . ($url // 'undef'));
}

# Download urls

is(
	get_google_drive_file_download_url({id => "abc"}),
	"https://drive.google.com/uc?export=download&id=abc",
	"download url"
);
is(
	get_google_drive_file_download_url({id => "abc", resource_key => "0-key"}),
	"https://drive.google.com/uc?export=download&id=abc&resourcekey=0-key",
	"download url with a resource key"
);

# Listing: no API key configured

my $result_ref = list_google_drive_folder_images("folder", undef, "");
is($result_ref->{error}, "google_drive_no_api_key", "no API key");
is($result_ref->{images}, [], "no images without an API key");

# Listing with mocked Drive API responses

# folder id => list of pages (each page is the list of files, the last page has no next page token)
my %folders = (
	root => [
		[
			{id => "f1", name => "IMG_9477.HEIC", mimeType => "image/heif"},
			{id => "f2", name => "IMG_9476.HEIC", mimeType => "image/heif"},
			{id => "v1", name => "IMG_9478.MOV", mimeType => "video/quicktime"},
		],
		[
			{id => "f3", name => "barcode.jpg", mimeType => "image/jpeg"},
			{
				id => "sub",
				name => "Subfolder",
				mimeType => "application/vnd.google-apps.folder",
				resourceKey => "0-sub"
			},
			{id => "d1", name => "Notes", mimeType => "application/vnd.google-apps.document"},
		],
	],
	sub => [[{id => "f4", name => "IMG_0001.HEIC", mimeType => "image/heif", resourceKey => "0-f4"},]],
);

my @requests;

sub mock_drive_api ($ua, $url, %headers) {
	my %query = URI->new($url)->query_form;
	push @requests, {query => \%query, headers => \%headers};

	my ($folder_id) = $query{q} =~ /^'([^']+)' in parents and trashed=false$/;
	if ((not defined $folder_id) or (not defined $folders{$folder_id})) {
		return HTTP::Response->new(
			404, "Not Found",
			HTTP::Headers->new(Content_Type => "application/json"),
			encode_json({error => {code => 404, message => "File not found: ."}})
		);
	}
	my $page = $query{pageToken} // 0;
	my $pages_ref = $folders{$folder_id};
	my $content_ref = {files => $pages_ref->[$page]};
	if ($page < $#$pages_ref) {
		$content_ref->{nextPageToken} = $page + 1;
	}
	return HTTP::Response->new(
		200, "OK",
		HTTP::Headers->new(Content_Type => "application/json"),
		encode_json($content_ref)
	);
}

my $ua_module = mock 'LWP::UserAgent' => (override => [get => \&mock_drive_api]);

$result_ref = list_google_drive_folder_images("root", "0-root", "test-key");

is($result_ref->{error}, undef, "no error");
is(
	[map {$_->{path}} @{$result_ref->{images}}],
	["IMG_9476.HEIC", "IMG_9477.HEIC", "Subfolder/IMG_0001.HEIC", "barcode.jpg"],
	"images of the folder and of its subfolder, sorted by path, without the video and the document"
);
is($result_ref->{skipped}, 2, "the video and the document are skipped");
is(
	$result_ref->{images}[2],
	{
		id => "f4",
		name => "IMG_0001.HEIC",
		path => "Subfolder/IMG_0001.HEIC",
		mime_type => "image/heif",
		resource_key => "0-f4"
	},
	"image in a subfolder"
);

is(scalar @requests, 3, "2 pages for the folder, 1 for the subfolder");
is($requests[0]{query}{key}, "test-key", "API key is sent");
is($requests[0]{query}{pageSize}, 1000, "page size");
is($requests[0]{query}{supportsAllDrives}, "true", "supportsAllDrives");
is($requests[0]{query}{includeItemsFromAllDrives}, "true", "includeItemsFromAllDrives");
like($requests[0]{query}{fields}, qr/nextPageToken,files\(id,name,mimeType/, "fields");
is($requests[0]{query}{pageToken}, undef, "no page token for the first page");
is($requests[1]{query}{pageToken}, 1, "page token for the second page");
is($requests[0]{headers}{'X-Goog-Drive-Resource-Keys'}, "root/0-root", "resource key of the folder");
is($requests[2]{headers}{'X-Goog-Drive-Resource-Keys'}, "sub/0-sub", "resource key of the subfolder");

# Folder that does not exist or is not public

@requests = ();
$result_ref = list_google_drive_folder_images("private", undef, "test-key");
is($result_ref->{error}, "google_drive_folder_not_found", "folder not found");
is($requests[0]{headers}{'X-Goog-Drive-Resource-Keys'}, undef, "no resource key header without a resource key");

# API error (e.g. invalid key)

$ua_module = mock 'LWP::UserAgent' => (
	override => [
		get => sub {
			return HTTP::Response->new(
				400, "Bad Request",
				HTTP::Headers->new(Content_Type => "application/json"),
				encode_json({error => {code => 400, message => "API key not valid. Please pass a valid API key."}})
			);
		}
	]
);

$result_ref = list_google_drive_folder_images("root", undef, "bad-key");
is($result_ref->{error}, "google_drive_api_error", "API error");
like($result_ref->{error_message}, qr/API key not valid/, "API error message");

done_testing();
