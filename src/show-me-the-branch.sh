#!/bin/bash

#
# March 13, 2024: 
#   Author: GPT-4+ and directed by JDunphy
#
# Demonstration of an inside joke showing the insane process for FOSS builds for each patch release of 10
#   Provided they stay consistent, it does work however.
#
# Ref: https://forums.zimbra.org/viewtopic.php?t=72627
#
#
# usage: Build me zimbra based on tags and not latest checked in.
#
#       % show_me_the_branch.sh 7     #will build 10.0.7
#       % show_me_the_branch.sh       #will build 10.0.7
#       % show_me_the_branch.sh 8     #will build 10.0.8
#
# Description: This will checkout the correct branch and generate a shell script to be used to compile Zimbra 
#              which will generate a tarball of the release you attempted to build
#
# Pre-Requisites: You have a build envionment for supported versions of Zimbra. 
#
#       Simpleset way is to use Ian's zimbra-build-scripts
#
#       % mkdir build-zimbra
#       % cd build-zimbra
#       % git clone https://github.com/ianw1974/zimbra-build-scripts
#       % zimbra-build-scripts/zimbra-build-helper.sh --install-deps
#
#   ************ READ THIS *****************
# Caveat: This script leaves a checked out branch of zm_build which must be removed prior to
#        running this script again.
#

VERSION=0.0   # there will be no other version ;-) 

# Define the base repository
REPO_URL="git@github.com:Zimbra/zm-build.git"
BASE_VERSION="10.0"

# Use the first command line argument as the latest tag version; default to 7 if not provided
LATEST_TAG_VERSION=${1:-7}

TAG_FOUND=false

# Function to clone the repository for a specific version
clone_repo() {
    git clone --depth 1 --branch "$BASE_VERSION.$1" $REPO_URL
    if [ $? -eq 0 ]; then
        TAG_FOUND=true
        echo "Successfully cloned $REPO_URL with tag $BASE_VERSION.$1."
        return 0
    else
        echo "Failed to clone $REPO_URL with tag $BASE_VERSION.$1."
        return 1
    fi
}

# Try cloning the repo from the latest tag version down to 0
for (( version=$LATEST_TAG_VERSION; version>=0; version-- )); do
    if clone_repo $version; then
        break
    fi
done

# Check if a tag was found and cloned successfully
if [ "$TAG_FOUND" = false ]; then
    echo "Unable to clone any tags from $REPO_URL."
    exit 1
fi

# Populate TAGS with all versions from the successful version down to 0
for (( version=$LATEST_TAG_VERSION; version>=0; version-- )); do
    if [ $version -eq 0 ]; then
        # Add special cases for version 0
        TAGS+=("$BASE_VERSION.0-GA")
        TAGS+=("$BASE_VERSION.0")
    else
        TAGS+=("$BASE_VERSION.$version")
    fi
done

# Change directory to zm-build
cd zm-build

# Convert TAGS array to a comma-separated list for the build command
TAGS_STRING=$(IFS=,; echo "${TAGS[*]}")

echo "_____________ Zimbra build script for Release: $BASE_VERSION.$LATEST_TAG_VERSION ________________"

cat << _END_OF_TEXT_ 
#!/bin/sh

export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/home/jad/bin:/usr/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin

cd zm-build

# Build the source tree with the specified parameters
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="$TAGS_STRING" --build-release-no="$BASE_VERSION.$LATEST_TAG_VERSION" --build-type=FOSS --build-release=DAFFODIL --build-release-candidate=GA --build-thirdparty-server=files.zimbra.com --no-interactive

_END_OF_TEXT_


