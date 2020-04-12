docker run --rm -it -v node_modules:/mnt/node_modules -v %~dp0../:/mnt -w /mnt node:12.16.1-alpine npm install
docker run --rm -it -v node_modules:/mnt/node_modules -v %~dp0../:/mnt -w /mnt node:12.16.1-alpine npm run build
