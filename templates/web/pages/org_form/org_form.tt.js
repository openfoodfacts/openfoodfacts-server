document.addEventListener('DOMContentLoaded', function() {
    var checkboxes = document.querySelectorAll('.admin-checkbox');

    checkboxes.forEach(function(checkbox) {
        checkbox.addEventListener('change', function() {
            updateCheckedUserIDs(); // Update the array when checkboxes are checked/unchecked
        });
    });

    function updateCheckedUserIDs() {
        var checkedUserIDs = Array.from(checkboxes)
            .filter(checkbox => checkbox.checked)
            .map(checkbox => checkbox.name.split('_')[2]); // Extract user ID from checkbox name

        // Update the hidden input field with the updated list of checked user IDs
        document.querySelector('input[name="checked_user_ids"]').value = checkedUserIDs.join(',');
    }
});
