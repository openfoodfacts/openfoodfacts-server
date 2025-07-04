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
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve_object/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Lang qw/lang/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/canonicalize_tag_link/;
use ProductOpener::Users qw/$Owner_id/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::HTTP qw/single_param/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);
use Data::DeepAccess qw(deep_get);

my $request_ref = ProductOpener::Display::init_request();

my $template_data_ref = {};

my $code = normalize_code(single_param('code'));

if (not defined $code) {
	display_error_and_exit($request_ref, lang("api_result_product_not_found"), 404);
}

# We can be passed an imgid, or image_type + image_lc
# Previously, we used an id that could be either imgid or image_type + image_lc

my $imgid = single_param('imgid');
my $image_type = single_param('image_type');
my $image_lc = single_param('image_lc');

my $id = single_param('id');

# Legacy support for old URLs, could probably be removed
if (defined $id) {
	if ($id =~ /^\d+$/) {
		# imgid
		$imgid = $id;
	}
	else {
		# image_type + image_lc
		($image_type, $image_lc) = get_image_type_and_image_lc_from_imagefield($id);
	}
}

$log->debug(
	"start",
	{
		code => $code,
		id => $id,
		imgid => $imgid,
		image_type => $image_type,
		image_lc => $image_lc
	}
) if $log->is_debug();

# Retrieve the image data from the product

my $product_id = product_id_for_owner($Owner_id, $code);

my $product_ref = retrieve_product($product_id);

if (not(defined $product_ref)) {
	display_error_and_exit($request_ref, sprintf(lang("no_product_for_barcode"), $code), 404);
}

my $image_ref;

if (defined $imgid) {
	$image_ref = deep_get($product_ref, "images", "uploaded", $imgid);
}
elsif ((defined $image_type) and (defined $image_lc)) {
	$image_ref = deep_get($product_ref, "images", "selected", $image_type, $image_lc);
	$id = $image_type . '_' . $image_lc;
}

if (not(defined $image_ref)) {
	display_error_and_exit($request_ref, lang("api_result_product_image_not_found"), 404);
}

my $imagetext;
if ($id =~ /^(.*)_(.*)$/) {
	$imagetext = lang($1 . '_alt');
}
else {
	$imagetext = $id;
}

my $path = product_path_from_id($product_id);
my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $imagetext;

my $display_image_url;
my $full_image_url;
if (defined $imgid) {
	$display_image_url = "$images_subdomain/images/products/$path/$imgid.$display_size.jpg";
	$full_image_url = "$images_subdomain/images/products/$path/$imgid.jpg";
}
else {
	$image_ref->{id} = $id;
	$display_image_url = get_image_url($product_ref, $image_ref, $display_size);
	$full_image_url = get_image_url($product_ref, $image_ref, "full");
}

my $photographer;
my $editor;
my $site_name = $options{site_name};

my $original_id = $imgid || $image_ref->{imgid};
my $original_link = "";
if ((defined $original_id) and (defined $product_ref->{images}{uploaded}{$original_id})) {
	$photographer = $product_ref->{images}{uploaded}{$original_id}{uploader};
	$original_link = " <a href=\"/cgi/product_image.pl?code=$code&imgid=$original_id\" rel=\"isBasedOn\">"
		. lang("image_original_link_text") . "</a>";
}

if (defined $image_ref->{rev}) {
	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes");
	if (not defined $changes_ref) {
		$changes_ref = [];
	}

	my $current_rev = $product_ref->{rev};

	foreach my $change_ref (reverse @{$changes_ref}) {
		my $change_rev = $change_ref->{rev};

		if (not defined $change_rev) {
			$change_rev = $current_rev;
		}
		$current_rev--;

		if ($change_rev eq $image_ref->{rev}) {
			$editor = $change_ref->{userid};
		}
	}
}

my $photographer_link
	= "<a href=\"" . canonicalize_tag_link("photographers", $photographer) . "\" rel=\"author\">$photographer</a>";
my $editor_link;
if (defined $editor) {
	$editor_link
		= "<a href=\"" . canonicalize_tag_link("photographers", $editor) . "\" rel=\"contributor\">$editor</a>";
}

my $full_size = lang('image_full_size');
my $attribution;
if ((defined $photographer) and (defined $editor) and (not($photographer eq $editor))) {
	$attribution = sprintf(lang('image_attribution_photographer_editor'), $photographer_link, $editor_link, $site_name);
}
elsif (defined $photographer) {
	$attribution = sprintf(lang('image_attribution_photographer'), $photographer_link, $site_name);
}
else {
	$attribution = $site_name;
}

my $product_name = remove_tags_and_quote(product_name_brand_quantity($product_ref));

# Prevent the quantity "750 g" to be split on two lines
$product_name =~ s/(.*) (.*?)/$1\&nbsp;$2/;
if ($product_name eq '') {
	$product_name = $code;
}

my $url = product_url($product_ref);
my $creativecommons = sprintf(
	lang('image_attribution_creativecommons'),
	"<a href=\"$url\" rel=\"about\">$product_name</a>",
	'<a href="https://creativecommons.org/licenses/by-sa/3.0/deed.en" rel="license">Creative Commons Attribution-Share Alike 3.0 Unported</a>'
);

$template_data_ref->{display_image_url} = $display_image_url;
$template_data_ref->{display_size_width} = $image_ref->{sizes}{$display_size}{w};
$template_data_ref->{display_size_height} = $image_ref->{sizes}{$display_size}{h};
$template_data_ref->{alt} = $alt;
$template_data_ref->{full_image_url} = $full_image_url;
$template_data_ref->{full_size} = $full_size;
$template_data_ref->{creativecommons} = $creativecommons;
$template_data_ref->{original_link} = $original_link;
$template_data_ref->{attribution} = $attribution;
$template_data_ref->{original_id} = $original_id;
$template_data_ref->{code} = $code;

my $html;
process_template('web/pages/product/includes/product_image.tt.html', $template_data_ref, \$html) or $html = '';
$html .= "<p>" . $tt->error() . "</p>";

$request_ref->{title} = $alt;
$request_ref->{content_ref} = \$html;
display_page($request_ref);

exit(0);

