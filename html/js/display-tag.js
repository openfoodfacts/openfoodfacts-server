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

/* global maplibregl turf */
import './maplibre-gl.js';
import './turf.min.js';

function createMaplibreMap() {
  const tagDescription = document.getElementById('tag_description');
  if (tagDescription) {
    tagDescription.classList.remove('large-12');
    tagDescription.classList.add('large-9');
  }

  const tagMap = document.getElementById('tag_map');
  if (tagMap) {
    tagMap.style.display = '';
  }

  const map = new maplibregl.Map({
    container: 'container',
    style: 'https://demotiles.maplibre.org/style.json',
    zoom: 3
  });

  // Add navigation control
  map.addControl(new maplibregl.NavigationControl({ showCompass: false }));

  return map;
}

function fitBoundsToAllLayers(map, geoJson) {
  const centre = turf.centroid(geoJson);
  if (centre) {
    map.flyTo({ center: centre.geometry.coordinates, zoom: 4 });
  }
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
    const map = createMaplibreMap();
    map.on('load', () => {
      map.addSource('area', {
        type: 'geojson',
        data: geoJson
      });

      map.addLayer({
        id: 'area-layer',
        type: 'fill',
        source: 'area',
        paint: {
          'fill-color': '#ff8714',
          'fill-opacity': 0.75
        }
      });

      fitBoundsToAllLayers(map, geoJson);
    });
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

  return data;
}

function displayPointers(pointers) {
  const map = createMaplibreMap();
  const bounds = new maplibregl.LngLatBounds();

  for (const pointer of pointers) {
    let coordinates;

    // If pointer is an array, it just contains (lat, lng) geo coordinates
    if (Array.isArray(pointer)) {
      coordinates = [pointer[1], pointer[0]]; // MapLibre uses [lng, lat] order
    }
    // Otherwise we have a structured object
    else {
      coordinates = [pointer.geo.lng, pointer.geo.lat];
    }

    new maplibregl.Marker().
      setLngLat(coordinates).
      addTo(map);

    bounds.extend(coordinates);
  }

  if (!bounds.isEmpty()) {
    fitBoundsToAllLayers(map, bounds);
  }
}

export async function displayMap(pointers, wikidataObjects) {
  if (pointers && pointers.length > 0) {
    displayPointers(pointers);
  }

  if (wikidataObjects) {
    for (const wikidataObject of wikidataObjects) {
      if (wikidataObject !== null) {
        await addWikidataObjectToMap(wikidataObject); // eslint-disable-line no-await-in-loop
      }
    }
  }
}
