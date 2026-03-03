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
		echo "BLOCKED: Cannot access .git directory directly. Use git commands instead." >&2
		exit 2
	fi
fi

# Block writes to system directories
# Match these paths anywhere in the command (as they shouldn't appear in safe commands)
SYSTEM_PATHS='(^|[[:space:]]|"|'"'"')/((etc|usr|var|System|Library|bin|sbin|opt|private|Applications)/)'
if [[ "$COMMAND" =~ $SYSTEM_PATHS ]]; then
	echo "BLOCKED: Cannot write to system directories" >&2
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
				echo "BLOCKED: Cannot write to $path. Allowed: ~/projects, ~/eonnext, ~/.Trash" >&2
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
			echo "BLOCKED: Only read-only AWS S3 commands allowed (ls)" >&2
			exit 2
		fi
	# S3API uses standard get-*/list-*/head-* patterns
	elif [[ "$COMMAND" =~ ^aws[[:space:]]s3api[[:space:]] ]]; then
		if ! [[ "$COMMAND" =~ [[:space:]](get-|list-|head-) ]]; then
			echo "BLOCKED: Only read-only AWS S3API commands allowed (get-*, list-*, head-*)" >&2
			exit 2
		fi
	# All other AWS services: describe-*, list-*, get-*
	else
		if ! [[ "$COMMAND" =~ [[:space:]](describe-|list-|get-|help) ]]; then
			echo "BLOCKED: Only read-only AWS commands allowed (describe-*, list-*, get-*)" >&2
			exit 2
		fi
	fi
fi

# Block destructive curl operations (allow only GET/HEAD)
if [[ "$COMMAND" =~ ^curl[[:space:]] ]]; then
	# Block explicit write methods
	if [[ "$COMMAND" =~ (-X|--request)[[:space:]]*(POST|PUT|DELETE|PATCH) ]] ||
		[[ "$COMMAND" =~ (-d|--data|--data-raw|--data-binary|--data-urlencode)[[:space:]] ]] ||
		[[ "$COMMAND" =~ (--upload-file|-T)[[:space:]] ]]; then
		echo "BLOCKED: Only read-only curl requests allowed (GET/HEAD)" >&2
		exit 2
	fi
fi

# Block destructive wget operations
if [[ "$COMMAND" =~ ^wget[[:space:]] ]]; then
	if [[ "$COMMAND" =~ (--post-data|--post-file|--method)(=|[[:space:]]) ]]; then
		echo "BLOCKED: Only read-only wget requests allowed" >&2
		exit 2
	fi
fi

# Block destructive docker commands
if [[ "$COMMAND" =~ ^docker[[:space:]] ]]; then
	if [[ "$COMMAND" =~ (prune|rm[[:space:]]|rmi[[:space:]]|kill[[:space:]]) ]]; then
		echo "BLOCKED: Destructive docker command not allowed" >&2
		exit 2
	fi
fi

# Block rm - use trash instead (mv to ~/.Trash/)
if [[ "$COMMAND" =~ ^rm[[:space:]] ]]; then
	echo "BLOCKED: Use 'mv FILE ~/.Trash/' instead of rm" >&2
	exit 2
fi

# Block git branch force deletion (-D), allow safe deletion (-d)
if [[ "$COMMAND" =~ ^git[[:space:]]branch[[:space:]]+-[a-zA-Z]*D ]]; then
	echo "BLOCKED: git branch -D (force delete) not allowed. Use -d for merged branches." >&2
	exit 2
fi

# Block cp/mv without -n (no-clobber) flag when destination could be overwritten
# Allow if -n flag is present
if [[ "$COMMAND" =~ ^cp[[:space:]] ]] && ! [[ "$COMMAND" =~ ([[:space:]]-[a-zA-Z]*n|--no-clobber) ]]; then
	echo "BLOCKED: Use 'cp -n' to prevent overwriting existing files" >&2
	exit 2
fi

