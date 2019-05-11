// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2019 Association Open Food Facts
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
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import './vendor/file-upload.js';

async function initImageSearchFormUpload() {
  $('input.imgupload_search').each(function () {
    const id = $(this).data('id');

    $('#imgupload_search_' + id).fileupload({
      dataType: 'json',
      url: '/cgi/product.pl',
      formData: [{ name: 'jqueryfileupload', value: 1 }],
      resizeMaxWidth: 2000,
      resizeMaxHeight: 2000,
      done: function (e, data) {
        if (data.result.location) {
          $(location).attr('href', data.result.location);
        }
        if (data.result.error) {
          $('#imgsearcherror_' + id).html(data.result.error);
          $('#imgsearcherror_' + id).show();
        }
      },
      fail: function () {
        $('#imgsearcherror_' + id).show();
      },
      always: function () {
        $('#progressbar_' + id).hide();
        $('#imgsearchbutton_' + id).show();
        $('#imgsearchmsg_' + id).hide();
      },
      start: function () {
        $('#imgsearchbutton_' + id).hide();
        $('#imgsearcherror_' + id).hide();
        $('#imgsearchmsg_' + id).show();
        $('#progressbar_' + id).show();
        $('#progressmeter_' + id).css('width', '0%');
      },
      sent: function (e, data) {
        if (data.dataType &&
          data.dataType.substr(0, 6) === 'iframe') {
          // Iframe Transport does not support progress events.
          // In lack of an indeterminate progress bar, we set
          // the progress to 100%, showing the full animated bar:
          $('#progressmeter_' + id).css('width', '100%');
        }
      },
      progress: function (e, data) {
        $('#progressmeter_' + id).css('width', parseInt(data.loaded / data.total * 100, 10) + '%');
        $('#imgsearchdebug_' + id).html(data.loaded + ' / ' + data.total);
      }
    });
  });
}

document.addEventListener('DOMContentLoaded', function () {
  initImageSearchFormUpload();
});
