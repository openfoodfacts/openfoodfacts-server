#if mac:
# check if git is installed on mac
git --version
git clone https://github.com/openfoodfacts/openfoodfacts-server.git
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew cask install docker
# opening docker for the first time in GUI mode to grant it priviledges
open docker
cd ./openfoodfacts-server/docker/
./build_npm.sh
./build_dev.sh
./start_dev.sh
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec backend bash /opt/scripts/import_sample_data.sh
  
