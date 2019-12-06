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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

/* eslint-disable no-undefined */
/*exported lang countries*/

function doWebShare(e) {
  e.preventDefault();

  if (!window.isSecureContext || navigator.share === undefined) {
    console.error('Error: Unsupported feature: navigator.share');

    return;
  }

  var title = this.title;
  var url = this.href;
  navigator.share({ title: title, url: url }).then(() => console.info('Successfully sent share'), (error) => console.error('Error sharing: ' + error));
}

function onLoad() {
  var buttons = document.getElementsByClassName('share_button');
  var shareAvailable = window.isSecureContext && navigator.share !== undefined;

  [].forEach.call(buttons, function (button) {
    if (shareAvailable) {
      button.style.display = 'block';

      [].forEach.call(button.getElementsByTagName('a'), function (a) {
        a.addEventListener('click', doWebShare);
      });
    }
    else {
      button.style.display = 'none';
    }
  });
}

let langData;
function lang() {
  if (!langData) {
    $.ajax({
      url: '/cgi/i18n/lang.pl',
      dataType: 'json',
      async: false,
      success: function(json) {
          langData = json;
      }
    });
  }

  return langData;
}

let countriesData;
function countries() {
  if (!countriesData) {
    $.ajax({
      url: '/cgi/i18n/countries.pl',
      dataType: 'json',
      async: false,
      success: function(json) {
        countriesData = json;
      }
    });
  }

  return countriesData;
}

window.addEventListener('load', onLoad);
