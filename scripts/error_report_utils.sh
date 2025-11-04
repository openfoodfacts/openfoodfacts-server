# Some utils functions for scripts to help report errors correctly

# counting for errors
# ERRORS is the number of errors
ERRORS=0
# FAILED_COMMANDS is a list of commands that failed
FAILED_COMMANDS=""

# reset the error count
init_error_report () {
    ERRORS=0
    FAILED_COMMANDS=""
}

# account for an error
# modifies the ERRORS and FAILED_COMMANDS variables
function report_error () {
    return_code=$1
    script_name=$2
    if [ -z "$script_name" ] || [ -z "$return_code" ]
    then
        >&2 echo "ERROR: report_error called with no arguments"
        exit 1
    fi
    if [ "$return_code" -ne 0 ]
    then
        >&2 echo "ERROR: $script_name not executed successfully - return value: $return_code"
        ERRORS=`expr $ERRORS + 1`
        FAILED_COMMANDS="${FAILED_COMMANDS}$script_name
    "
    fi
}

# If there were commands that resulted in errors,
# echo the list of commands so that it is included in the
# failure e-mail sent to root
function report_failed_commands () {
    script_name=$1
    if [ $ERRORS -gt 0 ]
    then
        >&2 echo "ERROR: $ERRORS ERROR(S) DURING EXECUTION OF $script_name"
        >&2 echo "ERROR: FAILED COMMANDS:
    $FAILED_COMMANDS"
        exit 1
    else
        echo "No errors during execution of $script_name"
        exit 0
    fi
}