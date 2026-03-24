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
  `deno`, `terraform`, `shellcheck`, `ruff`, `tldr`, `thefuck`, `autojump`,
  `tmux`, `trash`, and more
- **Homebrew casks** - VS Code, iTerm2, Docker, 1Password, Raycast, Firefox
  Developer Edition, Postman, Shottr, Tiles, and more
- **VS Code extensions** - Synced from version control
- Detects additions/removals from state files and prompts to install/uninstall

### Dotfiles

Symlinked from `linked/` so edits sync automatically:

- `.zshrc`, `.vimrc`, `.gitconfig`
- Shell functions and aliases
- Git aliases and custom commands

### Claude Code

Pre-configured Claude Code environment:

- **Permissions** - Pre-approved commands for git, docker, terraform, aws, glab,
  python, node, ruff, pytest, mypy, and many more
- **Hooks** - Auto-format before commits, block dangerous commands, prevent
  accidental file overwrites
- **Skills** - `/commit`, `/pr`, `/mr`, `/summary` for git workflows
- **Instructions** - `CLAUDE.md` with confidence scoring, sandbox rules, and
  coding preferences
- **Security** - Blocked access to secrets, credentials, SSH keys, and system
  directories

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

### Shell Commands

| Command             | Description                           |
| ------------------- | ------------------------------------- |
| `devenv`            | Re-run setup (safe, idempotent)       |
| `godir <pat>`       | Find and cd to a directory by pattern |
| `finddir <pat>`     | Find directories matching pattern     |
| `cs <dir>`          | cd + ls                               |
| `mcd <dir>`         | mkdir + cd                            |
| `..`, `...`, `....` | Navigate up 1, 2, 3 directories       |
| `lines <ext>`       | Count lines of code by extension      |
| `count`             | Count files in directory tree         |
| `count_lines`       | Count lines in directory tree         |
| `afk`               | Lock screen                           |
| `reload`            | Reload shell                          |
| `path`              | Print PATH entries (one per line)     |
| `ip`                | Show public IP address                |
| `localip`           | Show local IP address                 |
| `cleanup`           | Recursively delete `.DS_Store` files  |
| `urlencode <str>`   | URL-encode a string                   |
| `mergepdf`          | Merge PDFs preserving hyperlinks      |
| `unmeta <file>`     | Remove metadata from photos           |
| `backup_secrets`    | Backup `~/.env.sh` and `~/.gitconfig` |
| `please`            | Alias for `sudo`                      |
| `drun`              | `docker compose run --rm app`         |

### GitLab Sync

Automatically sync all repos from a GitLab group:

```bash
# In ~/.env.sh
export GITLAB_GROUP="your-group"
export GITLAB_EXCLUDE_DIRS="archive|sandbox"  # optional
```

The `devenv` command will:

- Clone new repos to `~/work/`
- Detect repos deleted from GitLab
- Sync branches and prune stale ones
- Run in parallel for speed

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

### Machine-specific config

Edit `~/.env.sh` for secrets and device-specific settings.

## Re-running

Safe to run anytime - all operations are idempotent:

```bash
devenv          # or: make setup
```

## Development

```bash
make dev        # lint + test
make test       # run bats tests
make fix        # auto-fix formatting
make check      # lint without fixing
```

## Troubleshooting

**Setup interrupted?** Re-run `devenv`. Backups are in `~/Documents/backups/`.

**Package failed?** Warnings are printed but setup continues. Re-run or install
manually with `brew install <package>`.
