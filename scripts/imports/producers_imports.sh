#!/usr/bin/env bash
export PERL5LIB="lib:${PERL5LIB}"

# run import scripts
PRODUCERS=(
    equadis
    agena3000
    carrefour
    intermarche
)
for PRODUCER in "${PRODUCERS[@]}"
do
  script_path="scripts/imports/${PRODUCER}/run_${PRODUCER}_import.sh"
  [[ -e $script_path ]] || >&2 echo "No script found for $PRODUCER"
  ./$script_path
done

# export
./scripts/export_producers_platform_data_to_public_database.sh