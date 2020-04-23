#!/bin/sh

OUTPUT_FILE="all.html"

echo "" > ${OUTPUT_FILE}

echo "<!doctype html><html><head>" >> ${OUTPUT_FILE}
echo "<title>google-play-badge-svg</title>" >> ${OUTPUT_FILE}
echo "<!--[if lt IE 9]>" >> ${OUTPUT_FILE}
echo "<script src='//html5shiv.googlecode.com/svn/trunk/html5.js'></script>" >> ${OUTPUT_FILE}
echo "<![endif]-->" >> ${OUTPUT_FILE}
echo "</head><body>" >> ${OUTPUT_FILE}

for f in ./img/*.svg
	do
		echo "<img src='img/${f##*/}' />" >> ${OUTPUT_FILE}
done

echo "<script src='javascripts/scale.fix.js'></script></body></html>" >> ${OUTPUT_FILE}
