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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

function modifySearchCriterion(element, criterion_number){
	//Type of criterion
	var typeSelect = $(element).find("#tagtype_0");
	typeSelect.attr("name", "tagtype_" + criterion_number);
	typeSelect.attr("id", "tagtype_" + criterion_number);
	typeSelect.val();

	//Contains/Does not contain select
	var containsSelect = $(element).find("#tag_contains_0");
	containsSelect.attr("name", "tag_contains_" + criterion_number);
	containsSelect.attr("id", "tag_contains_" + criterion_number);
	containsSelect.val();

	//Criterion value
	var tagContent = $(element).find("#tag_0");
	tagContent.attr("name", "tag_" + criterion_number);
	tagContent.attr("id", "tag_" + criterion_number);
	tagContent.val("");

	return element;
}

function addSearchCriterion(target, criteria_number) {
	var criterionRow1 = modifySearchCriterion($(".criterion-row").first().clone(), criteria_number);
	var criterionRow2 = modifySearchCriterion($(".criterion-row").first().clone(), criteria_number + 1);

	$(".criterion-row").last().after(criterionRow1);
	$(".criterion-row").last().after(criterionRow2);
}

(function( $ ){
	//On criterion value change
	$(document).on("change", ".tag-search-criterion > input", function(e){
		var criterionNumber = parseInt(e.target.name.substr(e.target.name.length - 1));
		//If it's the last criterion, add two more
		if(!isNaN(criterionNumber) && $("#tag_" + (criterionNumber + 1).toString()).length === 0){
			addSearchCriterion(e.target, criterionNumber + 1);
		}
	});

})( jQuery );
