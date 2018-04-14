// This file is part of Product Opener.
// 
// Product Opener
// Copyright (C) 2011-2018 Association Open Food Facts
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

import 'jquery';
import './vendor/jquery-ui.js';
import 'manupjs';
import './vendor/foundation.js';

import '../../css/src/display.css';
import '../../../scss/app.scss';

function initCountrySelect(placeholder, serverdomain) {
	return import('jquery').then($ => {
		import('select2').then(() => {
			var options = {
				placeholder: placeholder,
				allowClear: true
			};

			$('#select_country').select2(options).on('select2:select', function(e) {
				var subdomain =  e.params.data.id;
				if (! subdomain) {
					subdomain = 'world';
				}
				window.location.href = 'http://' + subdomain + '.' + serverdomain;
			}).on('select2:unselect', function() {            
				window.location.href = 'http://world.' + serverdomain;
			});
		}).catch(error => 'An error occurred while loading the jquery-tags-input component: ' + error);
	}).catch(error => 'An error occurred while loading the jquery component: ' + error);
}

document.addEventListener('DOMContentLoaded', function() {
	initCountrySelect(document.getElementById('mainscript').dataset['selectcountry'], document.documentElement.dataset['serverdomain']);
});