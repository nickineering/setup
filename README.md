# Nick's Mac setup

Everything I need to painlessly configure my Mac exactly how I like it.

## Get started

⚠️ **Danger:** This will completely change your system. It is strongly
recommended to create a fork and comment out any parts you do not want before
using it yourself.

```bash
curl -s https://raw.githubusercontent.com/nickineering/setup/master/bootstrap.sh | /bin/bash
```

After running, complete the [manual steps](MANUAL_STEPS.md).

## What It Does

### Package Management

- **Homebrew packages** - `fd`, `ripgrep`, `jq`, `yq`, `uv`, `go`, `rust`,
  `deno`, `terraform`, `shellcheck`, `ruff`, `tldr`, `pay-respects`, `autojump`,
  `tmux`, `trash`, and more
- **Homebrew casks** - VS Code, iTerm2, Docker, 1Password, Raycast, Firefox
  Developer Edition, Postman, Shottr, Tiles, and more
- **VS Code extensions** - Synced from version control
- Detects additions/removals from state files and prompts to install/uninstall

Node and Electron carry their own trust store and never read the macOS one, so
behind a TLS-intercepting proxy every Node tool fails with "unable to get local
issuer certificate". Each run exports the CA roots macOS has been given to
`~/.config/certs/keychain-ca.pem`, and `NODE_EXTRA_CA_CERTS` points at it for
the run and, via `.profile.sh`, for every shell afterwards.

### Dotfiles

Symlinked from `linked/` so edits sync automatically:

- `.zshrc`, `.vimrc`, `.gitconfig`
- Shell functions and aliases
- Git aliases and custom commands

### Claude Code

Pre-configured Claude Code environment:

- **Sandbox** - The kernel decides which files and hosts shell commands can
  reach. That boundary replaces a permission allowlist rather than supplementing
  one, so there is no list of pre-approved commands to maintain. See
  [SECURITY.md](linked/claude/SECURITY.md) for why, and what still prompts
- **Auto mode** - On by default, with the classifier given context about this
  machine through `autoMode.environment`. Prompts are reserved for operations
  that are irreversible or leave the machine
- **Hooks** - Auto-format before commits, AWS profile scoping, and a block on
  committing mid-merge
- **Status line** - Context remaining, session cost, the granted AWS profile,
  branch with dirty and unpushed markers, and an alert when a merge or rebase is
  left unresolved. The absolute path gets its own row so a deep worktree path is
  never truncated
- **Skills** - `/commit`, `/pr`, `/mr`, `/summary` for git workflows, plus
  `worktrees` and `git-recovery` as reference Claude loads only when needed
- **Instructions** - `CLAUDE.md` with confidence scoring, the worktree and
  git-write rules, and coding preferences
- **Credentials** - Credential files and secret-shaped environment variables are
  hidden from shell commands, and denied to the file tools separately
