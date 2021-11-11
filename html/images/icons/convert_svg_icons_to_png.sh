#!/bin/sh

# Some platforms (e.g. current version of iOS and Android) have issues
# displaying SVG images.

# This script converts the SVG icons to PNG.
# It needs Inkscape version 1 to be installed.

# Almost all the icons have been designed based on 24x24 grid, so they are
# best rendered and displayed at a multiple.
# A few icons have a different width, so just specify the height.

inkscape -z -h 192 --export-type="png" *.svg

