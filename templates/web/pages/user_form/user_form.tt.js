[%- IF action == 'display' -%]
function checkboxChange(checkbox) {
	if (checkbox.checked) {
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
}

var proCheckbox = document.getElementById('pro');
checkboxChange(proCheckbox);

proCheckbox.addEventListener('change', function() {
	checkboxChange(this);
});
[%- END -%]
