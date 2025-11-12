// csv2folksonomyEngineTags.js
//
// Command-line script to upload tags to Folksonomy Engine API
// from CSV files containing product barcodes and tag values.
//
// This script reads a CSV file where:
// - The first column contains product barcodes
// - Each subsequent column represents a Folksonomy Engine tag
// - Each row contains the values to upload for that product
//
// Usage:
//   node csv2folksonomyEngineTags.js --file <input_csv_file> --auth <auth_token>
//
//   node csv2folksonomyEngineTags.js --text "<csv_content>" --auth <auth_token>
//
//   echo -e "<csv_content>" | node csv2folksonomyEngineTags.js --stdin --auth <auth_token>
//
//   node csv2folksonomyEngineTags.js --help
//
// Authentication:
//   You can provide authentication via:
//   - Command line: --auth <token>
//   - Environment variable: FOLKSONOMY_AUTH_TOKEN
//   - config.json file with username and password
//   - Interactive prompt (if not provided)
//
// CSV Format:
//   The CSV file must contain:
//   - First column: code (product barcode/EAN)
//   - Subsequent columns: tag names (each column = one tag)
//   - Data rows: values for each tag
//
//   Example:
//     code,brand,origin,recyclable
//     3017620422003,Nutella,France,yes
//     5449000000996,Coca-Cola,USA,yes
//
// API Documentation:
//   https://api.folksonomy.openfoodfacts.org/docs
//
// Testing:
//   Tests are written as @example blocks in JSDoc comments.
//   To run tests, install testy and run:
//     npm install -g testy
//     npm run test-upload
//
//   Tests use these conventions:
//     // => expected_value    (assertion: result equals expected_value)
//     // !> Error: message    (assertion: should throw an error)
//
//   Note: This script uses ES modules (import/export).
//
// Copyright (c) 2024 Open Food Facts

// ============================================================================
// Imports - using only Node.js built-in modules
// ============================================================================

import fs from 'fs';
import https from 'https';
import readline from 'readline';
import path from 'path';
import { fileURLToPath } from 'url';

// ES modules don't have __dirname, so we need to create it
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ============================================================================
// Configuration
// ============================================================================

const API_BASE_URL = 'https://api.folksonomy.openfoodfacts.org';
const CONFIG_FILE = path.join(__dirname, 'config.json');

// ============================================================================
// Logging Functions
// ============================================================================

/**
 * Global logging state
 */
let LOGGING_ENABLED = false;

/**
 * Enable or disable logging
 * @param {boolean} enabled - Whether logging should be enabled
 */
export function setLogging(enabled) {
  LOGGING_ENABLED = enabled;
}

/**
 * Log a message with optional data items
 * Automatically prefixes each line with [log]
 * @param {string} message - The message to log
 * @param {Array} items - Optional array of items to display (strings, objects, arrays)
 * 
 * @example setLogging(true); log('Processing request');
 * //=> "[log] Processing request"
 * 
 * @example setLogging(true); log('User data:', [{ name: 'John', age: 30 }, 'status: active']);
 * //=> '[log] User data: {"name":"John","age":30} status: active'
 */
export function log(message, items = []) {
  if (!LOGGING_ENABLED) {
    return;
  }
  
  if (!items || items.length === 0) {
    console.log(`[log] ${message}`);
    return `[log] ${message}`;
  }
  
  // Convert each item to string representation
  const parts = items.map(item => {
    if (typeof item === 'string') {
      return item;
    } else if (typeof item === 'object') {
      return JSON.stringify(item);
    } else {
      return String(item);
    }
  });
  
  console.log(`[log] ${message} ${parts.join(' ')}`);
  return `[log] ${message} ${parts.join(' ')}`;
}

// ============================================================================
// CSV Parsing Functions
// ============================================================================

/**
 * Parse a CSV line, handling quoted fields
 * @param {string} line - A single CSV line
 * @returns {string[]} Array of field values
 * 
 * @example parseCSVLine('foo,bar,baz')
 *   // => ['foo', 'bar', 'baz']
 * 
 * @example parseCSVLine('"foo","bar","baz"')
 *   // => ['foo', 'bar', 'baz']
 * 
 * @example parseCSVLine('foo,"bar,baz",qux')
 *   // => ['foo', 'bar,baz', 'qux']
 * 
 * @example parseCSVLine('foo,"bar""baz",qux')
 *   // => ['foo', 'bar"baz', 'qux']
 * 
 * @example
 *   parseCSVLine('foo,,baz')
 *   // => ['foo', '', 'baz']
 * 
 * @example
 *   parseCSVLine('  foo  ,  bar  ,  baz  ')
 *   // => ['foo', 'bar', 'baz']
 */
