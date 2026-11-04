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

function isSafeHttpUrl(url) {
  if (typeof url !== 'string') {
    return false;
  }

  const trimmedUrl = url.trim();
  if (trimmedUrl === '') {
    return false;
  }

  try {
    const parsedUrl = new URL(trimmedUrl, window.location.origin);

    return parsedUrl.protocol === 'http:' || parsedUrl.protocol === 'https:';
  } catch {
    return false;
  }
}

function toSafeUrl(url) {
  if (isSafeHttpUrl(url)) {
    return url.trim();
  }

  return null;
}

function createSafeLink(url, text) {
  const safeUrl = toSafeUrl(url);
  const content = text ?? '';

  if (safeUrl === null) {
    const span = document.createElement('span');
    span.textContent = String(content);

    return span;
  }

  const link = document.createElement('a');
  link.setAttribute('href', safeUrl);
  link.textContent = String(content);

  return link;
}

function extractImageSrc(img) {
  if (typeof img !== 'string') {
    return null;
  }

  const trimmedImg = img.trim();
  if (trimmedImg === '') {
    return null;
  }

  // Current backend sends a full `<img ...>` HTML string (see
  // Images::display_image). Never inject that HTML: extract only the src.
  if (!trimmedImg.startsWith('<')) {
    return trimmedImg;
  }

  const match = trimmedImg.match(/<img[^>]*\ssrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);

  return match ? match[1] ?? match[2] ?? match[3] ?? null : null;
}

function createSafeImage(img, alt) {
  const src = extractImageSrc(img);
  if (src === null) {
    return null;
  }

  const safeSrc = toSafeUrl(src);
  if (safeSrc === null) {
    return null;
  }

  const image = document.createElement('img');
  image.setAttribute('src', safeSrc);
  image.setAttribute('alt', String(alt ?? ''));
  image.setAttribute('loading', 'lazy');

  return image;
}

// Server-side `origins` mixes plain text with intentional `<br>` separators.
// Split on `<br>` and re-emit safe text nodes so injected markup cannot run.
function appendOrigins(container, origins) {
  if (origins === null || typeof origins === 'undefined' || origins === '') {
    return;
  }

  const parts = String(origins).split(/<br\s*\/?>/i);
  parts.forEach((part, index) => {
    if (index > 0) {
      container.appendChild(document.createElement('br'));
    }

    if (part !== '') {
      container.appendChild(document.createTextNode(part));
    }
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

  const imageLinkUrl = toSafeUrl(pointer.url);
  const image = createSafeImage(pointer.img, pointer.product_name ?? '');
  if (image) {
    if (imageLinkUrl) {
      const imageLink = document.createElement('a');
      imageLink.setAttribute('href', imageLinkUrl);
      imageLink.appendChild(image);
      container.appendChild(imageLink);
    } else {
      container.appendChild(image);
    }

    container.appendChild(document.createElement('br'));
  }

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
