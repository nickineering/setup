#!/usr/bin/env bash
# PATH wrapper: always blocks rm. Use trash instead.
echo "BLOCKED (wrapper): rm is not allowed. Use 'trash' instead." >&2
exit 1
