#!/bin/bash

#
# Author: GPT 4.5
# Human: Jim Dunphy (Mar 24, 2025)
#
# usage: compare_pimbra.sh
#
# Caveat: assumes a repository was checked out for a verson of Zimbra.
#   ie) cd zm-web-client; compare_pimbra.sh
#
#
# Algorithm:
# 1. Determine the current local git tag (e.g., 10.0.12).
# 2. Construct the exact remote tag by appending '-maldua' (e.g., 10.0.12-maldua).
# 3. Check if this exact remote tag exists:
#    a. If yes, use it for comparison.
#    b. If no, find the highest available remote tag matching the same major.minor version
#       pattern with '-maldua' suffix (e.g., 10.0.13-maldua).
# 4. Fetch only the chosen remote tag.
# 5. Perform a diff between the local HEAD and the selected remote tag.
#

set -euo pipefail

REMOTE_NAMESPACE="maldua-pimbra"
REMOTE_TMP="tmp-maldua-remote"

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
REMOTE_URL="git@github.com:${REMOTE_NAMESPACE}/${REPO_NAME}.git"

echo "Local repository: $(git remote get-url origin)"
echo "Remote repository: $REMOTE_URL"

git remote remove "$REMOTE_TMP" &>/dev/null || true
git remote add "$REMOTE_TMP" "$REMOTE_URL"

# Determine local tag explicitly
LOCAL_TAG=$(git describe --tags --exact-match 2>/dev/null || true)
if [ -z "$LOCAL_TAG" ]; then
  echo "No local tag detected. Please checkout a tag first."
  git remote remove "$REMOTE_TMP"
  exit 1
fi

echo "Local tag detected: $LOCAL_TAG"

# Extract major.minor from local tag (e.g., 10.0 from 10.0.12)
VERSION_PREFIX=$(echo "$LOCAL_TAG" | awk -F. '{print $1 "." $2}')

# First try exact match: LOCAL_TAG-maldua
TARGET_REMOTE_TAG="${LOCAL_TAG}-maldua"
echo "Checking remote for exact tag: $TARGET_REMOTE_TAG"

if git ls-remote --exit-code --tags "$REMOTE_URL" "refs/tags/$TARGET_REMOTE_TAG" &>/dev/null; then
  echo "Exact remote tag found: $TARGET_REMOTE_TAG"
else
  echo "Exact remote tag not found. Searching for highest '${VERSION_PREFIX}.*-maldua' tag."

  TARGET_REMOTE_TAG=$(git ls-remote --tags "$REMOTE_URL" "${VERSION_PREFIX}.*-maldua" \
                      | awk '{print $2}' \
                      | sed 's|refs/tags/||' \
                      | sort -Vr \
                      | head -n1)

  if [ -z "$TARGET_REMOTE_TAG" ]; then
    echo "No matching '${VERSION_PREFIX}.*-maldua' tags found remotely."
    git remote remove "$REMOTE_TMP"
    exit 1
  fi

  echo "Selected highest available tag: $TARGET_REMOTE_TAG"
fi

# Fetch ONLY this specific remote tag (fast)
git fetch --quiet "$REMOTE_TMP" "refs/tags/$TARGET_REMOTE_TAG:refs/remotes/$REMOTE_TMP/$TARGET_REMOTE_TAG"

echo "Running diff: Local ($LOCAL_TAG) vs. Remote ($TARGET_REMOTE_TAG)"

# Check for common ancestor to prevent huge unrelated diffs
if ! git merge-base --is-ancestor "HEAD" "$REMOTE_TMP/$TARGET_REMOTE_TAG" && \
   ! git merge-base --is-ancestor "$REMOTE_TMP/$TARGET_REMOTE_TAG" "HEAD"; then
  echo "Warning: Tags don't share common history; diff may be large or unclear."
fi

# Diff without pager
git --no-pager diff HEAD "$REMOTE_TMP/$TARGET_REMOTE_TAG"

git remote remove "$REMOTE_TMP"

