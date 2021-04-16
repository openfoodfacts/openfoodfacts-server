\$('#pro').change(function() {
	if (\$(this).prop('checked')) {
		\$('.pro_org_display').show();
		\$('.tr_teams').hide();
	} else {
		\$('.pro_org_display').hide();
		\$('.tr_teams').show();
	}
	\$(document).foundation('equalizer', 'reflow');
});

if (\$('#pro').prop('checked')) {
	\$('.pro_org_display').show();
	\$('.tr_teams').hide();
}