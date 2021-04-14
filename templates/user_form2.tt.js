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

if (\$('#pro').prop('checked')) {
	\$('#pro_org').show();
	\$('#tr_teams').hide();
}