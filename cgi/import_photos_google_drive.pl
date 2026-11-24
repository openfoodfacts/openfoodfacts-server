#!/usr/bin/perl -w

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

# Import product photos from a public Google Drive folder (producers platform)
#
# POST action=start folder_url=... [tagtype_0=brands tag_0=...]
#  -> queue a minion job, returns {job_id}
# GET action=status job_id=...
#  -> returns {job_id, state, import => {status, total, processed, results => [...]}}

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/init_request/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id %User/;
use ProductOpener::Lang qw/$lc lang/;
use ProductOpener::Producers qw/get_minion start_google_drive_photos_import/;
use ProductOpener::ProductImageUpload qw/@photos_upload_add_fields/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);

my $request_ref = init_request();

my $action = single_param('action') || 'status';

my %response = ();

sub error_message ($error) {
	my $message = lang($error);
	return (defined $message and $message ne '') ? $message : $error;
}

if (not defined $Owner_id) {
	$response{error} = "no_owner_defined";
	$response{error_message} = error_message("no_owner_defined");
}
elsif ($action eq 'start') {

	if (request_method() ne 'POST') {
		$response{error} = "post_required";
		$response{error_message} = error_message("post_required");
	}
	else {
		# Field values to add to all the products (same fields as the import photos page)
		my %allowed_fields = map {$_ => 1} @photos_upload_add_fields;
		my @add_field_values = ();
		my $i = 0;
		while (defined single_param("tagtype_$i")) {
			my $field = single_param("tagtype_$i");
			my $value = decode utf8 => (single_param("tag_$i") // '');
			$value =~ s/^\s+|\s+$//g;
			if ($allowed_fields{$field} and ($value ne '')) {
				push @add_field_values, {field => $field, value => $value};
			}
			$i++;
		}

		my $result_ref = start_google_drive_photos_import(
			{
				folder_url => decode(utf8 => (single_param('folder_url') // '')),
				user_id => $User_id,
				org_id => $Org_id,
				owner_id => $Owner_id,
				moderator => $User{moderator} ? 1 : 0,
				lc => $lc,
				country => $request_ref->{country},
				add_field_values => \@add_field_values,
			}
		);

		$log->info("start Google Drive photos import", {owner_id => $Owner_id, result => $result_ref})
			if $log->is_info();

		%response = %$result_ref;
		if (defined $response{error}) {
			$response{error_message} = error_message($response{error});
		}
	}
}
elsif ($action eq 'status') {

	my $job_id = single_param('job_id');
	my $job = ((defined $job_id) and ($job_id =~ /^\d+$/)) ? get_minion()->job($job_id) : undef;
	my $info_ref = defined $job ? $job->info : undef;

	# Only the owner that started the import can see its results
	if (   (not defined $info_ref)
		or ($info_ref->{task} ne 'import_photos_from_google_drive_folder')
		or (($info_ref->{args}[0]{owner_id} // '') ne $Owner_id))
	{
		$response{error} = "job_not_found";
		$response{error_message} = error_message("job_not_found");
	}
	else {
		$response{job_id} = $job_id + 0;
		$response{state} = $info_ref->{state};
		$response{import} = $info_ref->{notes}{import};
		if ($info_ref->{state} eq 'failed') {
			$response{error} = "job_failed";
			$response{error_message} = error_message("job_failed");
		}
		elsif ((defined $response{import}) and (defined $response{import}{error})) {
			$response{error} = $response{import}{error};
			$response{error_message} = error_message($response{import}{error});
			if (defined $response{import}{error_message}) {
				$response{error_message} .= " " . $response{import}{error_message};
			}
		}
	}
}
else {
	$response{error} = "unknown_action";
	$response{error_message} = error_message("unknown_action");
}

print header(-type => 'application/json', -charset => 'utf-8') . encode_json(\%response);

exit(0);