# Block output redirection that could clobber files (allow /dev/null, >>, and heredocs)
# Patterns: "cmd > file" (space before) or "2>file" (fd redirect, but not 2>&1)
if [[ "$COMMAND" =~ [[:space:]]'>'[^'>'] ]] || [[ "$COMMAND" =~ [0-9]'>'[^'>&'] ]]; then
	if ! [[ "$COMMAND" =~ '>/dev/null' ]] && ! [[ "$COMMAND" =~ [0-9]'>/dev/null' ]]; then
		echo "BLOCKED: Output redirection '>' can overwrite files. Use '>>' to append or reconsider" >&2
		exit 2
	fi
fi

# CDK: only allow read-only commands (list, diff, synth, doctor, docs)
if [[ "$COMMAND" =~ ^cdk[[:space:]] ]]; then
	if [[ "$COMMAND" =~ [[:space:]](deploy|destroy|bootstrap) ]]; then
		echo "BLOCKED: Only read-only CDK commands allowed (list, diff, synth)" >&2
		exit 2
	fi
fi

# SAM: only allow read-only commands (validate, build, local, logs, list)
if [[ "$COMMAND" =~ ^sam[[:space:]] ]]; then
	if [[ "$COMMAND" =~ [[:space:]](deploy|delete|sync) ]]; then
		echo "BLOCKED: Only read-only SAM commands allowed (validate, build, local, logs)" >&2
		exit 2
	fi
fi

# Terraform: only allow read-only commands (handles -chdir flag before subcommand)
if [[ "$COMMAND" =~ ^terraform[[:space:]] ]]; then
	if [[ "$COMMAND" =~ [[:space:]](apply|destroy|import|taint|untaint)([[:space:]]|$) ]] ||
		[[ "$COMMAND" =~ [[:space:]]state[[:space:]]+(rm|mv|push) ]]; then
		echo "BLOCKED: Only read-only terraform commands allowed (plan, init, validate, fmt, output, show, state list/show)" >&2
		exit 2
	fi
fi

# Block piped rm (bypasses rm block)
if [[ "$COMMAND" =~ \|[[:space:]]*xargs[[:space:]].*rm ]] ||
	[[ "$COMMAND" =~ \|[[:space:]]*rm([[:space:]]|$) ]]; then
	echo "BLOCKED: Piped rm command not allowed" >&2
	exit 2
fi

# Block xargs with shell/interpreter execution
if [[ "$COMMAND" =~ xargs[[:space:]].*(bash|sh|zsh|python|node|ruby|perl) ]]; then
	echo "BLOCKED: xargs with shell/interpreter not allowed" >&2
	exit 2
fi

# Block bash -c (inline shell execution)
if [[ "$COMMAND" =~ (bash|sh|zsh)[[:space:]]+-c ]]; then
	echo "BLOCKED: bash -c can execute arbitrary code" >&2
	exit 2
fi

# Block eval
if [[ "$COMMAND" =~ (^|[;&|])[[:space:]]*eval[[:space:]] ]]; then
	echo "BLOCKED: eval can execute arbitrary code" >&2
	exit 2
fi

# Block source/dot from non-file sources
source_proc_subst='(source|\.)[[:space:]]+[<(]'
source_dev='(source|\.)[[:space:]]+/dev/(stdin|fd)'
if [[ "$COMMAND" =~ $source_proc_subst ]] || [[ "$COMMAND" =~ $source_dev ]]; then
	echo "BLOCKED: source from stdin/process substitution not allowed" >&2
	exit 2
fi

# Block piped shell/interpreter execution (arbitrary command execution)
if [[ "$COMMAND" =~ \|[[:space:]]*(bash|sh|zsh|python|python3|node|ruby|perl|php)([[:space:]]|$) ]]; then
	echo "BLOCKED: Piped shell/interpreter execution not allowed" >&2
	exit 2
fi

