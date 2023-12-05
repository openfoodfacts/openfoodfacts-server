# some utility functions for run_imports shell



# find last run and deduce how many days to fetch
#
# first arg should be the path to the import success file 
# containing a timestamp of last successful import
# it may not exists yet, in which case we default to one week
function import_since() {
    SUCCESS_FILE_PATH=$1
    if [[ -z "$SUCCESS_FILE_PATH" ]]
    then
        >&2 echo "ERROR: missing path to success file"
    fi
    if [[ -f "$SUCCESS_FILE_PATH" ]]
    then
        LAST_TS=$(cat $SUCCESS_FILE_PATH)
        CURRENT_TS=$(date +%s)
        DIFF=$(( $CURRENT_TS - $LAST_TS ))
        # 86400 seconds in a day, +1 because we want upper bound
        IMPORT_SINCE=$(( $DIFF / 86400 + 1 ))
    else
        # defaults to one year
        IMPORT_SINCE=365
    fi
    echo $IMPORT_SINCE
}

# mark a sucessful run of import by putting current timestamp in success file
# so that import_since can use it on next run
function mark_successful_run() {
    SUCCESS_FILE_PATH=$1
    if [[ -z "$SUCCESS_FILE_PATH" ]]
    then
        >&2 echo "ERROR: missing path to success file"
    fi
    echo $(date +%s) > $SUCCESS_FILE_PATH
}
