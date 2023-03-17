/html/images/attributes/src contains the source SVG images.

/html/images/attributes/src contains optimized SVG images + PNG images rendered at 192px height

Optimized SVGs are generated through gulp (npm run build)

PNG images are generated with Inkscape version 1:

inkscape -z -h 192 --export-type="png" *.svg 

(also saved in convert_svg_files_to_png.sh)
