docker run --rm -it -v node_modules:/mnt/node_modules -v %~dp0../:/mnt -w /mnt node:12.13.0-alpine npm install
docker run --rm -it -v node_modules:/mnt/node_modules -v %~dp0../:/mnt -w /mnt node:12.13.0-alpine npm run build
