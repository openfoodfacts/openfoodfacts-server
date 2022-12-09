#!/usr/bin/env bash

# adaptated from Tar-Minyatur/gettext-validation, (MIT License)

echo "Checking .po files in po/..."
if ! (which gettext)
then
    echo "you must install gettext to run this script"
    exit 2
fi
ERRORS=0
for filename in $(find po/ -type f -name \*.po)
do
    file_basename=$(basename "$filename")
    # exception for lol.po (crowdin ids tracking)
    if [ "$file_basename"  = "lol.po" ]
    then
        continue
    fi
    echo -n "→ $filename..."
    msgfmt "$filename"
    returnValue=$?
    if [ $returnValue -ne 0 ]
    then
        ERRORS=`expr $ERRORS + 1`
        echo "contains errors!"
    else
        echo "ok"
    fi
done
echo ""
if [ $ERRORS -gt 0 ]; then
    echo "FOUND $ERRORS ERROR(S) IN THE TRANSLATION FILES. SEE ABOVE FOR DETAILS."
    exit 1
else
    echo "No errors found."
    exit 0
fi
