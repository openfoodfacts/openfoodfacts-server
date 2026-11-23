/*
 * Theme handling: Light / Dark / System.
 *
 * This file is loaded synchronously in <head>, before the stylesheet, so the
 * theme is resolved before first paint and the page does not flash the wrong
 * colors. It sets two attributes on <html>:
 *   data-theme            "light" or "dark" (what the CSS reacts to)
 *   data-theme-preference "light", "dark" or "system" (what the user chose)
 * It also wires the theme menu items in the top bar (data-theme-choice).
 */
(function () {
  const KEY = 'off-theme';
  const root = document.documentElement;
  const mq = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
  // Used only when localStorage is unavailable (e.g. blocked by the browser)
  let fallback = 'system';

  function read() {
    try {
      const value = window.localStorage.getItem(KEY);

      return value === 'light' || value === 'dark' ? value : 'system';
    } catch {
      return fallback;
    }
  }

  function apply() {
    const preference = read();
    let resolved = preference;
    if (preference === 'system') {
      resolved = mq && mq.matches ? 'dark' : 'light';
    }
    root.setAttribute('data-theme', resolved);
    root.setAttribute('data-theme-preference', preference);
  }

  function set(preference) {
    fallback = preference;
    try {
      if (preference === 'system') {
        window.localStorage.removeItem(KEY);
      } else {
        window.localStorage.setItem(KEY, preference);
      }
    } catch {
      // Storage unavailable: the choice applies to this page only
    }
    apply();
  }

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

  apply();

  // Follow the operating system, but only while "System" is selected
  if (mq && mq.addEventListener) {
    mq.addEventListener('change', () => {
      if (read() === 'system') {
        apply();
      }
    });
  }

  // Keep other open tabs in sync
  window.addEventListener('storage', (event) => {
    if (event.key === KEY) {
      apply();
    }
  });

  // Menu items. Delegated from document, so it works before the menu exists.
  document.addEventListener('click', (event) => {
    const choice = event.target.closest('[data-theme-choice]');
    if (choice) {
      event.preventDefault();
      set(choice.getAttribute('data-theme-choice'));
    }
  });

  new window.MutationObserver(markCurrent).observe(root, {
    attributes: true,
    attributeFilter: ['data-theme-preference'],
  });
  document.addEventListener('DOMContentLoaded', markCurrent);

  // Kept for debugging from the console: offTheme.set('dark')
  window.offTheme = { get: read, set };
})();
