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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

ProductOpener::Display::init();

my $code = normalize_code(param('code'));
my $id = param('id');

$log->debug("start", { code => $code, id => $id }) if $log->is_debug();

if (not defined $code) {
	display_error(sprintf(lang("no_product_for_barcode"), $code), 404);
}

my $product_id = product_id_for_user($User_id, $Org_id, $code);

my $product_ref = retrieve_product($product_id);

if (not (defined $product_ref)) {
	display_error(sprintf(lang("no_product_for_barcode"), $code), 404);
}

if ((not (defined $product_ref->{images})) or (not (defined $product_ref->{images}{$id}))) {
	display_error(sprintf(lang("no_product_for_barcode"), $code), 404);
}

my $imagetext;
if ($id =~ /^(.*)_(.*)$/) {
	$imagetext = lang($1 . '_alt');
}
else {
	$imagetext = $id;
}

my $path = product_path_from_id($product_id);
my $rev = $product_ref->{images}{$id}{rev};
my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $imagetext;

my $display_image_url;
my $full_image_url;
if ($id =~ /^\d+$/) {
	$display_image_url = "/images/products/$path/$id.$display_size.jpg";
	$full_image_url = "/images/products/$path/$id.jpg";
}
else {
	$display_image_url = "/images/products/$path/$id.$rev.$display_size.jpg";
	$full_image_url = "/images/products/$path/$id.$product_ref->{images}{$id}{rev}.full.jpg";
}

my $photographer = $product_ref->{images}{$id}{uploader};
my $editor = $photographer;
my $site_name = lang('site_name');

my $original_id = $product_ref->{images}{$id}{imgid};
my $original_link = "";
if ((defined $original_id) and (defined $product_ref->{images}{$original_id})) {
	$photographer = $product_ref->{images}{$original_id}{uploader};
	$original_link = " <a href=\"/cgi/product_image.pl?code=$code&id=$original_id\" rel=\"isBasedOn\">" . lang("image_original_link_text") . "</a>";
}

if  (defined $product_ref->{images}{$id}{rev}) {
	my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
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

		if ($change_rev eq $product_ref->{images}{$id}{rev}) {
			$editor = $change_ref->{userid};
		}
	}
}

my $photographer_link = "<a href=\"" . canonicalize_tag_link("photographers", $photographer) . "\" rel=\"author\">$photographer</a>";
my $editor_link;
if (defined $editor) {
	$editor_link = "<a href=\"" . canonicalize_tag_link("photographers", $editor) . "\" rel=\"contributor\">$editor</a>";
}

my $full_size = lang('image_full_size');
my $attribution;
if ((defined $photographer) and (defined $editor) and (not ($photographer eq $editor))) {
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
my $creativecommons = sprintf(lang('image_attribution_creativecommons'), "<a href=\"$url\" rel=\"about\">$product_name</a>", '<a href="https://creativecommons.org/licenses/by-sa/3.0/deed.en" rel="license">Creative Commons Attribution-Share Alike 3.0 Unported</a>');

my $html .= <<"HTML"
<figure itemscope itemtype="https://schema.org/ImageObject">
	<img src="$display_image_url" width="$product_ref->{images}{$id}{sizes}{$display_size}{w}" height="$product_ref->{images}{$id}{sizes}{$display_size}{h}" alt="$alt" itemprop="thumbnail" loading="lazy">
	<figcaption>
		<p><a href="$full_image_url" itemprop="contentUrl">$full_size</a></p>
		<p>$creativecommons$original_link</p>
		<p>$attribution</p>
	</figcaption>
</figure>
HTML
;

display_new( {
	title=>$alt,
	content_ref=>\$html,
	full_width=>0,
});

exit(0);

