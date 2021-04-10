\$('#pro').change(function() {
	if (\$(this).prop('checked')) {
		\$('#pro_org').show();
		\$('#tr_teams').hide();
	} else {
		\$('#pro_org').hide();
		\$('#tr_teams').show();
	}
	\$(document).foundation('equalizer', 'reflow');
});


function normalize_string_value(inputfield) {

	var value = inputfield.value.toLowerCase();

	value = value.replace(new RegExp(" ", 'g'),"-");
	value = value.replace(new RegExp("[àáâãäå]", 'g'),"a");
	value = value.replace(new RegExp("æ", 'g'),"ae");
	value = value.replace(new RegExp("ç", 'g'),"c");
	value = value.replace(new RegExp("[èéêë]", 'g'),"e");
	value = value.replace(new RegExp("[ìíîï]", 'g'),"i");
	value = value.replace(new RegExp("ñ", 'g'),"n");
	value = value.replace(new RegExp("[òóôõö]", 'g'),"o");
	value = value.replace(new RegExp("œ", 'g'),"oe");
	value = value.replace(new RegExp("[ùúûü]", 'g'),"u");
	value = value.replace(new RegExp("[ýÿ]", 'g'),"y");
	value = value.replace(new RegExp("[^a-zA-Z0-9-]", 'g'),"-");
	value = value.replace(new RegExp("-+", 'g'),"-");
	value = value.replace(new RegExp("^-"),"");

	inputfield.value = value;
}