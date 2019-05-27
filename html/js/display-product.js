// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2019 Association Open Food Facts
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

/* eslint-disable max-classes-per-file */

class RobotoffAsker extends HTMLElement {

  static get template() {
    const tmpl = document.createElement('template');
    tmpl.innerHTML = `
      <style>
        :host { background-color: #274477; color: white; position: fixed; bottom: 0; width: 100%; border-top: 1px solid #eee; z-index: 100; padding-top: 10px; }
        #value { font-weight: bold; }
        #close { width: 10px; height: 10px; position: absolute; top: 0; left: 0; margin: 2px 0 0 2px; color: #888888 }
        #zoom[data-zoom-in-src=""] { cursor: zoom-out; }
        #zoom[data-zoom-out-src=""] { cursor: zoom-in; }
        .zoomrow { display: block; }
        .hidden { display: none; }
      </style>
      <div class="row hidden zoomrow" id="zoomrow">
        <div class="medium-12 columns">
          <img src="" id="zoom" data-zoom-in-src="" data-zoom-out-src="">
        </div>
      </div>
      <div class="row">
        <div class="medium-2 columns">
          <img src="" id="thumbnail">
        </div>
        <div class="medium-10 large-6 columns">
          <span id="question">Question</span>
          <span id="value">Value</span>
        </div>
        <ul class="medium-12 large-4 columns button-group">
          <li><a href="#" id="no" class="button alert annotate" data-annotation="0">No</a></li>
          <li><a href="#" id="skip" class="button secondary annotate" data-annotation="-1">Not sure</a></li>
          <li><a href="#" id="yes" class="button success annotate" data-annotation="1">Yes</a></li>
        </ul>
      </div>
      <a href="#" id="close">&times;</button>
    `;

    return tmpl;
  }

  get url() {
    return this.getAttribute('url');
  }

  set url(val) {
    if (val) {
      this.setAttribute('url', val);
    } else {
      this.removeAttribute('url');
    }
  }

  get code() {
    return this.getAttribute('code');
  }

  set code(val) {
    if (val) {
      this.setAttribute('code', val);
    } else {
      this.removeAttribute('code');
    }
  }

  get lang() {
    return this.getAttribute('lang');
  }

  set lang(val) {
    if (val) {
      this.setAttribute('lang', val);
    } else {
      this.removeAttribute('lang');
    }
  }

  async nextQuestion() {
    this.question = this.questions ? this.questions.pop() : null;
    if (!this.question) {
      const response = await fetch(`${this.url}/api/v1/questions/${this.code}?lang=${this.lang}`);
      const json = await response.json();
      if (!json || json.status !== 'found') {
        this.style.display = 'none';
        this.questions = null;

        return;
      }

      this.question = json.questions.pop();
      this.questions = json.questions;
    }

    const thumbnailEl = this.shadowRoot.querySelector('#thumbnail');
    const zoomEl = this.shadowRoot.querySelector('#zoom');
    this.shadowRoot.querySelector('#zoomrow').classList.add('hidden');
    thumbnailEl.setAttribute('src', '');
    thumbnailEl.style.cursor = 'zoom-in';
    zoomEl.setAttribute('src', '');
    zoomEl.setAttribute('data-zoom-in-src', '');
    zoomEl.setAttribute('data-zoom-out-src', '');
    zoomEl.setAttribute('data-small-src', '');
    zoomEl.setAttribute('data-large-src', '');
    // By convention, ProductOpener creates [imgid].jpg, [imgid].100.jpg, [imgid].400.jpg
    const source_image_url = this.question.source_image_url;
    if (source_image_url) {
      const matches = source_image_url.match(/^(.*\/[\d]+)(?:\.[\d]+)?(\.jpg)$/i);
      if (matches) {
        thumbnailEl.setAttribute('src', `${matches[1]}.100${matches[2]}`);
        zoomEl.setAttribute('src', source_image_url);
        const large = `${matches[1]}${matches[2]}`;
        zoomEl.setAttribute('data-small-src', source_image_url);
        zoomEl.setAttribute('data-large-src', large);
        zoomEl.setAttribute('data-zoom-in-src', large);
      }
    }

    this.shadowRoot.querySelector('#question').textContent = this.question.question;
    this.shadowRoot.querySelector('#value').textContent = this.question.value;
    this.style.display = 'block';
  }

  async annotate(annotation) {
    if (this.question) {
      const data = new URLSearchParams();
      data.append('insight_id', this.question.insight_id);
      data.append('annotation', annotation);
      await fetch(`${this.url}/api/v1/insights/annotate/`, {
        method: 'POST',
        body: data
      });
    }

    await this.nextQuestion();
  }

  constructor() {
    super();

    const shadowRoot = this.attachShadow({mode: 'open'});
    const content = RobotoffAsker.template.content.cloneNode(true);

    const styles = document.querySelectorAll('link[rel="stylesheet"]');
    for (let i = 0; i < styles.length; ++i) {
      const style = styles[i];
      content.appendChild(style.cloneNode(true));
    }

    const scripts = document.querySelectorAll('script');
    for (let i = 0; i < scripts.length; ++i) {
      const script = scripts[i];
      content.appendChild(script.cloneNode(true));
    }

    content.querySelector('#thumbnail').addEventListener('click', e => {
      const zoomRow = this.shadowRoot.querySelector('#zoomrow');
      if (zoomRow.classList.toggle('hidden')) {
        e.currentTarget.style.cursor = 'zoom-in';
      }
      else {
        e.currentTarget.style.cursor = 'zoom-out';
      }
    });

    content.querySelector('#zoom').addEventListener('click', e => {
      const small = e.currentTarget.getAttribute('data-small-src');
      const large = e.currentTarget.getAttribute('data-large-src');
      const zoomIn = e.currentTarget.getAttribute('data-zoom-in-src');
      const zoomOut = e.currentTarget.getAttribute('data-zoom-out-src');
      if (zoomOut !== '') {
        e.currentTarget.setAttribute('src', zoomOut);
        e.currentTarget.setAttribute('data-zoom-in-src', large);
        e.currentTarget.setAttribute('data-zoom-out-src', '');
      }
      else {
        e.currentTarget.setAttribute('src', zoomIn);
        e.currentTarget.setAttribute('data-zoom-in-src', '');
        e.currentTarget.setAttribute('data-zoom-out-src', small);
      }
    });

    content.querySelector('#close').addEventListener('click', () => {
      this.style.display = 'none';
    });

    const buttons = content.querySelectorAll('a.annotate');
    for (let i = 0; i < buttons.length; ++i) {
      const button = buttons[i];
      button.addEventListener('click', async (e) => {
        await this.annotate(parseInt(e.currentTarget.getAttribute('data-annotation')));
        await this.nextQuestion();
        e.preventDefault();
      });

      const caption = this.getAttribute('caption-' + button.id);
      if (caption) {
        button.textContent = caption;
      }
    }

    shadowRoot.appendChild(content);
    this.nextQuestion();
  }
}

window.customElements.define('robotoff-asker', RobotoffAsker);
