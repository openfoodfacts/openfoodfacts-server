#!/bin/sh

# Render SVG icons to PNG at 192 pixels height.
# Needs Inkscape version 1 to be installed

inkscape -z -h 192 --export-type="png" *.svg

