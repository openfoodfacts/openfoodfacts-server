// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2020 Association Open Food Facts
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

/*global L */
/*exported displayMap*/

function displayMap(containerId, pointers) {
  var map = L.map(containerId, { maxZoom: 12 });

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  }).addTo(map);


  var markers = new L.MarkerClusterGroup({ singleMarkerMode: true });

  var length = pointers.length,
    pointer = null;

  var layers = [];

  for (var i = 0; i < length; i++) {
    pointer = pointers[i];
    var marker = new L.marker(pointer.geo);
    marker.bindPopup('<a href="' + pointer.url + '">' + pointer.product_name + '</a><br>' + pointer.brands + "<br>" + '<a href="' + pointer.url + '">' + pointer.img + '</a><br>' + pointer.origins);
    layers.push(marker);
  }

  markers.addLayers(layers);

  map.addLayer(markers);
  map.fitBounds(markers.getBounds());
}
