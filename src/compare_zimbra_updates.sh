#!/bin/bash

#
# Author: GPT 4.5
# Human: Jim Dunphy (Mar 24, 2025)
#
# usage: compare_zimbra_updates.sh
#
# Caveat: assumes a repository was checked out for a verson of Zimbra.
#   ie) cd zm-web-client; compare_zimbra_updates.sh
#
# Algorithm:
# 1. Determine the current local git tag (e.g., 10.0.13).
# 2. Identify the highest available remote tag from Zimbra's GitHub repository 
#    within the same major.minor series (e.g., 10.0.*).
# 3. If the local tag is already the highest, report that no update is needed.
# 4. Otherwise, fetch the highest remote tag explicitly.
# 5. Compare local HEAD with the fetched remote tag:
#    a. If no differences, report "No change detected".
#    b. If differences exist, clearly display them.

set -euo pipefail

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
REMOTE_URL="https://github.com/Zimbra/${REPO_NAME}.git"
REMOTE_TMP="tmp-zimbra-remote"

echo "Local repository: $(git remote get-url origin)"
echo "Checking Zimbra official repository: $REMOTE_URL"

git remote remove "$REMOTE_TMP" &>/dev/null || true
git remote add "$REMOTE_TMP" "$REMOTE_URL"

LOCAL_TAG=$(git describe --tags --exact-match 2>/dev/null || true)

if [ -z "$LOCAL_TAG" ]; then
  echo "Please checkout a tagged version first. No local tag detected."
  git remote remove "$REMOTE_TMP"
  exit 1
fi

echo "Local tag detected: $LOCAL_TAG"

# Get major.minor from local tag (e.g., 10.0 from 10.0.13)
VERSION_PREFIX=$(echo "$LOCAL_TAG" | awk -F. '{print $1"."$2}')

# Find the highest available remote tag in the same major.minor series
HIGHEST_REMOTE_TAG=$(git ls-remote --tags "$REMOTE_URL" "${VERSION_PREFIX}.*" \
                      | awk '{print $2}' \
                      | sed 's|refs/tags/||; s|\^{}||' \
                      | sort -Vr \
                      | head -n1)

if [ -z "$HIGHEST_REMOTE_TAG" ]; then
  echo "No remote tags matching '${VERSION_PREFIX}.*' found."
  git remote remove "$REMOTE_TMP"
  exit 1
fi

echo "Highest remote tag found: $HIGHEST_REMOTE_TAG"

# Check if local tag is already the latest
if [ "$LOCAL_TAG" == "$HIGHEST_REMOTE_TAG" ]; then
  echo "You are already on the latest tag ($LOCAL_TAG). No updates."
  git remote remove "$REMOTE_TMP"
  exit 0
fi

# Fetch only the target remote tag quickly
git fetch --quiet "$REMOTE_TMP" "refs/tags/$HIGHEST_REMOTE_TAG:refs/remotes/$REMOTE_TMP/$HIGHEST_REMOTE_TAG"

# Check for differences between tags quickly
if git diff --quiet "HEAD" "$REMOTE_TMP/$HIGHEST_REMOTE_TAG"; then
  echo "No change detected between local tag ($LOCAL_TAG) and remote tag ($HIGHEST_REMOTE_TAG)."
else
  echo "Changes detected between local tag ($LOCAL_TAG) and remote tag ($HIGHEST_REMOTE_TAG):"
  git --no-pager diff "HEAD" "$REMOTE_TMP/$HIGHEST_REMOTE_TAG"
fi

git remote remove "$REMOTE_TMP"

