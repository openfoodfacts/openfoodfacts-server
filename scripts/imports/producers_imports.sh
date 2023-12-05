#!/usr/bin/env bash
export PERL5LIB="lib:${PERL5LIB}"

# run import scripts
PRODUCERS=(
    equadis
    agenar3000
    carrefour
    intermarches
)
for PRODUCER in "${PRODUCERS[@]}"
do
  script_path="scripts/imports/${PRODUCER}/run_${PRODUCER}_import.sh"
  [[ -e $script_path ]] || >&2 echo "No script found for $PRODUCER"
  ./$script_path
done

# export
./scripts/export_producers_platform_data_to_public_database.sh