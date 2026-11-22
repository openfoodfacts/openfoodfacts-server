/*
 * Theme selector (Light / Dark / System).
 * The theme is resolved by the inline script in site_layout.tt.html, which
 * exposes window.offTheme. This file only wires the menu items to it and
 * marks the current choice for assistive technologies and CSS.
 */
(function () {
  const root = document.documentElement;

  function markCurrent() {
    const current = root.getAttribute('data-theme-preference') || 'system';
    document.querySelectorAll('[data-theme-choice]').forEach((el) => {
      if (el.getAttribute('data-theme-choice') === current) {
        el.setAttribute('aria-current', 'true');
      } else {
        el.removeAttribute('aria-current');
      }
    });
  }

  document.addEventListener('click', (event) => {
    const choice = event.target.closest('[data-theme-choice]');
    if (!choice || !window.offTheme) {
      return;
    }
    event.preventDefault();
    window.offTheme.set(choice.getAttribute('data-theme-choice'));
    markCurrent();
  });

  // Keeps the menu in sync when the preference changes elsewhere (e.g. another tab).
  new window.MutationObserver(markCurrent).observe(root, {
    attributes: true,
    attributeFilter: ['data-theme-preference'],
  });

  markCurrent();
})();