- **Cost tracking** - `ccusage` with Bedrock pricing overrides (see
  [manual steps](MANUAL_STEPS.md#post-install-checks))
- **Employer config** - Kept out of this repo. `TERMINATOR_EXTRA_SETTINGS`
  points at a settings file layered on at launch, so internal hostnames and
  registries live with the environment they belong to

### Git Workflow

Aliases and functions for common operations:

| Command                | Description                              |
| ---------------------- | ---------------------------------------- |
| `git b`                | Interactive branch list with metadata    |
| `git c "msg"`          | Commit with message and push             |
| `git ca "msg"`         | Add all, commit, and push                |
| `git u`                | Amend last commit (keep message)         |
| `git ua`               | Add all and amend (keep message)         |
| `git cu`               | Amend last commit (edit message)         |
| `git ir [n]`           | Interactive rebase last n commits        |
| `git squash [n]`       | Squash last n commits                    |
| `git undo [n]`         | Soft reset last n commits                |
| `git wipe-commits [n]` | Hard reset last n commits                |
| `git wipe-local`       | Reset to origin (discard all local)      |
| `git ro`               | Reset to origin (keep files)             |
| `git delete-branches`  | Delete all local branches except current |
| `git start [ref]`      | Go to root, checkout ref, pull           |
| `git root`             | cd to repository root                    |
| `git cb <name>`        | Create and checkout new branch           |
| `git cl`               | Checkout last branch (`checkout -`)      |
| `git bd <name>`        | Delete branch locally                    |
| `git bdr <name>`       | Delete branch locally and remotely       |
| `git rename-branch`    | Rename branch locally and remotely       |
| `git d`                | Diff (excluding lock files)              |
| `git ll`               | Pretty log with graph                    |
| `git last`             | Show last commit                         |
| `git lc`               | List contributors                        |
| `git stats`            | Commit statistics for the repo           |
| `git sc <code>`        | Search commits by source code            |
| `git sm <msg>`         | Search commits by message                |
| `git ss <snippet>`     | Search for snippet in history            |
| `git li <pattern>`     | Local-only gitignore (this clone only)   |
| `git lie`              | Edit local gitignore                     |
| `git pa`               | Pull all nested repos                    |
| `git pf`               | Push with `--force-with-lease`           |
| `git retag <tag>`      | Delete and recreate tag on HEAD          |
| `git credit`           | Add co-author to last commit             |

See `git-aliases` and `git-functions` for the full list.

### Worktrees and reviewing agent work

There is one worktree layout here, Claude Code's:
`<main-clone>/.claude/worktrees/<name>` (gitignored), on branch `<name>`, cut
from the remote's default branch. `claude --worktree <name>`, the
`EnterWorktree` tool, subagents declaring `isolation: worktree`, and `git wt`
all produce it, so anything that reads a worktree can assume it. Working in one
is what makes `.git` writable: in the main checkout the sandbox makes it
read-only.

Lifecycle belongs to Claude Code — the exit prompt and a periodic sweep remove
worktrees holding no work, `git worktree list` shows them, and a
`.worktreeinclude` file copies gitignored files such as `.env` into each new
one. `git wt` exists so the same thing can be started **without** Claude and
handed over afterwards: `claude --worktree <name>` opens an existing worktree of
that name rather than creating another, so there is nothing to move.

What Claude Code has no answer for is reviewing a worktree **without pushing
it**, which is what the rest of these do.

| Command                  | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| `git wt <name>`          | Create or reuse one by hand, and cd into it            |
| `git wt-open [branch]`   | Add a worktree to the open editor window as a root     |
| `git wt-close [branch]`  | Drop it back out of the window                         |
| `git wt-review [branch]` | Commits, diffstat and what changed since the last look |
| `git wt-diff [branch]`   | The branch's diff, in an editor tab, against the base  |
| `git wt-browse [branch]` | Read a committed branch as uncommitted work            |

A Claude session must use `EnterWorktree` rather than `git wt`:
`git worktree
add` writes `.git/worktrees`, which the sandbox makes read-only,
and fails halfway through.

#### Tracking several agents at once

Each conversation is its own session: **Open in New Tab** or **New Window** from
the Command Palette starts another. The sidebar lists them all — filter to
`Active` for the ones working or waiting on you, right-click to group related
ones under a name, and watch the dots: blue wants a permission decision, orange
finished while hidden. When a conversation has subagents an `N agents` count
appears by the prompt box, and clicking it draws them as a tree with each one's
status, elapsed time and token count. `/tasks` opens the same view, and
`claude agents` is the terminal equivalent for background sessions.

#### Reviewing what they did

Agents leave their work uncommitted, which is the state the editor reads best,
so reviewing is just making it visible: `git wt-open` adds the worktree to the
window you already have open as an extra root. Its changes then get their own
section in the source-control view, with gutters, inline diffs and editing in
place. Add one per agent after a fan-out and they sit side by side.

Do not open a worktree as a folder. It is a directory the editor has never seen,
so the first open activates every installed extension from cold — a minute or so
regardless of whether the branch changed three lines or three hundred. Reopening
the same one is fast, which is how that was tracked down. Added as a root to a
running window it costs nothing and keeps every extension you have loaded.

When an agent has committed anyway, `git status` is empty and the question is no
longer "what changed" but "what does this branch do that its base does not".
`worktree.baseRef` is `fresh`, so branches are cut from `origin/<default>` and
that comparison is well defined. `git wt-review` prints it — base, commits,
diffstat, plus anything still uncommitted — and stamps `refs/review/<branch>` at
the tip it showed you. Run it again after the agent has done more and it adds a
`range-diff` against that stamp, so you see only what is new, including commits
that were amended or rebased rather than added. That is the part a web UI
handles worst, and none of it needs a push.

Adding that worktree as a root shows nothing for the same reason: the tree is
clean, so the source-control view has nothing to display. `git wt-diff` is the
answer. By default it writes one unified diff and opens it in a single tab, with
a diffstat header, deletions and renames included.

`--tabs` gives side-by-side diffs instead, one per file, base version on the
left and the real file on the right so fixes can be made while reading. It is
for a handful of files, not a branch: `code --diff` takes two files and reuses
the window and editor group, so a run of more than a couple of invocations
collapses into one visible diff — the loop runs, only the last pair shows. That
is why one patch is the default rather than the other way round. `WT_DIFF_MAX`
(default 25) caps the tabs.

The base defaults to **whatever the main clone has checked out**, since that is
the branch the work merges into — so the usual case is a bare `git wt-diff` with
no flags, and it follows the main clone when you move it. If the main clone is
detached, or is itself the checkout being asked about, it falls back to
`origin/HEAD`. `--base <ref>` overrides it.

Either way the comparison is against the _merge base_, not the ref's tip, so it
shows this branch's work and not everything the base gained since the branch was
cut. The patch filename and header both name the base that was used, so which
one it picked is never a guess.

To browse a branch the way you would browse uncommitted work — the whole file
tree, with the editor's own source-control view and gutter decorations marking
what changed — use `git wt-browse` instead. It moves `HEAD` to the base with a
mixed reset and leaves the working tree untouched, so every change the branch
made reads as uncommitted. That is the one thing a patch in a tab cannot give
you, and it is editable in place.

`git wt-browse --end` puts the commits back, keeping anything you fixed while
reading as an uncommitted change on top. The original tip is written to
`refs/wt-browse/<branch>` before the reset, which is what makes it reversible —
a real ref rather than a reflog entry, so it survives expiry.

It refuses to start if the worktree already has uncommitted changes, because
after the reset those could not be told apart from the branch's own, and ending
review mode would be guesswork. While review mode is on, the status line shows
`⚠ BROWSE`: a branch in that state looks like one with no commits, and a
`git commit -a` there would flatten its history into a single commit.

Run in a main checkout with no branch named, it says so instead of quietly
diffing the checkout against its own upstream and reporting nothing.

With GitLens installed, **Command Palette → `GitLens: Compare References…`**
does the same thing through the UI, against real files rather than copies.

**Nothing opens an editor on its own.** `code` takes window focus with no flag
to avoid it, so an automatic open steals the keyboard from the terminal the
session is running in — and after a fan-out it would do that once per agent,
including the ones that only read and left nothing behind.

Opening an editor is therefore always something you ask for: `git wt-open` adds
a worktree to the window, `git wt-review` and `git wt-diff` open what they
produce. Set `WT_OPEN_CMD` to use a different editor, or to the empty string so
they only print paths.

### Shell Commands

| Command                      | Description                           |
| ---------------------------- | ------------------------------------- |
| `devenv`                     | Re-run setup (safe, idempotent)       |
| `devenv --clean`             | Also clear tool caches                |
| `devenv --placeholders-only` | Sync, but clone no new repos          |
| `devenv --skip N…`           | Skip steps by number (`--skip 12 13`) |
| `devenv --only N…`           | Run only these steps (`--only 8,9`)   |
| `devenv --help`              | Usage, flags, and the step numbers    |
| `godir <pat>`                | Find and cd to a directory by pattern |
| `finddir <pat>`              | Find directories matching pattern     |
| `cs <dir>`                   | cd + ls                               |
| `mcd <dir>`                  | mkdir + cd                            |
| `..`, `...`, `....`          | Navigate up 1, 2, 3 directories       |
| `lines <ext>`                | Count lines of code by extension      |
| `count`                      | Count files in directory tree         |
| `count_lines`                | Count lines in directory tree         |
| `afk`                        | Lock screen                           |
| `reload`                     | Reload shell                          |
| `path`                       | Print PATH entries (one per line)     |
| `ip`                         | Show public IP address                |
| `localip`                    | Show local IP address                 |
| `cleanup`                    | Recursively delete `.DS_Store` files  |
| `urlencode <str>`            | URL-encode a string                   |
| `mergepdf`                   | Merge PDFs preserving hyperlinks      |
| `unmeta <file>`              | Remove metadata from photos           |
| `backup_secrets`             | Backup `~/.env.sh` and `~/.gitconfig` |
| `please`                     | Alias for `sudo`                      |
| `drun`                       | `docker compose run --rm app`         |

### Python Helpers

Short single-file Python utilities live in `scripts/` and are linked into
`~/.local/bin` without their `.py` extension, so `scripts/awake.py` runs by
typing `awake` from anywhere.

| Command | Description                                             |
| ------- | ------------------------------------------------------- |
| `awake` | Keep the display on and apps showing this Mac as active |

Each script declares its own dependencies in a
[PEP 723](https://peps.python.org/pep-0723/) header and runs under
`uv run --script`, so scripts never share a virtualenv and there is no project
to install.

`awake` holds a `caffeinate` power assertion against display and system sleep,
and nudges the pointer every minute to reset `HIDIdleTime`, which apps read to
decide you are away. Only the nudge needs Accessibility permission for the
terminal running it.

### GitLab Sync

Automatically sync all repos from a GitLab group:

```bash
# In ~/.env.sh
export GITLAB_GROUP="your-group"          # nested groups work: "parent/child"
export GITLAB_HOST="gitlab.example.com"   # optional: self-hosted instance
export GITLAB_EXCLUDE_DIRS="archive|sandbox"  # optional
export GITLAB_PLACEHOLDERS_ONLY=1             # optional: clone nothing new
```

`GITLAB_GROUP` is stripped from each repo's path, so `~/work` mirrors the
group's own structure however deeply the group itself is nested. `GITLAB_HOST`
is read by `glab`; leave it unset for gitlab.com.

If the instance answers on one hostname but reports clone URLs on another — a
Geo secondary reports its primary's `external_url` — set `GITLAB_URL_ALIASES` to
the other prefixes, pipe-separated. They are rewritten to `GITLAB_HOST` via
git's `insteadOf`, so remotes are recorded on the right host and every tool that
follows an API-supplied URL is covered, not just cloning.

The `devenv` command will:

- Clone new repos to `~/work/`
- Detect repos deleted from GitLab
- Sync branches and prune stale ones
- Prune stale worktrees the same way. A live worktree is only offered once its
  work has merged, and never while it is dirty or holds unpushed commits — those
  are reported under Active work instead. Directories in `~/work/.worktrees/`
  that git can no longer resolve are offered too, and since git cannot say what
  is in them they go to the Trash rather than being deleted
- Run in parallel for speed

Delete prompts take one keypress: `y` to delete, anything else to keep, `a` to
accept the rest of that group. Deleting a worktree and trashing a directory git
cannot read are separate groups, so `a` never crosses between them.

The branches kept level with origin are `develop`, `main` and `trunk` wherever
the remote has them, plus whatever `origin/HEAD` points at — which is where a
clone lands, so for a repo whose default is `master` or `staging` that branch is
a trunk too, not work of yours. Only a branch outside that set, holding commits
the default has not seen, is Active work.

#### Cloning only some of them

A group too big to hold on one machine — disk, or the time every update takes —
can be synced without cloning anything new: set `GITLAB_PLACEHOLDERS_ONLY=1` in
`~/.env.sh`, or pass `--placeholders-only` for a single run.

`~/work` still mirrors the group's structure, so the tree says where everything
lives whether or not it is here: each uncloned repo gets its directory with a
`.gitkeep` in it explaining itself. The rest of the sync is untouched — the
repos that are cloned are still synced, and repos, branches and worktrees that
are gone from GitLab are still offered for deletion.

Placeholders are reconciled on every run:

- a repo with nothing at its path yet gets one — only while the setting is on,
  since otherwise the run has just cloned it
- one that has been cloned since loses its `.gitkeep`, so cloning a repo by hand
  is all it takes to start syncing it
- one whose repo has left GitLab loses the directory too

The last two happen whether or not the setting is on, which is what makes
turning it off leave nothing behind: every placeholder is replaced by the real
repo in the same run.

To take a single repo, clear its placeholder first — git will not clone into a
directory that is not empty, and the `.gitkeep` holds the two commands:

```bash
trash ~/work/<path>/.gitkeep && rmdir ~/work/<path>
glab repo clone <group>/<path> ~/work/<path>
```

### macOS Configuration

- Dock layout with preferred apps
- System preferences (key repeat, scroll direction, etc.)
- Finder settings

### Tool Updates

Each run upgrades:

- Homebrew packages and casks
- VS Code extensions
- Go tools (gopls, staticcheck)
- Python tools (via uv)
- Oh My Zsh
- tldr pages

## Directory Structure

| Directory    | Purpose                                         |
| ------------ | ----------------------------------------------- |
| `linked/`    | Dotfiles symlinked to home (changes sync)       |
| `copied/`    | Templates copied once (e.g., `~/.env.sh`)       |
| `state/`     | Package/extension lists that drive installation |
| `configure/` | Tool-specific setup scripts                     |
| `scripts/`   | Python helpers linked into `~/.local/bin`       |
| `sync/`      | GitLab repo sync scripts                        |
| `lib/`       | Shared utilities                                |

## State Files

The `state/` directory controls what gets installed:

- `brew_packages.txt` - Homebrew formulae
- `brew_casks.txt` - Homebrew casks (GUI apps)
- `vscode_extensions.txt` - VS Code extensions
- `linked_files.txt` - Dotfiles to symlink
- `copied_files.txt` - Templates to copy

Lines support comments: `package # why it's needed`

## Customization

### Adding packages

```bash
echo "my-package" >> state/brew_packages.txt
```

### Adding dotfiles

1. Add the file to `linked/`
2. Add the filename to `state/linked_files.txt`

### Adding a Python helper

1. Create `scripts/<name>.py`, starting with:

```python
#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.13"
# dependencies = ["requests"]
# ///
```

2. `chmod +x scripts/<name>.py`
3. `devenv --only 8,9` to link it and cache its dependencies

There is no list to update - `scripts/` is globbed. Deleting a script removes
its link on the next run. Edits take effect immediately; only dependency changes
need step 9 again (or just run the script, which resolves them on demand).

### Machine-specific config

Edit `~/.env.sh` for secrets and device-specific settings.

## Re-running

Safe to run anytime - all operations are idempotent:

```bash
devenv          # or: make setup
devenv --clean  # also clear package manager caches
```

To run a subset, pass step numbers - the same numbers shown as `[N/13]` during a
run, and the prefixes on the files in `steps/`. Run `devenv --help` for the
list.

```bash
devenv --skip 13     # everything except the slow macOS software update
devenv --skip 12,13  # skip the steps that need sudo
devenv --only 8,9    # just re-link dotfiles and reconfigure tools
```

Numbers can be separated by commas, spaces or both, so these are equivalent:

```bash
devenv --skip 12,13   devenv --skip 12, 13   devenv --skip 12 13   devenv --skip=12,13
```

An out-of-range or non-numeric value is rejected before any step runs, with the
valid step list printed for reference.

## Development

```bash
make dev        # lint + test
make test       # run bats tests
make fix        # auto-fix formatting
make check      # lint, and let the formatters fix what they can
```

## Troubleshooting

**Setup interrupted?** Re-run `devenv`. Backups are in `~/Documents/backups/`.

**Package failed?** Warnings are printed but setup continues. Re-run or install
manually with `brew install <package>`.

**A repo fetches the same refs every run?** It has a remote-tracking ref whose
name differs from origin's only in case, so git deletes and re-creates it
forever. Harmless, and `git pack-refs --all` then `git update-ref -d` on the
mis-cased ref clears it.
