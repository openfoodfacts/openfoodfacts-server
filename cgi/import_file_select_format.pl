#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);
use Spreadsheet::CSV();

ProductOpener::Display::init();

my $type = param('type') || 'upload';
my $action = param('action') || 'display';

my $title = '';
my $html = '';

local $log->context->{type} = $type;
local $log->context->{action} = $action;

my $owner = "user-" . $User_id;
if (defined $Org_id) {
	$owner = "org-" . $Org_id;
}

my $import_files_ref = retrieve("$data_root/import_files/$owner/import_files.sto");
if (not defined $import_files_ref) {
	$import_files_ref = {};
}

my $file_id = get_string_id_for_lang("no_language", param('file_id'));

local $log->context->{file_id} = $file_id;

my $file;
my $extension;

if (defined $import_files_ref->{$file_id}) {
	$extension = $import_files_ref->{$file_id}{extension};
	$file = "$data_root/import_files/$owner/$file_id.$extension";
}
else {
	$log->debug("File not found in import_files.sto", { file_id => $file_id }) if $log->is_debug();
	display_error("File not found.", 404);
}

$log->debug("File found in import_files.sto", { file_id => $file_id,  file => $file, extension => $extension, import_file => $import_files_ref->{$file_id} }) if $log->is_debug();


if ($action eq "display") {

	# Spreasdsheet::CSV does not like CSV files with a BOM:
	# Wide character in print at /usr/local/share/perl/5.24.1/Spreadsheet/CSV.pm line 87.
	#

	# There are many issues with Spreadsheet::CSV handling of CSV files
	# (depending on whether there is a BOM, encoding, line endings etc.
	# -> use Spreadsheet::CSV only for Excel files
	# -> use Text::CSV directly for CSV files

	my $headers_ref = undef;
	my @rows = ();

	if (($extension eq "csv") or ($extension eq "tsv") or ($extension eq "txt")) {

		my $encoding = "UTF-8";

		$log->debug("opening CSV file", { file => $file, extension => $extension }) if $log->is_debug();

		my $csv_options_ref = { binary => 1 , sep_char => "\t" };

		my $csv = Text::CSV->new ( $csv_options_ref )  # should set binary attribute.
                 or die "Cannot use CSV: " . Text::CSV->error_diag ();

		open (my $io, "<:encoding($encoding)", $file) or die("Could not open CSV $file: $!");

		$headers_ref = [$csv->header ($io, { detect_bom => 1 })];

		while (my $row = $csv->getline ($io)) {
			push @rows, $row;
		}
	}
	else {
		$log->debug("opening Excel file", { file => $file, extension => $extension }) if $log->is_debug();

		open (my $io,  $file) or die("Could not open Excel $file: $!");

		my $csv_options_ref = { binary => 1 , sep_char => "\t" };

		my $csv = Spreadsheet::CSV->new();

		# Assume first line is headers line
		$headers_ref = $csv->getline ($io);

		if (not defined $headers_ref) {
			display_error("Unsupported file format (extension: $extension).", 200);
		}

		while (my $row = $csv->getline ($io)) {
			push @rows, $row;
		}
	}


	# Upload a file

	$html .= "<h1>" . lang("import_data_file_select_format_title") . "</h1>\n";
	$html .= "<p>" . lang("import_data_file_select_format_description") . "</p>\n";

	$html .= "<p>Columns:</p><p>" . join(" ", @$headers_ref) . "</p>";

	$html .= "<p>" . @rows . " lines</p>";

	$html .= start_multipart_form(-id=>"select_format_form") ;


	$html .= end_form();

	display_new( {
		title=>$title,
		content_ref=>\$html,
	});
}

exit(0);

