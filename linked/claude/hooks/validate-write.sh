#!/bin/bash
# Reads Write tool input from stdin, blocks overwrites of existing files

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# If file exists, require human confirmation
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
  echo "BLOCKED: File already exists: $FILE_PATH"
  echo "Use Edit tool to modify existing files, or confirm overwrite."
  exit 2
fi

exit 0
