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
});

// Donation banners: which one a click or a dismissal happened in, from the
// composed event path so a link inside the <donation-banner> shadow root counts
function donationBannerName(path) {
    if (path.some((node) => node.id === 'donation-banner-top')) {
        return 'top';
    }
    if (path.some((node) => node.tagName === 'DONATION-BANNER' || (node.classList && node.classList.contains('donation-banner-footer')))) {
        return 'footer';
    }

    return null;
}

document.addEventListener('DOMContentLoaded', function () {
    const topBanner = document.getElementById('donation-banner-top');
    if (topBanner && getComputedStyle(topBanner).display !== 'none') {
        trackMatomoEvent('donation', 'banner_shown', 'top');
    }
});

document.addEventListener('click', function (event) {
    const path = event.composedPath();
    const banner = donationBannerName(path);
    if (banner === null) {
        return;
    }
    if (path.some((node) => node.id === 'hide-donate-banner')) {
        trackMatomoEvent('donation', 'banner_dismissed', banner);
    } else if (path.some((node) => node.tagName === 'A' && node.href)) {
        trackMatomoEvent('donation', 'banner_clicked', banner);
    }
});
