/**
 * Tests for the enhanced language switcher functionality
 * 
 * This file contains unit tests to verify that the language switcher
 * correctly preserves the current page when changing languages.
 * 
 * File path: /html/js/tests/language_switcher_tests.js
 */

// Mock window.location for testing
const mockLocation = {
    protocol: 'https:',
    host: 'world.openfoodfacts.org',
    pathname: '/product/3017624010701',
    search: '?fields=product_name,nutrition_grades',
    href: 'https://world.openfoodfacts.org/product/3017624010701?fields=product_name,nutrition_grades'
  };
  
  // Save original location
  const originalLocation = window.location;
  
  // Setup test environment
  function setupTest() {
    // Define window.location as a writable property
    Object.defineProperty(window, 'location', {
      writable: true,
      value: { ...mockLocation }
    });
  }
  
  // Restore original window.location
  function teardownTest() {
    window.location = originalLocation;
  }
  
  /**
   * Test: getCurrentPathAndQuery returns the correct path and query
   */
  function testGetCurrentPathAndQuery() {
    setupTest();
    
    console.log('Test: getCurrentPathAndQuery');
    
    const result = getCurrentPathAndQuery();
    
    const expectedPath = '/product/3017624010701';
    const expectedQuery = '?fields=product_name,nutrition_grades';
    
    console.assert(
      result.path === expectedPath,
      `Path should be ${expectedPath}, got ${result.path}`
    );
    
    console.assert(
      result.query === expectedQuery,
      `Query should be ${expectedQuery}, got ${result.query}`
    );
    
    console.log('Test getCurrentPathAndQuery passed!');
    
    teardownTest();
  }
  
  /**
   * Test: switchLanguage creates the correct URL for product pages
   */
  function testSwitchLanguageForProductPage() {
    setupTest();
    
    console.log('Test: switchLanguage for product page');
    
    // Mock window.location.href setter
    let newHref = '';
    Object.defineProperty(window.location, 'href', {
      set: function(value) { newHref = value; }
    });
    
    // Call switchLanguage with 'fr' (French)
    switchLanguage('fr');
    
    const expectedURL = 'https://world-fr.openfoodfacts.org/product/3017624010701?fields=product_name,nutrition_grades';
    
    console.assert(
      newHref === expectedURL,
      `URL should be ${expectedURL}, got ${newHref}`
    );
    
    console.log('Test switchLanguage for product page passed!');
    
    teardownTest();
  }
  
  /**
   * Test: switchLanguage creates the correct URL for search pages
   */
  function testSwitchLanguageForSearchPage() {
    setupTest();
    
    // Change mock location to a search page
    window.location = {
      protocol: 'https:',
      host: 'world.openfoodfacts.org',
      pathname: '/search',
      search: '?categories_tags=beverages&nutrition_grades=a',
      href: 'https://world.openfoodfacts.org/search?categories_tags=beverages&nutrition_grades=a'
    };
    
    console.log('Test: switchLanguage for search page');
    
    // Mock window.location.href setter
    let newHref = '';
    Object.defineProperty(window.location, 'href', {
      set: function(value) { newHref = value; }
    });
    
    // Call switchLanguage with 'es' (Spanish)
    switchLanguage('es');
    
    const expectedURL = 'https://world-es.openfoodfacts.org/search?categories_tags=beverages&nutrition_grades=a';
    
    console.assert(
      newHref === expectedURL,
      `URL should be ${expectedURL}, got ${newHref}`
    );
    
    console.log('Test switchLanguage for search page passed!');
    
    teardownTest();
  }
  
  /**
   * Test: switchLanguage creates the correct URL for category pages
   */
  function testSwitchLanguageForCategoryPage() {
    setupTest();
    
    // Change mock location to a category page
    window.location = {
      protocol: 'https:',
      host: 'world.openfoodfacts.org',
      pathname: '/category/beverages',
      search: '',
      href: 'https://world.openfoodfacts.org/category/beverages'
    };
    
    console.log('Test: switchLanguage for category page');
    
    // Mock window.location.href setter
    let newHref = '';
    Object.defineProperty(window.location, 'href', {
      set: function(value) { newHref = value; }
    });
    
    // Call switchLanguage with 'de' (German)
    switchLanguage('de');
    
    const expectedURL = 'https://world-de.openfoodfacts.org/category/beverages';
    
    console.assert(
      newHref === expectedURL,
      `URL should be ${expectedURL}, got ${newHref}`
    );
    
    console.log('Test switchLanguage for category page passed!');
    
    teardownTest();
  }
  
  /**
   * Test: Language parameter is removed from query if it exists
   */
  function testLanguageParameterRemoval() {
    setupTest();
    
    // Change mock location to include a language parameter
    window.location = {
      protocol: 'https:',
      host: 'world.openfoodfacts.org',
      pathname: '/product/3017624010701',
      search: '?lc=en&fields=product_name',
      href: 'https://world.openfoodfacts.org/product/3017624010701?lc=en&fields=product_name'
    };
    
    console.log('Test: Language parameter removal');
    
    const result = getCurrentPathAndQuery();
    
    const expectedQuery = '?fields=product_name';
    
    console.assert(
      result.query === expectedQuery,
      `Query should be ${expectedQuery}, got ${result.query}`
    );
    
    console.log('Test language parameter removal passed!');
    
    teardownTest();
  }
  
  // Run all tests
  function runTests() {
    console.log('Running language switcher tests...');
    testGetCurrentPathAndQuery();
    testSwitchLanguageForProductPage();
    testSwitchLanguageForSearchPage();
    testSwitchLanguageForCategoryPage();
    testLanguageParameterRemoval();
    console.log('All tests completed!');
  }
  
  // Run tests when this script is loaded
  runTests();