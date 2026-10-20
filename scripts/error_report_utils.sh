# Some utils functions for scripts to help report errors correctly

# ANSI color definitions
_ERR_RED="\033[1;31m"
_ERR_GREEN="\033[1;32m"
_ERR_YELLOW="\033[1;33m"
_ERR_BOLD="\033[1m"
_ERR_RESET="\033[0m"

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
        >&2 echo -e "${_ERR_RED}${_ERR_BOLD}❌ ERROR: report_error called with no arguments${_ERR_RESET}"
        exit 1
    fi
    if [ "$return_code" -ne 0 ]
    then
        >&2 echo -e "${_ERR_RED}${_ERR_BOLD}❌ ERROR: $script_name failed with return code $return_code${_ERR_RESET}"
        if [ -n "$GITHUB_ACTIONS" ]; then
            echo "::error title=$script_name Failed::$script_name exited with return code $return_code"
        fi
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
        >&2 echo -e "${_ERR_RED}${_ERR_BOLD}════════════════════════════════════════════════════════════════${_ERR_RESET}"
        >&2 echo -e "${_ERR_RED}${_ERR_BOLD}❌ ERROR: $ERRORS FAILURE(S) DETECTED DURING EXECUTION OF $script_name${_ERR_RESET}"
        >&2 echo -e "${_ERR_RED}${_ERR_BOLD}════════════════════════════════════════════════════════════════${_ERR_RESET}"
        >&2 echo -e "${_ERR_YELLOW}Failed commands:${_ERR_RESET}"
        >&2 echo -e "$FAILED_COMMANDS"
        exit 1
    else
        echo -e "${_ERR_GREEN}${_ERR_BOLD}✅ Success: All steps in $script_name completed without errors.${_ERR_RESET}"
        exit 0
    fi
}