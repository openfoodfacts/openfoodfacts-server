// mass_rename_properties_admin_cli.js
//
// Command-line only admin version of the mass property rename script 
// for the Folksonomy Engine.
//
// This version uses the /admin/property/rename API endpoint which is more
// efficient for admins as it renames all instances of a property in a single call.
//
// This script requires admin authentication credentials.
//
// Usage:
//   node mass_rename_properties_admin_cli.js --file <input_csv_file> --auth <auth_token>
//
//   node mass_rename_properties_admin_cli.js --text "<csv_content>" --auth <auth_token>
//
//   echo -e "<csv_content>" | node mass_rename_properties_admin_cli.js --stdin --auth <auth_token>
//
//   node mass_rename_properties_admin_cli.js --help
//
// Authentication:
//   You can provide authentication via:
//   - Command line: --auth <token>
//   - Environment variable: FOLKSONOMY_AUTH_TOKEN
//   - Interactive prompt (if not provided)
//
// CSV Format:
//   The CSV file must contain at least two columns:
//   - source_property: The current property name to rename
//   - target_property: The new property name
//
// API Documentation:
//   https://api.folksonomy.openfoodfacts.org/docs
//
// Testing:
//   Tests are written as @example blocks in JSDoc comments.
//   To run tests, install testy and run:
//     npm install -g testy
//     npm run test-rename
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
function setLogging(enabled) {
  LOGGING_ENABLED = enabled;
}

/**
 * Log a message with optional data items
 * Automatically prefixes each line with [log]
 * @param {string} message - The message to log
 * @param {Array} items - Optional array of items to display (strings, objects, arrays)
 * 
 * @example
 *   setLogging(true)
 *   log('Processing request')
 *   // [log] Processing request
 * 
 * @example
 *   setLogging(true)
 *   log('User data:', [{ name: 'John', age: 30 }, 'status: active'])
 *   // [log] User data: {"name":"John","age":30} status: active
 * 
 * @example
 *   setLogging(true)
 *   log('Mixed data:', ['text', ['a', 'b'], { key: 'value' }])
 *   // [log] Mixed data: text ["a","b"] {"key":"value"}
 */
