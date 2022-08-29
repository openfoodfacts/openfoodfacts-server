/*global exports */

const { src, dest, series, parallel, watch } = require("gulp");
const concat = require("gulp-concat");
const sass = require("gulp-sass")(require("sass"));
const sourcemaps = require("gulp-sourcemaps");
const minifyCSS = require("gulp-csso");
const terser = require("gulp-terser-js");
const svgmin = require("gulp-svgmin");

const jsSrc = [
  './html/js/display*.js',
  './html/js/product-multilingual.js',
  './html/js/search.js'
];

const sassSrc = "./scss/**/*.scss";

const imagesSrc = ["./node_modules/leaflet/dist/**/*.png"];

const sassOptions = {
  errLogToConsole: true,
  outputStyle: "expanded",
  includePaths: ["./node_modules/foundation-sites/scss"]
};

function icons() {
  return src("*.svg", { cwd: "./icons" }).
    pipe(
      svgmin({
        configFile: 'icons/svgo.config.js'
      })
    ).
    pipe(dest("./html/images/icons/dist"));
}

function attributesIcons() {
  return src("*.svg", { cwd: "./html/images/attributes/src" }).
    pipe(
      svgmin()
    ).
    pipe(dest("./html/images/attributes"));
}

function css() {
  console.log("(re)building css");
  
return src(sassSrc).
    pipe(sourcemaps.init()).
    pipe(sass(sassOptions).on("error", sass.logError)).
    pipe(minifyCSS()).
    pipe(sourcemaps.write(".")).
    pipe(dest("./html/css/dist"));
}

function copyJs() {
  return src(
    [
      "./node_modules/@webcomponents/**/webcomponentsjs/**/*.js",
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
      "./node_modules/@yaireo/tagify/dist/tagify.min.js",
      "./node_modules/cropperjs/dist/cropper.js",
      "./node_modules/jquery-cropper/dist/jquery-cropper.js",
      "./node_modules/jquery-form/src/jquery.form.js",
      "./node_modules/highcharts/highcharts.js",
      "./node_modules/jvectormap-next/jquery-jvectormap.js",
      "./node_modules/jvectormap-content/world-mill.js",
      "./node_modules/select2/dist/js/select2.min.js"
    ]).
    pipe(sourcemaps.init()).
    pipe(terser()).
    pipe(sourcemaps.write(".")).
    pipe(dest("./html/js/dist"));
}

function buildJs() {
  console.log("(re)building js");
  
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

function jQueryUiThemes() {
  return src([
      './node_modules/jquery-ui/themes/base/core.css',
      './node_modules/jquery-ui/themes/base/autocomplete.css',
      './node_modules/jquery-ui/themes/base/menu.css',
      './node_modules/jquery-ui/themes/base/theme.css',
    ]).
    pipe(sourcemaps.init()).
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
      "./node_modules/cropperjs/dist/cropper.css",
      "./node_modules/jvectormap-next/jquery-jvectormap.css",
      "./node_modules/select2/dist/css/select2.min.css"
    ]).
    pipe(sourcemaps.init()).
    pipe(minifyCSS()).
    pipe(sourcemaps.write(".")).
    pipe(dest("./html/css/dist"));
}

function copyImages() {
  return src(imagesSrc).
    pipe(dest("./html/css/dist"));
}

function buildAll() {
  return new Promise(
    parallel(
      copyJs, buildJs, buildjQueryUi, copyCss, copyImages, jQueryUiThemes,
      series(icons, attributesIcons, css)
    )
  );
}

function watchAll () {
  watch(jsSrc, { delay: 500 }, buildJs);
  watch(sassSrc, { delay: 500 }, css);
  watch(imagesSrc, { delay: 500 }, copyImages);
  // do we want to watch everything to support checkout of a branch with new libs ?
}

exports.copyJs = copyJs;
exports.buildJs = buildJs;
exports.css = css;
exports.icons = icons;
exports.attributesIcons = attributesIcons;
exports.default = buildAll;
exports.watch = watchAll;
exports.dynamic = function () {
  buildAll().then(() => {
    console.log("Build succeeded start watching for css and js changes");
    watchAll();
  });
};
