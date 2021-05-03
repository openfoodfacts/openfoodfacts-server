wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
docker cp openfoodfacts-mongodbdump.tar.gz docker_mongodb_1:/data/db
docker exec -it docker_mongodb_1 bash
cd /data/db
tar -xzvf openfoodfacts-mongodbdump.tar.gz 
mongorestore
exit
