#!/usr/bin/env bash
# This script verifies that every important symlink is present on a deployment
#
# short name of service must be provided as argument

if [[ $(id --user) != 0 ]]
then
  >&2 echo "ERROR: This script must be run as root"
fi

while [[ $# -gt 0 ]]
do
  case $1 in
        "--verbose" | "-v")
          VERBOSE=1
          shift;;
        *)
          if [[ -n "$SERVICE" ]]
          then
            echo >&2 "ERROR: only one service can be verified at a time (for now):"
            exit 11
          fi
          SERVICE=$1
          shift;;
  esac
done

KNOWN_SERVICES=(obf off opf opff)

declare -A LONG_NAMES
LONG_NAMES[obf]=openbeautyfacts
LONG_NAMES[off]=openfoodfacts
LONG_NAMES[opf]=openproductsfoodfacts
LONG_NAMES[opff]=openpetfoodfacts

# EXPECTED_LINKS[destination]=target
# in the sens of `ln -s target destination``
declare -A EXPECTED_LINKS

declare -a SYSTEMD_LINKS
declare -a SYSTEMD_UNITS_ENABLED
declare -a SYSTEMD_UNITS_ACTIVE

function is_pro {
  # return -pro if it end by -pro
  echo $(expr match "$1" '.*\(-pro\)')
}

function non_pro_name {
  # off-pro --> off, off --> off
  echo $1 | sed 's/-pro$//'
}

function check_args {
  if [[ -z "$SERVICE" ]]
  then
    >&2 echo "ERROR: Please provide a service name as argument"
    exit -1
  fi
  REPO_PATH="/srv/$SERVICE"
  # check service is deployed as expected
  if [[ ! -d $REPO_PATH/.git ]]
  then
    >&2 echo "ERROR: $REPO_PATH must be a git repository"
    exit -2
  fi
  ZFS_PATH="/mnt/$SERVICE"
  IS_PRO=$(is_pro "$SERVICE")
  NON_PRO_SERVICE=$(non_pro_name "$SERVICE")
  PRO_SERVICE=$NON_PRO_SERVICE"-pro"
  SERVICE_LONG_NAME=${LONG_NAMES[$NON_PRO_SERVICE]}
  # check service name
  if ! ( echo "${KNOWN_SERVICES[@]}" | grep -w -q "$NON_PRO_SERVICE" )
  then
    >&2 echo "unknown service: $SERVICE"
    exit -1
  fi
}

function compute_services {
  # systemd services to check for symlinks
  SYSTEMD_LINKS+=( email-failures@.service nginx.service.d apache2.service.d cloud_vision_ocr@.service )
  # units that must be active (and enabled)
  SYSTEMD_UNITS_ACTIVE=( nginx.service apache2.service cloud_vision_ocr@$SERVICE.service )
  SYSTEMD_UNITS_ENABLED=( )
  if [[ -z $IS_PRO ]]
  then
    SYSTEMD_LINKS+=( gen_feeds{,_daily}@.{service,timer} )
    SYSTEMD_UNITS_ACTIVE+=( gen_feeds@$SERVICE.timer gen_feeds_daily@$SERVICE.timer )
    SYSTEMD_UNITS_ENABLED+=( gen_feeds@$SERVICE.service gen_feeds_daily@$SERVICE.service )
  else
    SYSTEMD_LINKS+=( producers_import@.{service,timer} )
    SYSTEMD_UNITS_ACTIVE+=( producers_import@$SERVICE.timer )
    SYSTEMD_UNITS_ENABLED+=( producers_import@$SERVICE.service )
  fi
}

