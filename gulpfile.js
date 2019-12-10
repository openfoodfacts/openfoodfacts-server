"use strict";

const { src, dest, series, parallel } = require("gulp");
const sass = require("gulp-sass");
const sourcemaps = require("gulp-sourcemaps");
const minifyCSS = require("gulp-csso");
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
      "./node_modules/jquery-ui-dist/jquery-ui.min.js",
      "./node_modules/papaparse/papaparse.min.js",
      "./node_modules/osmtogeojson/osmtogeojson.js",
      "./node_modules/leaflet/dist/**/*.*",
      "./node_modules/leaflet.markercluster/dist/**/*.*",
      "./node_modules/blueimp-tmpl/js/*.js",
      "./node_modules/blueimp-load-image/js/load-image.all.min.js",
      "./node_modules/blueimp-canvas-to-blob/js/*.js",
      "./node_modules/blueimp-file-upload/js/*.js",
      "./node_modules/@yaireo/tagify/dist/tagify.min.js"
    ],
    { sourcemaps: true }
  ).pipe(dest("./html/js/dist", { sourcemaps: true }));
}

function jQueryUiThemes() {
  return src("./node_modules/jquery-ui-dist/**/*.css", {
    sourcemaps: true
  }).pipe(dest("./html/css/dist/jqueryui/themes/base", { sourcemaps: true }));
}

function copyCss() {
  return src(["./node_modules/@yaireo/tagify/dist/tagify.css"]).pipe(
    dest("./html/css/dist")
  );

}

exports.copyJs = copyJs;
exports.css = css;
exports.icons = icons;
exports.default = parallel(copyJs, copyCss, jQueryUiThemes, series(icons, css));
