#!/bin/bash

# Some aliases credit: https://github.com/alrra/dotfiles/blob/main/src/git/gitconfig

# Commit with message $1, and push
commit () {
    git commit -v -m "$0"
    git push
}

# Add all files in current directory, commit with message $1, and push
commit-all () {
    git add .
    commit "$0"
}

# Amend last commit to credit co-author: $1=name, $2=email
credit () {
    if [ -n "$1" ] && [ -n "$2" ]; then
        GIT_EDITOR="git interpret-trailers --in-place --trailer='Co-authored-by: $1 <$2>'" git commit --amend;
    fi
}

# Delete all local branches other than current
delete-branches () {
    git branch | grep -v '^*' | xargs git branch -D;
}

# Reset to wherever origin for this branch is, but leave local files alone
reset-to-origin () {
    local branch
    branch=$(git branch --show-current)
    git reset origin/"$branch"
}

# Interactive rebase. $1=STEPS_BACK_FROM_HEAD / default=10
interactive-rebase () {
    git rebase --interactive HEAD~"${1:-10}";
}

# Rename a branch locally and remote. $1=NEW_NAME, $2=OLD_NAME
# Credit: https://gist.github.com/DamirPorobic/5be1a47d11c2c7444ddb171d19b4919e
rename-branch () {
    # Check if the user has provided input
    if [ $# -ne 2 ]; then
        echo "$0": usage: rename-branch OLD_BRANCH_NAME NEW_BRANCH_NAME
        exit 1
    fi

    local old_name=$1
    local new_name=$2

    # Check if old branch exists
    local old_branch_exists
    old_branch_exists="$(git show-ref refs/heads/"$old_name")"
    if [ -z "$old_branch_exists" ]; then
        echo There is no branch with name "$old_name"
        exit 1
    fi

    # Rename branch
    echo Renaming branch "$old_name" to "$new_name"
    git branch "$new_name" origin/"$old_name"
    git push origin --set-upstream "$new_name"
    git push origin :"$old_name"

    # Fetch and prune origin
    echo Cleaning up local repo
    git branch -D "$old_name"
    git fetch origin
    git remote prune origin
    echo Done.
}

# Remove tag if it exists and then tag the latest commit with that name: $1=TAG_NAME
retag () {
    git tag --delete "$1" &> /dev/null;
    git tag "$1";
}

# Search commits by source code: $0=CODE
search-for-commits () {
    git log --date=short --decorate --pretty=colorful -S"$0";
}

# Search commits by commit message: $0=COMMIT_MESSAGE
search-for-message () {
    git log --date=short --decorate --pretty=colorful --grep="$0";
}

# Search for snippet in history: $0=SNIPPET
search-for-snippet () {
    git rev-list --abbrev-commit --all | xargs git grep -F "$0";
}

# Go to root folder, checkout master, and pull
start () {
    git rev-parse --show-toplevel;
    git checkout master || git checkout main;
    git pull;
}

# Undo last commits, while preserving files: $1=NUM_TO_UNDO / default=1
undo-last-commits () {
    git reset --soft "HEAD~${1:-1}";
}

# Wipe last commits: $1=NUM_TO_WIPE / default=1
wipe-last-commits () {
    git reset --hard "HEAD~${1:-1}";
}

# Delete all local changes so that local is the same as remote
wipe-local () {
    local branch
    branch=$(git branch --show-current)
    git reset --hard origin/"$branch"
}
