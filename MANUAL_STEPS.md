# Manual Steps

If life were perfect flights would always depart on time and MacOS would allow
everything to be scripted, but life isn't perfect and there are some things
Apple just really wants you do do manually. Once
[the bootstrap script](bootstrap.sh) finishes you will have to follow the
following manual steps to finish setting up your Mac:

1. [Generate a new GPG key and add it to Github](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
   and then
   [configure git to sign commits with the new GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
1. Add system languages and keyboard layouts to the OS
1. Pair your Bluetooth devices
1. Search for "extensions" in System Settings. Click "Finder extensions" ->
   "Added extensions" -> Enable "OpenInTerminal"
1. Add the "Open in Terminal" and "New Folder" buttons to the Finder toolbar
1. Remove Apple News and Apple Stocks widgets from the Notification Center and
   replace them with weather, connected devices, Github, and Google Translate.
1. Go to System Settings -> Trackpad and increase the Tracking Speed. By default
   it can be tricky to cross the whole screen in one gesture.
1. This uses Raycast instead of Spotlight, so Spotlight should be moved out of
   the way. Search for "spotlight" in System Settings. Click on "Keyboard
   Shortcuts" -> "Spotlight". Then uncheck "Show Spotlight search" and "Show
   Finder search window"
1. Set a
   [lock screen message](https://support.apple.com/en-ie/guide/mac-help/mh35890/mac)
   including your email in case your laptop is misplaced and someone kind finds
   it.
1. Install Paragon NTFS for Mac for free via its Seagate Hard Drive installer
   and grant it permissions in System Settings as instructed during
   installation. This allows editing external NTFS drives.
1. Set 1Password and Chrome to start at login

Then run the following git commands:

```bash
git config --global user.name "Your Name"
git config --global user.email "Your email specifically for git"
```

Next, you will need to sign in or otherwise activate the following apps, being
sure to complete any steps noted:

1. 1Password
1. Cheatsheet
   1. Grant permissions
1. Chrome - all profiles
1. Docker
1. Firefox
1. VSCode
1. Github Actions VSCode extension
1. Github Pull Requests VSCode extension
1. iTerm2
   1. Make default terminal
1. NordVPN
1. OpenInTerminal
   1. Grant permissions
   2. Launch at Login
   3. Quick Toggle (terminal)
   4. Hide Status Bar Icon
   5. Default Terminal: iTerm
   6. Default Editor: Visual Studio Code
   7. iTerm: Tab
1. Paragon NTFS
1. Raycast
   1. Assign `cmd + space` hotkey
1. Rocket
   1. Open and follow instructions
   2. Enable start on startup
   3. Grant permissions for web browsers
1. Safari
   1. Enable the Develop menu in Settings -> Advanced
   1. General -> Safari opens with all windows from last session
   1. General -> Remove history items: Manually
1. Shottr
   1. Activate license
   2. Grant permissions
   3. Increase scrolling screenshot speed to max
   4. Assign hotkeys for all commands
   5. Default window to larger size
1. Signal
1. Skype
1. Spotify
1. Tiles
   1. Grant permissions
   2. Open on login
1. WhatsApp
1. Zoom

Finally, you need to run the following command in your terminal to finish the
automated setups:

```bash
chmod +x ~/projects/setup/util/after_signin.sh && ~/projects/setup/util/after_signin.sh
```
