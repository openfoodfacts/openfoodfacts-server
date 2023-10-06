#!/usr/bin/env bash

. scripts/imports/imports_utils.sh

function fail {
    >&2 echo $1
    # commit suicide, as `exit`` would only exit the function
    kill -SIGPIPE "$$"
}


TMP_DIR=$(mktemp -d)

SUCCESS_FILE=$TMP_DIR/success

import_since 2>$TMP_DIR/err >/dev/null
grep -q "missing path" $TMP_DIR/err || fail "should have missing path error"
mark_successful_run 2>$TMP_DIR/err
grep -q "missing path" $TMP_DIR/err || fail "should have missing path error"
[[ -f $SUCCESS_FILE ]] && fail "should not have success file"

NO_DATA_SINCE=$(import_since $SUCCESS_FILE)

[[ $NO_DATA_SINCE -eq 7 ]] || fail "should get 7 without any file got $NO_DATA_SINCE"

mark_successful_run $SUCCESS_FILE

NO_DATA_SINCE=$(import_since $SUCCESS_FILE)

[[ $NO_DATA_SINCE -eq 1 ]] || fail "should get 1 just after run  got $NO_DATA_SINCE"

# we need eval because of redirection to a file designated by a variable
eval "date +'%s' --date='50 hours ago'>$SUCCESS_FILE"

NO_DATA_SINCE=$(import_since $SUCCESS_FILE)

[[ $NO_DATA_SINCE -eq 3 ]] || fail "should get 3 got $NO_DATA_SINCE"

rm -rf $TMP_DIR

echo "SUCCESS - "$(basename $0)