# Block interpreter inline execution flags (direct or via uv run)
if [[ "$COMMAND" =~ (^|uv[[:space:]]run[[:space:]]+)(python|python3)[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]](-c[[:space:]]|-)([[:space:]]|$|\") ]]; then
	echo "BLOCKED: python -c/-stdin can execute arbitrary code" >&2
	exit 2
fi
if [[ "$COMMAND" =~ (^|uv[[:space:]]run[[:space:]]+)node[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]](-e[[:space:]]|--eval[[:space:]]|-p[[:space:]]|--print[[:space:]]|-)([[:space:]]|$|\") ]]; then
	echo "BLOCKED: node -e/--eval/-stdin can execute arbitrary code" >&2
	exit 2
fi

# Block awk/gawk system() and getline (shell execution)
if [[ "$COMMAND" =~ ^[gm]?awk[[:space:]] ]] && [[ "$COMMAND" =~ (system|getline|cmd\|) ]]; then
	echo "BLOCKED: awk system()/getline can execute shell commands" >&2
	exit 2
fi

# Block sed/perl in-place editing (bypasses Write hook)
if [[ "$COMMAND" =~ ^sed[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]](-i|--in-place) ]]; then
	echo "BLOCKED: sed -i modifies files in-place" >&2
	exit 2
fi
if [[ "$COMMAND" =~ ^perl[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]]-[a-zA-Z]*i[a-zA-Z]*([[:space:]]|$) ]]; then
	echo "BLOCKED: perl -i modifies files in-place" >&2
	exit 2
fi

# Block find with destructive actions
if [[ "$COMMAND" =~ ^find[[:space:]] ]]; then
	if [[ "$COMMAND" =~ -delete ]] || [[ "$COMMAND" =~ -exec[[:space:]]+(rm|rmdir)[[:space:]] ]]; then
		echo "BLOCKED: find with -delete or -exec rm not allowed" >&2
		exit 2
	fi
fi

# Block dd (direct disk/file writes)
if [[ "$COMMAND" =~ ^dd[[:space:]] ]]; then
	echo "BLOCKED: dd can overwrite disks and files directly" >&2
	exit 2
fi

# Block install (copies files with permissions, bypasses Write hook)
if [[ "$COMMAND" =~ ^install[[:space:]] ]]; then
	echo "BLOCKED: install copies files. Use cp -n instead" >&2
	exit 2
fi

# Block destructive git operations
if [[ "$COMMAND" =~ ^git[[:space:]]reset[[:space:]].*--hard ]]; then
	echo "BLOCKED: git reset --hard discards uncommitted changes" >&2
	exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]clean ]]; then
	echo "BLOCKED: git clean deletes untracked files permanently" >&2
	exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]push ]] && [[ "$COMMAND" =~ --force|[[:space:]]-[a-zA-Z]*f ]]; then
	echo "BLOCKED: git push --force can overwrite remote history" >&2
	exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]checkout[[:space:]].*--[[:space:]] ]]; then
	echo "BLOCKED: git checkout -- discards working changes" >&2
	exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]restore[[:space:]] ]] && ! [[ "$COMMAND" =~ --staged ]]; then
	echo "BLOCKED: git restore discards working changes. Use --staged to unstage only." >&2
	exit 2
fi
if [[ "$COMMAND" =~ ^git[[:space:]]stash[[:space:]]+(drop|clear) ]]; then
	echo "BLOCKED: git stash drop/clear can permanently lose stashed work" >&2
	exit 2
fi

# Block destructive commands in docker exec
if [[ "$COMMAND" =~ ^docker[[:space:]]exec[[:space:]] ]] && [[ "$COMMAND" =~ [[:space:]](rm|dd)[[:space:]] ]]; then
	echo "BLOCKED: Destructive command in docker exec" >&2
	exit 2
fi

# Block heredoc redirection to file (can overwrite files)
# Only match heredoc followed by actual file redirection (space before >), not > inside heredoc content
if [[ "$COMMAND" =~ '<<'[a-zA-Z\'\"_]+[[:space:]]+'>'[^'>'] ]] && ! [[ "$COMMAND" =~ '>/dev/null' ]]; then
	echo "BLOCKED: Heredoc with redirection can overwrite files" >&2
	exit 2
fi

# Block piped tee (can overwrite files mid-pipeline)
if [[ "$COMMAND" =~ \|[[:space:]]*tee[[:space:]] ]]; then
	echo "BLOCKED: Piped tee not allowed" >&2
	exit 2
fi

exit 0
