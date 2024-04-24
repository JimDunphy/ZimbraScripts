#!/bin/bash

# Learning what what is possible with Git
#  Say you have a repository like: ZimbraScripts/src
#    * In src is a bunch of files. You would like to tag one of these files but tags are at the repository level and not file. What to do?
#
# Solution: Write another script called: move-file-repository.sh that will take 2 arguments.
#    * the name of the repository (ZibmraScripts in this example)
#    * the name of the file you want to have its own repository (build_zimbra.sh) in this case.
#   After this script runs, you have a repository named: build_zimbra with a file inside called build_zimbra.sh
#     and all the commit history is preserved in addition to collapsing the src directory and removing the other
#     scripts that were part of the original repository.
#
# Example: 
#   mkdir test; cd test; cp -r ../ZimbraScripts .; ../git-commands/move-file-repository.sh ZimbraScripts src/build_zimbra.sh
# 
# Now to the taging problem. You have kept your own version variable in these programs but would like to have a corresponding
#   git tag associated with this. That is what this script will do. It can also handle holes if you decided to
#   not use tag 1.13 because it is bad luck or didn't have version in your scripot. ;-)
#
#  check results by: git tag 
#
#  Apr 23, 2024 - JDunphy

# Navigate to the repository directory
#cd path/to/build_zimbra

# Store the current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Iterate over each commit
for commit_hash in $(git log --reverse --pretty=format:"%H"); do
  # Checkout each commit
  git checkout $commit_hash

  # Read the version number from build_zimbra.sh. At some point, we changed the name of the variable
  version=$(egrep '(Version=|scriptVersion=)' build_zimbra.sh | cut -d'=' -f2 | tr -d '[:space:]')

  # Check if version is empty and continue if so
  if [ -z "$version" ]; then
    continue
  fi

  # Check if the tag already exists to avoid errors and ensure continuity
  if git rev-parse "v$version" >/dev/null 2>&1; then
    echo "Tag v$version already exists. Skipping..."
  else
    # Tag the commit with the version
    git tag -a "v$version" -m "Version $version"
  fi
done

# Checkout the original branch
git checkout $current_branch

# Push all tags to remote, if desired
# %%% eventually but not now
# git push --tags

echo "All commits have been tagged based on their scriptVersion."
