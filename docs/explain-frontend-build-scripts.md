# Explain Frontend Build Scripts

If you're new to the project, you might notice some build-related scripts in `package.json` and wonder when to use them. Here's what you need to know:

**For most contributors using Docker (recommended):**  
You don't need to run any npm commands manually! When you run `make up`, a container called `dynamicfront` automatically handles building and watching your frontend assets (CSS, JS, and icons). It watches for changes in your code and rebuilds everything on the fly.

**If you're curious about what's happening under the hood:**  
The build system uses Gulp to process frontend assets. Here's what each script does:

- `npm run build` – Builds all frontend assets once (CSS from SCSS, minified JS, optimized icons)
- `npm run build:watch` – Same as build, but keeps watching files and rebuilds when you make changes
- `npm run build:dynamic` – Installs dependencies, builds assets, and starts watching (this is what the Docker container runs)

**How it works with Docker:**  
The `dynamicfront` container runs in the background and shares the built files with the main backend container through Docker volumes. This means:
- Your SCSS files from `scss/` get compiled into CSS
- Your JavaScript files get minified and bundled
- Your SVG icons get optimized
- All these processed files go into `html/css/dist/`, `html/js/dist/`, and `html/images/icons/dist/`
- The backend picks them up automatically from those shared volumes

So if you're working on styles or scripts, just edit the source files in `scss/` or `html/js/`, and the changes will be picked up automatically while Docker is running.


**Tips for new contributors:**

If you are new to the project and using Docker, most frontend build steps run automatically in the background.  
You usually do not need to run npm commands manually unless you are debugging or working outside Docker.

If frontend assets are not updating as expected:
- Make sure Docker containers are running properly  
- Try restarting with `make down` and then `make up`  
- Check container logs to see if build errors occurred  

These quick checks can help resolve common frontend build issues during development.
