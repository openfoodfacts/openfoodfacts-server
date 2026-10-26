#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use ProductOpener::PerlStandards;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/init_request/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Producers qw/get_minion/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Log::Any qw($log);
use Spreadsheet::CSV();
use Text::CSV();

my $request_ref = ProductOpener::Display::init_request();

my $job_id = single_param("job_id");

my %data;

if ((not defined $job_id) or ($job_id !~ /^\d+$/)) {
	$data{error} = "Missing or invalid job_id";
}
else {
	$data{job_id} = $job_id;
}

$log->debug("minion_job_status.pl - start", {data => \%data}) if $log->is_debug();

if (not $data{error}) {

	# Get Minion::Job object without making any changes to the actual job or return undef if job does not exist.

	my $job = get_minion()->job($job_id);
	my $job_info = defined $job ? $job->info : undef;

	# Minion job arguments carry data of every tenant: e-mail addresses, the mapping from a
	# deleted account to the pseudonym its edit history was reassigned to, and server-side file
	# paths. Job ids are small numbers, so they can be enumerated: only administrators may read
	# an arbitrary job, other users only the jobs they queued, which we recognize by their
	# arguments carrying the user_id / org_id / owner_id of the caller.
	# (cgi/import_file_job_status.pl does the same, by looking the job id up in the import file
	# list of the caller's own $Owner_id.)

	my $can_read_job = $request_ref->{admin};

	if (not $can_read_job) {
		# Minion stores the arguments as the list the task was called with: our jobs are called
		# with a single hash ref (see the enqueue() calls in Producers.pm)
		my $args = defined $job_info ? $job_info->{args} : undef;
		my $args_ref = {};
		if (ref($args) eq "ARRAY") {
			$args_ref = $args->[0] if defined $args->[0] and ref($args->[0]) eq "HASH";
		}
		elsif (ref($args) eq "HASH") {
			$args_ref = $args;
		}

		$can_read_job = (
				   ((defined $User_id) and ($User_id ne "") and (($args_ref->{user_id} // "") eq $User_id))
				or ((defined $Org_id) and ($Org_id ne "") and (($args_ref->{org_id} // "") eq $Org_id))
		) or ((defined $Owner_id) and ($Owner_id ne "") and (($args_ref->{owner_id} // "") eq $Owner_id));
	}

	if (not $can_read_job) {
		$log->info("minion_job_status.pl - no permission to read the job", {job_id => $job_id, User_id => $User_id})
			if $log->is_info();
		# Answer like the other errors of this script: Apache replaces the body of a CGI
		# response that declares a 4xx status with its own error page
		$data{error} = "no_permission";
	}
	elsif (not defined $job_info) {
		$data{error} = "Unknown job_id";
	}
	else {
		# Check job info
		$log->debug("minion_job_status.pl - get job_info", {data => \%data}) if $log->is_debug();
		$data{job_info} = $job_info;
	}
}

my $data = encode_json(\%data);

$log->debug("minion_job_status.pl - done", {data => \%data}) if $log->is_debug();

print header(-type => 'application/json', -charset => 'utf-8') . $data;
exit();
