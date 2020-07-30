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
use ProductOpener::URL qw/:all/;
use Apache2::RequestRec ();
#use Apache2::Const ();
#use CGI qw/:cgi :form escapeHTML :cgi-lib/;
#use URI::Escape::XS;
#use Encode;
#use JSON::PP;
#use Log::Any qw($log);

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;

$header .= <<HEADER
<link rel="stylesheet" href="$static_subdomain/css/graph.min.css" >
<script src="$static_subdomain/js/dist/jquery.js"></script>
<script src="$static_subdomain/js/dist/jquery-ui.js"></script>
<script src="$static_subdomain/js/d3.v3.min.js"></script>
<script src="$static_subdomain/js/graph.min.js"></script>

HEADER
;

my $html = <<HTML
<!-- Waiting Screen -->

<!-- Display details of selected product among those which are suggested in the bottom banner -->
<div id="selected_product_details">

</div>

<!-- GRAPH HEADER -->

<div id="banner">Open Food Facts Graph - Product comparison</div>

<div id="product_details"><span id="prod_ref_code">&nbsp;</span> &nbsp;&nbsp;
    <span id="prod_ref_name"/></div>
<div style='width: 98%; text-align: right;'>
    <table style='text-align: right; width: 100%'>
        <tbody>
        <tr>
            <td style='border-radius: 5px;'>
                <table style="width: 100%">
                    <tr style='text-align: right; vertical-align: top; background-color: #d0d0d0;'>
                        <td id="cell_product_image">
                            <img id="prod_ref_image" height="javascript: $(window).innerHeight()/7"
                                 src='https://static.openfoodfacts.org/images/misc/openfoodfacts-logo-en-178x150.png'
                                 onclick="$(ID_INPUT_PRODUCT_CODE).val(current_product==null? PRODUCT_CODE_DEFAULT : current_product.code)"
                            />
                            <div id="links_off">
                                <div><a id="url_off_prod" href='https://world.openfoodfacts.org' target='_blank'>
                                    Product page
                                </a></div>
                            </div>
                        </td>
                        <td>
                            <div id="prod_ref_categories" style="display:none"></div>
                            <div id="criteria">
                                <table>
                                    <tr>
                                        <td>Country</td>
                                        <td>
                                            <select id="input_country"
                                                    onchange="set_user_country($(ID_INPUT_COUNTRY+' option:selected')[0]);
                                                    fetch_stores($(ID_INPUT_COUNTRY+' option:selected')[0])">
                                                <option></option>
                                            </select>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>Store</td>
                                        <td>
                                            <select id="input_store" title="select a store">
                                                <option></option>
                                            </select>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>Score</td>
                                        <td>
                                            <select id="input_score_db" title="select a score" onchange="changeScoreDb(this)">
                                                <option></option>
                                            </select>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>Barcode</td>
                                        <td>
                                            <div id="panel_input_code">
                                                <input id='input_product_code' type='text' title="product code"
                                                       value=""/>
                                                <div id="submitBtn" class="button expand" name="submitBtn">Go!</div>
                                            </div>

                                        </td>
                                    </tr>

                                </table>
                            </div>
                            <div id="msg_warning_prod_ref">&nbsp;</div>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
        </tbody>
    </table>
</div>

<div id="graph">&nbsp;</div>

<!-- Panel for the suggestion of products with a better score -->
<!-- navigation icons -->
<div id="menu_selection">
    <div>
        <div id="nb_suggestions"></div>
        suggestions
    </div>
    <img src="/images/graph/leftArrow.png"
         title="previous product" onclick="select_picture(-1)"/>
    <img src="/images/graph/details.png"
         title="compare this product" onclick="show_details()"/>
    <img src="/images/graph/rightArrow.png"
         title="next product" onclick="select_picture(+1)"/>
</div>

<div id="products_suggestion">

</div>

HTML
;

my $js = <<JS
	\$(document).ready(function() {
		init();
	});
JS
;
$initjs .= $js;

# ${$request_ref->{content_ref}} .= $html;
#
display_new( {
	title=>"Graph - Product comparison",
	content_ref=>\$html,
});
exit(0);
