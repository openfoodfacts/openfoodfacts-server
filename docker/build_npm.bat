docker run --rm -it -v node_modules:/mnt/node_modules -v %~dp0../:/mnt -w /mnt node:lts npm install
docker run --rm -it -v node_modules:/mnt/node_modules -v %~dp0../:/mnt -w /mnt node:lts npm run build
