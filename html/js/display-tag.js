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

/*global L osmtogeojson*/
/*exported displayMap*/

var map;
function ensureMapIsDisplayed() {
  if (map) {
    return;
  }

  var tagDescription = document.getElementById('tag_description');
  if (tagDescription) {
    tagDescription.classList.remove('large-12');
    tagDescription.classList.add('large-9');
  }

  var tagMap = document.getElementById('tag_map');
  if (tagMap) {
    tagMap.style.display = '';
  }

  map = L.map('container');

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  }).addTo(map);
}

function fitBoundsToAllLayers(mapToUpdate) {
  var latlngbounds = new L.latLngBounds();

  mapToUpdate.eachLayer(function (l) {
    if (typeof l.getBounds === "function") {
      latlngbounds.extend(l.getBounds());
    }
  });

  mapToUpdate.fitBounds(latlngbounds);
}

function runCallbackOnJson(callback) {
  ensureMapIsDisplayed();
  callback(map);
}

function addWikidataObjectToMap(id) {
  getOpenStreetMapFromWikidata(id, function (data) {
    var bindings = data.results.bindings;
    if (bindings.length === 0) {
      return;
    }

    var binding = bindings[0];
    var relationId = binding.OpenStreetMap_Relations_ID.value;
    if (!relationId) {
      return;
    }

    getGeoJsonFromOsmRelation(relationId, function (geoJson) {
      if (geoJson) {
        runCallbackOnJson(function (mapToUpdate) {
          L.geoJSON(geoJson).addTo(mapToUpdate);
          fitBoundsToAllLayers(mapToUpdate);
        });
      }
    });
  });
}

function getOpenStreetMapFromWikidata(id, callback) {
  var endpointUrl = 'https://query.wikidata.org/sparql',
    sparqlQuery = "SELECT ?OpenStreetMap_Relations_ID WHERE {\n" +
      "  wd:" + id + " wdt:P402 ?OpenStreetMap_Relations_ID.\n" +
      "}",
    settings = {
      headers: { Accept: 'application/sparql-results+json' },
      data: { query: sparqlQuery }
    };

  $.ajax(endpointUrl, settings).then(callback);
}

function getOsmDataFromOverpassTurbo(id, callback) {
  $.ajax('https://overpass-api.de/api/interpreter?data=relation%28' + id + '%29%3B%0A%28._%3B%3E%3B%29%3B%0Aout%3B').then(callback);
}

function getGeoJsonFromOsmRelation(id, callback) {
  getOsmDataFromOverpassTurbo(id, function (xml) {
    callback(osmtogeojson(xml));
  });
}

function displayPointers(pointers) {
  runCallbackOnJson(function (actualMap) {
    var markers = [];
    for (var i = 0; i < pointers.length; ++i) {
      var pointer = pointers[i];
      var marker = new L.marker(pointer);
      markers.push(marker);
    }

    if (markers.length > 0) {
      L.featureGroup(markers).addTo(actualMap);
      fitBoundsToAllLayers(actualMap);
      actualMap.setZoom(10);
    }
  });
}

function displayMap(pointers, wikidataObjects) {
  if (pointers.length > 0) {
    displayPointers(pointers);
  }

  for (var i = 0; i < wikidataObjects.length; ++i) {
    addWikidataObjectToMap(wikidataObjects[i]);
  }
}
