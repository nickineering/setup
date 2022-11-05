# Nick's Mac setup

Everything I need to painlessly setup a new Mac.

## Get started from scratch

```
curl -s https://raw.githubusercontent.com/nferrara100/mac/master/install.sh | bash
```

## Manual bits

Onces installation script is complete you will have to manually do the following:

1. [Generate a new GPG key and add it to Github](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
   and then
   [configure git to sign commits with the new GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
1. Add system languages and keyboard layouts to the OS
1. Pair your bluetooth devices
1. Add signature to Preview from the "Signature with white background" Google Doc
1. Search for "extensions" in System Settings. Click "Finder extensions" -> "Added
   extensions" -> Enable "OpenInTerminal"
1. Add the "Open in Terminal" and "New Folder" buttons to the Finder toolbar
1. Open and configure Shottr:
    - Grant permissions
    - Increase scrolling screenshot speed to max
    - Assign hotkeys for all commands
    - Default window to larger size

Then run the following git commands:

```bash
git config --global user.name "Your Name"
git config --global user.email "Your email"
```

Finally, you will need to activate:

1. 1Password
1. AWS CLI: `awscli`
1. Cheatsheet (Just open and grant permissions)
1. Chrome - all profiles
1. Docker
1. Fig
1. Firefox
1. Github VSCode extension
1. iTerm2 (Make default terminal)
1. Kindle
1. Muzzle (Just open and grant permissions)
1. NordVPN
1. OpenInTerminal
    1. Grant permissions
    1. Launch at Login
    1. Quick Toggle (terminal)
    1. Hide Status Bar Icon
    1. Default Terminal: iTerm
    1. Default Editor: Visual Studio Code
    1. iTerm: Tab
1. Raycast
1. Signal
1. Skype
1. Spotify
1. Tiles (Open, grant permissions, and open on login)
1. WhatsApp
1. Xcode
1. Zoom

## Changing your dotfiles

Changes to your dotfiles will be mirrored in your local copy of the repo to make
contributing upstream easier. Do not move the repo or it will break their links!
