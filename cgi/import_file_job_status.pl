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
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/get_string_id_for_lang retrieve/;
use ProductOpener::Display qw/init_request/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$Owner_id/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/lang/;
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

my $import_files_ref;

my $file_id = get_string_id_for_lang("no_language", single_param('file_id'));
my $import_id = single_param('import_id');
my $job_id;

my %data = (
	owner => $Owner_id,
	file_id => $file_id,
	import_id => $import_id,
);

$log->debug("import_file_job_status.pl - start", {data => \%data}) if $log->is_debug();

if (not defined $Owner_id) {
	$data{error} = "no_owner_defined";
}
elsif (not defined single_param('file_id')) {
	$data{error} = "missing_file_id";
}
elsif (not defined single_param('import_id')) {
	$data{error} = "missing_import_id";
}
else {

	$import_files_ref = retrieve("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/import_files.sto");

	if ((not defined $import_files_ref) or (not defined $import_files_ref->{$file_id})) {
		$data{error} = "file_id_not_found";
	}
	elsif ((not defined $import_files_ref->{$file_id}{imports})
		or (not defined $import_files_ref->{$file_id}{imports}{$import_id}))
	{
		$data{error} = "import_id_not_found";
	}
	elsif (not defined $import_files_ref->{$file_id}{imports}{$import_id}{job_id}) {
		$data{error} = "no_job_id";
	}
	else {
		$job_id = $import_files_ref->{$file_id}{imports}{$import_id}{job_id};
		$data{job_id} = $job_id;
		$log->debug("import_file_job_status.pl - found job_id", {data => \%data}) if $log->is_debug();
	}
}

if (not $data{error}) {

	my $job = get_minion()->job($job_id);
	# Get Minion::Job object without making any changes to the actual job or return undef if job does not exist.

	# Check job info
	$log->debug("import_file_job_status.pl - get job_info", {data => \%data}) if $log->is_debug();
	$data{job_info} = get_minion()->job($job_id)->info;
}

my $data = encode_json(\%data);

$log->debug("import_file_job_status.pl - done", {data => \%data}) if $log->is_debug();

print header(-type => 'application/json', -charset => 'utf-8') . $data;
exit();
