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

/* global maplibregl */
import './maplibre-gl.js';

export function displayMap(containerId, pointers) {
  if (!containerId || !pointers || pointers.length === 0) {
    return;
  }

  const map = new maplibregl.Map({
    container: containerId,
    style: {
      version: 8,
      sources: {
        osm: {
          type: 'raster',
          tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
          tileSize: 256,
          attribution: '&copy; OpenStreetMap Contributors',
          maxzoom: 19
        }
      },
      layers: [
        {
          id: 'osm',
          type: 'raster',
          source: 'osm'
        }
      ]
    },
    zoom: 3
  });

  const bounds = new maplibregl.LngLatBounds();

  for (const pointer of pointers) {
    new maplibregl.Marker().
      setLngLat([pointer.geo[1], pointer.geo[0]]). // MapLibre uses [lng, lat] order
      setPopup(new maplibregl.Popup().setHTML(
        `<a href="${pointer.url}">${pointer.product_name}</a><br>
         ${pointer.brands}<br>
         <a href="${pointer.url}">${pointer.img}</a><br>
         ${pointer.origins}`
      )).
      addTo(map);

    bounds.extend([pointer.geo[1], pointer.geo[0]]);
  }

  // Add navigation control
  map.addControl(new maplibregl.NavigationControl());

  // Fit map to bounds of all markers
  if (!bounds.isEmpty()) {
    map.fitBounds(bounds, { padding: 50 });
  }
}
