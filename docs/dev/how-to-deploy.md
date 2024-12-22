# How to deploy to Prod environment

Note: prod deployment is very manual and not automated yet.

- Login to the off1 server, as the "off" user
- cd /home/off/openfoodfacts-server
- Check that you are on the main branch
- git pull
- Copy changed files (don't copy everything, in particular not the lang directory that is being moved to the openfoodfacts-web repository)
- e.g. cp cgi scripts lib po taxonomies templates /srv/off/
- cd /srv/off
- export NPM_CONFIG_PREFIX=~/.npm-global
- npm install
- npm run build
- cd /srv/off/cgi
- export PERL5LIB=.
- ./build_lang.pl
- as the root user:
- systemctl stop apache2@off
- systemctl start apache2@off
- systemctl stop minion-off
- systemctl start minion-off
