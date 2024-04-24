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
#     % mkdir junk
#     % cp -r ZimbraScripts junk/
#     % cd junk
#     % ../git-commands/move-file-repository.sh ZimbraScripts src/build_zimbra.sh
#     % ls build_zimbra
#        build_zimbra.sh
#
#  Apr 23, 2024 - JDunphy

# Define variables
REPO_URL="$1"
FILE_PATH="$2"
FILE_NAME=$(basename -- "$FILE_PATH")
REPO_NAME="${FILE_NAME%.*}"  # Remove file extension

# Clone the repository
git clone "$REPO_URL" "$REPO_NAME"
cd "$REPO_NAME"

# Filter the repository to only include the specified file
git filter-repo --path "$FILE_PATH" --force

# Move the file to the root directory and update the path in the history
git filter-repo --path-rename "${FILE_PATH}:${FILE_NAME}"

# Remove the original remote and add a new one if needed
git remote remove origin
# git remote add origin <new-repository-url>

# Commit the path change if needed
git add .
git commit -m "Move ${FILE_NAME} to root directory and update paths in history"

# Clean up and reduce the repository size
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "Repository for ${FILE_NAME} has been created as ${REPO_NAME}, with all paths updated."

# End of the script