export function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const nextChar = line[i + 1];
    
    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        current += '"';
        i++; // Skip next quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  
  return result;
}

/**
 * Parse CSV content into an array of product data objects
 * @param {string} csvContent - The CSV content as a string
 * @returns {Object[]} Array of objects with barcode and tags
 * @throws {Error} If CSV format is invalid
 * 
 * @example parseCSV('code,brand,origin\n3017620422003,Nutella,Italy')
 * // => [{ code: '3017620422003', properties: { brand: 'Nutella', origin: 'Italy' } }]
 * 
 * @example parseCSV('code,brand,origin\n001,A,B\n002,C,D')
 * // => [
 *      { code: '001', properties: { brand: 'A', origin: 'B' } },
 *      { code: '002', properties: { brand: 'C', origin: 'D' } }
 *   ]
 * 
 * @example parseCSV('CODE,BRAND,ORIGIN\n001,A,B')
 * // => [{ code: '001', properties: { brand: 'A', origin: 'B' } }]
 * 
 * @example parseCSV('code,brand\n001,A\n\n002,B\n')
 * //=> [
 *      { code: '001', properties: { brand: 'A' } },
 *      { code: '002', properties: { brand: 'B' } }
 *    ]
 */
export function parseCSV(csvContent) {
  const lines = csvContent.trim().split('\n').filter(line => line.trim());
  
  if (lines.length < 2) {
    throw new Error('CSV must contain at least a header row and one data row');
  }
  
  const headers = parseCSVLine(lines[0]).map(h => h.toLowerCase().trim());
  const codeIdx = headers.indexOf('code');

  if (codeIdx === -1) {
    throw new Error('CSV must contain "code" column (found columns: ' + headers.join(', ') + ')');
  }
  
  if (headers.length < 2) {
    throw new Error('CSV must contain "code" column and at least one tag column');
  }

  // Get tag names (all columns except code)
  const propertyNames = headers.filter((h, idx) => idx !== codeIdx && h);

  if (propertyNames.length === 0) {
    throw new Error('CSV must contain at least one tag column besides code');
  }
  
  const products = [];
  for (let i = 1; i < lines.length; i++) {
    const fields = parseCSVLine(lines[i]);
    if (fields.length > codeIdx) {
      const code = fields[codeIdx].trim();
      if (code) {
        const properties = {};
        
        // Extract all property values
        headers.forEach((header, idx) => {
          if (idx !== codeIdx && header && fields[idx] !== undefined) {
            const value = fields[idx].trim();
            // Only include non-empty values
            if (value) {
              properties[header] = value;
            }
          }
        });
        
        // Only add product if it has at least one property
        if (Object.keys(properties).length > 0) {
          products.push({
            code: code,
            properties: properties
          });
        }
      }
    } else {
      // Provide helpful error with line number for malformed rows
      throw new Error(`Line ${i + 1}: Invalid CSV format - expected at least ${codeIdx + 1} columns, got ${fields.length}`);
    }
  }
  
  return products;
}

// ============================================================================
// API Functions
// ============================================================================

/**
 * Make an HTTPS request
 * @param {string} url - The URL to request
 * @param {Object} options - Request options (method, headers, body)
 * @returns {Promise<Object>} Response object with status, headers, and data
 * 
 * @example
 *   httpsRequest('https://api.folksonomy.openfoodfacts.org/', {
 *     method: 'GET',
 *     headers: {
 *       'Content-Type': 'application/json',
 *     },
 *     body: JSON.stringify({ key: 'value' })
 *   }).then(response => response.data.message)
 * //=> "Hello folksonomy World! Tip: open /docs for documentation"
 */
