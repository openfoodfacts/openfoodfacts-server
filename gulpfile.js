'use strict';

var gulp = require('gulp');
var sass = require('gulp-sass');
var sourcemaps = require('gulp-sourcemaps');
var cleanCSS = require('gulp-clean-css');

var input = './scss/**/*.scss';
var output = './html/css/dist';
var sassOptions = {
  errLogToConsole: true,
  outputStyle: 'expanded',
  includePaths: ['./html/bower_components/foundation/scss']
};

gulp.task('default', function() {
  return gulp
    .src(input)
    .pipe(sourcemaps.init())
    .pipe(sass(sassOptions).on('error', sass.logError))
    .pipe(cleanCSS())
    .pipe(sourcemaps.write('.'))
    .pipe(gulp.dest(output));
});
