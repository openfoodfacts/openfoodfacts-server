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

binmode(STDOUT);
binmode(STDERR, ":encoding(UTF-8)");

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Producers qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use Log::Any qw($log);
use Excel::Writer::XLSX;

my $request_ref = ProductOpener::Display::init_request();

my $r = Apache2::RequestUtil->request();

$r->headers_out->set("Content-type" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
$r->headers_out->set("Content-disposition" => "attachment;filename=openfoodfacts_import_template_$lc.xlsx");

print "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n";

my $workbook = Excel::Writer::XLSX->new(\*STDOUT);
my $worksheet = $workbook->add_worksheet();
my %formats = (
	normal => $workbook->add_format(border => 1, bold => 1),
	mandatory => $workbook->add_format(
		border => 1,
		bold => 1,
		bg_color => '#0f55cc',
		color => 'white',
		valign => 'vcenter',
		align => 'center'
	),
	recommended => $workbook->add_format(
		border => 1,
		bold => 1,
		bg_color => '#1f6ced',
		color => 'white',
		valign => 'vcenter',
		align => 'center'
	),
	optional => $workbook->add_format(
		border => 1,
		bold => 1,
		bg_color => '#4d89f1',
		color => 'white',
		valign => 'vcenter',
		align => 'center'
	),
	description => $workbook->add_format(italic => 1, text_wrap => 1, valign => 'vcenter'),
);

# Re-use the structure used to output select2 options in import_file_select_format.pl
my $select2_options_ref = generate_import_export_columns_groups_for_select2([$lc]);

my $headers_row = 0;
my $description_row = 1;
my $col = 1;

my $description = lang("description");
my $field_id;
my $comment;

$worksheet->set_row(0, 70);
$worksheet->set_column('A:ZZ', 30);
$worksheet->set_column('A:A', 30);
$worksheet->write($description_row, 0, $description, $formats{'description'});

my $fields_param = param('fields');

foreach my $group_ref (@$select2_options_ref) {
	my $group_start_col = $col;

	my $group_id = $group_ref->{group_id};

	$log->debug("group", {group_id => $group_id}) if $log->is_debug();

	# Skip nutrition_other, only add default nutrients
	next if ($group_id eq "nutrition_other");

	my $seen_salt_or_sodium = 0;

	foreach my $field_ref (@{$group_ref->{children}}) {

		my $field_id = $field_ref->{id};

		# Remove language (e.g. product_name_en -> product_name)
		if (($field_id =~ /^(.*)_(\w\w)$/) and (defined $language_fields{$1})) {
			$field_id =~ s/_\w\w$//;
		}

		$log->debug("field", {group_id => $group_id, field_id => $field_id}) if $log->is_debug();

		# Skip fields intended only for the select2 dropdown
		next if ($field_id =~ /_specific$/);

		# Skip carbon footprint
		next if ($field_id =~ /carbon-footprint/);

		# For now, keep only the per 100g as sold fields
		next if ($field_id =~ /_serving|_prepared/);

		# Comment / note / examples
		my $comment = "";

		if ($group_id =~ /^nutrition/) {
			my $nid = $field_id;
			$nid =~ s/_(100g|serving|prepared).*//;
			$log->debug("field nutrition", {group_id => $group_id, field_id => $field_id, nid => $nid})
				if $log->is_debug();
			my $unit = default_unit_for_nid($nid);
			$log->debug("field nutrition default unit",
				{group_id => $group_id, field_id => $field_id, nid => $nid, unit => $unit})
				if $log->is_debug();
			$comment .= sprintf(lang("specify_value_and_unit_or_use_default_unit"), $unit) . "\n\n";
			$log->debug("field after sprintf", {group_id => $group_id, field_id => $field_id}) if $log->is_debug();
		}
		elsif ($field_id =~ /_value_unit/) {
			$field_id = $`;
			$comment .= lang("specify_value_and_unit") . "\n\n";
		}

		if ($group_id eq "images") {
			$comment .= lang("images_can_be_provided_separately") . "\n\n";
		}

		if (defined $tags_fields{$field_id}) {
			$comment .= lang("separate_values_with_commas") . "\n\n";
		}

		# Add notes that are defined in the .po files
		foreach my $note_field ("note", "note_2", "note_3", "import_note") {
			my $note = lang($field_id . "_" . $note_field);
			if ($note ne "") {
				$comment .= $note . "\n\n";
			}
		}

		my $example = lang($field_id . "_example");

		if ($example ne "") {

			my $example_title = lang("example");

			# Several examples?
			if ($example =~ /,/) {
				$example_title = lang("examples");
			}
			$comment .= $example_title . " " . $example . "\n\n";
		}

		# Set a different format for mandatory / recommended / optional fields

		my $importance = "normal";

		if (defined $options{import_export_fields_importance}) {

			$importance = "optional";

			if (defined $options{import_export_fields_importance}{$group_id . "_group"}) {
				$importance = $options{import_export_fields_importance}{$group_id . "_group"};
			}
			if (defined $options{import_export_fields_importance}{$field_id}) {
				$importance = $options{import_export_fields_importance}{$field_id};
			}

			# Make sodium optional if we have seen salt already (or the reverse)
			if (($field_id eq "salt_100g_value_unit") or ($field_id eq "sodium_100g_value_unit")) {
				if ($seen_salt_or_sodium) {
					$importance = "optional";
				}
				else {
					$seen_salt_or_sodium = 1;
				}
			}

			$comment .= lang($importance . "_field") . " - " . lang($importance . "_field_note") . "\n\n";
		}

		# Write cell and comment
		if ($fields_param && $fields_param eq 'mandatory' && $importance ne 'mandatory') {
			next;
		}

		$worksheet->write($headers_row, $col, $field_ref->{text}, $formats{$importance});
		my $width = length($field_ref->{text});
		($width < 20) and $width = 20;
		$worksheet->set_column($col, $col, $width);

		if ($comment ne "") {
			$worksheet->write($description_row, $col, $comment, $formats{'description'});
		}

		$col++;

		$log->debug("field - comment", {group_id => $group_id, field_id => $field_id, comment => $comment})
			if $log->is_debug();
	}
}

exit(0);
