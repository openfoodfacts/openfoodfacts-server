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

/*global lang*/

import jsVectorMap from 'jsvectormap';
// eslint-disable-next-line sort-imports
import './world-merc.js';

function getServerDomain() {
  return (/^https?:\/\/([^/?#]+)(?:[/?#]|$)/i).exec(globalThis.location.href)[1];
}

export function displayWorldMap(selector, countries) {
  const countries_map_data = countries.data;
  const countries_map_links = countries.links;
  const countries_map_names = countries.names;
  const products = lang().products;
  const direction = getComputedStyle(document.querySelector(selector)).direction;

  const JsVectorMap = jsVectorMap; // Workaround for SonarQube false positive
  const map = new JsVectorMap({
    selector: selector,
    map: "world_merc",
    visualizeData: {
      values: countries_map_data,
      scale: ["#008C8C", "#ff8714"]
    },
    onRegionTooltipShow: (_e, tooltip, index) => {
      let label = countries_map_names[index];
      if (countries_map_data[index] > 0) {
        label =
          direction === "rtl"
            ? `(${products} ${countries_map_data[index]}) ${label}`
            : `${label} (${countries_map_data[index]} ${products})`;
      }
      tooltip.text(label);
    },
    onRegionClick: (_e, code) => {
      if (countries_map_links[code]) {
        globalThis.location.href = `//${getServerDomain()}${countries_map_links[code]}`;
      }
    },
  });

  globalThis.addEventListener("resize", () => {
    map.updateSize();
  });
}
