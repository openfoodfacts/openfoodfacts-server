# Explain JavaScript Usage and Strategy

While the core backend of the Open Food Facts server is built with Perl, JavaScript is crucial for creating a dynamic and interactive user experience. The project is currently in a transitional phase, moving from a legacy jQuery-based approach towards a modern, component-based architecture.

## Legacy Front-end: jQuery

The project historically relied extensively on **jQuery**. This approach is now considered legacy, and the jQuery version in use is outdated. However, it still powers many existing functionalities:

* **DOM Manipulation:** Selecting and modifying elements on server-rendered pages.
* **Event Handling:** Managing user interactions like clicks and form submissions.
* **AJAX Requests:** Communicating asynchronously with the Perl backend to fetch data (e.g., search suggestions) or submit forms without a full page reload.

## Node.js Tooling

**Node.js** is used within the project, but **not** for running the main web server (which remains Perl-based). Its role is primarily for development and tooling, including:

* Running utility scripts.
* Managing dependencies for modern components.
* Powering build processes for newer front-end assets.

## Modernization: The Web Component Strategy

To gradually modernize the front-end without a complete rewrite, the project has adopted a **Web Component** strategy. This allows for:

* **Incremental Updates:** New features can be developed as encapsulated, reusable Web Components.
* **Interoperability:** These components can be dropped into the existing Perl-rendered templates, allowing modern JavaScript (e.g., Lit) to coexist with the legacy jQuery code.
* **Scoped Styles and Logic:** Web Components prevent CSS and JS conflicts with the older parts of the application.

## The Next Generation: OpenFoodFacts-Explorer

The long-term vision for the Open Food Facts front-end is [**openfoodfacts-explorer**](https://github.com/openfoodfacts/openfoodfacts-explorer). This will be a fully autonomous and modern JavaScript application, likely built with a framework like Vue.js or SvelteKit. It will communicate with the Perl backend via API and will eventually replace the server-rendered pages, offering a faster, richer, and more maintainable user experience.

## File Structure and Build Process

* **Legacy Location:** Older JavaScript and jQuery plugins are located in the `htdocs/js/` directory and are included directly via `<script>` tags without a build step.
* **Modern Location:** Newer code, including Web Components, resides in separate directories and has its own modern build process (e.g., using Vite or Rollup) to bundle and optimize assets.
