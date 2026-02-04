#!/bin/bash
# Run RuboCop on edited Ruby files

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only run on Ruby files
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.rb ]]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || exit 1

# Run RuboCop on the edited file
# Exit 2 to block edits that fail RuboCop
# Redirect output to stderr so Claude sees it
OUTPUT=$(mise exec -- ./bin/rubocop "$FILE_PATH" 2>&1)
RESULT=$?

if [ $RESULT -ne 0 ]; then
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
