// Before page renders, check if page is in darkmode.
// Otherwise, it will load regular styles before dark style.
let dark = localStorage.getItem('darkMode');
var sheet = document.styleSheets[2];

if (dark === 'enabled') {
	sheet.disabled = false;
  localStorage.setItem('darkMode','enabled');
} else {sheet.disabled = true;}
