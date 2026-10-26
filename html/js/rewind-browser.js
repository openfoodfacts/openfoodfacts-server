/* SPDX-License-Identifier: ISC
   Author: mapstertech
   Source https://github.com/mapstertech/mapster-right-hand-rule-fixer/blob/d374e4153ba26c2100b509f59e5a5fe616e267dd/lib/rewind-browser.js */
export class GeoJSONRewind {

  static rewindRing(ring, dir) {
    let area = 0,
      err = 0;
    // eslint-disable-next-line no-plusplus
    for (let i = 0, len = ring.length, j = len - 1; i < len; j = i++) {
      const k = (ring[i][0] - ring[j][0]) * (ring[j][1] + ring[i][1]);
      const m = area + k;
      err += Math.abs(area) >= Math.abs(k) ? area - m + k : k - m + area;
      area = m;
    }
    // eslint-disable-next-line no-mixed-operators
    if (area + err >= 0 !== Boolean(dir)) {
      ring.reverse();
    }
  }

  static rewindRings(rings, outer) {
    if (rings.length === 0) {
      return;
    }

    GeoJSONRewind.rewindRing(rings[0], outer);
    for (let i = 1; i < rings.length; i++) {
      GeoJSONRewind.rewindRing(rings[i], !outer);
    }
  }

  /**
   * Rewinds the GeoJSON object to ensure that polygons are oriented correctly.
   * @param {Object} gj - The GeoJSON object to rewind.
   * @param {boolean} outer - If true, the outer ring should be clockwise; if false, counter-clockwise.
   * @returns {Object} The rewound GeoJSON object.
   */
  static rewind(gj, outer) {
    const type = gj?.type;
    let i;

    if (type === 'FeatureCollection') {
      for (i = 0; i < gj.features.length; i++) {
        GeoJSONRewind.rewind(gj.features[i], outer);
      }

    } else if (type === 'GeometryCollection') {
      for (i = 0; i < gj.geometries.length; i++) {
        GeoJSONRewind.rewind(gj.geometries[i], outer);
      }

    } else if (type === 'Feature') {
      GeoJSONRewind.rewind(gj.geometry, outer);

    } else if (type === 'Polygon') {
      GeoJSONRewind.rewindRings(gj.coordinates, outer);

    } else if (type === 'MultiPolygon') {
      for (i = 0; i < gj.coordinates.length; i++) {
        GeoJSONRewind.rewindRings(gj.coordinates[i], outer);
      }
    }

    return gj;
  }
}