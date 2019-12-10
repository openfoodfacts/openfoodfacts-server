"use strict";

const { src, dest, series, parallel } = require("gulp");
const concat = require("gulp-concat");
const sass = require("gulp-sass");
const sourcemaps = require("gulp-sourcemaps");
const minifyCSS = require("gulp-csso");
const uglify = require("gulp-uglify");
const svgmin = require("gulp-svgmin");

const sassOptions = {
  errLogToConsole: true,
  outputStyle: "expanded",
  includePaths: ["./node_modules/foundation-sites/scss"]
};

function icons() {
  return src("*.svg", { cwd: "./icons" })
    .pipe(
      svgmin({
      plugins: [
        { removeMetadata: false },
        { removeTitle: false },
        { removeDimensions: true },
          { addClassesToSVGElement: { className: "icon" } },
          {
            addAttributesToSVGElement: {
              attributes: [{ "aria-hidden": "true", focusable: "false" }]
            }
          }
      ]
      })
    )
    .pipe(dest("./html/images/icons/dist"));
}

function css() {
  return src("./scss/**/*.scss")
    .pipe(sourcemaps.init())
    .pipe(sass(sassOptions).on("error", sass.logError))
    .pipe(minifyCSS())
    .pipe(sourcemaps.write("."))
    .pipe(dest("./html/css/dist"));
}

function copyJs() {
  return src(
    [
      "./node_modules/foundation-sites/js/vendor/*.js",
      "./node_modules/foundation-sites/js/foundation.min.js",
      "./node_modules/papaparse/papaparse.min.js",
      "./node_modules/osmtogeojson/osmtogeojson.js",
      "./node_modules/leaflet/dist/**/*.*",
      "./node_modules/leaflet.markercluster/dist/**/*.*",
      "./node_modules/blueimp-tmpl/js/*.js",
      "./node_modules/blueimp-load-image/js/load-image.all.min.js",
      "./node_modules/blueimp-canvas-to-blob/js/*.js",
      "./node_modules/blueimp-file-upload/js/*.js",
      "./node_modules/@yaireo/tagify/dist/tagify.min.js"
    ])
    .pipe(sourcemaps.init())
    .pipe(sourcemaps.write("."))
    .pipe(dest("./html/js/dist"));
}

function buildJs() {
  return src([
    './html/js/display*.js',
    './html/js/product-multilingual.js',
    './html/js/search.js'
  ])
  .pipe(sourcemaps.init())
  .pipe(sourcemaps.write("."))
  .pipe(dest("./html/js/dist"));
}

function buildjQueryUi() {
  return src([
    './node_modules/jquery-ui/ui/widget.js',
    './node_modules/jquery-ui/ui/position.js',
    './node_modules/jquery-ui/ui/keycode.js',
    './node_modules/jquery-ui/ui/unique-id.js',
    './node_modules/jquery-ui/ui/widgets/autocomplete.js',
    './node_modules/jquery-ui/ui/widgets/menu.js'
  ])
  .pipe(sourcemaps.init())
  .pipe(uglify())
  .pipe(concat('jquery-ui.min.js'))
  .pipe(sourcemaps.write("."))
  .pipe(dest('./html/js/dist'))
}

function jQueryUiThemes() {
  return src([
      './node_modules/jquery-ui/themes/base/core.css',
      './node_modules/jquery-ui/themes/base/autocomplete.css',
      './node_modules/jquery-ui/themes/base/menu.css',
      './node_modules/jquery-ui/themes/base/theme.css',
    ])
    .pipe(sourcemaps.init())
    .pipe(minifyCSS())
    .pipe(concat('jquery-ui.min.css'))
    .pipe(sourcemaps.write("."))
    .pipe(dest('./html/css/dist/jqueryui/themes/base'));
}

function copyCss() {
  return src(["./node_modules/@yaireo/tagify/dist/tagify.css"]).pipe(
    dest("./html/css/dist")
  );

}

exports.copyJs = copyJs;
exports.buildJs = buildJs;
exports.css = css;
exports.icons = icons;
exports.default = parallel(copyJs, buildJs, buildjQueryUi, copyCss, jQueryUiThemes, series(icons, css));