export function httpsRequest(url, options = {}) {
  log('Making HTTPS request:', [url, `method: ${options.method || 'GET'}`]);
  
  return new Promise((resolve, reject) => {
    // Parse URL to get hostname, path, etc.
    const urlObj = new URL(url);
    const requestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port || 443,
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: options.headers || {}
    };
    
    // Log request options but mask Authorization header for security
    const logOptions = { ...requestOptions };
    if (logOptions.headers?.Authorization) {
      logOptions.headers = { ...logOptions.headers, Authorization: 'Bearer ********' };
    }
    log('Request options:', [logOptions]);
    
    const req = https.request(requestOptions, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = data ? JSON.parse(data) : null;
          log('HTTPS response:', [`status: ${res.statusCode}`, parsed]);
          resolve({ status: res.statusCode, headers: res.headers, data: parsed });
        } catch (e) {
          log('HTTPS response (non-JSON):', [`status: ${res.statusCode}`, data]);
          resolve({ status: res.statusCode, headers: res.headers, data: data });
        }
      });
    });
    
    req.on('error', (err) => {
      log('HTTPS request error:', [err.message]);
      reject(err);
    });
    
    if (options.body) {
      // Mask sensitive data in logs
      let logBody = options.body;
      try {
        // Try JSON format first
        const bodyObj = JSON.parse(options.body);
        if (bodyObj.password) {
          logBody = JSON.stringify({ ...bodyObj, password: '********' });
        }
      } catch (e) {
        // Try URL-encoded format
        if (options.body.includes('password=')) {
          logBody = options.body.replace(/password=[^&]*/, 'password=********');
        }
      }
      log('Request body:', [logBody, `bytes to write: ${Buffer.byteLength(options.body)}`]);
      req.write(options.body, 'utf8');
    }
    
    req.end();
  });
}

/**
 * Get an existing tag for a product
 * @param {string} code - Product barcode
 * @param {string} key - Tag key/name
 * @param {string} authToken - Authentication token
 * @returns {Promise<Object|null>} Existing tag object or null if not found
 */
async function getProperty(code, key, authToken) {
  log('Getting existing tag:', [`code: ${code}`, `key: ${key}`]);

  const url = `${API_BASE_URL}/product/${encodeURIComponent(code)}/${encodeURIComponent(key)}`;
  
  try {
    const response = await httpsRequest(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });

    if (response.status === 200) {
      log('Tag found:', [response.data]);
      return response.data;
    } else if (response.status === 404) {
      log('Tag not found');
      return null;
    } else {
      log('Get tag unexpected status:', [response.status]);
      return null;
    }
  } catch (error) {
    log('Get tag failed:', [error.message]);
    return null;
  }
}

/**
 * Add or update a tag for a product
 * If the tag already exists, it will be updated using PUT with the correct version
 * @param {string} code - Product barcode
 * @param {string} key - Tag key/name
 * @param {string} value - Tag value
 * @param {string} authToken - Authentication token
 * @param {boolean} dryRun - If true, only simulate the action without executing
 * @returns {Promise<Object>} API response with action taken ('added' or 'updated')
 * 
 * @example addProperty('123', 'brand', 'TestBrand', 'fake_token', true)
 * // => { message: 'DRY RUN - No changes made', code: '123', key: 'brand', value: 'TestBrand' }
 *
 * @example addProperty('456', 'origin', 'France', 'token', true)
 * // => { message: 'DRY RUN - No changes made', code: '456', key: 'origin', value: 'France' }
 */
