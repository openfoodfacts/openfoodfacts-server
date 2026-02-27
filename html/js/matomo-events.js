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
