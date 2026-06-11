# Manual Steps

If life were perfect flights would always depart on time and MacOS would allow
everything to be scripted, but life isn't perfect and there are some things
Apple just really wants you do do manually. Once
[the bootstrap script](bootstrap.sh) finishes you will have to follow the
following manual steps to finish setting up your Mac:

1. Add system languages and keyboard layouts to the OS
1. Pair your Bluetooth devices
1. Open "Finder" -> "Settings" -> "Advanced" -> Enable "Remove items from Trash
   after 30 days"
1. Open the "OpenInTerminal" app and then search for "extensions" in System
   Settings. Click "File Providers" -> -> Enable "OpenInTerminal"
1. Add the "New Folder" button to the Finder toolbar
1. Remove Apple News and Apple Stocks widgets from the Notification Center and
   replace them with weather, connected devices, Github, and Google Translate.
1. Go to System settings -> Menu Bar -> Add: Bluetooth, Weather
1. Go to System settings -> Menu Bar -> Battery Options -> Show Percentage
1. Install Paragon NTFS for Mac for free via its Seagate Hard Drive installer
   and grant it permissions in System Settings as instructed during
   installation. This allows editing external NTFS drives.

## GitLab repo sync setup

To enable GitLab repo syncing:

1. Configure your GitLab group in `~/.env.sh`:
   ```bash
   export GITLAB_GROUP="your-group"
   # Optional: exclude specific subdirectories (pipe-separated)
   export GITLAB_EXCLUDE_DIRS="archived|sandbox"
   ```

2. Authenticate with GitLab:
   ```bash
   glab auth login
   ```

Next, you will need to sign in or otherwise activate the following apps, being
sure to complete any steps noted:

1. 1Password
1. Keyclu
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
   3. Window Screenshot Background: Wallpaper
   4. Increase scrolling screenshot speed to max
   5. Assign hotkeys for all commands
   6. Default window to larger size
1. Signal
1. Skype
1. Spotify
1. Tiles
   1. Grant permissions
   2. Open on login
1. WhatsApp
1. Zoom

Finally, after signing in to Firefox (to create the profile folder), run the
following command to finish automated setup:

```bash
~/projects/setup/configure/after_signin.sh
```
