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

import { FeatureGroup, GeoJSON, LatLngBounds, Map as LeafletMap, Marker, TileLayer } from 'leaflet';
import { GeoJSONRewind } from './rewind-browser.js';

function createLeafletMap() {
  const tagDescription = document.getElementById('tag_description');
  if (tagDescription) {
    tagDescription.classList.remove('large-12');
    tagDescription.classList.add('large-9');
  }

  const tagMap = document.getElementById('tag_map');
  if (tagMap) {
    tagMap.style.display = '';
  }

  const map = new LeafletMap('container');

  const tileLayer = new TileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  });
  tileLayer.addTo(map);

  return map;
}

function fitBoundsToAllLayers(mapToUpdate) {
  const latlngbounds = new LatLngBounds();

  mapToUpdate.eachLayer(function (l) {
    if (typeof l.getBounds === "function") {
      latlngbounds.extend(l.getBounds());
    }
  });

  mapToUpdate.fitBounds(latlngbounds);
}

async function addWikidataObjectToMap(id) {
  const wikidata_result = await getOpenStreetMapFromWikidata(id);
  const bindings = wikidata_result.results.bindings;
  if (bindings.length === 0) {
    return;
  }

  const binding = bindings[0];
  const relationId = binding.OpenStreetMap_Relations_ID.value;
  if (!relationId) {
    return;
  }

  const geoJson = await getGeoJsonFromOsmRelation(relationId);
  if (geoJson) {
    const map = createLeafletMap();
    new GeoJSON(geoJson).addTo(map);
    fitBoundsToAllLayers(map);
  }
}

async function getOpenStreetMapFromWikidata(id) {
  const endpointUrl = 'https://query.wikidata.org/sparql';
  const sparqlQuery = `SELECT ?OpenStreetMap_Relations_ID WHERE {
    wd:${id} wdt:P402 ?OpenStreetMap_Relations_ID.
  }`;
  const settings = {
    headers: { Accept: 'application/sparql-results+json' }
  };

  const response = await fetch(`${endpointUrl}?query=${encodeURIComponent(sparqlQuery)}`, settings);
  const data = await response.json();

  return data;
}

async function getGeoJsonFromOsmRelation(id) {
  const response = await fetch(`https://polygons.openstreetmap.fr/get_geojson.py?params=0&id=${encodeURIComponent(id)}`);
  const data = await response.json();
  
  return GeoJSONRewind.rewind(data);
}

function displayPointers(pointers) {
  const map = createLeafletMap();
  const markers = [];
  for (const pointer of pointers) {
    let coordinates;

    // If pointer is an array, it just contains (lat, lng) geo coordinates
    if (Array.isArray(pointer)) {
      coordinates = pointer;
    }
    // Otherwise we have a structured object
    // e.g. from a map element of a knowledge panel
    else {
      coordinates = [pointer.geo.lat, pointer.geo.lng];
    }

    const marker = new Marker(coordinates);
    markers.push(marker);
  }

  if (markers.length > 0) {
    new FeatureGroup(markers).addTo(map);
    fitBoundsToAllLayers(map);
    map.setZoom(8);
  }
}

export async function displayMap(pointers, wikidataObjects) {
  if (pointers.length > 0) {
    displayPointers(pointers);
  }

  for (const wikidataObject of wikidataObjects) {
    if (wikidataObject !== null) {
      await addWikidataObjectToMap(wikidataObject); // eslint-disable-line no-await-in-loop
    }
  }
}