function log(message, items = []) {
  if (!LOGGING_ENABLED) {
    return;
  }
  
  if (!items || items.length === 0) {
    console.log(`[log] ${message}`);
    return;
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
}

// ============================================================================
// CSV Parsing Functions
// ============================================================================

/**
 * Parse a CSV line, handling quoted fields
 * @param {string} line - A single CSV line
 * @returns {string[]} Array of field values
 * 
 * @example
 *   parseCSVLine('foo,bar,baz')
 *   // => ['foo', 'bar', 'baz']
 * 
 * @example
 *   parseCSVLine('"foo","bar","baz"')
 *   // => ['foo', 'bar', 'baz']
 * 
 * @example
 *   parseCSVLine('foo,"bar,baz",qux')
 *   // => ['foo', 'bar,baz', 'qux']
 * 
 * @example
 *   parseCSVLine('foo,"bar""baz",qux')
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
 * Parse CSV content into an array of objects
 * @param {string} csvContent - The CSV content as a string
 * @returns {Object[]} Array of objects with source_property and target_property
 * @throws {Error} If CSV format is invalid
 * 
 * @example
 *   parseCSV('source_property,target_property\nold_name,new_name')
 *   // => [{ source_property: 'old_name', target_property: 'new_name' }]
 * 
 * @example
 *   parseCSV('source_property,target_property\nold1,new1\nold2,new2\nold3,new3')
 *   // => [
 *   //   { source_property: 'old1', target_property: 'new1' },
 *   //   { source_property: 'old2', target_property: 'new2' },
 *   //   { source_property: 'old3', target_property: 'new3' }
 *   // ]
 * 
 * @example
 *   parseCSV('SOURCE_PROPERTY,TARGET_PROPERTY\nold_name,new_name')
 *   // => [{ source_property: 'old_name', target_property: 'new_name' }]
 * 
 * @example
 *   parseCSV('source_property,target_property\n\nold_name,new_name\n\n')
 *   // => [{ source_property: 'old_name', target_property: 'new_name' }]
 * 
 * @example
 *   parseCSV('source_property,target_property\nagps_capable,consumer_electronics:agps_capable')
 *   // => [{ source_property: 'agps_capable', target_property: 'consumer_electronics:agps_capable' }]
 * 
 * @example
 *   parseCSV('only_one_header\nvalue')
 *   // !> Error: CSV must contain "source_property" and "target_property" columns
 * 
 * @example
 *   parseCSV('')
 *   // !> Error: CSV must contain at least a header row and one data row
 * 
 * @example
 *   parseCSV('source_property,target_property')
 *   // !> Error: CSV must contain at least a header row and one data row
 */
export function parseCSV(csvContent) {
  const lines = csvContent.trim().split('\n').filter(line => line.trim());
  
  if (lines.length < 2) {
    throw new Error('CSV must contain at least a header row and one data row');
  }
  
  const headers = parseCSVLine(lines[0]).map(h => h.toLowerCase().trim());
  const sourceIdx = headers.indexOf('source_property');
  const targetIdx = headers.indexOf('target_property');
  
  if (sourceIdx === -1 || targetIdx === -1) {
    throw new Error('CSV must contain "source_property" and "target_property" columns');
  }
  
  const mappings = [];
  for (let i = 1; i < lines.length; i++) {
    const fields = parseCSVLine(lines[i]);
    if (fields.length > Math.max(sourceIdx, targetIdx)) {
      const source = fields[sourceIdx].trim();
      const target = fields[targetIdx].trim();
      if (source && target) {
        mappings.push({
          source_property: source,
          target_property: target
        });
      }
    }
  }
  
  return mappings;
}

// ============================================================================
// API Functions
// ============================================================================

/**
 * Make an HTTPS request
 * @param {string} url - The URL to request
 * @param {Object} options - Request options
 * @returns {Promise<Object>} Response object with status, headers, and data
 */
function httpsRequest(url, options = {}) {
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
    
    log('Request options:', [requestOptions]);
    
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
 * Get all keys for a specific property (for reporting purposes)
 * @param {string} property - The property name
 * @returns {Promise<Object[]>} Array of property objects with product barcodes
 */
export async function getPropertyKeys(property) {
  log('Getting property keys:', [property]);
  const url = `${API_BASE_URL}/keys?q=${encodeURIComponent(property)}`;
  const response = await httpsRequest(url, { method: 'GET' });
  
  if (response.status !== 200) {
    throw new Error(`Failed to get keys for property ${property}: ${response.status}`);
  }
  
  const allKeys = response.data || [];
  log('API returned keys:', [`${allKeys.length} keys found`]);
  
  // Filter to get only exact matches (the API does fuzzy search)
  const exactMatch = allKeys.find(key => key.k === property);
  const count = exactMatch ? exactMatch.count : 0;
  
  log('Exact match count:', [`${count} products for property "${property}"`]);
  
  // Return array format for backward compatibility
  // Note: We return the count, not individual product keys
  return Array(count).fill({ property: property });
}

/**
 * Get the products list URL for a specific property
 * @param {string} property - The property name
 * @returns {Promise<{url: string, count: number}|null>} Object with URL and product count, or null if error
 */
async function getPropertyProductsURL(property) {
  try {
    const keys = await getPropertyKeys(property);
    const url = `https://world.openfoodfacts.org/property/${encodeURIComponent(property)}`;
    return {
      url: url,
      count: keys.length
    };
  } catch (error) {
    log('Error getting products URL:', [error.message]);
    return null;
  }
}

/**
 * Rename a property using the admin API
 * @param {string} oldKey - The old property name
 * @param {string} newKey - The new property name
 * @param {string} authToken - Admin authentication token
 * @param {boolean} dryRun - If true, only simulate the action without executing
 * @returns {Promise<Object>} API response
 * 
 * @example
 *   (async () => {
 *     await renameProperty('old_key', 'new_key', 'fake_token', true)
 *     // => { message: 'DRY RUN - No changes made', old_property: 'old_key', new_property: 'new_key' }
 *   })()
 * 
 * @example
 *   (async () => {
 *     // In dry-run mode, no API calls are made
 *     const result = await renameProperty('test_prop', 'new_prop', 'token', true)
 *     result.message
 *     // => 'DRY RUN - No changes made'
 *   })()
 */
export async function renameProperty(oldKey, newKey, authToken, dryRun = false) {
  log('Renaming property:', [`old_property: ${oldKey}`, `new_property: ${newKey}`, `dryRun: ${dryRun}`]);
  
  if (dryRun) {
    // Simulate successful response in dry-run mode
    log('Dry run mode - skipping actual API call');
    return { 
      message: 'DRY RUN - No changes made',
      old_property: oldKey,
      new_property: newKey
    };
  }
  
  const url = `${API_BASE_URL}/admin/property/rename`;
  const body = JSON.stringify({
    old_property: oldKey,
    new_property: newKey
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
    const errorMsg = response.data?.detail || response.data || `HTTP ${response.status}`;
    log('Rename property failed:', [errorMsg]);
    throw new Error(`Failed to rename property: ${errorMsg}`);
  }
  
  log('Rename property succeeded');
  return response.data;
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
// Rename Logic
// ============================================================================

/**
 * Process property renaming for all mappings using admin API
 * @param {Object[]} mappings - Array of {source_property, target_property} objects
 * @param {string} authToken - Admin authentication token
 * @param {boolean} dryRun - If true, only simulate the actions without executing
 * @param {Function} progressCallback - Optional callback for progress updates
 * @returns {Promise<Object>} Results object with success and error counts
 * 
 * @example
 *   (async () => {
 *     const mappings = [
 *       { source_property: 'old1', target_property: 'new1' },
 *       { source_property: 'old2', target_property: 'new2' }
 *     ]
 *     const results = await processRenames(mappings, 'token', true, null)
 *     results.total
 *     // => 2
 *   })()
 * 
 * @example
 *   (async () => {
 *     const mappings = [{ source_property: 'old', target_property: 'new' }]
 *     const results = await processRenames(mappings, 'token', true, null)
 *     results.dryRun
 *     // => true
 *   })()
 * 
 * @example
 *   (async () => {
 *     const mappings = [{ source_property: 'test', target_property: 'new_test' }]
 *     const results = await processRenames(mappings, 'token', true, null)
 *     Array.isArray(results.errors)
 *     // => true
 *   })()
 */
export async function processRenames(mappings, authToken, dryRun = false, progressCallback = null) {
  const results = {
    total: mappings.length,
    success: 0,
    errors: [],
    details: [],
    dryRun: dryRun
  };
  
  for (const mapping of mappings) {
    const { source_property, target_property } = mapping;
    
    if (progressCallback) {
      progressCallback(`${dryRun ? '[DRY RUN] ' : ''}Processing: ${source_property} -> ${target_property}`);
    }
    
    try {
      // Get count before rename (for reporting)
      let beforeCount = 0;
      try {
        const keys = await getPropertyKeys(source_property);
        beforeCount = keys.length;
        if (progressCallback) {
          progressCallback(`  Found ${beforeCount} products with property "${source_property}"`);
        }
      } catch (error) {
        if (progressCallback) {
          progressCallback(`  Warning: Could not get count: ${error.message}`);
        }
      }
      
      // Check if property exists (has products)
      if (beforeCount === 0) {
        results.errors.push({
          from: source_property,
          to: target_property,
          error: 'Property does not exist (no products found)'
        });
        
        if (progressCallback) {
          progressCallback(`  ✗ Skipped: Property does not exist (0 products found)`);
        }
        
        continue; // Skip to next mapping
      }
      
      // Perform the rename using admin API (or simulate in dry-run mode)
      const result = await renameProperty(source_property, target_property, authToken, dryRun);
      
      results.success++;
      results.details.push({
        from: source_property,
        to: target_property,
        count: beforeCount,
        result: result,
        status: 'success'
      });
      
      if (progressCallback) {
        if (dryRun) {
          progressCallback(`  ✓ Would rename property (${beforeCount} products affected)`);
        } else {
          progressCallback(`  ✓ Successfully renamed property`);
        }
      }
      
      // Add a small delay between requests
      await sleep(200);
      
    } catch (error) {
      results.errors.push({
        from: source_property,
        to: target_property,
        error: error.message
      });
      
      if (progressCallback) {
        progressCallback(`  ✗ Failed: ${error.message}`);
      }
    }
  }
  
  return results;
}

// ============================================================================
// Configuration File Functions
// ============================================================================

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
  process.stdout.write('Enter admin authentication token: ');
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
  console.log('\nAuthentication required for admin API.');
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
mass_rename_properties_admin_cli.js - Mass rename properties (Admin API)

Usage:
  node mass_rename_properties_admin_cli.js --file <input_csv_file> [--auth <token>] [--run]
  node mass_rename_properties_admin_cli.js --text "<csv_content>" [--auth <token>] [--run]
  echo -e "<csv_content>" | node mass_rename_properties_admin_cli.js --stdin [--auth <token>] [--run]
  node mass_rename_properties_admin_cli.js --help

Authentication (priority order):
  1. --auth <token>           Admin authentication token (command line)
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
  The CSV file must contain at least two columns:
  - source_property: The current property name
  - target_property: The new property name

Examples:
  # Dry run using config.json for authentication (default - no changes will be made)
  node mass_rename_properties_admin_cli.js --file mappings.csv
  
  # Actually execute the changes with config.json authentication
  node mass_rename_properties_admin_cli.js --file mappings.csv --run
  
  # Dry run with explicit token
  node mass_rename_properties_admin_cli.js --file mappings.csv --auth "your_token"
  
  # Execute with environment variable
  FOLKSONOMY_AUTH_TOKEN="your_token" node mass_rename_properties_admin_cli.js --file mappings.csv --run
  
  echo "source_property,target_property
old_name,new_name" | node mass_rename_properties_admin_cli.js --stdin --run

API Documentation:
  https://api.folksonomy.openfoodfacts.org/docs

Note:
  This script uses the /admin/property/rename endpoint which requires
  admin privileges. It's more efficient than the regular script as it
  renames all instances of a property in a single API call.
  
  By default, the script runs in DRY RUN mode to prevent accidental changes.
  Use --run to actually execute the modifications.
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
    const mappings = parseCSV(csvContent);
    log('CSV parsed successfully:', [`${mappings.length} mappings`]);
    console.log(`Found ${mappings.length} property mapping(s):\n`);
    
    // Check if there are any mappings to process
    if (mappings.length === 0) {
      console.error('Error: No valid property mappings found in CSV');
      process.exit(1);
    }
    
    mappings.forEach((m, i) => {
      console.log(`  ${i + 1}. ${m.source_property} -> ${m.target_property}`);
    });
    log('Mappings:', [mappings]);
    
    // Show sample products that will be affected (no auth needed for GET)
    console.log('\n' + '='.repeat(60));
    console.log('📦 Products affected by property renames:');
    console.log('='.repeat(60));
    
    let totalProductsAffected = 0;
    for (const mapping of mappings) {
      const result = await getPropertyProductsURL(mapping.source_property);
      if (result && result.count > 0) {
        console.log(`\n${mapping.source_property} -> ${mapping.target_property}:`);
        console.log(`  ${result.count} product${result.count !== 1 ? 's' : ''}: ${result.url}`);
        totalProductsAffected += result.count;
      } else if (result && result.count === 0) {
        console.log(`\n${mapping.source_property} -> ${mapping.target_property}:`);
        console.log(`  No products found with this property`);
      }
    }
    
    // Check if any products would be affected
    if (totalProductsAffected === 0) {
      console.log('\n' + '='.repeat(60));
      console.error('Error: No products found for any of the properties to rename');
      console.log('Nothing to do. Exiting.');
      process.exit(1);
    }
    
    // Get authentication (only needed for actual renames, not for dry-run GET queries)
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
      console.log('⚠️  ADMIN MODE - This will rename properties globally');
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
          rl.question('\nProceed with renaming? (yes/no): ', (ans) => {
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
          rl.question('\nProceed with renaming? (yes/no): ', (ans) => {
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
    
    // Process renames
    console.log('\n' + '='.repeat(60));
    console.log(dryRun ? 'Simulating property rename process...' : 'Starting property rename process...');
    console.log('='.repeat(60) + '\n');
    
    log('Starting processRenames');
    const results = await processRenames(mappings, authToken, dryRun, (msg) => console.log(msg));
    log('processRenames completed:', [`success: ${results.success}`, `errors: ${results.errors.length}`]);
    
    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('SUMMARY' + (dryRun ? ' (DRY RUN)' : ''));
    console.log('='.repeat(60));
    console.log(`Total properties: ${results.total}`);
    console.log(`Successfully ${dryRun ? 'would be' : ''} renamed: ${results.success}`);
    console.log(`Failed: ${results.errors.length}`);
    
    if (results.details.length > 0) {
      console.log('\nDetails:');
      results.details.forEach((detail, i) => {
        console.log(`  ${i + 1}. ${detail.from} -> ${detail.to} (${detail.count} products)`);
      });
    }
    
    if (results.errors.length > 0) {
      console.log('\nErrors:');
      results.errors.forEach((err, i) => {
        console.log(`  ${i + 1}. ${err.from} -> ${err.to}: ${err.error}`);
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
