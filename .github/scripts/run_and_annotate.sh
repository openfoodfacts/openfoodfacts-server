#!/bin/bash
# Wrapper to run a command and, if it fails, surface the last lines of its output
# as a GitHub Actions "Error:" annotation, so the failure is visible directly on
# the run summary page (under the red "Error:" box) without opening the raw logs.
#
# Usage: ./.github/scripts/run_and_annotate.sh "<title>" <command> [args...]
#
# The command output is always streamed live to the log (so nothing is lost),
# and also tee'd to a temp file used to build the annotation on failure.

set -uo pipefail

if [ $# -lt 2 ]; then
	echo "usage: $0 <title> <command> [args...]" >&2
	exit 2
fi

title="$1"
shift

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

# Stream output live, keeping a copy for the annotation.
status=0
"$@" 2>&1 | tee "$log_file" || status="${PIPESTATUS[0]}"

if [ "$status" -ne 0 ]; then
	# Collapse carriage returns (progress bars) and trim long lines so the
	# annotation stays readable.
	detail="$(tr '\r' '\n' < "$log_file" | tail -n 40 \
		| sed -e 's/\x1b\[[0-9;]*[mGKHF]//g' -e 's/\x1b\][^\x07]*\x07//g' \
		| cut -c 1-200 \
		| grep -v '^[[:space:]]*$' | tail -n 15)"

	# GitHub workflow commands need: % => %25, \r => %0D, \n => %0A
	detail="$(printf '%s' "$detail" \
		| sed -e 's/%/%25/g' -e 's/$/%0A/' | tr -d '\n')"

	echo "::error::${title} failed (exit ${status}). Last output:%0A${detail}"
	exit "$status"
fi
