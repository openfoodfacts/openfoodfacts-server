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

gulp.task('sass', function() {
  return gulp
    .src(input)
    .pipe(sourcemaps.init())
    .pipe(sass(sassOptions).on('error', sass.logError))
    .pipe(cleanCSS())
    .pipe(sourcemaps.write('.'))
    .pipe(gulp.dest(output));
});

var imagemin = require('gulp-imagemin');
var imageminSvgo = require('imagemin-svgo');

gulp.task('imagemin-svg', function() {
  return gulp.src('html/images_src/**/*.svg')
        .pipe(imagemin([imageminSvgo()]))
        .pipe(gulp.dest('html/images'))
});

gulp.task('imagemin-default', function() {
  return gulp.src('html/images_src/**/*.{gif,png,jpg,jpeg}')
        .pipe(imagemin())
        .pipe(gulp.dest('html/images'))
});

gulp.task('imagemin', ['imagemin-svg','imagemin-default']);

gulp.task('default', ['sass', 'imagemin']);
