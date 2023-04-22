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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::URL qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;

my $request_ref = ProductOpener::Display::init_request();

# Passing values to the template
my $template_data_ref = {};

$scripts .= <<SCRIPTS
<script src="/js/datatables.min.js"></script>
<script src="/js/dist/papaparse.js"></script>
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
				if (results.errors.length === 0) {
					dataSource = dataSource.concat(results.data);
				}
				else {
					for (var i = 0; i < results.errors.length; ++i) {
						var error = results.errors[0];
						console.warn('%s error %s while parsing CSV row %d: %s', error.type, error.code, error.row, error.message);
					}
				}
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

my $html;
process_template('web/pages/top_translators/top_translators.tt.html', $template_data_ref, \$html) or $html = '';
$html .= "<p>" . $tt->error() . "</p>";

$request_ref->{title} = lang('translators_title');
$request_ref->{content_ref} = \$html;
$request_ref->{canon_url} = '/cgi/top_translators.pl';
display_page($request_ref);
