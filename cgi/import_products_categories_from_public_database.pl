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

ProductOpener::Display::init();

my $action = param('action') || 'display';

my $title = lang("import_products_categories_from_public_database");
my $html = '';
my $js = '';
my $template_data_ref = {};

if (not defined $Owner_id) {
	display_error(lang("no_owner_defined"), 200);
}

if ($action eq "display") {
	process_template('web/pages/import_product_categories/import_product_categories_from_public_database.tt.html', $template_data_ref, \$html) or $html = "<p>" . $tt->error() . "</p>";
}

elsif ($action eq "process") {

	my $import_id = time();

	my $args_ref = {
		user_id => $User_id,
		org_id => $Org_id,
		owner => $Owner_id,
		import_id => $import_id,
	};

	my $job_id = $minion->enqueue(import_products_categories_from_public_database => [ $args_ref ]
		=> { queue => $server_options{minion_local_queue}});

	$template_data_ref->{import_id}= $import_id ;
	$template_data_ref->{job_id}= $job_id;
	$template_data_ref->{link}= "/cgi/minion_job_status.pl?job_id=$job_id";

	process_template('web/pages/import_product_categories_process/import_product_categories_from_public_database_process.tt.html', $template_data_ref, \$html) or $html = "<p>" . $tt->error() . "</p>";
	process_template('web/pages/import_product_categories_process/import_product_categories_from_public_database_process.tt.js', $template_data_ref, \$js);
	$initjs .= $js;

}

display_page( {
	title=>$title,
	content_ref=>\$html,
});

exit(0);

