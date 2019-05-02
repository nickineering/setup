# mac-init

Everything needed to produce a working RCVS development Mac setup

# Get started now

Run `sudo chmod 700 entry.sh && ./entry.sh` to install the automated components. You
will then have to manually install the following:

1. Adobe XD from within Adobe Creative Cloud
2. Onyx to customise your Mac settings beyond system preferences
3. [Display Link drivers](https://www.displaylink.com/downloads/macos) for dongle

You will also need to:
Generate a GPG key and configure git to sign commits with it
Add your frequently used applications to the doc

To run the following git commands:

```bash
git config --global user.name "Your Name"
git config --global user.email "Your email"
git config --global user.signingkey "Your gpg key"
```

Finally, you will need to activate:
1Password
awscli
Chrome
Datagrip
expo
Firefox
Github Pull Requests (VSCode)
Microsoft Office
Microsoft Teams
Snagit
Xcode

The following is great optional software:
[Kaliedoscope](https://www.kaleidoscopeapp.com) $ - File comparison
[Omnigraffle](https://www.omnigroup.com/omnigraffle) $ - Like Visio, but good
[Parallels](https://www.parallels.com/uk) $ - Run Windows apps on Mac
[Tableau](https://www.tableau.com/en-gb/products/desktop) $ - Data visualisation
[Tableau Prep](https://www.tableau.com/en-gb/products/prep) $ - Data prep
[Transmit](https://panic.com/transmit) $ - FTP client

Do not manually edit your .bash_profile unless you intend to update the repository!
