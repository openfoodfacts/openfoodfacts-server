var stylesheet = document.styleSheets[3]; // dark-mode stylesheet

let darkMode = localStorage.getItem('darkMode');
const darkToggle = document.getElementById("switch");

const enableDarkMode = () => {
  stylesheet.disabled = false;
  localStorage.setItem('darkMode','enabled');
}

const disableDarkMode = () => {
  stylesheet.disabled = true;
  localStorage.setItem('darkMode',null);
}

// on page refresh
if (darkMode === 'enabled') {
  enableDarkMode();
  darkToggle.checked = true;
}

darkToggle.addEventListener("click", () => {
  darkMode = localStorage.getItem("darkMode");
  if (darkMode !== "enabled") {
    enableDarkMode();
  }
  else {
    disableDarkMode();
  }
});
