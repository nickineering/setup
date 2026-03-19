# Nick's Mac setup

Everything I need to painlessly configure my Mac exactly how I like it.

## Get started

⚠️ **Danger:** This will completely change your system. It is strongly
recommended to create a fork and comment out any parts you do not want before
using it yourself.

```bash
curl -s https://raw.githubusercontent.com/nickineering/setup/master/bootstrap.sh | /bin/bash
```

Once you run that script you will have to
[manually configure the remaining settings](MANUAL_STEPS.md).

## Directory structure

| Directory | Purpose                                                                 |
| --------- | ----------------------------------------------------------------------- |
| `linked/` | Dotfiles symlinked to wherever they belong (changes sync automatically) |
| `copied/` | Template files copied to wherever they belong (only on first run)       |
| `state/`  | Lists of packages, extensions, and files to manage                      |
| `util/`   | Setup scripts and helper functions                                      |

## State files

The `state/` directory contains text files that control what gets installed:

- `brew_packages.txt` - Homebrew formulae
- `brew_casks.txt` - Homebrew casks (GUI apps)
- `vscode_extensions.txt` - VS Code extensions
- `linked_files.txt` - Dotfiles to symlink
- `copied_files.txt` - Templates to copy

Lines can include comments after a space (e.g., `package # why it's needed`).

## Customization

### Adding packages

Add the package name to the appropriate state file:

```bash
echo "my-package" >> state/brew_packages.txt
```

### Adding dotfiles

1. Add the file to `linked/`
2. Add the filename to `state/linked_files.txt`

### Machine-specific settings

Edit `~/.env.sh` for environment variables that shouldn't be committed.

## Re-running and updating

The setup is idempotent - safe to re-run after pulling updates:

```bash
cd ~/projects/setup
git pull
make setup
```

## Changing your dotfiles

Changes to your dotfiles will be mirrored in your local copy of the repo in the
`linked` folder to make contributing upstream easier. Do not move the repo or it
will break the links!

## Troubleshooting

### Setup interrupted

If you Ctrl+C during setup, you'll see which step was interrupted. Re-run the
setup script to resume. Backups are in `~/Documents/backups/`.

### Backup collisions

Backups include timestamps (e.g., `.zshrc.backup.2026-03-11_143022`) to prevent
overwrites.

### Package installation failed

Warnings are printed but setup continues. Re-run or install manually with
`brew install <package>`.

## Running tests

```bash
make test
```

## Maintenance

Periodically update dependencies:

```bash
make update-formatters  # Update dprint plugins
make update-actions     # Update GitHub Actions versions
```
