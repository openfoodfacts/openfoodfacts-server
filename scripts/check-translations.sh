#!/usr/bin/env bash

# adaptated from Tar-Minyatur/gettext-validation, (MIT License)

echo "Checking .po files in po/..."
if ! (which gettext)
then
    >2 echo "you must install gettext to run this script"
    exit 2
fi
ERRORS=0
tmplog=$(mktemp --suffix "-check-translations.log")
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
    fi
    # msggrep will directly search for messages with placeholders
    msggrep $filename  --msgid -e '%[sd]' --msgstr -e '%[sd]' | \
    while read -r line
    do
        if [[ $line =~ ^msgid ]]
        then
            msgid=$line
        elif [[ $line =~ ^msgstr ]]
        then
            msgstr=$line
            # if msgstr and msgid is not empty
            if ( ! ( echo "$msgstr" | grep '"\s*"' > /dev/null ) ) && ( ! ( echo "$msgid" | grep '"\s*"' > /dev/null ) )
            then
                # Count the number of %s placeholders in the msgid and msgstr lines
                msgid_placeholders=$(echo "$msgid" | grep -o "%[sd]" | wc -l)
                msgstr_placeholders=$(echo "$msgstr" | grep -o "%[sd]" | wc -l)
                if [ $msgid_placeholders -ne $msgstr_placeholders ]
                then
                    echo ""
                    echo "ERROR: The number of placeholders in the msgid and msgstr lines are different."
                    echo "msgid: $msgid"
                    echo "msgstr: $msgstr"
                    # we append in tmplog to analyze errors afterwards
                    # as we can't directly update ERRORS for we are in a sub process
                    echo "ERROR" >> $tmplog
                fi
            fi
        fi
    done
    echo ""
done
logerrors=$(cat $tmplog|wc -l)
rm $tmplog
ERRORS=`expr $ERRORS + $logerrors`
echo "$ERRORS errors, $logerrors"
if [ $ERRORS -gt 0 ]; then
    echo "FOUND $ERRORS ERROR(S) IN THE TRANSLATION FILES. SEE ABOVE FOR DETAILS."
    exit 1
else
    echo "No errors found."
    exit 0
fi
