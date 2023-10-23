document.addEventListener('DOMContentLoaded', function() {
    var checkboxForm =document.querySelectorAll('.admin-checkbox');
    var hiddenInputForm = document.getElementById('hiddenInputForm');
    
    checkboxForm.forEach(function(checkbox) {
        checkbox.addEventListener('change', function() {
            var hiddenInput = hiddenInputForm.querySelector('input[name="admin_status_hidden_' + checkbox.name.split('_')[2] + '"]');
            hiddenInput.value = checkbox.checked ? '1' : '0';
        });
    });
});