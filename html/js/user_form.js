var proCheckbox = document.getElementById('pro');

if (proCheckbox) {
    proCheckbox.addEventListener('change', function () {
        if (this.checked) {
            document.querySelectorAll('.pro_org_display').forEach(function (element) {
                element.style.display = 'block';
            });
        } else {
            document.querySelectorAll('.pro_org_display').forEach(function (element) {
                element.style.display = 'none';
            });
        }
    });

    if (proCheckbox.checked) {
        document.querySelectorAll('.pro_org_display').forEach(function (element) {
            element.style.display = 'block';
        });
    }
}
