echo "🥫 Downloading the full MongoDB dump…"
wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
echo "🥫 Copying the dump to Docker…"
docker cp openfoodfacts-mongodbdump.tar.gz docker_mongodb_1:/data/db
echo "🥫 Opening a shell within the Mongo docker…"
docker exec -it docker_mongodb_1 bash
echo "🥫 Unzipping the Mongo Dump…"
cd /data/db
tar -xzvf openfoodfacts-mongodbdump.tar.gz
echo "🥫 Restoring the Mongo Dump…"
mongorestore
exit
echo "🥫 You now have the full database in your instance. If this is too slow, restart from scratch, and you'll have a 200 products sample database. Ensure to update this dump regularly if needed. Open Food Facts is under OdBL. You should attribute the source, and send back any additions or modifications using the Live product WRITE API"
