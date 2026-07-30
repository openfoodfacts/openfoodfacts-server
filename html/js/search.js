// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2024 Association Open Food Facts
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

/*global folksonomy_url */

function modifySearchCriterion(element, criterion_number) {
	//Type of criterion
	const selects = element.find('select');
	const typeSelect = selects.eq(0);
	typeSelect.attr("name", "tagtype_" + criterion_number);
	typeSelect.attr("id", "tagtype_" + criterion_number);
	typeSelect.val();

	//Contains/Does not contain select
	const containsSelect = selects.eq(1);
	containsSelect.attr("name", "tag_contains_" + criterion_number);
	containsSelect.attr("id", "tag_contains_" + criterion_number);
	containsSelect.val();

	//Criterion value
	const tagContent = element.find('input');
	tagContent.attr("name", "tag_" + criterion_number);
	tagContent.attr("id", "tag_" + criterion_number);
	tagContent.val("");

	return element;
}

function addSearchCriterion(target, criteria_number) {
	const first = $(".criterion-row").first();

	first.parent().append(
		modifySearchCriterion(first.clone(), criteria_number)
	);

	// keep it responsive
	if (Foundation.utils.is_large_up()) {
		first.parent().append(
			modifySearchCriterion(first.clone(), criteria_number + 1)
		);
	}
}

(function ($) {
	//On criterion value change for the last criterion
	$(document).on("change", ".criterion-row:last .tag-search-criterion > input", function (e) {
		const criterionNumber = parseInt(e.target.name.substr(e.target.name.length - 1), 10);
		addSearchCriterion(e.target, criterionNumber + 1);
		e.preventDefault();

		// keep focus on rolling criterion
		if (Foundation.utils.is_large_up()) {
			$(".criterion-row:nth-last-of-type(2) select:first").focus();
		} else {
			$(".criterion-row:last select:first").focus();
		}
	});

	// On axis change, show/hide the corresponding folksonomy property value input for the axis
	$(document).on("change", "#axis_x, #axis_y", function (e) {

		const axis = e.target.id.split("_")[1];
		const axisSelect = $("#" + e.target.id);
		const folksonomyInput = $("#axis_" + axis + "_folksonomy_property_div");

		if (axisSelect.val() === "folksonomy") {
			folksonomyInput.show();
		} else {
			folksonomyInput.hide();
		}
	});

	// Autocomplete for Folksonomy Engine properties

    fetch(folksonomy_url + "/keys").
        then(function(u){ return u.json(); }).
        then(function(json){

        /* [    { "k": "knockoff_brand", "count": 25, "values": 7 },
                { "k": "packaging:has_character", "count": 18, "values": 1 }  ] */
        const list = $.map(json, function (value) {
                    return {
                        label: value.k + " (" + value.count + ")",
                        value: value.k
                    };
                });
        // jquery UI autocomplete: https://jqueryui.com/autocomplete/
		$("#axis_x_folksonomy_property, #axis_y_folksonomy_property").autocomplete({
			source: list,
		});
    });

})(jQuery);