export async function addProperty(code, key, value, authToken, dryRun = false) {
  log('Adding tag:', [`code: ${code}`, `key: ${key}`, `value: ${value}`, `dryRun: ${dryRun}`]);

  if (dryRun) {
    // Simulate successful response in dry-run mode
    log('Dry run mode - skipping actual API call');
    return { 
      message: 'DRY RUN - No changes made',
      code: code,
      key: key,
      value: value
    };
  }
  
  const url = `${API_BASE_URL}/product`;
  const body = JSON.stringify({
    product: code,
    k: key,
    v: value
  });
  
  const response = await httpsRequest(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
      'Authorization': `Bearer ${authToken}`
    },
    body: body
  });
  
  if (response.status !== 200 && response.status !== 201) {
    // Extract error message from response
    let errorMsg;
    if (response.data?.detail) {
      // FastAPI/Pydantic error format
      errorMsg = typeof response.data.detail === 'string' 
        ? response.data.detail 
        : JSON.stringify(response.data.detail);
    } else if (response.data) {
      // Generic error - stringify if it's an object
      errorMsg = typeof response.data === 'string'
        ? response.data
        : JSON.stringify(response.data);
    } else {
      errorMsg = `HTTP ${response.status}`;
    }
    
    // Check if error is about tag already existing or version conflict
    const isAlreadyExists = errorMsg.toLowerCase().includes('already exists') || 
                           errorMsg.toLowerCase().includes('duplicate') ||
                           errorMsg.toLowerCase().includes('version conflict') ||
                           response.status === 409 ||
                           response.status === 422;
    
    if (isAlreadyExists) {
      log('Tag already exists, attempting to update with PUT');
      try {
        // Get the existing tag to retrieve its version
        const existingTag = await getProperty(code, key, authToken);
        
        if (!existingTag || existingTag.version === undefined) {
          throw new Error('Could not retrieve existing tag version');
        }
        
        // Update the existing tag using PUT with version incremented by 1
        const putBody = JSON.stringify({
          product: code,
          k: key,
          v: value,
          version: existingTag.version + 1
        });
        
        const putResponse = await httpsRequest(url, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(putBody),
            'Authorization': `Bearer ${authToken}`
          },
          body: putBody
        });
        
        if (putResponse.status === 200 || putResponse.status === 201) {
          log('Tag updated successfully');
          return { ...putResponse.data, action: 'updated' };
        } else {
          throw new Error(`Failed to update tag: HTTP ${putResponse.status}`);
        }
      } catch (updateError) {
        log('Update failed:', [updateError.message]);
        throw new Error(`Failed to update existing tag: ${updateError.message}`);
      }
    }
    
    log('Add tag failed:', [errorMsg]);
    throw new Error(`Failed to add tag: ${errorMsg}`);
  }
  
  log('Add tag succeeded');
  return response.data;
}

/**
 * Login with username and password to get authentication token
 * @param {string} username - Username
 * @param {string} password - Password
 * @returns {Promise<string>} Authentication token
 */
async function loginWithCredentials(username, password) {
  log('Attempting login:', [username, `password length: ${password ? password.length : 0}`]);
  const url = `${API_BASE_URL}/auth`;
  
  // OAuth2 password grant - use x-www-form-urlencoded format
  const params = new URLSearchParams();
  params.append('grant_type', 'password');
  params.append('username', username);
  params.append('password', password);
  params.append('scope', '');
  params.append('client_id', 'string');
  params.append('client_secret', 'string');
  
  const body = params.toString();
  
  log('Login body prepared:', [`username present: ${!!username}`, `password present: ${!!password}`, `body length: ${body.length}`]);
  
  const response = await httpsRequest(url, {
    method: 'POST',
    headers: {
      'accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body)
    },
    body: body
  });
  
  if (response.status !== 200) {
    const errorMsg = response.data?.detail || 'Authentication failed';
    log('Login failed:', [errorMsg]);
    throw new Error(errorMsg);
  }
  
  log('Login successful');
  return response.data?.access_token || response.data?.token;
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Sleep for a specified duration
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// ============================================================================
// Upload Logic
// ============================================================================

/**
 * Process tag uploads for all products
 * @param {Object[]} products - Array of {code, properties} objects
 * @param {string} authToken - Authentication token
 * @param {boolean} dryRun - If true, only simulate the actions without executing
 * @param {Function} progressCallback - Optional callback for progress updates
 * @returns {Promise<Object>} Results object with success and error counts
 * 
 * @example processUploads([
 *       { code: '001', properties: { brand: 'A', origin: 'B' } },
 *       { code: '002', properties: { brand: 'C' } }
 *     ], 'token', true, null).then(r => r.totalProducts)
 * // => 2
 *
 * @example processUploads([{ code: '001', properties: { brand: 'A' } }], 'token', true, null).then(r => r.dryRun)
 * // => true
 */
export async function processUploads(products, authToken, dryRun = false, progressCallback = null) {
  const results = {
    totalProducts: products.length,
    totalProperties: 0,
    successProducts: 0,
    successProperties: 0,
    errors: [],
    details: [],
    dryRun: dryRun
  };
  
  // Count total properties
  for (const product of products) {
    results.totalProperties += Object.keys(product.properties).length;
  }
  
  for (const product of products) {
    const { code, properties } = product;
    const propertyKeys = Object.keys(properties);
    
    if (progressCallback) {
      progressCallback(`${dryRun ? '[DRY RUN] ' : ''}Processing product: ${code} (${propertyKeys.length} tags)`);
    }
    
    let productSuccess = true;
    const productErrors = [];
    const productProperties = [];
    
    for (const key of propertyKeys) {
      const value = properties[key];
      
      try {
        // Add the property
        const result = await addProperty(code, key, value, authToken, dryRun);
        
        results.successProperties++;
        productProperties.push({
          key: key,
          value: value,
          status: 'success'
        });
        
        if (progressCallback) {
          if (dryRun) {
            progressCallback(`  ✓ Would add: ${key} = ${value}`);
          } else {
            progressCallback(`  ✓ Added: ${key} = ${value}`);
          }
        }
        
        // Add a small delay between requests
        if (!dryRun) await sleep(500);
        
      } catch (error) {
        productSuccess = false;
        productErrors.push({
          key: key,
          value: value,
          error: error.message
        });
        
        results.errors.push({
          code: code,
          key: key,
          value: value,
          error: error.message
        });
        
        if (progressCallback) {
          progressCallback(`  ✗ Failed: ${key} = ${value}: ${error.message}`);
        }
      }
    }
    
    if (productSuccess) {
      results.successProducts++;
    }
    
    results.details.push({
      code: code,
      properties: productProperties,
      errors: productErrors,
      status: productSuccess ? 'success' : 'partial'
    });
  }
  
  return results;
}

// ============================================================================
// Configuration File Functions
// ============================================================================

/**
 * Read configuration from config.json file
 * @returns {Object|null} Configuration object or null if file doesn't exist
 * 
 * Expected JSON format:
 * {
 *   "username": "your_username",
 *   "password": "your_password"
 * }
 */
function readConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const content = fs.readFileSync(CONFIG_FILE, 'utf8');
      return JSON.parse(content);
    }
  } catch (error) {
    // Silently ignore if file doesn't exist or can't be read
  }
  return null;
}

