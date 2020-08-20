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
use ProductOpener::Producers qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Log::Any qw($log);
use Excel::Writer::XLSX;

my $action = param('action') || 'display';

ProductOpener::Display::init();

use Apache2::RequestRec ();
my $r = Apache2::RequestUtil->request();

$r->headers_out->set("Content-type" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
$r->headers_out->set("Content-disposition" => "attachment;filename=openfoodfacts_import.xlsx");
binmode( STDOUT );
print "Content-Type: text/csv; charset=UTF-8\r\n\r\n";

my $workbook = Excel::Writer::XLSX->new( \*STDOUT );
my $worksheet = $workbook->add_worksheet();
my $format = $workbook->add_format();
$format->set_bold();

# Re-use the structure used to output select2 options in import_file_select_format.pl
my $select2_options_ref = generate_import_export_columns_groups_for_select2([ $lc ]);

my $headers_row = 0;
my $col = 0;

foreach my $group_ref (@$select2_options_ref) {
	my $group_start_col = $col;
	
	my $group_id = $group_ref->{group_id};
	
	$log->debug("group", { group_id => $group_id }) if $log->is_debug();	
	
	# Skip nutrition_other, only add default nutrients
	next if ($group_id eq "nutrition_other");
	
	foreach my $field_ref (@{$group_ref->{children}}) {
		
		my $field_id = $field_ref->{id};
		
		$log->debug("field", { group_id => $group_id, field_id => $field_id }) if $log->is_debug();
		
		# Skip fields intended only for the select2 dropdown
		next if ($field_id =~ /_specific$/);
		
		# For now, keep only the per 100g as sold fields
		next if ($field_id =~ /_serving_|_prepared_/);
		
		$worksheet->write( $headers_row, $col, $field_ref->{text}, $format);
		my $width = length($field_ref->{text});
		($width < 20) and $width = 20;
		$worksheet->set_column( $col, $col, $width );
		
		# Comment / note / examples
		my $comment = "";
		
		if ($group_id =~ /^nutrition/) {
			my $nid = $field_id;
			$nid =~ s/_(100g|serving|prepared).*//;
			$log->debug("field nutrition", { group_id => $group_id, field_id => $field_id, nid => $nid }) if $log->is_debug();
			my $unit = default_unit_for_nid($nid);
			$log->debug("field nutrition default unit", { group_id => $group_id, field_id => $field_id, nid => $nid, unit => $unit }) if $log->is_debug();
			$comment .= sprintf(lang("specify_value_and_unit_or_use_default_unit"), $unit) . "\n\n";
			$log->debug("field after sprintf", { group_id => $group_id, field_id => $field_id }) if $log->is_debug();
		}
		
		if (defined $tags_fields{$field_id}) {
			$comment .= lang("separate_values_with_commas") . "\n\n";
		}
		
		my $note = lang($field_id . "_note");
		my $import_note = lang($field_id . "_import_note");
		my $example = lang($field_id . "_example");
		
		if ($note ne "") {
			$comment .= lang($field_id . "_note") . "\n\n";
		}
		
		if ($import_note ne "") {
			$comment .= lang($field_id . "_import_note") . "\n\n";
		}		

		if ($example ne "") {

			my $example_title = lang("example");
			# Several examples?
			if ($example =~ /,/) {
				$example_title = lang("examples");
			}
			$comment .= $example_title . " " . $example . "\n\n";
		}

		if ($comment ne "") {
			$worksheet->write_comment($headers_row, $col, $comment); 
		}
		
		$col++;
		
		$log->debug("field - comment", { group_id => $group_id, field_id => $field_id, comment => $comment }) if $log->is_debug();
	}
}

exit(0);

