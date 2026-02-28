#!/bin/bash
# Reads tool input from stdin, blocks dangerous patterns

# Parse the JSON input
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only validate Bash commands
if [[ "$TOOL" != "Bash" ]]; then
  exit 0
fi

# =============================================================================
# SANDBOX: Restrict file modifications to allowed directories
# =============================================================================

# Block any direct access to .git directories (except via git commands)
if [[ ! "$COMMAND" =~ ^git[[:space:]] ]]; then
  # Match .git as a path component (not in the middle of a word)
  if [[ "$COMMAND" =~ (^|[[:space:]]|/)\.git(/|[[:space:]]|$) ]]; then
    echo "BLOCKED: Cannot access .git directory directly. Use git commands instead."
    exit 2
  fi
fi

# Block writes to system directories
# Match these paths anywhere in the command (as they shouldn't appear in safe commands)
SYSTEM_PATHS='(^|[[:space:]]|"|'"'"')/((etc|usr|var|System|Library|bin|sbin|opt|private|Applications)/|tmp[[:space:]]|tmp$)'
if [[ "$COMMAND" =~ $SYSTEM_PATHS ]]; then
  echo "BLOCKED: Cannot write to system directories"
  exit 2
fi

# For file-writing commands, block absolute paths outside allowed directories
# Allowed: ~/projects, ~/eonnext, ~/.Trash (and /dev/null)
WRITE_COMMANDS='^(cp|mv|tar|unzip|mkdir|touch|tee)[[:space:]]'
if [[ "$COMMAND" =~ $WRITE_COMMANDS ]]; then
  # Extract all absolute paths from command
  PATHS_IN_CMD=$(echo "$COMMAND" | grep -oE '(/[^[:space:]]+|~[^[:space:]]*)' || true)

  for path in $PATHS_IN_CMD; do
    # Expand ~ to $HOME
    expanded_path="${path/#\~/$HOME}"

    # Skip /dev/null
    [[ "$expanded_path" == "/dev/null" ]] && continue

    # Check if path is within allowed directories
    if [[ "$expanded_path" =~ ^/ ]]; then
      if [[ ! "$expanded_path" =~ ^"$HOME"/(projects|eonnext|\.Trash)(/?|/.*)$ ]]; then
        echo "BLOCKED: Cannot write to $path. Allowed: ~/projects, ~/eonnext, ~/.Trash"
        exit 2
      fi
    fi
  done
fi

# AWS: only allow read-only commands
if [[ "$COMMAND" =~ ^aws[[:space:]] ]]; then
  # S3 has different command structure - handle separately
  if [[ "$COMMAND" =~ ^aws[[:space:]]s3[[:space:]] ]]; then
    # S3: allow ls, deny cp/mv/rm/sync/mb/rb/website
    if [[ "$COMMAND" =~ [[:space:]](cp|mv|rm|sync|mb|rb|website)[[:space:]] ]]; then
      echo "BLOCKED: Only read-only AWS S3 commands allowed (ls)"
      exit 2
    fi
  # S3API uses standard get-*/list-*/head-* patterns
  elif [[ "$COMMAND" =~ ^aws[[:space:]]s3api[[:space:]] ]]; then
    if ! [[ "$COMMAND" =~ [[:space:]](get-|list-|head-) ]]; then
      echo "BLOCKED: Only read-only AWS S3API commands allowed (get-*, list-*, head-*)"
      exit 2
    fi
  # All other AWS services: describe-*, list-*, get-*
  else
    if ! [[ "$COMMAND" =~ [[:space:]](describe-|list-|get-|help) ]]; then
      echo "BLOCKED: Only read-only AWS commands allowed (describe-*, list-*, get-*)"
      exit 2
    fi
  fi
fi

# Block destructive curl operations (allow only GET/HEAD)
if [[ "$COMMAND" =~ ^curl[[:space:]] ]]; then
  # Block explicit write methods
  if [[ "$COMMAND" =~ (-X|--request)[[:space:]]*(POST|PUT|DELETE|PATCH) ]] || \
     [[ "$COMMAND" =~ (-d|--data|--data-raw|--data-binary|--data-urlencode)[[:space:]] ]] || \
     [[ "$COMMAND" =~ (--upload-file|-T)[[:space:]] ]]; then
    echo "BLOCKED: Only read-only curl requests allowed (GET/HEAD)"
    exit 2
  fi
fi

# Block destructive wget operations
if [[ "$COMMAND" =~ ^wget[[:space:]] ]]; then
  if [[ "$COMMAND" =~ (--post-data|--post-file|--method)(=|[[:space:]]) ]]; then
    echo "BLOCKED: Only read-only wget requests allowed"
    exit 2
  fi
fi

# Block destructive docker commands
if [[ "$COMMAND" =~ ^docker[[:space:]] ]]; then
  if [[ "$COMMAND" =~ (prune|rm[[:space:]]|rmi[[:space:]]|kill[[:space:]]|stop[[:space:]]) ]]; then
    echo "BLOCKED: Destructive docker command not allowed"
    exit 2
  fi
fi

# Block rm - use trash instead (mv to ~/.Trash/)
if [[ "$COMMAND" =~ ^rm[[:space:]] ]]; then
  echo "BLOCKED: Use 'mv FILE ~/.Trash/' instead of rm"
  exit 2
fi

# Block git branch deletion
if [[ "$COMMAND" =~ ^git[[:space:]]branch[[:space:]]+-[dD] ]]; then
  echo "BLOCKED: git branch deletion not allowed"
  exit 2
