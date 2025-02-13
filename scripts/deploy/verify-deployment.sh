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
  OFF_ZFS_PATH="/mnt/off"
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
  SYSTEMD_LINKS+=( email-failures@.service nginx.service.d apache2.service.d cloud_vision_ocr@.service minion@.service )
  # units that must be active (and enabled)
  SYSTEMD_UNITS_ACTIVE=( nginx.service apache2.service cloud_vision_ocr@$SERVICE.service minion@.service )
  # units that must be enabled
  SYSTEMD_UNITS_ENABLED=( )
  # priority request on off
  if [[ $SERVICE = "off" ]]
  then
    SYSTEMD_LINKS+=( apache2@.service.d prometheus-apache-exporter@.service )
    SYSTEMD_UNITS_ACTIVE+=( apache2@priority.service prometheus-apache-exporter.service prometheus-apache-exporter@priority.service )
  fi
  if [[ -z $IS_PRO ]]
  then
    # non pro
    SYSTEMD_LINKS+=( gen_feeds_daily@.{service,timer} )
    SYSTEMD_UNITS_ACTIVE+=( gen_feeds_daily@$SERVICE.timer )
    SYSTEMD_UNITS_ENABLED+=( gen_feeds_daily@$SERVICE.service )
  else
    # pro
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
  EXPECTED_LINKS["$REPO_PATH/po/site-specific"]="$REPO_PATH/po/$SERVICE_LONG_NAME"
  # off-web
  EXPECTED_LINKS["$REPO_PATH/lang"]="/srv/openfoodfacts-web/lang"
  EXPECTED_LINKS["$REPO_PATH/html/off_web_html"]="/srv/openfoodfacts-web/html"
  # data linked to zfs storages
  EXPECTED_LINKS["$REPO_PATH/data"]="$ZFS_PATH/data"
  EXPECTED_LINKS["$REPO_PATH/orgs"]="$ZFS_PATH/orgs"
  EXPECTED_LINKS["$REPO_PATH/users"]="$ZFS_PATH/users"
  # image and products are now merges on off zfs storage
  EXPECTED_LINKS["$REPO_PATH/products"]="$OFF_ZFS_PATH/products"
  EXPECTED_LINKS["$REPO_PATH/html/images/products"]="$OFF_ZFS_PATH/images/products"
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
  EXPECTED_LINKS["/etc/apache2/ports.conf"]="$REPO_PATH/conf/apache-2.4/ports.conf"
  EXPECTED_LINKS["/etc/apache2/off-envvars"]="$REPO_PATH/conf/apache-2.4/off-envvars"
  EXPECTED_LINKS["/etc/apache2/mods-available/mpm_prefork.conf"]="$REPO_PATH/conf/apache-2.4/mpm_prefork.conf"
  EXPECTED_LINKS["/etc/apache2/sites-enabled/$SERVICE.conf"]="$REPO_PATH/conf/apache-2.4/sites-available/$SERVICE.conf"
  if [[ $SERVICE = "off" ]]
  then
    EXPECTED_LINKS["/etc/apache2-priority"]="/etc/apache2"
  fi

  for systemd_unit in {apache2,nginx}.service.d ${SYSTEMD_LINKS[@]}
  do
    EXPECTED_LINKS["/etc/systemd/system/$systemd_unit"]="$REPO_PATH/conf/systemd/$systemd_unit"
  done

  # log rotate config
  EXPECTED_LINKS["/etc/logrotate.d/apache2"]="$REPO_PATH/conf/logrotate/apache2"
  EXPECTED_LINKS["/etc/logrotate.d/nginx"]="$REPO_PATH/conf/logrotate/nginx"

  # prometheus configs
  if [[ $SERVICE = "off" ]]
  then
    EXPECTED_LINKS["/etc/default/prometheus-apache-exporter"]="$REPO_PATH/conf/etc-default/prometheus-apache-exporter"
    EXPECTED_LINKS["/etc/default/prometheus-apache-priority-exporter"]="$REPO_PATH/conf/etc-default/prometheus-apache-priority-exporter"
  fi

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
        >&2 echo "ERROR: link $target does not exist (should link to $destination)"
      else
        if [[ ! -e $destination ]]
        then
          >&2 echo "ERROR: link $destination does not exist (while $target links to it)"
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
      GOT_ERROR=1
      >&2 echo "ERROR: $unit unit must be enabled"
    else
      [[ -n "$VERBOSE" ]] && echo "    OK: $unit unit enabled"
    fi
  done
  for unit in ${SYSTEMD_UNITS_ACTIVE[@]}
  do
    if ! ( systemctl -q is-active $unit )
    then
      GOT_ERROR=1
      >&2 echo "ERROR: $unit unit must be active"
    else
      [[ -n "$VERBOSE" ]] && echo "    OK: $unit unit active"
    fi
  done

}


function other_checks {
  # a common pitfall is to have log rotate not working
  # because conf file must be owned by root
  [[ -n "$VERBOSE" ]] && echo "Checking other things..."
  # we need -follow because our confs are symlinked
  NON_ROOT_LOGROTATE_CONF=$(find /etc/logrotate.d/ -follow -type f -not -user root)
  if [[ -n "$NON_ROOT_LOGROTATE_CONF" ]]
  then
    GOT_ERROR=1
    >&2 echo "ERROR: logrotate config files $NON_ROOT_LOGROTATE_CONF must be owned by root"
  else
    [[ -n "$VERBOSE" ]] && echo "    OK: logrotate config files are owned by root"
  fi
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
