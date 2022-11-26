# Nick's Mac setup

Everything I need to painlessly setup a new Mac.

## Get started on a fresh Mac

⚠️ **Danger**: This will completely change your system. It is only designed to be run on
a new Mac.

```bash
curl -s https://raw.githubusercontent.com/nferrara100/mac/master/install.sh | bash
```

## Manual bits

Once the installation script is complete you will have to manually do the following:

1. [Generate a new GPG key and add it to Github](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
   and then
   [configure git to sign commits with the new GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
1. Add system languages and keyboard layouts to the OS
1. Pair your Bluetooth devices
1. Add your signature to Preview from the "Signature with white background" Google Doc
1. Search for "extensions" in System Settings. Click "Finder extensions" -> "Added
   extensions" -> Enable "OpenInTerminal"
1. Add the "Open in Terminal" and "New Folder" buttons to the Finder toolbar
1. Remove Apple News and Apple Stocks widgets from the Notification Center
1. Go to System Settings -> Trackpad and increase the Tracking Speed. By default it can
   be tricky to cross the whole screen in one gesture.
1. This uses Raycast instead of Spotlight, so Spotlight should be moved out of the way.
   Search for "spotlight" in System Settings. Click on "Keyboard Shortcuts" ->
   "Spotlight". Then uncheck "Show Spotlight search" and "Show Finder search window"
1. Set a
   [lock screen message](https://support.apple.com/en-ie/guide/mac-help/mh35890/mac)
   including your email in case your laptop is misplaced and someone kind finds it.

Then run the following git commands:

```bash
git config --global user.name "Your Name"
git config --global user.email "Your email"
```

Finally, you will need to activate:

1. 1Password
1. AWS CLI: `awscli`
1. Cheatsheet
    1. Grant permissions
1. Chrome - all profiles
1. Docker
1. Fig
1. Firefox
1. Github VSCode extension
1. iTerm2
    1. Make default terminal
1. Kindle
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
1. Shottr
    1. Grant permissions
    1. Increase scrolling screenshot speed to max
    1. Assign hotkeys for all commands
    1. Default window to larger size
1. Signal
1. Skype
1. Spotify
1. Tiles
    1. Grant permissions
    1. Open on login)
1. WhatsApp
1. Xcode
1. Zoom

## Changing your dotfiles

Changes to your dotfiles will be mirrored in your local copy of the repo in the `linked`
folder to make contributing upstream easier. Do not move the repo or it will break the
links!
