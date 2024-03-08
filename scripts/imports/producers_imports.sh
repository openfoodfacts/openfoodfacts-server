#!/usr/bin/env bash
export PERL5LIB="lib:${PERL5LIB}"

if [[ $(id -un) != "off" ]]
then
  >&2 echo "ERROR: script must be launch with user off"
  exit -1
fi

# run import scripts
PRODUCERS=(
    equadis
    agena3000
    carrefour
    intermarche
)
for PRODUCER in "${PRODUCERS[@]}"
do
  echo "STARTING $PRODUCER IMPORT SCRIPT"
  script_path="scripts/imports/${PRODUCER}/run_${PRODUCER}_import.sh"
  [[ -e $script_path ]] || >&2 echo "No script found for $PRODUCER"
  ./$script_path
done

# export
./scripts/export_producers_platform_data_to_public_database.sh