function compute_expected_links {
  # links to check target - dest
  # nginx configuration
  EXPECTED_LINKS["/etc/nginx/sites-enabled/$SERVICE"]="$REPO_PATH/conf/nginx/sites-available/$SERVICE"
  EXPECTED_LINKS["$REPO_PATH/log.conf"]="$REPO_PATH/conf/$SERVICE-log.conf"
  EXPECTED_LINKS["$REPO_PATH/minion_log.conf"]="$REPO_PATH/conf/$SERVICE-minion_log.conf"
  # config
  EXPECTED_LINKS["$REPO_PATH/lib/ProductOpener/Config.pm"]="$REPO_PATH/lib/ProductOpener/Config_$NON_PRO_SERVICE.pm"
  EXPECTED_LINKS["$REPO_PATH/po/site-specific"]="$REPO_PATH/po/$SERVICE_LONG_NAME"
  # off-web
  EXPECTED_LINKS["$REPO_PATH/lang"]="/srv/openfoodfacts-web/lang"
  # data linked to zfs storages
  EXPECTED_LINKS["$REPO_PATH/data"]="$ZFS_PATH/data"
  EXPECTED_LINKS["$REPO_PATH/orgs"]="$ZFS_PATH/orgs"
  EXPECTED_LINKS["$REPO_PATH/users"]="$ZFS_PATH/users"
  EXPECTED_LINKS["$REPO_PATH/products"]="$ZFS_PATH/products"
  EXPECTED_LINKS["$REPO_PATH/html/images/products"]="$ZFS_PATH/images/products"
  # public data
  EXPECTED_LINKS["$REPO_PATH/html/data"]="$ZFS_PATH/html_data"
  EXPECTED_LINKS["$REPO_PATH/html/exports"]="$ZFS_PATH/html_data/exports"
  EXPECTED_LINKS["$REPO_PATH/html/dump"]="$ZFS_PATH/html_data/dump"
  EXPECTED_LINKS["$REPO_PATH/html/files"]="$ZFS_PATH/html_data/files"

  # .well-known
  if [[ -z $IS_PRO ]]
  then
    for path in apple-app-site-association apple-developer-merchantid-domain-association
    do
      EXPECTED_LINKS["$REPO_PATH/html/.well-known/$path"]="$REPO_PATH/conf/well-known/$SERVICE-$path"
    done
  fi
  # deeper link in zfs storages
  EXPECTED_LINKS["$REPO_PATH/deleted.images"]="$ZFS_PATH/deleted.images"
  EXPECTED_LINKS["$REPO_PATH/reverted_products"]="$ZFS_PATH/reverted_products"
  EXPECTED_LINKS["$REPO_PATH/translate"]="$ZFS_PATH/translate"

  if [[ -z $IS_PRO ]]
  then
    EXPECTED_LINKS["$REPO_PATH/deleted_products"]="$ZFS_PATH/deleted_products"
    EXPECTED_LINKS["$REPO_PATH/deleted_products_images"]="$ZFS_PATH/deleted_products_images"
    # producers imports
    EXPECTED_LINKS["$REPO_PATH/imports"]="$ZFS_PATH/imports"
  else
    EXPECTED_LINKS["$REPO_PATH/deleted_private_products"]="$ZFS_PATH/deleted_private_products"
  fi

  # caches
  EXPECTED_LINKS["$REPO_PATH/build-cache"]="$ZFS_PATH/cache/build-cache"
  EXPECTED_LINKS["$REPO_PATH/debug"]="$ZFS_PATH/cache/debug"
  EXPECTED_LINKS["$REPO_PATH/new_images"]="$ZFS_PATH/cache/new_images"
  EXPECTED_LINKS["$REPO_PATH/tmp"]="$ZFS_PATH/cache/tmp"
  EXPECTED_LINKS["$REPO_PATH/export_files"]="$ZFS_PATH/cache/export_files"

  # exchange path
  if [[ -z $IS_PRO ]]
  then
    EXPECTED_LINKS["/srv/$PRO_SERVICE/export_files"]="/mnt/$PRO_SERVICE/cache/export_files"
  fi

  # link in zfs storages to files in git
  EXPECTED_LINKS["$ZFS_PATH/html_data/data-fields.md"]="$REPO_PATH/html/data/data-fields.md"
  EXPECTED_LINKS["$ZFS_PATH/html_data/data-fields.txt"]="$REPO_PATH/html/data/data-fields.txt"

  # logs
  EXPECTED_LINKS["$REPO_PATH/logs"]="/var/log/$SERVICE"
  EXPECTED_LINKS["$REPO_PATH/logs/apache2"]="/var/log/apache2"
  EXPECTED_LINKS["$REPO_PATH/logs/nginx"]="/var/log/nginx"

  if [[ -z $IS_PRO ]]
  then
    # links to other projects to handle data migration between projects
    for OTHER_SERVICE in "${KNOWN_SERVICES[@]}"
    do
      if [[ $OTHER_SERVICE != "$SERVICE" ]] && [[ -z $(is_pro "$$OTHER_SERVICE") ]]
      then
        EXPECTED_LINKS["/srv/$OTHER_SERVICE/products"]="/mnt/$OTHER_SERVICE/products"
        EXPECTED_LINKS["/srv/$OTHER_SERVICE/html/images/products"]="/mnt/$OTHER_SERVICE/images/products"
      fi
    done
  fi

  # nginx links
  EXPECTED_LINKS["/etc/nginx/sites-enabled/$SERVICE"]="$REPO_PATH/conf/nginx/sites-available/$SERVICE"
  EXPECTED_LINKS["/etc/nginx/snippets/expires-no-json-xml.conf"]="$REPO_PATH/conf/nginx/snippets/expires-no-json-xml.conf"
  EXPECTED_LINKS["/etc/nginx/snippets/off.cors-headers.include"]="$REPO_PATH/conf/nginx/snippets/off.cors-headers.include"
  EXPECTED_LINKS["/etc/nginx/conf.d/log_format_realip.conf"]="$REPO_PATH/conf/nginx/conf.d/log_format_realip.conf"
  EXPECTED_LINKS["/etc/nginx/mime.types"]="$REPO_PATH/conf/nginx/mime.types"
  if [[ $SERVICE = "off" ]]
  then
    EXPECTED_LINKS["/etc/nginx/snippets/off.domain-redirects.include"]="$REPO_PATH/conf/nginx/snippets/off.domain-redirects.include"
    EXPECTED_LINKS["/etc/nginx/snippets/off.locations-redirects.include"]="$REPO_PATH/conf/nginx/snippets/off.locations-redirects.include"
  fi

  # apache2 links
  EXPECTED_LINKS["/etc/apache2/ports.conf"]="$REPO_PATH/conf/apache-2.4/$SERVICE-ports.conf"
  EXPECTED_LINKS["/etc/apache2/mods-available/mpm_prefork.conf"]="$REPO_PATH/conf/apache-2.4/$SERVICE-mpm_prefork.conf"
  EXPECTED_LINKS["/etc/apache2/sites-enabled/$SERVICE.conf"]="$REPO_PATH/conf/apache-2.4/sites-available/$SERVICE.conf"

  for systemd_unit in {apache2,nginx}.service.d ${SYSTEMD_LINKS[@]}
  do
    EXPECTED_LINKS["/etc/systemd/system/$systemd_unit"]="$REPO_PATH/conf/systemd/$systemd_unit"
  done

  # log rotate config
  EXPECTED_LINKS["/etc/logrotate.d/apache2"]="$REPO_PATH/conf/logrotate/apache2"

  # Note: other link on old versions:
  # /srv/$SERVICE/users_emails.sto -> /srv/$SERVICE/users/users_emails.sto
  # /srv/$SERVICE/orgs_glns.sto -> /srv/$SERVICE/orgs/orgs_glns.sto
  #
}

