// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2024 Association Open Food Facts
// Contact: contact@openfoodfacts.org
// Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
//
// Product Opener is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

/*global revert_confirm_message*/
/*exported activate_product_revert_buttons_in_history*/

function activate_product_revert_buttons_in_history () {
    $('#history_list a.product_revert_button').on('click', function() {
        const code = $(this).data('code');
        const rev = $(this).data('rev');
        // using confirm, could be replaced with some JS dialog / modal
        const confirm = window.confirm(revert_confirm_message); // eslint-disable-line no-alert
        if (confirm) {
            $.ajax({
                url: '/api/v3/product_revert',
                type: 'POST',
                contentType: "application/json; charset=utf-8",
                dataType: "json",
                data: JSON.stringify({
                    code: code,
                    rev: rev,
                    fields: "rev"
                    // we don't pass cc and lc, as they will get the right default value from the subdomain
                }),
                success: function(data) {
                    let message = data.status;
                    if (data.status === 'success') {
                        message = message + ' - <a href="/product/' + code +'">' + data.result.lc_name + '</a>';
                    }
                    else {
                        message = message + ' - ' + data.result.lc_name;
                    }
                    $('#revert_result_' + rev).html(message);
                }
            });
        }
    });
}

$(function() {
    activate_product_revert_buttons_in_history();
});

