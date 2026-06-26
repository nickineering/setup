#!/usr/bin/env bash
# PATH wrapper: always blocks dd.
echo "BLOCKED (wrapper): dd is not allowed in Claude sessions." >&2
exit 1
