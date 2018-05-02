#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::URL qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;

ProductOpener::Display::init();

$scripts .= <<SCRIPTS
<script src="/js/datatables.min.js"></script>
<script src="/bower_components/papaparse/papaparse.min.js"></script>
SCRIPTS
;

$header .= <<HEADER
<link rel="stylesheet" href="/js/datatables.min.css" />
HEADER
;

my $url = format_subdomain('static') . '/data/top_translators.csv';
my $js = <<JS
	\$(document).ready(function() {
		var dataSource = [];

		Papa.parse("$url", {
			download: true,
			delimiter: ",",
			header: true,
			dynamicTyping: true,
			skipEmptyLines: true,
			withCredentials: false,
			step: function(results, parser) {
				dataSource = dataSource.concat(results.data);
				console.log("Row data:", results.data);
				console.log("Row errors:", results.errors);
			},
			complete: function () {
				\$('#top_translators').DataTable({
					"data": dataSource,
					"columns": [
						{ "data": "Name" },
						{ "data": "Translated (Words)" },
						{ "data": "Target Words" },
						{ "data": "Approved (Words)" },
						{ "data": "Votes Made" }
					],
					"order": [[ 1, "desc" ]],
					"paging": false,
					"info": false,
					"searching": false
				});
			}
		});
	});
JS
;
$initjs .= $js;

my $html = '<p>' . lang('translators_lead') . '</p>';

my $translators_column_name = lang('translators_column_name');
my $translators_column_translated_words = lang('translators_column_translated_words');
my $translators_column_target_words = lang('translators_column_target_words');
my $translators_column_approved_words = lang('translators_column_approved_words');
my $translators_column_votes_made = lang('translators_column_votes_made');

$html .= <<HTML
<table id="top_translators" class="display" cellspacing="0" width="100%">
	<thead>
		<tr>
			<th>$translators_column_name</th>
			<th>$translators_column_translated_words</th>
			<th>$translators_column_target_words</th>
			<th>$translators_column_approved_words</th>
			<th>$translators_column_votes_made</th>
		</tr>
	</thead>
	<tfoot>
		<tr>
			<th>$translators_column_name</th>
			<th>$translators_column_translated_words</th>
			<th>$translators_column_target_words</th>
			<th>$translators_column_approved_words</th>
			<th>$translators_column_votes_made</th>
		</tr>
	</tfoot>
	<tbody>
	</tbody>
</table>
HTML
;

$html .= '<p style="font-size: smaller;">' . lang('translators_renewal_notice') . '</p>';

display_new( {
	title=>lang('translators_title'),
	content_ref=>\$html
});
