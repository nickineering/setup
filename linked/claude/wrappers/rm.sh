#!/usr/bin/env bash
# PATH wrapper: rm is allowed inside the temp directories, blocked everywhere else.
#
# A flat deny was the original rule, and it also blocked this repo's own cleanup.
# sync/repos.sh's RETURN trap leaked nine mktemp entries per sync run, and
# steps/12_privileged.sh silently failed to unlink the file holding the sudo
# password. `trash` cannot fix that second one: trashing a secret only moves it
# somewhere it survives until the Trash is next emptied.
#
# So the gate is on location rather than on the verb. A script may clean up the
# temp files it created; nothing aimed at real work gets through.

set -uo pipefail

readonly REAL_RM=/bin/rm

die() {
	echo "BLOCKED (wrapper): $1" >&2
	echo "  rm is only allowed on paths inside \$TMPDIR or /tmp. Use 'trash' instead." >&2
	exit 1
}

# Lexical pass: absolute path with "." and ".." collapsed. Lexical on purpose,
# because a path that does not exist cannot be resolved on disk and
# `rm -f missing` is both legal and common. ".." has to be collapsed *before*
# the prefix check, or "$TMPDIR/../../Users/nick/work" passes a naive
# starts-with test.
#
# Only ever handed single-line input: the caller rejects operands containing a
# newline, because `read` below stops at the first one and would otherwise
# validate a truncated path while rm received the whole thing.
normalise() {
	local p="$1" part
	[[ "$p" == /* ]] || p="$PWD/$p"

	local -a parts=() out=()
	local old_ifs="$IFS"
	IFS=/
	read -r -a parts <<<"$p"
	IFS="$old_ifs"

	for part in "${parts[@]+"${parts[@]}"}"; do
		case "$part" in
		'' | .) ;;
		..)
			# Climbing above / stays at /, matching the kernel.
			((${#out[@]})) && out=("${out[@]:0:${#out[@]}-1}")
			;;
		*) out+=("$part") ;;
		esac
	done

	local result=""
	for part in "${out[@]+"${out[@]}"}"; do result+="/$part"; done
	printf '%s' "${result:-/}"
}

# Each root is registered in both spellings, because macOS firmlinks /tmp and
# /var into /private: the lexical pass will not rewrite one into the other, and
# the physical pass below always reports the /private form.
add_root() {
	local root="$1"
	roots+=("$root")
	case "$root" in
	/private/*) roots+=("${root#/private}") ;;
	*) roots+=("/private$root") ;;
	esac
}

# This used to list bare /var/folders, which made `rm -rf /var/folders/zz` —
# every user's temp tree, not just this session's — pass the gate. The guard is
# this session's own $TMPDIR, which is where mktemp puts things anyway, so
# nothing legitimate needed the wider root.
#
# A $TMPDIR containing a newline is ignored rather than trusted: normalise
# would truncate it, leaving a root that is a prefix of paths nobody meant.
# A $TMPDIR of "/" is ignored for the blunter reason that it would make every
# path on the machine contained.
roots=()
if [[ -n "${TMPDIR:-}" && "$TMPDIR" != *$'\n'* ]]; then
	tmpdir_root=$(normalise "$TMPDIR")
	[[ "$tmpdir_root" == / ]] || add_root "$tmpdir_root"
fi
add_root /tmp

in_temp_root() {
	local path="$1" root
	for root in "${roots[@]}"; do
		[[ "$path" == "$root" || "$path" == "$root"/* ]] && return 0
	done
	return 1
}

# Physical pass: the path rm will actually act on, with every symlink resolved,
# or "" when it cannot be resolved. The lexical pass alone is not containment —
# a symlink inside $TMPDIR pointing anywhere at all turns a path that looks
# contained into a write outside the root.
#
# `cd -P` rather than realpath: no external binary to substitute via PATH, which
# matters in a gate whose whole job is to not be bypassable.
physical_target() {
	local arg="$1" dir base
	[[ "$arg" == /* ]] || arg="$PWD/$arg"

	case "$arg" in
	*/ | */. | */..)
		# A trailing slash makes rm operate on what a final symlink points at
		# rather than on the link itself, so that component is resolved too.
		# "." and ".." are directory references and go the same way.
		dir="$arg"
		base=""
		;;
	*)
		# Otherwise rm unlinks the final component itself. Resolving it would
		# reject a symlink that legitimately lives in a temp dir and happens to
		# point outside it, so only the parent is resolved.
		dir="${arg%/*}"
		base="/${arg##*/}"
		;;
	esac

	# Failure means the directory does not exist or is not searchable, so there
	# is nothing there for rm to remove and the lexical pass is the whole check.
	dir=$(CDPATH='' cd -P -- "${dir:-/}" 2>/dev/null && printf '%s' "$PWD") || return 0
	printf '%s%s' "${dir%/}" "$base"
}

# Split operands from flags. rm takes no option *values*, so the only subtlety is
# "--", after which everything is an operand even if it looks like a flag.
operands=()
empty_operands=0
end_of_flags=0
for arg in "$@"; do
	if ((end_of_flags == 0)); then
		case "$arg" in
		--)
			end_of_flags=1
			continue
			;;
		-*) continue ;;
		esac
	fi
	# An empty operand is not a path and must not be normalised, or it resolves to
	# $PWD and gets judged as if the caller had said ".". This is the ordinary case
	# for `rm -f "${VAR:-}"` with VAR unset, which steps/12_privileged.sh relies on.
	if [[ -z "$arg" ]]; then
		empty_operands=1
		continue
	fi
	# normalise() splits on IFS with `read`, which stops at the first newline, so
	# a multi-line operand would be judged on its first line only and then handed
	# to rm whole. Nothing here needs to remove a file with a newline in its name.
	[[ "$arg" == *$'\n'* ]] && die "operand contains a newline"
	operands+=("$arg")
done

# Only empty operands: hand straight to rm, whose own semantics apply (-f treats
# them as missing files and succeeds; without -f it reports them).
if ((${#operands[@]} == 0 && empty_operands)); then
	exec "$REAL_RM" "$@"
fi

((${#operands[@]})) || die "no paths given"

# A temp root itself is not a legitimate target: removing $TMPDIR wholesale is
# never what a script means, and it takes every other process's state with it.
is_root() {
	local path="$1" root
	for root in "${roots[@]}"; do
		[[ "$path" == "$root" ]] && return 0
	done
	return 1
}

for arg in "${operands[@]}"; do
	resolved=$(normalise "$arg")
	is_root "$resolved" && die "refusing to remove the temp root itself: $arg"
	in_temp_root "$resolved" || die "$arg is outside the temp directories"

	# Both passes have to agree. The lexical one catches paths that do not exist
	# yet; this one catches the ones that do but lead somewhere else.
	physical=$(physical_target "$arg")
	if [[ -n "$physical" ]]; then
		is_root "$physical" && die "refusing to remove the temp root itself: $arg"
		in_temp_root "$physical" ||
			die "$arg resolves to $physical, outside the temp directories"
	fi
done

exec "$REAL_RM" "$@"
