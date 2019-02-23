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

function update_userid(e) {

  var userid = this.value.toLowerCase();
  userid = userid.replace(new RegExp(' ', 'g'), '-');
  userid = userid.replace(new RegExp('[àáâãäå]', 'g'), 'a');
  userid = userid.replace(new RegExp('æ', 'g'), 'ae');
  userid = userid.replace(new RegExp('ç', 'g'), 'c');
  userid = userid.replace(new RegExp('[èéêë]', 'g'), 'e');
  userid = userid.replace(new RegExp('[ìíîï]', 'g'), 'i');
  userid = userid.replace(new RegExp('ñ', 'g'), 'n');
  userid = userid.replace(new RegExp('[òóôõö]', 'g'), 'o');
  userid = userid.replace(new RegExp('œ', 'g'), 'oe');
  userid = userid.replace(new RegExp('[ùúûü]', 'g'), 'u');
  userid = userid.replace(new RegExp('[ýÿ]', 'g'), 'y');
  userid = userid.replace(new RegExp('[^a-zA-Z0-9-]', 'g'), '-');
  userid = userid.replace(new RegExp('-+', 'g'), '-');
  userid = userid.replace(new RegExp('^-'), '');
  e.target.value = userid;

}

document.addEventListener('DOMContentLoaded', function() {
  document.getElementById('userid').addEventListener('keyup', update_userid);
});