// ============================================================================
// Authentication Functions
// ============================================================================

/**
 * Prompt user for authentication token
 * @returns {string} Authentication token
 */
function promptForAuth() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  // Use synchronous prompting
  process.stdout.write('Enter authentication token: ');
  const token = fs.readFileSync(0, 'utf8').trim();
  rl.close();
  return token;
}

/**
 * Get authentication token from various sources
 * @param {string[]} args - Command line arguments
 * @returns {Promise<string>} Authentication token
 */
async function getAuthToken(args) {
  log('Getting authentication token');
  
  // Check command line argument
  if (args.includes('--auth')) {
    log('Auth method: command line argument');
    const authIdx = args.indexOf('--auth');
    const token = args[authIdx + 1];
    if (token) {
      return token;
    }
  }
  
  // Check environment variable
  if (process.env.FOLKSONOMY_AUTH_TOKEN) {
    log('Auth method: environment variable');
    return process.env.FOLKSONOMY_AUTH_TOKEN;
  }
  
  // Check config.json file
  const config = readConfig();
  if (config && config.username && config.password) {
    log('Auth method: config.json file', [`username: ${config.username}`]);
    console.log(`\nUsing credentials from config.json for user: ${config.username}`);
    try {
      const token = await loginWithCredentials(config.username, config.password);
      console.log('Authentication successful!');
      return token;
    } catch (error) {
      const errorMsg = error.message || error.toString() || 'Unknown error';
      console.error(`Failed to authenticate with config.json credentials: ${errorMsg}`);
      console.log('Falling back to manual authentication...\n');
    }
  }
  
  // Prompt user
  log('Auth method: interactive prompt');
  console.log('\nAuthentication required.');
  console.log('You can provide the token via:');
  console.log('  - Command line: --auth <token>');
  console.log('  - Environment: FOLKSONOMY_AUTH_TOKEN=<token>');
  console.log('  - config.json file with username and password');
  console.log('');
  return promptForAuth();
}

// ============================================================================
// CLI Functions
// ============================================================================

/**
 * Print help message
 */
