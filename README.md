# mac-init

Everything needed to produce a working RCVS development Mac setup

# Get started now

this repository should be locally cloned into your home directory. If not move it there
now. Run `sudo chmod 700 entry.sh && ./entry.sh` to install the automated components.
You will then have to manually do the following:

1. Install Adobe XD from within Adobe Creative Cloud
2. Install Onyx to customise your Mac settings beyond system preferences
3. Install [Display Link drivers](https://www.displaylink.com/downloads/macos) for
   dongle
4. Generate a GPG key and configure git to sign commits with it
5. Add your frequently used applications to the doc
6. Add a British keyboard for the external keyboard in addition to the built in keyboard
7. Get connected to the staff WiFi
8. Mount the RCVS fileserver

Then run the following git commands:

```bash
git config --global user.name "Your Name"
git config --global user.email "Your email"
git config --global user.signingkey "Your gpg key"
```

Finally, you will need to activate:

1. 1Password
2. awscli
3. Chrome
4. Datagrip
5. expo
6. Firefox
7. Github
8. Pull Requests (VSCode)
9. Microsoft Office
10. Microsoft Teams
11. Snagit
12. Xcode

The following is great paid optional software:

1. [Kaliedoscope](https://www.kaleidoscopeapp.com) - File comparison
2. [Omnigraffle](https://www.omnigroup.com/omnigraffle) - Like Visio, but good
3. [Parallels](https://www.parallels.com/uk) - Run Windows apps on Mac
4. [Tableau](https://www.tableau.com/en-gb/products/desktop) - Data visualisation
5. [Tableau Prep](https://www.tableau.com/en-gb/products/prep) - Data prep
6. [Transmit](https://panic.com/transmit) - FTP client
