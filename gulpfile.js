'use strict'

const { src, dest, series, parallel } = require('gulp')
const sass = require('gulp-sass')
const sourcemaps = require('gulp-sourcemaps')
const minifyCSS = require('gulp-csso')
const iconfont = require('gulp-iconfont')
const iconfontCss = require('gulp-iconfont-css')
const runTimestamp = Math.round(Date.now()/1000)

const fontName = 'Icons';
const sassOptions = {
  errLogToConsole: true,
  outputStyle: 'expanded',
  includePaths: ['./node_modules/foundation-sites/scss']
}

function icons() {
  return src('*.svg', { cwd: './icons'  })
  .pipe(iconfontCss({
    fontName: fontName,
    path: './scss/templates/_icons.scss',
    targetPath: '_icons.scss',
    fontPath: '/fonts/icons/'
  }))
  .pipe(iconfont({
    prependUnicode: false,
    fontName: fontName,
    formats: ['ttf', 'eot', 'woff', 'woff2'],
    normalize: true,
    timestamp: runTimestamp
  }))
  .pipe(dest('./html/fonts/icons'))
}

function css() {
  return src('./scss/**/*.scss')
    .pipe(sourcemaps.init())
    .pipe(sass(sassOptions).on('error', sass.logError))
    .pipe(minifyCSS())
    .pipe(sourcemaps.write('.'))
    .pipe(dest('./html/css/dist'))
}

function js() {
  return src([
      './node_modules/foundation-sites/js/vendor/*.js',
      './node_modules/foundation-sites/js/foundation.min.js',
      './node_modules/jqueryui/jquery-ui.min.js',
      './node_modules/papaparse/papaparse.min.js',
      './node_modules/osmtogeojson/osmtogeojson.js',
      './node_modules/leaflet/dist/**/*.*',
      './node_modules/leaflet.markercluster/dist/**/*.*'
    ], { sourcemaps: true })
    .pipe(dest('./html/js/dist', { sourcemaps: true }))
}

function jQueryUiThemes() {
  return src('./node_modules/jqueryui/themes/base/**/*.css', { sourcemaps: true })
    .pipe(dest('./html/css/dist/jqueryui/themes/base', { sourcemaps: true }))
}

exports.js = js
exports.css = css
exports.icons = icons
exports.default = parallel(js, jQueryUiThemes, series(icons, css))
