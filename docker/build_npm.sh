docker run --rm -it -v node_modules:/mnt/node_modules -v ../:/mnt -w /mnt node:12.13.0-alpine npm install
docker run --rm -it -v node_modules:/mnt/node_modules -v ../:/mnt -w /mnt node:12.13.0-alpine npm run build
