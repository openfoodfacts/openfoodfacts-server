docker run --rm -it -v node_modules:/mnt/node_modules -v ../:/mnt -w /mnt node:12.9.0-alpine yarn install
docker run --rm -it -v node_modules:/mnt/node_modules -v ../:/mnt -w /mnt node:12.9.0-alpine yarn run build
