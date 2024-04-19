
\$(document).ready( function () {

	\$('#pro').change(function() {
	if (\$(this).prop('checked')) {
		\$('.pro_org_display').show();
		\$('#teams_section').hide();
		if ( ! \$('#pro-email-warning').length ) {
			let pro_email_warning = '<div style="color: red; font-weight: 600;" id="pro-email-warning">🚨 [% esq(lang("email_warning")) %]</div>';
			\$('.pro_org_display').first().prepend(pro_email_warning);
		}
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

});