function printHelp() {
  console.log(`
csv2folksonomyEngineTags.js - Upload tags to Folksonomy Engine

Usage:
  node csv2folksonomyEngineTags.js --file <input_csv_file> [--auth <token>] [--run]
  node csv2folksonomyEngineTags.js --text "<csv_content>" [--auth <token>] [--run]
  echo -e "<csv_content>" | node csv2folksonomyEngineTags.js --stdin [--auth <token>] [--run]
  node csv2folksonomyEngineTags.js --help

Authentication (priority order):
  1. --auth <token>           Authentication token (command line)
  2. FOLKSONOMY_AUTH_TOKEN    Environment variable
  3. config.json file         JSON file with username and password
  4. Interactive prompt       Will prompt if not provided by other methods

Config file format (config.json):
  {
    "username": "your_username",
    "password": "your_password"
  }

Options:
  --run                       Execute the changes (default is DRY RUN mode)
  --dry-run                   Explicitly enable dry-run mode (default)
  --log, --verbose            Enable detailed logging

CSV Format:
  The CSV file must contain:
  - First column: code (product barcode/EAN)
  - Subsequent columns: tag names (each column = one tag)
  - Data rows: values for each tag

  Example CSV:
    code,brand,origin,recyclable
    3017620422003,Nutella,Italy,yes
    5449000000996,Coca-Cola,USA,yes
    7622300221294,Toblerone,Switzerland,no

Examples:
  # Dry run (default - no changes will be made)
  node csv2folksonomyEngineTags.js --file products.csv
  
  # Actually upload the tags
  node csv2folksonomyEngineTags.js --file products.csv --run
  
  # With explicit token
  node csv2folksonomyEngineTags.js --file products.csv --auth "your_token" --run
  
  # With environment variable
  FOLKSONOMY_AUTH_TOKEN="your_token" node csv2folksonomyEngineTags.js --file products.csv --run
  
  # From stdin
  echo "code,brand,origin
3017620422003,Nutella,Italy" | node csv2folksonomyEngineTags.js --stdin --run

API Documentation:
  https://api.folksonomy.openfoodfacts.org/docs

Note:
  By default, the script runs in DRY RUN mode to prevent accidental changes.
  Use --run to actually upload the tags to the Folksonomy Engine.
`);
}

/**
 * Read from stdin synchronously
 * @returns {string} Content from stdin
 */
function readStdin() {
  // Use readFileSync with file descriptor 0 (stdin)
  return fs.readFileSync(0, 'utf8');
}

/**
 * Main CLI handler
 */
