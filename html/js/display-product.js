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
      </style>
      <div class="row">
        <div class="medium-12 large-8 columns">
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
