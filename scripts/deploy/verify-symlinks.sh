#!/usr/bin/env bash
# This script verifies that every important symlink is present on a deployment
#
# short name of service must be provided as argument

SERVICE=$1

KNOWN_SERVICES=(obf off off-pro opf opff)


function check_args {
  # check service name
  if ! ( echo $KNOWN_SERVICES | grep -w "$SERVICE" )
  then
    >2 echo "unknown service: $SERVICE"
    exit -1
  fi
  REPO_PATH="/srv/$SERVICE"
  # check service is deployed as expected
  if [[ ! -d $REPO_PATH/.git ]];
    >2 echo "$REPO_PATH must be a git repository"
    exit -2
  fi
  ZFS_PATH="/mnt/$SERVICE"
}

function compute_expected_links {
  # links to check target - dest
  EXPECTED_LINKS=(
    # nginx configuration
    "$REPO_PATH/conf/nginx/sites-available/$SERVICE" "/etc/nginx/sites-enabled/$SERVICE"
    # data linked to zfs storages
    "$ZFS_PATH/orgs" "$REPO_PATH/orgs"
    "$ZFS_PATH/users" "$REPO_PATH/users"
    "$ZFS_PATH/products" "$REPO_PATH/products"
    "$ZFS_PATH/images/products" "$REPO_PATH/html/images/products"
    "$ZFS_PATH/html_data" "$REPO_PATH/html/data"
    # deeper link in zfs storages
    "$ZFS_PATH/deleted.images" "$REPO_PATH/deleted.images"

    # link in zfs storages to files in git
    "$REPO_PATH/html/data/data-fields.md" "$ZFS_PATH/html_data/data-fields.md"
    "$REPO_PATH/html/data/data-fields.txt" "$ZFS_PATH/html_data/data-fields.txt"

  )
  if [[ $SERVICE != "off-pro" ]]
  then
    # links to other projects to handle data migration between projects
    for OTHER_SERVICE in "${KNOWN_SERVICES[@]}"
    do
      if [[ $OTHER_SERVICE != "$SERVICE" ]] && [[ $OTHER_SERVICE != "off-pro" ]]
      then
        EXPECTED_LINKS+=(
          "/mnt/$OTHER_SERVICE/products" "/srv/$OTHER_SERVICE/products"
          "/mnt/$OTHER_SERVICE/images/products" "/srv/$OTHER_SERVICE/html/images/products"
        )
      fi
    done
  fi
}

# check links
function check_links{
  GOT_ERROR=0
  for ((i=0;i<${#EXPECTED_LINKS[@]};i+=2)); do
    target=${EXPECTED_LINKS[i]}
    destination=${EXPECTED_LINKS[i+1]}
    if [[ $destination -ef $target ]]
    then
      GOT_ERROR=1
      >2 echo "WRONG link: $target -> $destination"
    fi
}

# run

check_args
compute_expected_links
check_links
if [[ $GOT_ERROR -ne 0 ]]; then
  exit -3
fi