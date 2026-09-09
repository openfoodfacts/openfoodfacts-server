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

/*global lang HTMLElement customElements CustomEvent URLSearchParams*/

import Cropper from 'cropperjs';

const ROTATE_LEFT = -90;
const ROTATE_RIGHT = 90;

// The cropper.js v2 markup, rendered by the Cropper factory in the crop container
// (the <img id="crop-image"> element is passed to the factory as the cropper source).
// Note: no "initial-coverage" attribute, so no selection is created until the user
// clicks and drags on the canvas (same behavior as the previous implementation,
// which used "autoCrop: false").
const CROPPER_TEMPLATE = [
  '<cropper-canvas background>',
  '  <cropper-shade hidden></cropper-shade>',
  '  <cropper-handle action="select" plain></cropper-handle>',
  '  <cropper-selection movable resizable>',
  '    <cropper-grid role="grid" covered></cropper-grid>',
  '    <cropper-crosshair centered></cropper-crosshair>',
  '    <cropper-handle action="move" theme-color="rgba(255, 255, 255, 0.35)"></cropper-handle>',
  '    <cropper-handle action="n-resize"></cropper-handle>',
  '    <cropper-handle action="e-resize"></cropper-handle>',
  '    <cropper-handle action="s-resize"></cropper-handle>',
  '    <cropper-handle action="w-resize"></cropper-handle>',
  '    <cropper-handle action="ne-resize"></cropper-handle>',
  '    <cropper-handle action="nw-resize"></cropper-handle>',
  '    <cropper-handle action="se-resize"></cropper-handle>',
  '    <cropper-handle action="sw-resize"></cropper-handle>',
  '  </cropper-selection>',
  '</cropper-canvas>',
].join('\n');

class ImageEditorComponent extends HTMLElement {
  constructor() {
    super();
    // The template is maintained in templates/web/pages/product_edit/image_editor_template.tt.html
    const template = document.getElementById('image-editor-template');
    const templateContent = template.content;

    // Create open Shadow DOM and append the template content
    this.attachShadow({ mode: 'open' });
    this.shadowRoot.appendChild(templateContent.cloneNode(true));

    this.command = this.shadowRoot.querySelector('.editor-command');
    this.rotateLeftButton = this.shadowRoot.querySelector('#rotate-left');
    this.rotateRightButton = this.shadowRoot.querySelector('#rotate-right');
    this.fullSizeLink = this.shadowRoot.querySelector('#open-full-size');
    this.zoomOnWheelCheckbox = this.shadowRoot.querySelector('#zoom-on-wheel');
    this.zoomOnWheelLabel = this.shadowRoot.querySelector('#zoom-on-wheel-label');
    this.saveButton = this.shadowRoot.querySelector('#save');
    this.saveStatus = this.shadowRoot.querySelector('#save-status');
    this.cropContainer = this.shadowRoot.querySelector('#crop-container');
    this.cropImage = this.shadowRoot.querySelector('#crop-image');
    this.normalizeCheckbox = this.shadowRoot.querySelector('#normalize');
    this.normalizeLabel = this.shadowRoot.querySelector('#normalize-label');
    this.whiteMagicCheckbox = this.shadowRoot.querySelector('#white-magic');
    this.whiteMagicLabel = this.shadowRoot.querySelector('#white-magic-label');

    // The editor is not visible until an image is loaded into it.
    this.hidden = true;

    // State, reset each time an image is loaded.
    this.cropper = null;
    this.imgid = null;
    this.angle = 0;
    this.coordinates_image_size = 'full';
    this.imageUrl = '';
    this.fullImageUrl = '';
    this.naturalWidth = 0;
    this.naturalHeight = 0;
    this.loadToken = 0;
  }

