/*exported trackMatomoEvent*/
/*global _paq*/

// Safely track event to Matomo queue, ignoring if blocked.
function trackMatomoEvent(category, action, name, value) {
    if (typeof _paq === 'undefined') {
        return;
    }

    const eventData = ['trackEvent', category, action];

    if (name) {
        eventData.push(name);
        if (typeof value === 'number') {
            eventData.push(value);
        }
    }

    _paq.push(eventData);
}

// Track product page scores (Nutri-Score, Eco-Score, NOVA) dynamically
document.addEventListener('DOMContentLoaded', function () {
    if (document.body.classList.contains('product_page')) {
        // Nutri-Score
        var nsImg = document.querySelector('img[src*="nutriscore-"]');
        if (nsImg) {
            var nsMatch = nsImg.src.match(/nutriscore-([a-e])/);
            if (nsMatch) {
                trackMatomoEvent('product', 'has_nutriscore', nsMatch[1]);
            }
        }

        // Eco-Score
        var esImg = document.querySelector('img[src*="ecoscore-"]');
        if (esImg) {
            var esMatch = esImg.src.match(/ecoscore-([a-e])/);
            if (esMatch) {
                trackMatomoEvent('product', 'has_ecoscore', esMatch[1]);
            }
        }

        // NOVA group
        var novaImg = document.querySelector('img[src*="nova-group-"]');
        if (novaImg) {
            var novaMatch = novaImg.src.match(/nova-group-([1-4])/);
            if (novaMatch) {
                trackMatomoEvent('product', 'has_nova', novaMatch[1]);
            }
        }
    }

    // Key page visits: track visits to important landing pages
    const path = globalThis.location.pathname.toLowerCase();
    const keyPages = ['nutriscore', 'nova', 'ecoscore', 'contribute', 'discover'];
    keyPages.forEach(function (pageName) {
        if (path.includes(pageName)) {
            trackMatomoEvent('page_visit', 'visit', pageName);
        }
    });

    // "Explore by" button click tracking
    const exploreBtn = document.querySelector('button[data-dropdown="drop1"]');
    if (exploreBtn) {
        exploreBtn.addEventListener('click', function () {
            trackMatomoEvent('navigation', 'explore_by');
        });
    }

    // "Sorting by" button click tracking
    const sortBtn = document.querySelector('button[data-dropdown="drop_sort"]');
    if (sortBtn) {
        sortBtn.addEventListener('click', function () {
            trackMatomoEvent('navigation', 'sort_by');
        });
    }

    // Google Play button click tracking
    const googlePlayLinks = document.querySelectorAll('a[href*="play.google.com"]');
    googlePlayLinks.forEach(function (link) {
        link.addEventListener('click', function () {
            trackMatomoEvent('navigation', 'click_google_play');
        });
    });

    // App Store button click tracking
    const appStoreLinks = document.querySelectorAll('a[href*="apps.apple.com"]');
    appStoreLinks.forEach(function (link) {
        link.addEventListener('click', function () {
            trackMatomoEvent('navigation', 'click_app_store');
        });
    });

    // Menu hover tracking on the upper navigation bar
    const menuHoverTracked = {};
    const upperNav = document.getElementById('upNav');
    if (upperNav) {
        const menuItems = upperNav.querySelectorAll('li.has-dropdown');
        menuItems.forEach(function (menuItem) {
            let menuName = 'tools'; // default for the hamburger/tools menu
            if (menuItem.querySelector('.userlink')) {
                menuName = 'user';
            } else if (menuItem.closest('.country_language_selection') || menuItem.querySelector('#select_country')) {
                menuName = 'language';
            }

            menuItem.addEventListener('mouseenter', function () {
                if (!menuHoverTracked[menuName]) {
                    menuHoverTracked[menuName] = true;
                    trackMatomoEvent('navigation', 'menu_hover', menuName);
                }
            });
        });
    }

    // "Share product" button click tracking
    const shareButtons = document.querySelectorAll('.share_button a');
    shareButtons.forEach(function (btn) {
        btn.addEventListener('click', function () {
            trackMatomoEvent('product', 'share');
        });
    });
});
