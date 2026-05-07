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
