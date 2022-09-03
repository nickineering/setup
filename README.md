# Nick's Mac setup

Everything I need to painlessly setup a new Mac.

# Get started now

This repository should be locally cloned to your home directory. If not move it there
now. Run `chmod +x install.sh && ./install.sh 3.10.6` to install the automated
components. The final parameter is the version of Python you want to install. You will
then have to manually do the following:

1. [Generate a new GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
   and configure git to sign commits with it
1. Add yours favorite applications to the Dock
1. Add languages and virtual keyboards to the OS
1. Pair your bluetooth devices

Then run the following git commands:

```bash
git config --global user.name "Your Name"
git config --global user.email "Your email"
git config --global user.signingkey "Your gpg key"
```

Finally, you will need to activate:

1. 1Password
1. AWS CLI: `awscli`
1. Chrome - all profiles
1. Docker
1. Firefox
1. Github CLI: `gh`
1. Kindle
1. NordVPN
1. Pull Requests (VSCode)
1. Signal
1. Skype
1. Spotify
1. WhatsApp
1. Xcode
1. Zoom
