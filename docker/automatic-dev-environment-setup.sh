#if mac:
# check if git is installed on mac
echo "Checking git is installed…"
git --version
echo "Cloning Open Food Facts web server - product-opener…"
git clone https://github.com/openfoodfacts/openfoodfacts-server.git
echo "Installing Docker… you may have to open it manually to grant permissions"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew cask install docker
# opening docker for the first time in GUI mode to grant it priviledges
open docker
cd ./openfoodfacts-server/docker/
echo "Building visual assets…"
./build_npm.sh
echo "Building Product Opener…"
echo "Your ventilator is probably going to start"
./build_dev.sh
echo "TODO: describe me…"
echo "This phase is going to be very long, up to an hour. Look for the increasing number snapshot min"
./start_dev.sh
echo "Populating database…"
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec backend bash /opt/scripts/import_sample_data.sh
echo "You should be able to access your local install of Open Food Facts at http://0.0.0.0…"
echo "You have around 200 test products. Please run ./install-full-database.sh if you want a full dump."