# check links
function check_links {
  [[ -n "$VERBOSE" ]] && echo "Checking links..."
  for target in ${!EXPECTED_LINKS[@]}
  do
    destination=${EXPECTED_LINKS[$target]}
    if [[ ! $(readlink -f $destination) = $(readlink -f $target) ]]
    then
      GOT_ERROR=1
      if [[ ! -e $target ]]
      then
        >&2 echo "ERROR: link $target does not exist"
      else
        if [[ ! -e $destination ]]
        then
          >&2 echo "ERROR: link $destination does not exist"
        else
          >&2 echo "ERROR: link instead of $target -> $destination, got $(readlink -f $target) instead"
        fi
      fi
    else
      [[ -n "$VERBOSE" ]] && echo "    OK link: $target -> $destination"
    fi
  done
}


function check_systemd_units {
  for unit in ${SYSTEMD_UNITS_ENABLED[@]}
  do
    if ! ( systemctl -q is-enabled $unit )
    then
      >&2 echo "ERROR: $unit unit must be enabled"
    else
      [[ -n "$VERBOSE" ]] && echo "    OK: $unit unit enabled"
    fi
  done
  for unit in ${SYSTEMD_UNITS_ACTIVE[@]}
  do
    if ! ( systemctl -q is-active $unit )
    then
      >&2 echo "ERROR: $unit unit must be enabled"
    else
      [[ -n "$VERBOSE" ]] && echo "    OK: $unit unit enabled"
    fi
  done

}


function other_checks {
  # apache2 must run with off user and group
  for variable in USER GROUP
  do
    if ! ( grep -q "^export APACHE_RUN_$variable=off" /etc/apache2/envvars )
    then
      GOT_ERROR=1
      >&2 echo "ERROR: $variable for apache2 should be off instead off" $(grep "^export APACHE_RUN_$variable=.*" /etc/apache2/envvars)
    else
      [[ -n "$VERBOSE" ]] && echo "    OK APACHE_RUN_$variable for apache2"
    fi
  done
}


# run
check_args
# must be before compute_expected_links
compute_services
compute_expected_links
GOT_ERROR=0
check_links
check_systemd_units
other_checks
if [[ $GOT_ERROR -ne 0 ]]; then
  exit -3
fi
