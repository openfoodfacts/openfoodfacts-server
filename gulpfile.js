'use strict';

var gulp = require('gulp');
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
gulp.task('default', ['imagemin']);
