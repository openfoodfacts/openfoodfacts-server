/**
 * Enhanced language switcher functionality for Open Food Facts
 * 
 * This implementation ensures that when users switch languages, they remain
 * on the same page instead of being redirected to the home page.
 * 
 * File path: /html/js/lang.js
 */

/**
 * Gets the current path and query parameters (excluding language parameter)
 * @returns {Object} Object containing path and query string
 */
function getCurrentPathAndQuery() {
    // Get the current URL
    const currentURL = window.location.href;
    // Parse the URL to extract components
    const url = new URL(currentURL);
    
    // Get path without domain
    const path = url.pathname;
    
    // Get query parameters and remove any existing language parameter
    const queryParams = new URLSearchParams(url.search);
    if (queryParams.has('lc')) {
        queryParams.delete('lc');
    }
    
    // Return path and query string (if any)
    return {
        path: path,
        query: queryParams.toString() ? '?' + queryParams.toString() : ''
    };
}

/**
 * Handles language selection, preserving the current page
 * @param {string} lang - The language code selected by the user
 */
function switchLanguage(lang) {
    // Get the current path and query parameters
    const urlParts = getCurrentPathAndQuery();
    
    // Get the base domain
    const domain = window.location.protocol + '//' + window.location.host;
    
    // Build the new URL with the selected language while preserving the current path
    // Format: {domain}/{langPrefix}{path}{query}
    
    // Check if we're already on a language-specific subdomain
    const hostParts = window.location.host.split('.');
    const currentSubdomain = hostParts[0];
    
    let newURL;
    
    // Handle special page types (product pages, search results, etc.)
    if (urlParts.path.includes('/product/')) {
        // For product pages, ensure the product code is preserved
        const productCodeMatch = urlParts.path.match(/\/product\/(\d+)/);
        if (productCodeMatch && productCodeMatch[1]) {
            const productCode = productCodeMatch[1];
            // Format: world-{lang}.openfoodfacts.org/product/{code}
            newURL = domain.replace('world', 'world-' + lang) + '/product/' + productCode + urlParts.query;
        } else {
            // Fallback if we can't parse the product code
            newURL = domain.replace('world', 'world-' + lang) + urlParts.path + urlParts.query;
        }
    } else if (urlParts.path.includes('/search')) {
        // For search pages, preserve the search parameters
        newURL = domain.replace('world', 'world-' + lang) + urlParts.path + urlParts.query;
    } else if (urlParts.path.includes('/category/')) {
        // For category pages
        newURL = domain.replace('world', 'world-' + lang) + urlParts.path + urlParts.query;
    } else {
        // For other pages, simply preserve the path and query
        newURL = domain.replace('world', 'world-' + lang) + urlParts.path + urlParts.query;
    }
    
    // Navigate to the new URL
    window.location.href = newURL;
}

/**
 * Initialize the language switcher
 * This function attaches event handlers to language selector elements
 */
function initLanguageSwitcher() {
    // Get all language selector links
    const languageLinks = document.querySelectorAll('.language-selector a, .language-li a');
    
    // Attach click event handler to each language link
    languageLinks.forEach(link => {
        link.addEventListener('click', function(event) {
            // Prevent the default behavior
            event.preventDefault();
            
            // Extract the language code from the link
            // This assumes the language code is available as data-lang attribute
            const langCode = this.getAttribute('data-lang');
            
            // If language code is available, switch to that language
            if (langCode) {
                switchLanguage(langCode);
            }
        });
    });
}

// Initialize when the DOM is fully loaded
document.addEventListener('DOMContentLoaded', initLanguageSwitcher);