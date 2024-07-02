/* eslint-disable no-unused-vars */

function togglePasswordVisibility(FieldID) {
    const passwordInput = document.getElementById(FieldID);
    const toggleIcon = passwordInput.nextElementSibling.querySelector(".material-icons");
    
    if (passwordInput.type === "password") {
        passwordInput.setAttribute("type", "text");
        if (toggleIcon) {
            toggleIcon.textContent = "visibility";
        }
    } else {
        passwordInput.setAttribute("type", "password");
        if (toggleIcon) {
            toggleIcon.textContent = "visibility_off";
        }
    }
}

