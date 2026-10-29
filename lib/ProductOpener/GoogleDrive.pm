# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::GoogleDrive - list the images of public Google Drive folders

=head1 SYNOPSIS

	my ($folder_id, $resource_key) = parse_google_drive_folder_url($url);
	my $result_ref = list_google_drive_folder_images($folder_id, $resource_key);

=head1 DESCRIPTION

Producers can share the photos of their products in a Google Drive folder shared with
"anyone with the link". The producers platform lists the images of that folder (and of its
subfolders) with the Google Drive API v3, and downloads them one by one.

Listing a folder needs an API key restricted to the Google Drive API, set in the
GOOGLE_DRIVE_API_KEY environment variable ($google_drive_api_key in Config2.pm).

=cut

package ProductOpener::GoogleDrive;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		$GOOGLE_DRIVE_MAX_FOLDER_DEPTH
		$GOOGLE_DRIVE_MAX_LISTED_ITEMS

		&parse_google_drive_folder_url
		&list_google_drive_folder_images
		&get_google_drive_file_download_url

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config2;
use ProductOpener::HTTP qw/create_user_agent/;

use JSON::MaybeXS;
use URI;
use Log::Any qw($log);

# Subfolders deeper than this are not listed
$GOOGLE_DRIVE_MAX_FOLDER_DEPTH = 5;

# Stop listing after this many items (files and folders), so that a huge folder tree does not keep
# the import listing for ever
$GOOGLE_DRIVE_MAX_LISTED_ITEMS = 10000;

my $google_drive_api_files_url = "https://www.googleapis.com/drive/v3/files";

my $google_drive_folder_mime_type = "application/vnd.google-apps.folder";

=head1 FUNCTIONS

=head2 parse_google_drive_folder_url ($url)

Extract the folder id and the resource key (if any) from the URL of a Google Drive folder.

Supported URLs:

	https://drive.google.com/drive/folders/<folder id>
	https://drive.google.com/drive/folders/<folder id>?usp=sharing
	https://drive.google.com/drive/folders/<folder id>?resourcekey=<key>&usp=drive_link
	https://drive.google.com/drive/u/0/folders/<folder id>
	https://drive.google.com/open?id=<folder id>&resourcekey=<key> (only if it is a folder: we cannot know from the URL)

=head3 Arguments

=head4 $url - the folder URL entered by the user

=head3 Return values

A list with the folder id and the resource key (undef if there is none), or an empty list
if the URL is not a Google Drive folder URL.

=cut

