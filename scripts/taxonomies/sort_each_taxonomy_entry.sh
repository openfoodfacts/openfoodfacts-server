#!/usr/bin/env bash

ARGS=();
FILES=();

ACTION="Linting"
# options are passed as arguments to the script
for arg in "$@"
do
    if [[ "$arg" = -* ]]
    then
        ARGS+=( "$arg" );
    else
        FILES+=( "$arg" );
    fi
    if [[ "$arg" = "--check" ]]
    then
        IS_CHECK=1;
        ACTION="Checking"
    fi
done

script=$(dirname $0 )"/sort_each_taxonomy_entry.pl"
FINAL_EXIT=0;
for taxonomy in "${FILES[@]}"
do
    echo "$ACTION $taxonomy ==============="
    rm -f $taxonomy.tmp
    # redirect output only if we're not checking
    ( \
        [[ -z "$IS_CHECK" ]] && exec >$taxonomy.tmp; \
        $script "${ARGS[@]}" <$taxonomy; \
    )
    [[ -s $taxonomy.tmp ]] && mv $taxonomy.tmp $taxonomy
    EXIT=$?
    if [[ $EXIT -ne 0 ]]
    then
        echo "=> Error in $taxonomy"
        FINAL_EXIT=$EXIT;
    fi
done

exit $FINAL_EXIT;