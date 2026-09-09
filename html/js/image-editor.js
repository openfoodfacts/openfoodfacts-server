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

/*global lang admin*/

import Cropper from 'cropperjs';

class ImageEditorComponent extends HTMLElement {
  constructor() {
    super();
    // Template is maintained in templates/web/pages/product_edit/image_editor_template.tt.html
    const template = document.getElementById('image-editor-template');
    const templateContent = template.content;

    // Create open Shadow DOM and append the template content
    this.attachShadow({ mode: 'open' });
    this.shadowRoot.appendChild(templateContent.cloneNode(true));
  }
}

// Define the custom element for the image editor component
customElements.define('image-editor', ImageEditorComponent);
