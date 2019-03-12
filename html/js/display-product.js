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
      <link rel="stylesheet" href="/css/dist/app.css">
      <style>
        #question { font-size: larger; }
        #value { font-weight: bold; font-size: xx-large; }
      </style>
      <div data-alert class="alert-box secondary radius" tabindex="0" aria-live="assertive" role="alertdialog">
          <div class="row">
            <div class="small-12 columns"><p id="question">Question</p></div>
            <div class="small-12 columns"><p id="value">Value</p></div>
            <div class="small-4 columns"><a href="#" id="yes" class="button annotate" data-annotation="1">Yes</a></div>
            <div class="small-4 columns"><a href="#" id="no" class="button annotate" data-annotation="0">No</a></div>
            <div class="small-4 columns"><a href="#" id="skip" class="button annotate" data-annotation="-1">Skip</a></div>
          </div>
          <button id="close" tabindex="0" class="close" aria-label="Close Alert">&times;</button>
      </div>
      <script src="/bower_components/foundation/js/vendor/modernizr.js"></script>
      <script src="/bower_components/foundation/js/vendor/jquery.js"></script>
      <script src="/bower_components/foundation/js/foundation.min.js"></script>
      <script src="/bower_components/foundation/js/vendor/jquery.cookie.js"></script>
      <script>
      $(document).foundation({
        equalizer : {
          equalize_on_stack: true
        },
        accordion: {
          callback : function (accordion) {
            $(document).foundation('equalizer', 'reflow');
          }
        }
      });
      </script>
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
    shadowRoot.appendChild(RobotoffAsker.template.content.cloneNode(true));

    this.nextQuestion();
    shadowRoot.querySelector('#close').addEventListener('click', () => {
      this.style.display = 'none';
    });

    const buttons = shadowRoot.querySelectorAll('a.annotate');
    for (let i = 0; i < buttons.length; ++i) {
      buttons[i].addEventListener('click', async (e) => {
        await this.annotate(parseInt(e.currentTarget.getAttribute('data-annotation')));
        await this.nextQuestion();
        e.preventDefault();
      });
    }
  }

}

window.customElements.define('robotoff-asker', RobotoffAsker);