sub parse_google_drive_folder_url ($url) {

	return () if not defined $url;

	$url =~ s/^\s+|\s+$//g;

	# Accept URLs entered without the scheme
	$url = "https://" . $url if $url =~ m{^drive\.google\.com/}i;

	my $uri = eval {URI->new($url)};
	return () if (not defined $uri) or (not $uri->can('host'));
	return () if ($uri->scheme // '') !~ /^https?$/i;
	return () if lc($uri->host // '') ne "drive.google.com";

	my %query = $uri->query_form;

	my $folder_id;

	# /drive/folders/<id>, /drive/u/0/folders/<id>, /drive/mobile/folders/<id>
	if ($uri->path =~ m{^/drive/(?:u/\d+/|mobile/)?folders/([\w-]+)/?$}) {
		$folder_id = $1;
	}
	# /open?id=<id> or /drive/u/0/folders?id=<id> share links
	elsif (($uri->path =~ m{^/(?:open|drive/(?:u/\d+/)?folders)/?$}) and (defined $query{id})) {
		$folder_id = $query{id};
	}

	return () if (not defined $folder_id) or ($folder_id !~ /^[\w-]+$/);

	my $resource_key = $query{resourcekey};
	if ((defined $resource_key) and ($resource_key !~ /^[\w-]+$/)) {
		$resource_key = undef;
	}

	return ($folder_id, $resource_key);
}

=head2 get_google_drive_file_download_url ($file_ref)

Return the URL to download a file listed by list_google_drive_folder_images()

=cut

sub get_google_drive_file_download_url ($file_ref) {

	my $url = "https://drive.google.com/uc?export=download&id=" . $file_ref->{id};
	if (defined $file_ref->{resource_key}) {
		$url .= "&resourcekey=" . $file_ref->{resource_key};
	}
	return $url;
}

# List the items directly inside a folder, following pagination.
# Returns an array ref of files, or undef and an error

sub list_google_drive_folder_items ($ua, $folder_id, $resource_keys_header, $api_key, $listed_items_ref) {

	my @items = ();
	my $page_token;

	do {
		my $uri = URI->new($google_drive_api_files_url);
		$uri->query_form(
			q => "'$folder_id' in parents and trashed=false",
			fields => "nextPageToken,files(id,name,mimeType,resourceKey)",
			pageSize => 1000,
			supportsAllDrives => "true",
			includeItemsFromAllDrives => "true",
			orderBy => "name",
			(defined $page_token ? (pageToken => $page_token) : ()),
			key => $api_key,
		);

		my @headers = ('Accept' => 'application/json');
		if (defined $resource_keys_header) {
			push @headers, ('X-Goog-Drive-Resource-Keys' => $resource_keys_header);
		}

		# Do not log the URL: it contains the API key
		$log->debug("listing Google Drive folder", {folder_id => $folder_id, page_token => $page_token})
			if $log->is_debug();

		my $response = $ua->get($uri->as_string, @headers);

		my $content_ref = eval {decode_json($response->decoded_content // '')};

		if (not $response->is_success) {
			my $message = (ref($content_ref) eq 'HASH') ? $content_ref->{error}{message} : undef;
			$log->warn("Google Drive API error",
				{folder_id => $folder_id, status => $response->code, message => $message})
				if $log->is_warn();
			# 404: the folder does not exist, or it is not shared with "anyone with the link"
			if ($response->code == 404) {
				return (undef, "google_drive_folder_not_found", $message);
			}
			return (undef, "google_drive_api_error", ($message // $response->status_line));
		}

		if ((ref($content_ref) ne 'HASH') or (ref($content_ref->{files}) ne 'ARRAY')) {
			return (undef, "google_drive_api_error", "unexpected response");
		}

		push @items, @{$content_ref->{files}};
		$page_token = $content_ref->{nextPageToken};

		$$listed_items_ref += scalar @{$content_ref->{files}};
		if ($$listed_items_ref > $GOOGLE_DRIVE_MAX_LISTED_ITEMS) {
			return (undef, "google_drive_folder_too_many_items", undef);
		}
	} while (defined $page_token);

	return (\@items, undef, undef);
}

=head2 list_google_drive_folder_images ($folder_id, $resource_key, $api_key = $google_drive_api_key)

List the images of a public Google Drive folder and of its subfolders.

Only files with an image/* MIME type are kept: Drive reports .HEIC files as image/heif, and
folders can also contain videos or documents, which are skipped.

=head3 Arguments

=head4 $folder_id

=head4 $resource_key - optional resource key of the folder (for older link-shared folders)

=head4 $api_key - optional, defaults to the configured Google Drive API key

=head3 Return value

A hash ref with:

=over

=item images - array ref of hashes with id, name, path (name prefixed with the subfolder names), mime_type and resource_key, sorted by path

=item skipped - number of files that are not images

=item error - an error id if the folder could not be listed: google_drive_no_api_key, google_drive_folder_not_found, google_drive_folder_too_many_items or google_drive_api_error

=item error_message - details about the error, if any

=back

=cut

sub list_google_drive_folder_images ($folder_id, $resource_key = undef, $api_key = undef) {

	$api_key //= $ProductOpener::Config2::google_drive_api_key;

	if ((not defined $api_key) or ($api_key eq '')) {
		return {images => [], skipped => 0, error => "google_drive_no_api_key"};
	}

	my $ua = create_user_agent(timeout => 30);
	$ua->protocols_allowed(['https']);

	my @images = ();
	my $skipped = 0;
	my $listed_items = 0;
	my %seen_folders = ();

	# Folders to list: [folder id, resource key, path prefix, depth]
	my @folders = ([$folder_id, $resource_key, "", 0]);

	while (my $folder_ref = shift @folders) {
		my ($id, $key, $prefix, $depth) = @$folder_ref;

		next if $seen_folders{$id}++;

		my $resource_keys_header = (defined $key) ? "$id/$key" : undef;

		my ($items_ref, $error, $error_message)
			= list_google_drive_folder_items($ua, $id, $resource_keys_header, $api_key, \$listed_items);

		if (not defined $items_ref) {
			# Listing limits apply to the whole tree; other inaccessible subfolders are skipped.
			if (($depth == 0) or ($error eq "google_drive_folder_too_many_items")) {
				return {images => [], skipped => 0, error => $error, error_message => $error_message};
			}
			$log->warn("could not list Google Drive subfolder", {folder_id => $id, error => $error})
				if $log->is_warn();
			next;
		}

		foreach my $item_ref (@$items_ref) {
			my $mime_type = $item_ref->{mimeType} // '';
			my $name = $item_ref->{name} // $item_ref->{id};
			if ($mime_type eq $google_drive_folder_mime_type) {
				if ($depth < $GOOGLE_DRIVE_MAX_FOLDER_DEPTH) {
					push @folders, [$item_ref->{id}, $item_ref->{resourceKey}, $prefix . $name . "/", $depth + 1];
				}
			}
			elsif ($mime_type =~ m{^image/}) {
				push @images,
					{
					id => $item_ref->{id},
					name => $name,
					path => $prefix . $name,
					mime_type => $mime_type,
					(defined $item_ref->{resourceKey} ? (resource_key => $item_ref->{resourceKey}) : ()),
					};
			}
			else {
				$skipped++;
			}
		}
	}

	# Photos taken in sequence (e.g. IMG_9476.HEIC, IMG_9477.HEIC) need to be processed in order:
	# a photo without a barcode is assigned to the product of the previous photo
	@images = sort {$a->{path} cmp $b->{path}} @images;

	return {images => \@images, skipped => $skipped};
}

1;
