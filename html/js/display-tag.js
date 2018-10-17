// This file is part of Product Opener.
// 
// Product Opener
// Copyright (C) 2011-2017 Association Open Food Facts
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
/*exported addWikidataObjectToMap*/

var markers = [];
var map;
function ensureMapIsDisplayed() {
	if (map) {
		return;
	}

	$('#tag_description').removeClass('large-12');
	$('#tag_description').addClass('large-9');
	$('#tag_map').show();

	map = L.map('container');

	L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
		maxZoom: 19,
		attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
	}).addTo(map);
}

function fitBoundsToAllLayers(map) {
	var latlngbounds = new L.latLngBounds();

	map.eachLayer(function (l) {
		if (typeof l.getBounds === "function") {
			latlngbounds.extend(l.getBounds());
		}
	});

	latlngbounds.extend(L.latLngBounds(markers));
	map.fitBounds(latlngbounds);
}

function runCallbackOnJson(callback) {
	ensureMapIsDisplayed();
	callback(map);
}

function addWikidataObjectToMap(id){
	getOpenStreetMapFromWikidata(id, function(data)
	{
		var bindings = data.results.bindings;
		if (bindings.length == 0) {
			return;
		}

		var binding = bindings[0];
		var relationId = binding.OpenStreetMap_Relations_ID.value;
		if (!relationId) {
			return;
		}

		getGeoJsonFromOsmRelation(relationId, function (geoJson) {
			if (geoJson) {
				runCallbackOnJson(function (map) {
					L.geoJSON(geoJson).addTo(map);
					fitBoundsToAllLayers(map);
				});
			}
		});
	});
}

function getOpenStreetMapFromWikidata(id, callback) {
	var endpointUrl = 'https://query.wikidata.org/sparql',
    sparqlQuery = "SELECT ?OpenStreetMap_Relations_ID WHERE {\n" +
        "  wd:" + id +" wdt:P402 ?OpenStreetMap_Relations_ID.\n" +
        "}",
    settings = {
        headers: { Accept: 'application/sparql-results+json' },
        data: { query: sparqlQuery }
    };

	$.ajax( endpointUrl, settings ).then(callback);
}

function getOsmDataFromOverpassTurbo(id, callback) {
	$.ajax('https://overpass-api.de/api/interpreter?data=relation%28' + id + '%29%3B%0A%28._%3B%3E%3B%29%3B%0Aout%3B').then(callback);
}

function getGeoJsonFromOsmRelation(id, callback) {
	getOsmDataFromOverpassTurbo(id, function(xml) {
		callback(osmtogeojson(xml));
	});
}