import { dest, parallel, series, src, watch } from "gulp";
import { init, write } from "gulp-sourcemaps";

import concat from "gulp-concat";
import gulpSass from "gulp-sass";
import minifyCSS from "gulp-csso";
import sassLib from "sass";
import svgmin from "gulp-svgmin";
import terser from "gulp-terser";

const sass = gulpSass(sassLib);

const jsSrc = [
  "./html/js/display*.js",
  "./html/js/product-multilingual.js",
  "./html/js/search.js",
  "./html/js/hc-sticky.js",
  "./html/js/stikelem.js",
  "./html/js/scrollNav.js",
];

const sassSrc = "./scss/**/*.scss";

const imagesSrc = ["./node_modules/leaflet/dist/**/*.png"];

export function icons() {
  return src("*.svg", { cwd: "./icons" }).
    pipe(
      svgmin({
        // @ts-ignore
        configFile: "icons/svgo.config.js",
      })
    ).
    pipe(dest("./html/images/icons/dist"));
}

export function attributesIcons() {
  return src("*.svg", { cwd: "./html/images/attributes/src" }).
    pipe(svgmin()).
    pipe(dest("./html/images/attributes"));
}

export function css() {
  console.log("(re)building css");

  return src(sassSrc).
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
}

export function copyJs() {
  return src([
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
    "./node_modules/jsvectormap/dist/js/jsvectormap.js",
    "./node_modules/jsvectormap/dist/maps/world-merc.js",
    "./node_modules/select2/dist/js/select2.min.js",
  ]).
    pipe(init()).
    pipe(terser()).
    pipe(write(".")).
    pipe(dest("./html/js/dist"));
}

export function buildJs() {
  console.log("(re)building js");

  return src(jsSrc).
    pipe(init()).
    pipe(terser()).
    pipe(write(".")).
    pipe(dest("./html/js/dist"));
}

function buildjQueryUi() {
  return src([
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
}

function jQueryUiThemes() {
  return src([
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
}

function copyCss() {
  return src([
    "./node_modules/leaflet/dist/leaflet.css",
    "./node_modules/leaflet.markercluster/dist/MarkerCluster.css",
    "./node_modules/leaflet.markercluster/dist/MarkerCluster.Default.css",
    "./node_modules/@yaireo/tagify/dist/tagify.css",
    "./node_modules/cropperjs/dist/cropper.css",
    "./node_modules/jsvectormap/dist/css/jsvectormap.css",
    "./node_modules/select2/dist/css/select2.min.css",
  ]).
    pipe(init()).
    pipe(minifyCSS()).
    pipe(write(".")).
    pipe(dest("./html/css/dist"));
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
