#!/bin/bash

#
# Author: J Dunphy 3/14/2024
#
# Purpose:  Build a zimbra FOSS version based on latest tags in the Zimbra FOSS github for version 8.8.15, 9.0.0 or 10.0.0
#               The end result is there will be a tarball inside the BUILDS directory that can be installed which contains a install.sh script
#
# CAVEAT: Command option --init needs to run as root. Script uses sudo and prompts user when required.
#
#
buildVersion=1.1

# Fine the latest zm-build we can check out
function clone_until_success() {
  local tags=$1
  local repo_url=$2
  
  IFS=',' read -ra TAG_ARRAY <<< "$tags"
  for tag in "${TAG_ARRAY[@]}"; do
    echo "Attempting to clone branch $tag..."
    if git clone --depth 1 --branch "$tag" "git@github.com:Zimbra/zm-build.git"; then
      echo "Successfully cloned branch $tag"
      echo "git clone --depth 1 --branch $tag git@github.com:Zimbra/zm-build.git"
      return
    else
      echo "Failed to clone branch $tag. Trying the next tag..."
    fi
  done
  
  echo "All attempts failed. Unable to clone the repository with the provided tags."
}

# Tools that make this possible
function clone_if_not_exists() {
  # Extract the repo name from the URL
  repo_name=$(basename "$1" .git)

  # Check if the directory already exists
  if [ -d "$repo_name" ]; then
    echo "Repository $repo_name already exists locally."
    return
  else
    # Clone the repository
    git clone "$1"
    echo "Repository $repo_name cloned successfully."
  fi
}

# Run one time only
function init ()
{
   # Get supporting scripts that we will use
   clone_if_not_exists https://github.com/ianw1974/zimbra-build-scripts
   clone_if_not_exists https://github.com/maldua/zimbra-tag-helper

   # We need another filter script for verison 8.8.15. 
   cp zimbra-tag-helper/zm-build-filter-tags-9.sh zimbra-tag-helper/zm-build-filter-tags-8.sh
   sed -i 's/MAIN_BRANCH="9.0"/MAIN_BRANCH="8.8.15"/' zimbra-tag-helper/zm-build-filter-tags-8.sh

   echo "Will need to run next command as root to install system dependicies and tools"
   sudo zimbra-build-scripts/zimbra-build-helper.sh --install-deps
}


function usage() {
   echo "
        $0
        --init			#first time to setup envioroment (only once)
        --version [10|9|8]      #build release 8.8.15 or 9.0.0 or 10.0.0
        --clean                 #remove everything but BUILDS
        --tags			#create tags for version 10
        --tags8			#create tags for version 8
        --tags9			#create tags for version 9
        -V                      #version of this program
        --help

       Example usage:
       $0 --init               # first time only
       $0 --version 10         # build version 10

       $0 --clean; $0 --version 9  #build version 9 leaving version 10 around
       $0 --clean; $0 --version 8  #build version 8 leaving version 9, 10 around
  "
}

function isRoot() {
   # need to run as root because local cache has perm problem
   ID=`id -u`
   if [ "x$ID" != "x0" ]; then
     echo "Run as root!"
     exit 1
   fi
}

function get_tags ()
{
  # requires that it be run in the local directory
  pushd zimbra-tag-helper
  ./zm-build-filter-tags-10.sh > ../tags_for_10.txt
  popd
}

function get_tags_9 ()
{
  # requires that it be run in the local directory
  pushd zimbra-tag-helper
  ./zm-build-filter-tags-9.sh > ../tags_for_9.txt
  popd
}

function get_tags_8 ()
{
  # requires that it be run in the local directory
  pushd zimbra-tag-helper
  ./zm-build-filter-tags-8.sh > ../tags_for_8.txt
  # odd case of how we do release_no
  echo ',8.8.15' >> ../tags_for_8.txt
  popd
}

# main program logic starts here
args=$(getopt -l "init,tags,tags8,tags9,help,clean,version:" -o "d:hV" -- "$@")
eval set -- "$args"

while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
                    shift
                    break
                    ;;
                --init)
                    init
                    exit 0
                    ;;
                -V)
                    echo "Version: $buildVersion"
                    exit 0
                    ;;
                --clean)
                    /bin/rm -rf zm-* j* neko* ant* ical*
                    exit 0
                    ;;
                --version)
                    version=$2
                    shift
                    ;;
                --tags)
                    get_tags
                    exit 0
                    ;;
                --tags9)
                    get_tags_9
                    exit 0
                    ;;
                --tags8)
                    get_tags_8
                    exit 0
                    ;;
                -h|--help)
                    usage
                    exit 0
                    ;;
        esac

        shift
done

# tags is a comma seperated list of tags used to make a release to build
case "$version" in
  8)
    if [ ! -f tags_for_8.txt ]; then get_tags_8; fi
    tags="$(cat tags_for_8.txt)"
    ;;
  9)
    if [ ! -f tags_for_9.txt ]; then get_tags_9; fi
    tags="$(cat tags_for_9.txt)"
    ;;
  10)
    if [ ! -f tags_for_10.txt ]; then get_tags; fi
    tags="$(cat tags_for_10.txt)"
    ;;
  *)
    echo "Possible values: 8 or 9 or 10"
    exit
    ;;
esac


# pass these on to the Zimbra build.pl script
# 10.0.0 | 9.0.0 | 8.8.15 are possible values
TAGS_STRING=$tags
LATEST_TAG_VERSION=$(echo "$tags" | awk -F',' '{print $NF}')
PATCH_LEVEL=$(echo "$tags" | cut -d ',' -f 1 | awk -F'.' '{print $NF}' | sed 's/[pP]//')
PATCH_LEVEL="GA_P${PATCH_LEVEL}"

# find appropriate branch to checkout
clone_until_success "$tags" 

cd zm-build
# Build the source tree with the specified parameters
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="$TAGS_STRING" --build-release-no="$LATEST_TAG_VERSION" --build-type=FOSS --build-release=DAFFODIL --build-release-candidate=GA --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=$PATCH_LEVEL
cd ..

# show completed builds
find BUILDS -name \*.tgz -print

exit
