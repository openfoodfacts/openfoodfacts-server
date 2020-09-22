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
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Producers qw/:all/;
use ProductOpener::Data qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Log::Any qw($log);


ProductOpener::Display::init();

my $action = param('action') || 'display';

my $title = lang("remove_products_from_producers_platform");
my $html = '';

if (not $server_options{producers_platform}) {
	display_error(lang("function_not_available"), 200);
}

if ((not defined $Owner_id) or ($Owner_id !~ /^(user|org)-\S+$/)) {
	display_error(lang("no_owner_defined"), 200);
}


if ($action eq "display") {

	$html .= "<p>" . lang("remove_products_from_producers_platform_description") . "</p>";
	$html .= "<p>" . lang("this_action_cannot_be_undone") . "</p>";

	my $confirm = lang("remove_products_confirm");
	$confirm =~ s/'/\'/g;

	$html .= start_multipart_form(-id=>"remove_products_form",
		-onsubmit=>"return confirm('" . $confirm . "');") ;

	$html .= <<HTML
<input type="submit" class="button small" value="$Lang{remove_products}{$lc}">
<input type="hidden" name="action" value="process">
HTML
;
	$html .= end_form();

}

elsif ($action eq "process") {

	$log->debug("Deleting products for owner in mongodb", { owners_tags => $Owner_id }) if $log->is_debug();

	my $products_collection = get_products_collection();
	$products_collection->delete_many({"owners_tags" => $Owner_id});

	require File::Copy::Recursive;
	File::Copy::Recursive->import( qw( dirmove ) );

	my $deleted_dir = $data_root . "/deleted_private_products/" . $Owner_id . "." . time();
	(-e $data_root . "/deleted_private_products") or mkdir($data_root . "/deleted_private_products", oct(755));

	$log->debug("Moving data to deleted dir", { owners_tags => $Owner_id, deleted_dir => $deleted_dir }) if $log->is_debug();

	mkdir($deleted_dir, oct(755));

	dirmove("$data_root/import_files/$Owner_id", "$deleted_dir/import_files") or print STDERR "Could not move $data_root/import_files/$Owner_id to $deleted_dir/import_files : $!\n";
	dirmove("$data_root/export_files/$Owner_id", "$deleted_dir/export_files") or print STDERR "Could not move $data_root/export_files/$Owner_id to $deleted_dir/export_files : $!\n";
	dirmove("$data_root/products/$Owner_id", "$deleted_dir/products") or print STDERR "Could not move $data_root/products/$Owner_id to $deleted_dir/products : $!\n";
	dirmove("$www_root/images/products/$Owner_id", "$deleted_dir/images") or print STDERR "Could not move $www_root/images/products/$Owner_id to $deleted_dir/images : $!\n";

	$html .= "<p>" . lang("remove_products_done") . "</p>";
}

display_new( {
	title=>$title,
	content_ref=>\$html,
});

exit(0);

