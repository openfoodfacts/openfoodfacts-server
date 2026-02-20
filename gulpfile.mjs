/* eslint-disable dot-location */
/* eslint-disable sort-imports */

import gulp from "gulp";
import sourcemaps from "gulp-sourcemaps";
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
  "./html/js/tagify-init.js",
  "./html/js/search.js",
  "./html/js/hc-sticky.js",
  "./html/js/stikelem.js",
  "./html/js/scrollNav.js",
  "./html/js/barcode-scanner*.js",
  "./html/js/rewind-browser.js",
  "./html/js/external-knowledge-panels.js",
];

const sassSrc = "./scss/**/*.scss";

const jsLibSrc = [
  "./node_modules/@webcomponents/**/webcomponentsjs/**/*.js",
  "./node_modules/@openfoodfacts/openfoodfacts-webcomponents/dist/**/*.js",
  "./node_modules/foundation-sites/js/vendor/*.js",
  "./node_modules/foundation-sites/js/foundation.js",
  "./node_modules/papaparse/papaparse.js",
  "./node_modules/leaflet/dist/leaflet-src.js",
  "./node_modules/@kristjan.esperanto/leaflet.markercluster/dist/leaflet.markercluster.js",
  "./node_modules/blueimp-tmpl/js/tmpl.js",
  "./node_modules/blueimp-load-image/js/load-image.all.min.js",
  "./node_modules/blueimp-canvas-to-blob/js/canvas-to-blob.js",
  "./node_modules/blueimp-file-upload/js/*.js",
  "./node_modules/@yaireo/tagify/dist/tagify.js",
  "./node_modules/cropperjs/dist/cropper.js",
  "./node_modules/jquery-cropper/dist/jquery-cropper.js",
  "./node_modules/highcharts/highcharts.js",
  "./node_modules/jsvectormap/dist/jsvectormap.esm.js",
  "./node_modules/jsvectormap/dist/maps/world-merc.js",
  "./node_modules/select2/dist/js/select2.min.js",
  "./node_modules/jsbarcode/dist/JsBarcode.all.min.js",
  "./node_modules/jquery/dist/jquery.js",
];

function handleMultipleImageFormats(path) {
  return [".png", ".jpg", ".jpeg", ".webp", ".svg"].map((ext) => path + ext);
}

const imagesSrc = [
  "./node_modules/leaflet/dist/**/*.png",
  ...handleMultipleImageFormats(
    "./node_modules/@openfoodfacts/openfoodfacts-webcomponents/dist/assets/**/*",
  ),
];

// nginx needs both uncompressed and compressed files as we use try_files with gzip_static always & gunzip

export function icons() {
  const processed = gulp
    .src("*.svg", { cwd: "./icons" })
    .pipe(
      svgmin({
        // @ts-ignore
        configFile: "icons/svgo.config.js",
      }),
    )
    .pipe(gulp.dest("./html/images/icons/dist"));

  const compressed = processed
    .pipe(gzip())
    .pipe(gulp.dest("./html/images/icons/dist"));

  return processed && compressed;
}

export function attributesIcons() {
  const processed = gulp
    .src("*.svg", { cwd: "./html/images/attributes/src" })
    .pipe(svgmin())
    .pipe(gulp.dest("./html/images/attributes/dist"));

  const compressed = processed
    .pipe(gzip())
    .pipe(gulp.dest("./html/images/attributes/dist"));

  return processed && compressed;
}

export function css() {
  console.log("(re)building css");

  const processed = gulp
    .src(sassSrc)
    .pipe(sourcemaps.init())
    .pipe(
      sass({
        errLogToConsole: true,
        outputStyle: "expanded",
        includePaths: ["./node_modules"],
      }).on("error", sass.logError),
    )
    .pipe(minifyCSS())
    .pipe(sourcemaps.write("."))
    .pipe(gulp.dest("./html/css/dist"));

  const compressed = processed.pipe(gzip()).pipe(gulp.dest("./html/css/dist"));

  return processed && compressed;
}