  connectedCallback() {
    if (this.initialized) {
      return;
    }
    this.initialized = true;

    const messages = lang();

    this.command.textContent = messages.product_js_image_rotate_and_crop;
    this.rotateLeftButton.textContent = messages.product_js_image_rotate_left;
    this.rotateRightButton.textContent = messages.product_js_image_rotate_right;
    this.fullSizeLink.textContent = messages.product_js_image_open_full_size_image;
    this.zoomOnWheelLabel.textContent = messages.product_js_zoom_on_wheel;
    this.saveButton.textContent = messages.product_js_image_save;
    this.normalizeLabel.textContent = messages.product_js_image_normalize;
    this.whiteMagicLabel.textContent = messages.product_js_image_white_magic;

    this.rotateLeftButton.addEventListener('click', () => this.rotate(ROTATE_LEFT));
    this.rotateRightButton.addEventListener('click', () => this.rotate(ROTATE_RIGHT));
    this.zoomOnWheelCheckbox.addEventListener('change', () => this.applyZoomOnWheel());
    this.normalizeCheckbox.addEventListener('change', () => this.updateImagePreview());
    this.whiteMagicCheckbox.addEventListener('change', () => this.updateImagePreview());
    this.saveButton.addEventListener('click', () => this.save());

    // Clicking the canvas (without dragging) removes the selection, so that the
    // full image can be saved, as in the previous implementation.
    this.addEventListener('pointerdown', (event) => {
      this.pointerDown = { x: event.clientX, y: event.clientY };
    });
    this.addEventListener('click', (event) => {
      const start = this.pointerDown;
      this.pointerDown = null;
      if (!start || !this.cropper) {
        return;
      }
      // Only clicks on the crop canvas itself, and only clicks that are not
      // the end of a drag gesture, clear the selection.
      if (!event.composedPath().includes(this.cropContainer)) {
        return;
      }
      if (Math.hypot(event.clientX - start.x, event.clientY - start.y) > 3) {
        return;
      }
      const selection = this.cropper.getCropperSelection();
      if (selection && !selection.hidden && selection.width > 0 && selection.height > 0) {
        selection.$clear();
      }
    });
  }

  get imagefield() {
    const selectCrop = this.closest('.select_crop');

    return selectCrop ? selectCrop.id : '';
  }

  // eslint-disable-next-line class-methods-use-this
  get code() {
    const codeInput = document.getElementById('code');

    return codeInput ? codeInput.value.replace(/\s/g, '') : '';
  }

  // eslint-disable-next-line class-methods-use-this
  get imagePath() {
    return (window.imageEditorConfig && window.imageEditorConfig.img_path) || '';
  }

  // Site color for the cropper selection outline and handles, from the CSS
  // custom property set on the .select_crop element (scss/_product-form.scss).
  get editorThemeColor() {
    const color = getComputedStyle(this).getPropertyValue('--cropper-theme-color').trim();

    return color || '#0064c8';
  }

  loadImage({ imgid, image_size = '', coordinates_image_size = 'full' } = {}) {
    if (!imgid) {
      return;
    }

    this.destroyCropper();
    this.loadToken += 1;

    this.imgid = imgid;
    this.angle = 0;
    this.coordinates_image_size = coordinates_image_size;
    this.imageUrl = this.imagePath + imgid + image_size + '.jpg';
    this.fullImageUrl = this.imagePath + imgid + '.jpg';

    // Display the low resolution image at its real size.
    this.cropContainer.style.maxWidth = this.coordinates_image_size === '400' ? '400px' : '100%';

    this.fullSizeLink.href = this.fullImageUrl;
    this.fullSizeLink.hidden = false;
    this.hideStatus();
    this.setControlsEnabled(false);

    this.cropImage.setAttribute('src', this.imageUrl);

    const token = this.loadToken;
    this.cropper = new Cropper(this.cropImage, {
      container: this.cropContainer,
      template: CROPPER_TEMPLATE,
    });
    this.applyThemeColor();

    const cropperImage = this.cropper.getCropperImage();
    if (cropperImage) {
      cropperImage.$ready().then((image) => {
        // Ignore the result if a newer image has been loaded meanwhile.
        if (token !== this.loadToken) {
          return;
        }
        this.naturalWidth = image.naturalWidth;
        this.naturalHeight = image.naturalHeight;
        this.hidden = false;
        this.applyZoomOnWheel();
        this.setControlsEnabled(true);
      }).catch(() => {
        if (token !== this.loadToken) {
          return;
        }
        this.setStatusMessage(lang().not_saved);
      });
    }
  }

