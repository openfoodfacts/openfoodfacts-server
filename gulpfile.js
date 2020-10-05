/*global exports */

const { src, dest, series, parallel, watch } = require("gulp");
const concat = require("gulp-concat");
const sass = require("gulp-sass");
const sourcemaps = require("gulp-sourcemaps");
const minifyCSS = require("gulp-csso");
const terser = require("gulp-terser-js");
const svgmin = require("gulp-svgmin");
const modernizr = require("gulp-modernizr");
const autoprefixer = require("gulp-autoprefixer");

const jsSrc = [
  './html/js/display*.js',
  './html/js/product-multilingual.js',
  './html/js/search.js'
];

const sassSrc = "./scss/**/*.scss";

const sassOptions = {
  errLogToConsole: true,
  outputStyle: "expanded",
  includePaths: ["./node_modules/foundation-sites/scss"]
};

function icons() {
  return src("*.svg", { cwd: "./icons" }).
    pipe(
      svgmin({
      plugins: [
        { removeMetadata: true },
        { removeTitle: true },
        { removeDimensions: true },
          { addClassesToSVGElement: { className: "icon" } },
          {
            addAttributesToSVGElement: {
              attributes: [{ "aria-hidden": "true", focusable: "false" }]
            }
          }
      ]
      })
    ).
    pipe(dest("./html/images/icons/dist"));
}

function css() {
  return src(sassSrc).
    pipe(sourcemaps.init()).
    pipe(sass(sassOptions).on("error", sass.logError)).
    pipe(autoprefixer()).
    pipe(minifyCSS()).
    pipe(sourcemaps.write(".")).
    pipe(dest("./html/css/dist"));
}

function copyJs() {
  return src(
    [
      "./node_modules/jquery/dist/jquery.js",
      "./node_modules/what-input/dist/what-input.js",
      "./node_modules/jquery.cookie/jquery.cookie.js",
      "./node_modules/foundation-sites/dist/js/foundation.js",
      "./node_modules/@webcomponents/**/webcomponentsjs/**/*.js",
      "./node_modules/papaparse/papaparse.js",
      "./node_modules/osmtogeojson/osmtogeojson.js",
      "./node_modules/leaflet/dist/leaflet.js",
      "./node_modules/leaflet.markercluster/dist/leaflet.markercluster.js",
      "./node_modules/blueimp-tmpl/js/tmpl.js",
      "./node_modules/blueimp-load-image/js/load-image.all.min.js",
      "./node_modules/blueimp-canvas-to-blob/js/canvas-to-blob.js",
      "./node_modules/blueimp-file-upload/js/*.js",
      "./node_modules/@yaireo/tagify/dist/tagify.min.js",
      "./node_modules/cropper/dist/cropper.js",
      "./node_modules/jquery-form/src/jquery.form.js",
      "./node_modules/highcharts/highcharts.js",
      "./node_modules/jvectormap-next/jquery-jvectormap.js",
      "./node_modules/jvectormap-content/world-mill.js"
    ]).
    pipe(sourcemaps.init()).
    pipe(terser()).
    pipe(sourcemaps.write(".")).
    pipe(dest("./html/js/dist"));
}

function buildJs() {
  return src(jsSrc).
  pipe(sourcemaps.init()).
  pipe(terser()).
  pipe(sourcemaps.write(".")).
  pipe(dest("./html/js/dist"));
}

function buildjQueryUi() {
  return src([
    './node_modules/jquery-ui/ui/version.js',
    './node_modules/jquery-ui/ui/widget.js',
    './node_modules/jquery-ui/ui/position.js',
    './node_modules/jquery-ui/ui/keycode.js',
    './node_modules/jquery-ui/ui/unique-id.js',
    './node_modules/jquery-ui/ui/safe-active-element.js',
    './node_modules/jquery-ui/ui/widgets/autocomplete.js',
    './node_modules/jquery-ui/ui/widgets/menu.js'
  ]).
  pipe(sourcemaps.init()).
  pipe(terser()).
  pipe(concat('jquery-ui.js')).
  pipe(sourcemaps.write(".")).
  pipe(dest('./html/js/dist'));
}

function modernizeJs() {
  return src('./html/js/dist/*.js').
  pipe(modernizr()).
  pipe(sourcemaps.init()).
  pipe(terser()).
  pipe(sourcemaps.write(".")).
  pipe(dest('./html/js/dist'));
}

function jQueryUiThemes() {
  return src([
      './node_modules/jquery-ui/themes/base/core.css',
      './node_modules/jquery-ui/themes/base/autocomplete.css',
      './node_modules/jquery-ui/themes/base/menu.css',
      './node_modules/jquery-ui/themes/base/theme.css',
    ]).
    pipe(sourcemaps.init()).
    pipe(autoprefixer()).
    pipe(minifyCSS()).
    pipe(concat('jquery-ui.css')).
    pipe(sourcemaps.write(".")).
    pipe(dest('./html/css/dist/jqueryui/themes/base'));
}

function copyCss() {
  return src([
      "./node_modules/leaflet/dist/leaflet.css",
      "./node_modules/leaflet.markercluster/dist/MarkerCluster.css",
      "./node_modules/leaflet.markercluster/dist/MarkerCluster.Default.css",
      "./node_modules/@yaireo/tagify/dist/tagify.css",
      "./html/css/product-multilingual.css",
      "./node_modules/cropper/dist/cropper.css",
      "./node_modules/jvectormap-next/jquery-jvectormap.css"
    ]).
    pipe(sourcemaps.init()).
    pipe(autoprefixer()).
    pipe(minifyCSS()).
    pipe(sourcemaps.write(".")).
    pipe(dest("./html/css/dist"));
}

function copyImages() {
  return src(["./node_modules/leaflet/dist/**/*.png"]).
    pipe(dest("./html/css/dist"));
}

exports.copyJs = copyJs;
exports.buildJs = buildJs;
exports.css = css;
exports.icons = icons;
exports.default = parallel(series(parallel(copyJs, buildJs, buildjQueryUi), modernizeJs), copyCss, copyImages, jQueryUiThemes, series(icons, css));
exports.watch = function () {
  watch(jsSrc, { delay: 500 }, series(buildJs, modernizeJs));
  watch(sassSrc, { delay: 500 }, css);
};