fi

# Block cp/mv without -n (no-clobber) flag when destination could be overwritten
# Allow if -n flag is present
if [[ "$COMMAND" =~ ^cp[[:space:]] ]] && ! [[ "$COMMAND" =~ ([[:space:]]-[a-zA-Z]*n|--no-clobber) ]]; then
  echo "BLOCKED: Use 'cp -n' to prevent overwriting existing files"
  exit 2
fi

# Block output redirection that could clobber files (allow /dev/null and >>)
if [[ "$COMMAND" =~ [^'>'][[:space:]]*'>'[^'>'] ]] && ! [[ "$COMMAND" =~ '>/dev/null' ]]; then
  echo "BLOCKED: Output redirection '>' can overwrite files. Use '>>' to append or reconsider"
  exit 2
fi

# CDK: only allow read-only commands (list, diff, synth, doctor, docs)
if [[ "$COMMAND" =~ ^cdk[[:space:]] ]]; then
  if [[ "$COMMAND" =~ [[:space:]](deploy|destroy|bootstrap) ]]; then
    echo "BLOCKED: Only read-only CDK commands allowed (list, diff, synth)"
    exit 2
  fi
fi

# SAM: only allow read-only commands (validate, build, local, logs, list)
if [[ "$COMMAND" =~ ^sam[[:space:]] ]]; then
  if [[ "$COMMAND" =~ [[:space:]](deploy|delete|sync) ]]; then
    echo "BLOCKED: Only read-only SAM commands allowed (validate, build, local, logs)"
    exit 2
  fi
fi

# Terraform: only allow read-only commands (handles -chdir flag before subcommand)
if [[ "$COMMAND" =~ ^terraform[[:space:]] ]]; then
  if [[ "$COMMAND" =~ [[:space:]](apply|destroy|import|taint|untaint)([[:space:]]|$) ]] || \
     [[ "$COMMAND" =~ [[:space:]]state[[:space:]]+(rm|mv|push) ]]; then
    echo "BLOCKED: Only read-only terraform commands allowed (plan, init, validate, fmt, output, show, state list/show)"
    exit 2
  fi
fi

# Block piped rm (bypasses rm block)
if [[ "$COMMAND" =~ \|[[:space:]]*xargs[[:space:]].*rm ]] || \
   [[ "$COMMAND" =~ \|[[:space:]]*rm([[:space:]]|$) ]]; then
  echo "BLOCKED: Piped rm command not allowed"
  exit 2
fi

# Block piped shell execution (arbitrary command execution)
if [[ "$COMMAND" =~ \|[[:space:]]*(bash|sh|zsh)([[:space:]]|$) ]]; then
  echo "BLOCKED: Piped shell execution not allowed"
  exit 2
fi

# Block sed/perl in-place editing (bypasses Write hook)
if [[ "$COMMAND" =~ ^sed[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]](-i|--in-place) ]]; then
  echo "BLOCKED: sed -i modifies files in-place"
  exit 2
fi
if [[ "$COMMAND" =~ ^perl[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]]-[a-zA-Z]*i[a-zA-Z]*([[:space:]]|$) ]]; then
  echo "BLOCKED: perl -i modifies files in-place"
  exit 2
fi

# Block find with destructive actions
if [[ "$COMMAND" =~ ^find[[:space:]] ]]; then
  if [[ "$COMMAND" =~ -delete ]] || [[ "$COMMAND" =~ -exec[[:space:]]+(rm|rmdir)[[:space:]] ]]; then
    echo "BLOCKED: find with -delete or -exec rm not allowed"
    exit 2
  fi
fi

# Block dd (direct disk/file writes)
if [[ "$COMMAND" =~ ^dd[[:space:]] ]]; then
  echo "BLOCKED: dd can overwrite disks and files directly"
  exit 2
fi

# Block install (copies files with permissions, bypasses Write hook)
if [[ "$COMMAND" =~ ^install[[:space:]] ]]; then
  echo "BLOCKED: install copies files. Use cp -n instead"
  exit 2
fi

# Block destructive git operations
if [[ "$COMMAND" =~ ^git[[:space:]]reset[[:space:]].*--hard ]]; then
  echo "BLOCKED: git reset --hard discards uncommitted changes"
  exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]clean ]]; then
  echo "BLOCKED: git clean deletes untracked files permanently"
  exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]push ]] && [[ "$COMMAND" =~ --force|[[:space:]]-[a-zA-Z]*f ]]; then
  echo "BLOCKED: git push --force can overwrite remote history"
  exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]checkout[[:space:]].*--[[:space:]] ]]; then
  echo "BLOCKED: git checkout -- discards working changes"
  exit 2
fi

# Block destructive commands in docker exec
if [[ "$COMMAND" =~ ^docker[[:space:]]exec[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]](rm|dd)[[:space:]] ]]; then
  echo "BLOCKED: Destructive command in docker exec"
  exit 2
fi

# Block heredoc redirection (can overwrite files)
if [[ "$COMMAND" =~ '<<'.*[^'>']'>'[^'>'] ]] && ! [[ "$COMMAND" =~ '>/dev/null' ]]; then
  echo "BLOCKED: Heredoc with redirection can overwrite files"
  exit 2
fi

# Block piped tee (can overwrite files mid-pipeline)
if [[ "$COMMAND" =~ \|[[:space:]]*tee[[:space:]] ]]; then
  echo "BLOCKED: Piped tee not allowed"
  exit 2
fi

exit 0
