#!/bin/sh

cd /srv/opf/scripts
./get_blog_updates.pl --lang fr --rss "https://fr.blog.openfoodfacts.org/index.xml"
./get_blog_updates.pl --lang en --rss "https://en.blog.openfoodfacts.org/index.xml"
./get_blog_updates.pl --lang de --rss "https://en.blog.openfoodfacts.org/german.xml"
./get_blog_updates.pl --lang es --rss "https://en.blog.openfoodfacts.org/spanish.xml"
./get_blog_updates.pl --lang he --rss "https://en.blog.openfoodfacts.org/hebrew.xml"
./get_blog_updates.pl --lang pt --rss "https://en.blog.openfoodfacts.org/portuguese.xml"
./gen_top_tags_per_country.pl
#./gen_categories_stats.pl
#./gen_users_list.pl

