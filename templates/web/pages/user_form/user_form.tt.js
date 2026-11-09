[%- IF action == 'display' -%]
function checkboxChange(checkbox) {
	if (checkbox.checked) {
		\$('.pro_org_display').show();
		\$('#teams_section').hide();
		if ( ! \$('#pro-email-warning').length ) {
			const email_warning = [% lang('email_warning') | js %];
			const element = \$('<div style="color: red; font-weight: 600;" id="pro-email-warning"></div>');
			element.text(`🚨 ${email_warning}`);
			\$('.pro_org_display').first().prepend(element);
		}
	} else {
		\$('.pro_org_display').hide();
		\$('#teams_section').show();
	}
}

var proCheckbox = document.getElementById('pro');
checkboxChange(proCheckbox);

proCheckbox.addEventListener('change', function() {
	checkboxChange(this);
});
[%- END -%]
[%- IF action == 'process' AND type == 'add' -%]
// Track successful signup event in Matomo (issue #13166)
if (typeof trackMatomoEvent === 'function') {
	trackMatomoEvent('user', 'signup', 'successful');
}
[%- END -%]
