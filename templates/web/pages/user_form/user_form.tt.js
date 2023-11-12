\$('#pro').change(function() {
	if (\$(this).prop('checked')) {
		\$('.pro_org_display').show();
		\$('#teams_section').hide();
	} else {
		\$('.pro_org_display').hide();
		\$('#teams_section').show();
	}
	\$(document).foundation('equalizer', 'reflow');
});

if (\$('#pro').prop('checked')) {
	\$('.pro_org_display').show();
	\$('#teams_section').hide();
}