  unload() {
    this.loadToken += 1;
    this.destroyCropper();
    this.imgid = null;
    this.hidden = true;
  }

  destroyCropper() {
    if (this.cropper) {
      this.cropper.destroy();
      this.cropper = null;
    }
  }

  rotate(angle) {
    if (!this.cropper) {
      return;
    }

    this.angle = (((this.angle + angle) % 360) + 360) % 360;

    const cropperImage = this.cropper.getCropperImage();
    if (cropperImage) {
      cropperImage.$rotate((angle * Math.PI) / 180);
    }

    // Keep the selection over the same zone of the image after the rotation,
    // as the previous implementation did.
    const selection = this.cropper.getCropperSelection();
    const canvas = this.cropper.getCropperCanvas();
    if (selection && !selection.hidden && selection.width > 0 && selection.height > 0 && canvas) {
      const x1 = selection.x;
      const y1 = selection.y;
      const x2 = selection.x + selection.width;
      const y2 = selection.y + selection.height;
      const width = y2 - y1;
      const height = x2 - x1;
      let x;
      let y;
      if (angle === ROTATE_RIGHT) {
        x = canvas.clientHeight - y2;
        y = x1;
      } else {
        x = y1;
        y = canvas.clientWidth - x2;
      }
      selection.$change(x, y, width, height);
    }
  }

  applyZoomOnWheel() {
    const canvas = this.cropper && this.cropper.getCropperCanvas();
    if (canvas) {
      // Wheel zoom is disabled by default (as in the previous implementation): the
      // checkbox enables it.
      canvas.scaleStep = this.zoomOnWheelCheckbox.checked ? 0.1 : 0;
    }
  }

  applyThemeColor() {
    const canvas = this.cropper && this.cropper.getCropperCanvas();
    if (!canvas) {
      return;
    }
    const color = this.editorThemeColor;
    // The selection border, crosshair, grid and handles all have their own
    // "theme-color" default (blue #39f / translucent white): apply the site
    // color to each of them. The shade keeps its dark default to dim the area
    // outside the selection. Setting the attributes (rather than the
    // properties) also themes elements that are not yet upgraded.
    canvas.setAttribute('theme-color', color);
    canvas.querySelectorAll('cropper-selection, cropper-crosshair, cropper-grid, cropper-handle').forEach((element) => {
      element.setAttribute('theme-color', color);
    });
  }

  updateImagePreview() {
    if (!this.cropper || !this.imgid) {
      return;
    }
    const cropperImage = this.cropper.getCropperImage();
    if (!cropperImage) {
      return;
    }
    // Ask the server to render the image with the normalize / white_magic effects.
    // The rotation stays client-side: the server applies the same angle on save.
    this.hideStatus();
    const url = '/cgi/product_image_rotate.pl?code=' + encodeURIComponent(this.code)
      + '&imgid=' + encodeURIComponent(this.imgid)
      + '&angle=0'
      + '&normalize=' + encodeURIComponent(this.normalizeCheckbox.checked)
      + '&white_magic=' + encodeURIComponent(this.whiteMagicCheckbox.checked);
    cropperImage.src = url;
  }

