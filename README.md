# Nick's Mac setup

Everything I need to painlessly setup a new Mac.

# Get started now

This repository should be locally cloned to your home directory. If not move it there
now. Run `sudo chmod 700 entry.sh && ./entry.sh` to install the automated components.
You will then have to manually do the following:

1. Install Onyx to customise your Mac settings beyond system preferences
1. Generate a GPG key and configure git to sign commits with it
1. Add your frequently used applications to the Dock
1. Add keyboards for different languages

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
4. Firefox
5. Github
6. Pull Requests (VSCode)
7. Xcode
