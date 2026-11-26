// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2025 Association Open Food Facts
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

import { Map as LeafletMap, Marker, TileLayer } from 'leaflet';
import { MarkerClusterGroup } from 'leaflet.markercluster';

function createSafeLink(url, text) {
  const link = document.createElement('a');
  link.setAttribute('href', String(url ?? ''));
  link.textContent = String(text ?? '');

  return link;
}

function appendTrustedImage(container, imgHtml, url) {
  if (imgHtml === null || typeof imgHtml === 'undefined' || imgHtml === '') {
    return;
  }

  const imageLink = document.createElement('a');
  imageLink.setAttribute('href', String(url ?? ''));
  imageLink.innerHTML = String(imgHtml);
  container.appendChild(imageLink);
  container.appendChild(document.createElement('br'));
}

// Server sends `origins` as an array of plain-text lines (see
// Display::map_of_products). Each line is rendered as inert text.
function appendOrigins(container, origins) {
  const lines = origins;
  if (!Array.isArray(lines)) {
    return;
  }

  lines.forEach((line) => {
    if (line === null || typeof line === 'undefined' || line === '') {
      return;
    }

    container.appendChild(document.createTextNode(String(line)));
    container.appendChild(document.createElement('br'));
  });
}

function createPopupContent(pointer) {
  const container = document.createElement('div');

  container.appendChild(createSafeLink(pointer.url, pointer.product_name ?? ''));
  container.appendChild(document.createElement('br'));

  const brands = document.createElement('span');
  brands.textContent = String(pointer.brands ?? '');
  container.appendChild(brands);
  container.appendChild(document.createElement('br'));

  appendTrustedImage(container, pointer.img, pointer.url);

  appendOrigins(container, pointer.origins);

  return container;
}

export function displayMap(containerId, pointers) {
  const map = new LeafletMap(containerId, { maxZoom: 12 });

  const tileLayer = new TileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  });
  tileLayer.addTo(map);

  const markers = new MarkerClusterGroup({ singleMarkerMode: true });
  const layers = [];

  for (const pointer of pointers) {
    const marker = new Marker(pointer.geo);
    marker.bindPopup(() => createPopupContent(pointer));
    layers.push(marker);
  }

  markers.addLayers(layers);

  map.addLayer(markers);
  map.fitBounds(markers.getBounds());
}