  async save() {
    if (!this.cropper || !this.imgid) {
      return;
    }

    const selection = this.cropper.getCropperSelection();
    let x1 = -1;
    let y1 = -1;
    let x2 = -1;
    let y2 = -1;
    if (selection && !selection.hidden && selection.width > 0 && selection.height > 0) {
      const coordinates = this.getSelectionCoordinates(selection);
      if (coordinates) {
        ([x1, y1, x2, y2] = coordinates);
      }
    }

    const params = {
      code: this.code,
      id: this.imagefield,
      imgid: this.imgid,
      x1,
      y1,
      x2,
      y2,
      coordinates_image_size: this.coordinates_image_size,
      angle: this.angle,
      normalize: this.normalizeCheckbox.checked,
      white_magic: this.whiteMagicCheckbox.checked,
    };

    this.saveButton.hidden = true;
    this.showSavingStatus();

    try {
      const response = await fetch('/cgi/product_image_crop.pl', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
        body: new URLSearchParams(params),
      });
      const data = await response.json();
      if (data.image && data.image.display_url) {
        this.setStatusMessage(lang().product_js_image_saved);
        this.dispatchEvent(new CustomEvent('crop-saved', {
          bubbles: true,
          composed: true,
          detail: { imagefield: this.imagefield, display_url: data.image.display_url },
        }));
      } else {
        this.setStatusMessage(lang().not_saved);
      }
    } catch {
      this.setStatusMessage(lang().not_saved);
    } finally {
      this.saveButton.hidden = false;
    }
  }

  getSelectionCoordinates(selection) {
    const cropperImage = this.cropper.getCropperImage();
    if (!cropperImage) {
      return null;
    }

    // The transform matrix of the image ("matrix(a, b, c, d, e, f)") maps the
    // local coordinates of the image to the canvas, with the transform origin
    // at the center of the image (as cropper.js does).
    const [a, b, c, d, e, f] = cropperImage.$getTransform();
    const det = (a * d) - (b * c);
    const scale = Math.hypot(a, b);
    if (!det || !scale) {
      return null;
    }

    const originX = this.naturalWidth / 2;
    const originY = this.naturalHeight / 2;

    // Inverse of the affine transform matrix [a c e; b d f; 0 0 1].
    const invA = d / det;
    const invB = -b / det;
    const invC = -c / det;
    const invD = a / det;
    const invE = ((c * f) - (d * e)) / det;
    const invF = ((b * e) - (a * f)) / det;

    // Map a canvas point to the local (original image) coordinates.
    function toLocal(x, y) {
      const px = x - originX;
      const py = y - originY;

      return [
        (invA * px) + (invC * py) + invE + originX,
        (invB * px) + (invD * py) + invF + originY,
      ];
    }

    // Map local coordinates to the coordinates of the rotated image, i.e. the
    // image as it is displayed and as the server will produce it on save.
    function toRotated(x, y) {
      return [((a * x) + (c * y)) / scale, ((b * x) + (d * y)) / scale];
    }

    const [sx1, sy1] = toRotated(...toLocal(selection.x, selection.y));
    const [sx2, sy2] = toRotated(...toLocal(selection.x + selection.width, selection.y + selection.height));

    const swapped = Math.abs(this.angle % 180) === 90;
    const maxX = swapped ? this.naturalHeight : this.naturalWidth;
    const maxY = swapped ? this.naturalWidth : this.naturalHeight;

    return [
      Math.round(Math.min(Math.max(Math.min(sx1, sx2), 0), maxX)),
      Math.round(Math.min(Math.max(Math.min(sy1, sy2), 0), maxY)),
      Math.round(Math.min(Math.max(Math.max(sx1, sx2), 0), maxX)),
      Math.round(Math.min(Math.max(Math.max(sy1, sy2), 0), maxY)),
    ];
  }

  setControlsEnabled(enabled) {
    this.rotateLeftButton.disabled = !enabled;
    this.rotateRightButton.disabled = !enabled;
    this.saveButton.disabled = !enabled;
  }

  hideStatus() {
    this.saveStatus.hidden = true;
    this.saveStatus.textContent = '';
  }

  setStatusMessage(message) {
    this.saveStatus.hidden = false;
    this.saveStatus.textContent = message;
  }

  showSavingStatus() {
    this.saveStatus.hidden = false;
    this.saveStatus.textContent = '';
    const loadingImage = document.createElement('img');
    loadingImage.src = '/images/misc/loading2.gif';
    loadingImage.alt = '';
    this.saveStatus.appendChild(loadingImage);
    this.saveStatus.appendChild(document.createTextNode(' ' + lang().product_js_image_saving));
  }
}

// Define the custom element for the image editor component
customElements.define('image-editor', ImageEditorComponent);