'use strict'

const { src, dest, series } = require('gulp')
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
  includePaths: ['./html/bower_components/foundation/scss']
}

function icons() {
  return src('**/*.svg', { cwd: './icons'  })
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

exports.css = css
exports.icons = icons
exports.default = series(icons, css)
