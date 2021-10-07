function modifyAddFieldValue(element, field_value_number){
	// Type of field
	var typeSelect = \$(element).find("#tagtype_0");
	typeSelect.attr("name", "tagtype_" + field_value_number);
	typeSelect.attr("id", "tagtype_" + field_value_number);
	typeSelect.val();

	// Value
	var tagContent = \$(element).find("#tag_0");
	tagContent.attr("name", "tag_" + field_value_number);
	tagContent.attr("id", "tag_" + field_value_number);
	tagContent.val("");

	return element;
}

function addAddFieldValue(target, field_values_number) {
	var addFieldValue1 = modifyAddFieldValue(\$(".add_field_values_row").first().clone(), field_values_number);

	\$(".add_field_values_row").last().after(addFieldValue1);
}

//On tag field value change
\$(document).on("change", ".tag-add-field-value > input", function(e){
    var field_value_number = parseInt(e.target.name.substr(e.target.name.length - 1));
    //If it's the last field value, add one more
    if(!isNaN(field_value_number) && \$("#tag_" + (field_value_number + 1).toString()).length === 0){
        addAddFieldValue(e.target, field_value_number + 1);
    }
});

\$(document).on("change", ".tag-add-field > select", function(e){
    var field_value_number = parseInt(e.target.name.substr(e.target.name.length - 1));
    //If it's the last field value, add one more
    if(!isNaN(field_value_number) && \$("#tag_" + (field_value_number + 1).toString()).length === 0){
        addAddFieldValue(e.target, field_value_number + 1);
    }
});

