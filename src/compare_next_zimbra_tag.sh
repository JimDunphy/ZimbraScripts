#!/bin/bash

# usage: compare_next_zimbra_tag repository tag
#        compare_next_zimbra_tag zm-web-client 10.0.8
#
# Author: GPT 4.5
# Human: Jim Dunphy Mar 25, 2025
#
# Algorithm:
# 1. Given a Zimbra repository name and specific tag (e.g., zm-web-client 10.0.12).
# 2. Find the next higher numeric tag in the same major.minor series (e.g., 10.0.13).
# 3. If no next higher tag exists, report clearly "No change".
# 4. Fetch only the two relevant tags (current and next highest).
# 5. Compare tags directly:
#    a. If no differences exist, report "No change detected".
#    b. If differences exist, clearly display them.

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <repo-name> <tag>"
  echo "Example: $0 zm-web-client 10.0.12"
  exit 1
fi

REPO_NAME="$1"
CURRENT_TAG="$2"
REMOTE_URL="https://github.com/Zimbra/${REPO_NAME}.git"
TMP_DIR=$(mktemp -d)

echo "Checking Zimbra repo: $REMOTE_URL"
echo "Current tag specified: $CURRENT_TAG"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

git -C "$TMP_DIR" init -q
git -C "$TMP_DIR" remote add origin "$REMOTE_URL"

# Get major.minor prefix (e.g., "10.0")
VERSION_PREFIX=$(echo "$CURRENT_TAG" | awk -F. '{print $1"."$2}')

# Quickly list and numerically sort tags, correctly filtering higher patch numbers
NEXT_TAG=$(git ls-remote --tags "$REMOTE_URL" "${VERSION_PREFIX}.*" \
  | awk '{print $2}' \
  | sed 's|refs/tags/||; s|\^{}||' \
  | sort -t '.' -k1,1n -k2,2n -k3,3n \
  | awk -v curr="$CURRENT_TAG" '
      BEGIN { found=0 }
      {
        if(found) {print; exit}
        if($0 == curr) found=1
      }')

if [ -z "$NEXT_TAG" ]; then
  echo "No higher tag found after '$CURRENT_TAG' in ${VERSION_PREFIX}.* series. No change."
  exit 0
fi

echo "Next higher tag found: $NEXT_TAG"

# Fetch just these two tags quickly
git -C "$TMP_DIR" fetch --quiet --depth 1 origin "refs/tags/$CURRENT_TAG:refs/tags/$CURRENT_TAG"
git -C "$TMP_DIR" fetch --quiet --depth 1 origin "refs/tags/$NEXT_TAG:refs/tags/$NEXT_TAG"

# Check for diffs
if git -C "$TMP_DIR" diff --quiet "$CURRENT_TAG" "$NEXT_TAG"; then
  echo "No change detected between tags '$CURRENT_TAG' and '$NEXT_TAG'."
else
  echo "Changes detected between tags '$CURRENT_TAG' and '$NEXT_TAG':"
  git -C "$TMP_DIR" --no-pager diff "$CURRENT_TAG" "$NEXT_TAG"
fi

