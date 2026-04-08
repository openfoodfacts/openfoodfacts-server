/* SPDX-License-Identifier: AGPL-3.0-or-later */
// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2026 Association Open Food Facts
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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

/* Shared front-end utilities exported as an ES module and attached to window.offUtils
 * This file is bundled to html/js/dist/off-utils.js by gulp and exposed via importmap
 */

export function escapeHtml(s) {
    if (s === undefined || s === null) {
        return '';
    }
    const escapeMap = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
        '`': '&#96;'
    };

    return String(s).replace(/[&<>"'`]/g, function (c) {
        return escapeMap[c];
    });
}

export function escapeAttr(s) {
    return escapeHtml(s);
}

export function sanitizeSubdomain(s) {
    if (typeof s === 'undefined' || s === null) {

        return '';
    }

    return String(s).replace(/[^A-Za-z0-9-]/g, '');
}

export function encodeForUrlComponent(s) {
    if (typeof s === 'undefined' || s === null) {

        return '';
    }

    return encodeURIComponent(String(s));
}

// Make available as a global for legacy non-module scripts
if (typeof window !== 'undefined') {
    window.offUtils = window.offUtils || {};
    Object.assign(window.offUtils, {
        escapeHtml,
        escapeAttr,
        sanitizeSubdomain,
        encodeForUrlComponent,
    });
}

export default {
    escapeHtml,
    escapeAttr,
    sanitizeSubdomain,
    encodeForUrlComponent,
};
