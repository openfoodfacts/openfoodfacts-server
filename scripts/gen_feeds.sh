#!/bin/sh

cd /home/off-fr/cgi
./get_blog_updates.pl --lang fr --rss "http://fr.blog.openfoodfacts.org/index.xml"
./get_blog_updates.pl --lang en --rss "http://en.blog.openfoodfacts.org/index.xml"
./get_blog_updates.pl --lang de --rss "http://en.blog.openfoodfacts.org/german.xml"
./get_blog_updates.pl --lang es --rss "http://en.blog.openfoodfacts.org/spanish.xml"
./get_blog_updates.pl --lang he --rss "http://en.blog.openfoodfacts.org/hebrew.xml"
./get_blog_updates.pl --lang pt --rss "http://en.blog.openfoodfacts.org/portuguese.xml"
./gen_top_tags_per_country.pl
#./gen_categories_stats.pl
./gen_users_list.pl

