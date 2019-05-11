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
import 'manupjs';

import '../../css/src/display.css';
import '../../../scss/app.scss';

async function initIOLazy() {
  const tmp = await import('iolazyload');
  const IOlazy = tmp.default.constructor;
  new IOlazy();
}

async function initCountrySelect(placeholder, serverdomain) {
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

async function initProductPageUtilityButtons() {
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

  $('#editingredients').click({}, function (event) {
    event.stopPropagation();
    event.preventDefault();

    var divHtml = $('#ingredients_list').html();
    var allergens = /(<span class="allergen">|<\/span>)/g;
    divHtml = divHtml.replace(allergens, '_');

    var editableText = $('<textarea id="ingredients_list" style="height:8rem"/>');
    editableText.val(divHtml);
    $('#ingredients_list').replaceWith(editableText);
    editableText.focus();

    $('#editingredientsbuttondiv').hide();
    $('#saveingredientsbuttondiv').show();

    $(document).foundation('equalizer', 'reflow');
  });

  $('#saveingredients').click({}, function (event) {
    event.stopPropagation();
    event.preventDefault();

    $('div[id="saveingredientsbuttondiv"]').hide();
    $('div[id="saveingredientsbuttondiv_status"]').html('<img src="/images/misc/loading2.gif"> Saving ingredients_texts_' + event.target.dataset.ilc);
    $('div[id="saveingredientsbuttondiv_status"]').show();

    const eventData = { code: event.target.dataset.code, comment: 'Updated ingredients_texts_' + event.target.dataset.ilc };
    eventData['ingredients_text_' + event.target.dataset.ilc] = $('#ingredients_list').val();
    $.post('/cgi/product_jqm_multilingual.pl', eventData, function () {

      $('div[id="saveingredientsbuttondiv_status"]').html('Saved ingredients_texts_' + event.target.dataset.ilc);
      $('div[id="saveingredientsbuttondiv"]').show();

      $(document).foundation('equalizer', 'reflow');
    }, 'json');

    $(document).foundation('equalizer', 'reflow');
  });

  $('#wipeingredients').click({}, function (event) {
    event.stopPropagation();
    event.preventDefault();

    $('div[id="wipeingredientsbuttondiv"]').html('<img src="/images/misc/loading2.gif"> Erasing ingredients_texts_' + event.target.dataset.ilc);

    const eventData = { code: event.target.dataset.code, ingredients_text_$ilc: '', comment: 'Erased ingredients_texts_' + event.target.dataset.ilc + ': too much bad data' };
    eventData['ingredients_text_' + event.target.dataset.ilc] = '';
    $.post('/cgi/product_jqm_multilingual.pl', eventData, function () {

      $('div[id="wipeingredientsbuttondiv"]').html('Erased ingredients_texts_' + event.target.dataset.ilc);
      $('div[id="ingredients_list"]').html('');

      $(document).foundation('equalizer', 'reflow');
    }, 'json');

    $(document).foundation('equalizer', 'reflow');
  });
}

document.addEventListener('DOMContentLoaded', function() {
  initIOLazy();
  initFoundation();
  initCountrySelect(document.getElementById('mainscript').dataset['selectcountry'], document.documentElement.dataset['serverdomain']);
  initCategoryStats();
  initProductPageUtilityButtons();
});
