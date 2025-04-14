import { dest, parallel, series, src, watch } from "gulp";
import { init, write } from "gulp-sourcemaps";

import concat from "gulp-concat";
import gulpSass from "gulp-sass";
import gzip from "gulp-gzip";
import minifyCSS from "gulp-csso";
import sassLib from "sass";
import svgmin from "gulp-svgmin";
import terser from "gulp-terser";

const sass = gulpSass(sassLib);

const jsSrc = [
  "./html/js/display*.js",
  "./html/js/product-*.js",
  "./html/js/search.js",
  "./html/js/hc-sticky.js",
  "./html/js/stikelem.js",
  "./html/js/scrollNav.js",
  "./html/js/off-webcomponents-utils.js",
  "./html/js/barcode-scanner*.js",
];

const sassSrc = "./scss/**/*.scss";

// Added function to handle multiple image formats
function handleMultipleImageFormats(path: string) {
  return [".png", ".jpg", ".jpeg", ".webp", ".svg"].map((ext) => path + ext);
}
const imagesSrc = [
  "./node_modules/leaflet/dist/**/*.png",
  ...handleMultipleImageFormats(
    "./node_modules/@openfoodfacts/openfoodfacts-webcomponents/dist/assets/**/*"
  ),
];

// nginx needs both uncompressed and compressed files as we use try_files with gzip_static always & gunzip

export function icons() {
  const processed = src("*.svg", { cwd: "./icons" }).
    pipe(
      svgmin({
        // @ts-ignore
        configFile: "icons/svgo.config.js",
      })
    ).
    pipe(dest("./html/images/icons/dist"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/images/icons/dist"));

  return processed && compressed;
}

export function attributesIcons() {
  const processed = src("*.svg", { cwd: "./html/images/attributes/src" }).
    pipe(svgmin()).
    pipe(dest("./html/images/attributes/dist"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/images/attributes/dist"));

  return processed && compressed;
}

export function css() {
  console.log("(re)building css");

  const processed = src(sassSrc).
    pipe(init()).
    pipe(
      sass({
        errLogToConsole: true,
        outputStyle: "expanded",
        includePaths: ["./node_modules/foundation-sites/scss"],
      }).on("error", sass.logError)
    ).
    pipe(minifyCSS()).
    pipe(write(".")).
    pipe(dest("./html/css/dist"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/css/dist"));
  
  return processed && compressed;
}

export function copyJs() {
  const processed = src([
    "./node_modules/@webcomponents/**/webcomponentsjs/**/*.js",
    "./node_modules/@openfoodfacts/openfoodfacts-webcomponents/dist/**/*.js",
    "./node_modules/foundation-sites/js/vendor/*.js",
    "./node_modules/foundation-sites/js/foundation.js",
    "./node_modules/papaparse/papaparse.js",
    "./node_modules/osmtogeojson/osmtogeojson.js",
    "./node_modules/leaflet/dist/leaflet.js",
    "./node_modules/leaflet.markercluster/dist/leaflet.markercluster.js",
    "./node_modules/blueimp-tmpl/js/tmpl.js",
    "./node_modules/blueimp-load-image/js/load-image.all.min.js",
    "./node_modules/blueimp-canvas-to-blob/js/canvas-to-blob.js",
    "./node_modules/blueimp-file-upload/js/*.js",
    "./node_modules/@yaireo/tagify/dist/tagify.js",
    "./node_modules/cropperjs/dist/cropper.js",
    "./node_modules/jquery-cropper/dist/jquery-cropper.js",
    "./node_modules/jquery-form/src/jquery.form.js",
    "./node_modules/highcharts/highcharts.js",
    "./node_modules/jsvectormap/dist/jsvectormap.js",
    "./node_modules/jsvectormap/dist/maps/world-merc.js",
    "./node_modules/select2/dist/js/select2.min.js",
    "./node_modules/jsbarcode/dist/JsBarcode.all.min.js",
  ]).
    pipe(init()).
    pipe(terser()).
    pipe(write(".")).
    pipe(dest("./html/js/dist"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/js/dist"));

  return processed && compressed;
}

export function buildJs() {
  console.log("(re)building js");

  const processed = src(jsSrc).
    pipe(init()).
    pipe(terser()).
    pipe(write(".")).
    pipe(dest("./html/js/dist"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/js/dist"));

  return processed && compressed;
}

function buildjQueryUi() {
  const processed = src([
    "./node_modules/jquery-ui/ui/jquery-patch.js",
    "./node_modules/jquery-ui/ui/version.js",
    "./node_modules/jquery-ui/ui/widget.js",
    "./node_modules/jquery-ui/ui/position.js",
    "./node_modules/jquery-ui/ui/keycode.js",
    "./node_modules/jquery-ui/ui/unique-id.js",
    "./node_modules/jquery-ui/ui/safe-active-element.js",
    "./node_modules/jquery-ui/ui/widgets/autocomplete.js",
    "./node_modules/jquery-ui/ui/widgets/menu.js",
  ]).
    pipe(init()).
    pipe(terser()).
    pipe(concat("jquery-ui.js")).
    pipe(write(".")).
    pipe(dest("./html/js/dist"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/js/dist"));

  return processed && compressed;
}

function jQueryUiThemes() {
  const processed = src([
    "./node_modules/jquery-ui/themes/base/core.css",
    "./node_modules/jquery-ui/themes/base/autocomplete.css",
    "./node_modules/jquery-ui/themes/base/menu.css",
    "./node_modules/jquery-ui/themes/base/theme.css",
  ]).
    pipe(init()).
    pipe(minifyCSS()).
    pipe(concat("jquery-ui.css")).
    pipe(write(".")).
    pipe(dest("./html/css/dist/jqueryui/themes/base"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/css/dist/jqueryui/themes/base"));
  
  return processed && compressed;
}

function copyCss() {
  const processed = src([
    "./node_modules/leaflet/dist/leaflet.css",
    "./node_modules/leaflet.markercluster/dist/MarkerCluster.css",
    "./node_modules/leaflet.markercluster/dist/MarkerCluster.Default.css",
    "./node_modules/@yaireo/tagify/dist/tagify.css",
    "./node_modules/cropperjs/dist/cropper.css",
    "./node_modules/select2/dist/css/select2.min.css",
  ]).
    pipe(init()).
    pipe(minifyCSS()).
    pipe(write(".")).
    pipe(dest("./html/css/dist"));

  const compressed = processed.
    pipe(gzip()).
    pipe(dest("./html/css/dist"));

  return processed && compressed;
}

function copyImages() {
  return src(imagesSrc).pipe(dest("./html/css/dist"));
}

export default function buildAll() {
  return new Promise(
    parallel(
      copyJs,
      buildJs,
      buildjQueryUi,
      copyCss,
      copyImages,
      jQueryUiThemes,
      series(icons, attributesIcons, css)
    )
  );
}

function watchAll() {
  watch(jsSrc, { delay: 500 }, buildJs);
  watch(sassSrc, { delay: 500 }, css);
  watch(imagesSrc, { delay: 500 }, copyImages);
  // do we want to watch everything to support checkout of a branch with new libs ?
}
export { watchAll as watch };

export function dynamic() {
  buildAll().then(() => {
    console.log("Build succeeded start watching for css and js changes");
    watchAll();
  });
}