async function runCLI() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    printHelp();
    process.exit(0);
  }
  
  // Enable logging if requested
  if (args.includes('--log') || args.includes('--verbose')) {
    setLogging(true);
    log('Logging enabled');
  }
  
  // Check if we're in dry-run mode (default) or run mode
  const dryRun = !args.includes('--run');
  log('Running in mode:', [dryRun ? 'DRY RUN' : 'EXECUTE']);
  
  let csvContent = '';
  
  try {
    // Parse command line arguments
    if (args.includes('--file')) {
      const fileIdx = args.indexOf('--file');
      const filePath = args[fileIdx + 1];
      if (!filePath) {
        console.error('Error: --file requires a file path');
        process.exit(1);
      }
      log('Reading CSV from file:', [filePath]);
      csvContent = fs.readFileSync(filePath, 'utf8');
      console.log(`Reading from file: ${filePath}`);
    } else if (args.includes('--text')) {
      const textIdx = args.indexOf('--text');
      csvContent = args[textIdx + 1];
      if (!csvContent) {
        console.error('Error: --text requires CSV content');
        process.exit(1);
      }
      log('Reading CSV from text argument');
      console.log('Reading from text argument');
    } else if (args.includes('--stdin')) {
      log('Reading CSV from stdin');
      console.log('Reading from stdin...');
      csvContent = readStdin();
    } else {
      console.error('Error: Invalid arguments. Use --help for usage information.');
      process.exit(1);
    }
    
    log('CSV content length:', [`${csvContent.length} characters`]);
    
    // Parse CSV first (before authentication)
    console.log('\nParsing CSV...');
    const products = parseCSV(csvContent);
    log('CSV parsed successfully:', [`${products.length} products`]);
    
    // Check if there are any products to process
    if (products.length === 0) {
      console.error('Error: No valid products found in CSV');
      process.exit(1);
    }
    
    // Calculate total properties
    let totalProperties = 0;
    products.forEach(p => {
      totalProperties += Object.keys(p.properties).length;
    });
    
    console.log(`Found ${products.length} product(s) with ${totalProperties} total tags:\n`);
    
    // Show first few products as preview
    const previewCount = Math.min(5, products.length);
    for (let i = 0; i < previewCount; i++) {
      const p = products[i];
      const propKeys = Object.keys(p.properties);
      console.log(`  ${i + 1}. ${p.code} (${propKeys.length} tags)`);
      propKeys.forEach(key => {
        console.log(`     - ${key}: ${p.properties[key]}`);
      });
    }
    
    if (products.length > previewCount) {
      console.log(`  ... and ${products.length - previewCount} more product(s)`);
    }
    
    log('Products:', [products]);
    
    // Get authentication (only needed for actual uploads, not for dry-run)
    let authToken = null;
    if (!dryRun) {
      authToken = await getAuthToken(args);
      if (!authToken) {
        console.error('Error: Authentication token is required for --run mode');
        process.exit(1);
      }
      log('Authentication token obtained');
    }
    
    // Show mode
    console.log('\n' + '='.repeat(60));
    if (dryRun) {
      console.log('🔍 DRY RUN MODE - No changes will be made');
      console.log('To actually execute changes, use --run flag');
    } else {
      console.log('⚠️  UPLOAD MODE - This will add tags to products');
    }
    console.log('='.repeat(60));
    
    // Confirm action (only in run mode)
    if (!dryRun) {
      // Use readline with /dev/tty to allow confirmation even when stdin is used for CSV
      let answer = '';
      try {
        const ttyStream = fs.createReadStream('/dev/tty');
        const rl = readline.createInterface({
          input: ttyStream,
          output: process.stdout
        });
        
        answer = await new Promise((resolve) => {
          rl.question('\nProceed with upload? (yes/no): ', (ans) => {
            rl.close();
            ttyStream.close();
            resolve(ans);
          });
        });
      } catch (error) {
        // Fallback to stdin if /dev/tty is not available (e.g., non-interactive environment)
        log('Could not read from /dev/tty, falling back to stdin:', [error.message]);
        const rl = readline.createInterface({
          input: process.stdin,
          output: process.stdout
        });
        
        answer = await new Promise((resolve) => {
          rl.question('\nProceed with upload? (yes/no): ', (ans) => {
            rl.close();
            resolve(ans);
          });
        });
      }
      
      const confirmed = answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y';
      log('User confirmation:', [confirmed ? 'yes' : 'no']);
      
      if (!confirmed) {
        console.log('\nOperation cancelled.');
        process.exit(0);
      }
    }
    
    // Process uploads
    console.log('\n' + '='.repeat(60));
    console.log(dryRun ? 'Simulating tag upload process...' : 'Starting tag upload process...');
    console.log('='.repeat(60) + '\n');
    
    log('Starting processUploads');
    const results = await processUploads(products, authToken, dryRun, (msg) => console.log(msg));
    log('processUploads completed:', [
      `successProducts: ${results.successProducts}`,
      `successProperties: ${results.successProperties}`,
      `errors: ${results.errors.length}`
    ]);
    
    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('SUMMARY' + (dryRun ? ' (DRY RUN)' : ''));
    console.log('='.repeat(60));
    console.log(`Total products: ${results.totalProducts}`);
    console.log(`Total tags: ${results.totalProperties}`);
    console.log(`Successfully processed products: ${results.successProducts}`);
    console.log(`Successfully ${dryRun ? 'would be' : ''} added tags: ${results.successProperties}`);
    console.log(`Failed tags: ${results.errors.length}`);
    
    if (results.errors.length > 0) {
      console.log('\nErrors:');
      results.errors.forEach((err, i) => {
        console.log(`  ${i + 1}. ${err.code} - ${err.key} = ${err.value}: ${err.error}`);
      });
    }
    
    if (dryRun) {
      console.log('\n' + '='.repeat(60));
      console.log('ℹ️  This was a DRY RUN. No changes were made.');
      console.log('To execute the changes, run again with --run flag');
      console.log('='.repeat(60));
    }
    
    console.log('\nDone!');
    
  } catch (error) {
    console.error(`\nError: ${error.message}`);
    log('Error stack trace:', [error.stack]);
    process.exit(1);
  }
}

// ============================================================================
// Main Entry Point
// ============================================================================

// Run CLI if this is the main module
if (import.meta.url === `file://${process.argv[1]}`) {
  runCLI();
}
