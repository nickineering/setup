#!/bin/bash

# Some aliases credit: https://github.com/alrra/dotfiles/blob/main/src/git/gitconfig

# Amend last commit to credit author: $1=name, $2=email
function credit {
    if [ -n "$1" ] && [ -n "$2" ]; then
        git commit --amend --author "$1 <$2>" --no-edit --reuse-message=HEAD;
    fi
}

# Amend last commit to credit co-author: $1=name, $2=email
function credit-co-author {
    if [ -n "$1" ] && [ -n "$2" ]; then
        GIT_EDITOR="git interpret-trailers --in-place --trailer='Co-authored-by: $1 <$2>'" git commit --amend;
    fi
}

# Delete all local branches other than current
function delete-branches {
    git branch | grep -v '^*' | xargs git branch -D;
}

# Reset to wherever origin for this branch is, but leave local files alone
function reset-to-origin {
    branch=$(git branch --show-current)
    git reset origin/"$branch"
}

# Interactive rebase. $1=STEPS_BACK_FROM_HEAD / default=10
function interactive-rebase {
    git rebase --interactive HEAD~"${1:-10}";
}

# Rename a branch locally and remote. $1=NEW_NAME, $2=OLD_NAME
# Credit: https://gist.github.com/DamirPorobic/5be1a47d11c2c7444ddb171d19b4919e
function rename-branch() {
    # Check if the user has provided input
    if [ $# -ne 2 ]; then
        echo "$0": usage: rename-branch OLD_BRANCH_NAME NEW_BRANCH_NAME
        exit 1
    fi

    OLD_BRANCH_NAME=$1
    NEW_BRANCH_NAME=$2

    # Check if old branch exists
    BRANCH_EXISTS="$(git show-ref refs/heads/"$OLD_BRANCH_NAME")"
    if [ -z "$BRANCH_EXISTS" ]; then
        echo There is no branch with name "$OLD_BRANCH_NAME"
        exit 1
    fi

    # Rename branch
    echo Renaming branch "$OLD_BRANCH_NAME" to "$NEW_BRANCH_NAME"
    git branch "$NEW_BRANCH_NAME" origin/"$OLD_BRANCH_NAME"
    git push origin --set-upstream "$NEW_BRANCH_NAME"
    git push origin :"$OLD_BRANCH_NAME"

    # Fetch and prune origin
    echo Cleaning up local repo
    git branch -D "$OLD_BRANCH_NAME"
    git fetch origin
    git remote prune origin
    echo Done.
}

# Remove tag if it exists and then tag the latest commit with that name: $1=TAG_NAME
function retag {
    git tag --delete "$1" &> /dev/null;
    git tag "$1";
}

# Remove last commits: $1=NUM_TO_REMOVE / default=1
function remove-last-commits {
    number_of_commits="${1:-1}";
    git reset --hard "HEAD~$number_of_commits";
}

# Search commits by source code: $1=CODE
function search-for-commits {
    git log --date=short --decorate --pretty=colorful -S"$1";
}

# Search commits by commit message: $1=COMMIT_MESSAGE
function search-for-message {
    git log --date=short --decorate --pretty=colorful --grep="$1";
}

# Search for snippet in history: $1=SNIPPET
function search-for-snippet {
    git rev-list --abbrev-commit --all | xargs git grep -F "$1";
}

# Go to root folder, checkout master, and pull
function start {
    git rev-parse --show-toplevel;
    git checkout master || git checkout main;
    git pull;
}

# Undo last commits, while preserving files: $1=NUM_TO_UNDO / default=1
function undo-last-commits {
    number_of_commits="${1:-1}";
    git reset --soft "HEAD~$number_of_commits";
}
