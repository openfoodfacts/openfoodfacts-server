#!/usr/bin/env bash
# Decide whether the required Perl test jobs ended the way this run expects.
# Called by the `tests_summary` job, which branch protection requires.
# Inputs, all job results or outputs from the workflow: FILTER_RESULT, BUILD_RESULT,
# CODE_MODIFIED, MATRIX_RESULT, UNIT_RESULT, INTEGRATION_RESULT and EVENT_NAME.
set -euo pipefail

if [ "$FILTER_RESULT" != success ] || [ "$BUILD_RESULT" != success ]; then
  echo "The path filter and backend build must succeed."
  exit 1
fi
case "$CODE_MODIFIED" in
  true)
    [ "$MATRIX_RESULT" = success ] && [ "$UNIT_RESULT" = success ] || exit 1
    case "$EVENT_NAME" in
      pull_request) [ "$INTEGRATION_RESULT" = success ] || exit 1 ;;
      push) [ "$INTEGRATION_RESULT" = skipped ] || exit 1 ;;
      *) exit 1 ;;
    esac
    ;;
  false)
    [ "$MATRIX_RESULT" = skipped ] && [ "$UNIT_RESULT" = skipped ] \
      && [ "$INTEGRATION_RESULT" = skipped ] || exit 1
    ;;
  *) exit 1 ;;
esac
echo "All required Perl test jobs succeeded."
