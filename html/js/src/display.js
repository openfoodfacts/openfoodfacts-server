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

import './vendor/jquery-ui.js';
import { IOlazy } from 'iolazyload';
import 'manupjs';

import '../../css/src/display.css';
import '../../../scss/app.scss';

function initIOLazy() {
  new IOlazy();
}

async function initCountrySelect(placeholder, serverdomain) {
  const $ = await import('jquery');
  await import('select2');
  var options = {
    placeholder: placeholder,
    allowClear: true
  };

  $('#select_country').select2(options).on('select2:select', function(e) {
    var subdomain =  e.params.data.id;
    if (! subdomain) {
      subdomain = 'world';
    }
    window.location.href = document.location.protocol + '//' + subdomain + '.' + serverdomain;
  }).on('select2:unselect', function() {
    window.location.href = document.location.protocol + '//world.' + serverdomain;
  });
}

async function initFoundation() {
  const $ = await import('jquery');
  await import('foundation-sites');
  $(document).foundation({
    equalizer : {
      // Specify if Equalizer should make elements equal height once they become stacked.
      equalize_on_stack: true
    },
    accordion: {
      callback : function () {
        $(document).foundation('equalizer', 'reflow');
      }
    }
  });
}

async function initCategoryStats() {
  const $ = await import('jquery');
  const Cookies = await import('js-cookie');
  if (Cookies.get('show_stats') == '1') {
    $('#show_stats').prop('checked',true);
  }
  else {
    $('#show_stats').prop('checked',false);
  }

  if ($('#show_stats').prop('checked')) {
    $('.stats').show();
  }
  else {
    $('.stats').hide();
  }

  $('#show_stats').change(function () {
    if ($('#show_stats').prop('checked')) {
      Cookies.set('show_stats', '1', { expires: 365 });
      $('.stats').show();
    }
    else {
      Cookies.set('show_stats', null);
      $('.stats').hide();
    }
  });
}

async function initUnselectButton() {
  const $ = await import('jquery');
  $('.unselectbutton').click(function (event) {
    event.stopPropagation();
    event.preventDefault();
    $('div.unselectbuttondiv' + event.target.dataset.idlc).html('<img src="/images/misc/loading2.gif"> Unselecting image');
    $.post('/cgi/product_image_unselect.pl',
      { code: event.target.dataset.code, id: event.target.dataset.idlc }, function (data) {
        if (data.status_code === 0) {
          $('div.unselectbuttondiv' + event.target.dataset.idlc).html('Unselected image');
          $('div[id="image_box_' + event.target.dataset.id + '"]').html('');
        }
        else {
          $('div.unselectbuttondiv' + event.target.dataset.idlc).html('Could not unselect image');
        }
        $(document).foundation('equalizer', 'reflow');
      }, 'json');

    $(document).foundation('equalizer', 'reflow');
  });
}

async function initNutritionCompareToggle() {
  const $ = await import('jquery');
  $('input:radio[name=nutrition_data_compare_type]').change(function () {
    if ($('input:radio[name=nutrition_data_compare_type]:checked').val() == 'compare_value') {
      $('.compare_percent').hide();
      $('.compare_value').show();
    }
    else {
      $('.compare_value').hide();
      $('.compare_percent').show();
    }
  });

  $('.show_comparison').change(function () {
    if ($(this).prop('checked')) {
      $('.' + $(this).attr('id')).show();
    }
    else {
      $('.' + $(this).attr('id')).hide();
    }
  });
}

document.addEventListener('DOMContentLoaded', function() {
  initIOLazy();
  initFoundation();
  initCountrySelect(document.getElementById('mainscript').dataset['selectcountry'], document.documentElement.dataset['serverdomain']);
  initCategoryStats();
  initUnselectButton();
  initNutritionCompareToggle();
});