export function copyJs() {
  const processed = gulp
    .src(jsLibSrc, {
      // prefer jquery from package.json to foundation-vendored copy
      ignore: "./node_modules/foundation-sites/js/vendor/jquery.js",
    })
    .pipe(sourcemaps.init())
    .pipe(terser())
    .pipe(sourcemaps.write("."))
    .pipe(gulp.dest("./html/js/dist"));

  const compressed = processed.pipe(gzip()).pipe(gulp.dest("./html/js/dist"));

  return processed && compressed;
}

export function buildJs() {
  console.log("(re)building js");

  const processed = gulp
    .src(jsSrc)
    .pipe(sourcemaps.init())
    .pipe(terser())
    .pipe(sourcemaps.write("."))
    .pipe(gulp.dest("./html/js/dist"));

  const compressed = processed.pipe(gzip()).pipe(gulp.dest("./html/js/dist"));

  return processed && compressed;
}

function buildjQueryUi() {
  const processed = gulp
    .src([
      "./node_modules/jquery-ui/ui/jquery-patch.js",
      "./node_modules/jquery-ui/ui/version.js",
      "./node_modules/jquery-ui/ui/widget.js",
      "./node_modules/jquery-ui/ui/position.js",
      "./node_modules/jquery-ui/ui/keycode.js",
      "./node_modules/jquery-ui/ui/unique-id.js",
      "./node_modules/jquery-ui/ui/widgets/autocomplete.js",
      "./node_modules/jquery-ui/ui/widgets/menu.js",
    ])
    .pipe(sourcemaps.init())
    .pipe(terser())
    .pipe(concat("jquery-ui.js"))
    .pipe(sourcemaps.write("."))
    .pipe(gulp.dest("./html/js/dist"));

  const compressed = processed.pipe(gzip()).pipe(gulp.dest("./html/js/dist"));

  return processed && compressed;
}

function jQueryUiThemes() {
  const processed = gulp
    .src([
      "./node_modules/jquery-ui/themes/base/core.css",
      "./node_modules/jquery-ui/themes/base/autocomplete.css",
      "./node_modules/jquery-ui/themes/base/menu.css",
      "./node_modules/jquery-ui/themes/base/theme.css",
    ])
    .pipe(sourcemaps.init())
    .pipe(minifyCSS())
    .pipe(concat("jquery-ui.css"))
    .pipe(sourcemaps.write("."))
    .pipe(gulp.dest("./html/css/dist/jqueryui/themes/base"));

  const compressed = processed
    .pipe(gzip())
    .pipe(gulp.dest("./html/css/dist/jqueryui/themes/base"));

  return processed && compressed;
}

function copyCss() {
  const processed = gulp
    .src([
      "./node_modules/leaflet/dist/leaflet.css",
      "./node_modules/@kristjan.esperanto/leaflet.markercluster/dist/MarkerCluster.css",
      "./node_modules/@kristjan.esperanto/leaflet.markercluster/dist/MarkerCluster.Default.css",
      "./node_modules/cropperjs/dist/cropper.css",
      "./node_modules/select2/dist/css/select2.min.css",
    ])
    .pipe(sourcemaps.init())
    .pipe(minifyCSS())
    .pipe(sourcemaps.write("."))
    .pipe(gulp.dest("./html/css/dist"));

  const compressed = processed.pipe(gzip()).pipe(gulp.dest("./html/css/dist"));

  return processed && compressed;
}

function copyImages() {
  return gulp.src(imagesSrc).pipe(gulp.dest("./html/css/dist"));
}

// Shared task list for build steps
const buildTasks = [
  copyJs,
  buildJs,
  buildjQueryUi,
  copyCss,
  copyImages,
  jQueryUiThemes,
  gulp.series(icons, attributesIcons, css),
];

export default gulp.parallel(...buildTasks);

function watchAll() {
  gulp.watch(jsSrc, { delay: 500 }, buildJs);
  gulp.watch(sassSrc, { delay: 500 }, css);
  gulp.watch(imagesSrc, { delay: 500 }, copyImages);
  gulp.watch(jsLibSrc, { delay: 500 }, copyJs);
  // do we want to watch everything to support checkout of a branch with new libs ?
}
export { watchAll as watch };

export const dynamic = gulp.series(
  gulp.parallel(...buildTasks),
  function startWatch(done) {
    console.log("Build succeeded start watching for css and js changes");
    watchAll();
    done();
  },
);
