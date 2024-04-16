#!/bin/bash

#
# Author: J Dunphy 3/14/2024
#
# Purpose:  Build a zimbra FOSS version based on latest tags in the Zimbra FOSS github for version 8.8.15, 9.0.0 or 10.0.0
#               The end result is there will be a tarball inside the BUILDS directory that can be installed which contains a install.sh script
#
# CAVEAT: Command option --init needs to run as root. Script uses sudo and prompts user when required.
#
#         %%%
#         --tags,--tags9, --tags8 do not work with dry-run. The issue is that we have a cached version of the tags. To generate new tags, takes
#              some time but would be required to figure out tags for a --dry-run for example. Therefore, we exit on tags eventhough --dry-run
#              was specified. We will however have a new cached list of tags that future builds can use. Chicken/Egg problem for --dry-run.
#
# Edit: V Sherwood 4/5/2024
#         Enhance script so that specific releases can be requested rather than just the latest release of a particular Zimbra series
#       J Dunphy  4/16/2024 Ref: https://forums.zimbra.org/viewtopic.php?p=313419#p313419
#         --builder switch and some code recommended from V Sherwood. 
#

buildVersion=1.10
copyTag=0.0
builder="GA"

function find_tag() {
    # find tag that we cloned the zm-build with
    if [ -d "zm-build" ] ; then 
       pushd zm-build

       # Get the current branch name
       copyTag=$(git describe --tags --exact-match)

       # Print the current branch
       echo "Current branch is: $copyTag"
      popd
    fi
}

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
      copyTag=$tag
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
        --upgrade		#echo what needs to be done to upgrade the script
        -V                      #version of this program
        --dry-run               #show what we would do
        --builder foss          # will add to this format for version 10: GAT{tag}C{$release}${builder}
                                #GAT1007C1006foss meaning with zmcontrol -v:
                                #      (built with 10.0.7 tags, and zm_build branch 10.0.6)
        --help

       Example usage:
       $0 --init               # first time only
       $0 --upgrade            # show how get latest version of this script
       $0 --upgrade | sh       # overwrite current version of script with latest version from github
       $0 --version 10         # build latest patch version 10 according to tags
       $0 --version 10.0.6     # build version 10.0.6

       $0 --clean; $0 --version 9  #build version 9 leaving version 10 around
       $0 --clean; $0 --version 8  #build version 8 leaving version 9, 10 around
       $0 --clean; $0 --version 10 --dry-run  #see how to build version 10
       $0 --clean; $0 --version 10 --dry-run | sh  #build version 10
              or
       $0 --clean; $0 --version 10  #build version 10
       $0 --clean; $0 --version 10  --builder FOSS #build version 10 with builder tag FOSS

      WARNING: ********************************************************************************
        the tags are cached. If a new release comes out, you must explicity do this before building if you are using the same directory:

       $0 --clean; $0 --tags

      This is because the tags are cached in a file and need to recalculated again.
      *****************************************************************************************
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
  # %%% not sure but thinking in the future for version 10.1.0
  if [ -d "zm-build" ] ; then /bin/rm -rf zm-build; fi
  ./zm-build-filter-tags-10.sh > ../tags_for_10.txt
  popd
}

function get_tags_9 ()
{
  # requires that it be run in the local directory
  pushd zimbra-tag-helper
  if [ -d "zm-build" ] ; then /bin/rm -rf zm-build; fi
  ./zm-build-filter-tags-9.sh > ../tags_for_9.txt
  popd
}

function get_tags_8 ()
{
  # requires that it be run in the local directory
  # This is EOL already
  pushd zimbra-tag-helper
  ./zm-build-filter-tags-8.sh > ../tags_for_8.txt
  # odd case of how we do release_no
  echo ',8.8.15' >> ../tags_for_8.txt
  popd
}

function strip_newer_tags()
{
  # Trims off the leading tags that are newer than the requested release
  
  # Add [,] to both strings to avoid matching extended release numbers. e.g. 10.0.0-GA when searching for 10.0.0, or 9.0.0.p32.1 when searching for 9.0.0.p32
  tagscomma="$tags,"
  releasecomma="$release,"

  # earlier_releases will either contain the entire tags string if the requested release wasn't found 
  # or the tail of the tags string after the requested release (which could be nothing if the earliest release was requested)
  earlier_releases=${tagscomma#*$releasecomma}

  if [ -n "${earlier_releases}" ]; then
    # Some earlier releases in tags - strip the [,] we added for searching
    earlier_releases=${earlier_releases%?}
  fi
 
  if [ "$tags" == "$earlier_releases" ]; then
    # If earlier_releases contains everything then the requested release does not exist
    echo "Bad release number requested - $release!"
	echo "You must specify a release number from the tag list: $tags"
    exit 0
  else
    if [ -n "$earlier_releases" ]; then
      # There are earlier_releases. Append release[,]earlier_releases to make new tags string for building
      tags="$release,$earlier_releases"
    else
      # There are no earlier_releases. Set tags string to release for building
      tags="$release"
    fi
    echo "Building $release!"
    echo "Tags for build: $tags"
  fi
}

# main program logic starts here
dryrun=0
args=$(getopt -l "init,dry-run,tags,tags8,tags9,help,clean,version:,upgrade,builder:" -o "hV" -- "$@")
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
                --upgrade)
                    echo wget 'https://raw.githubusercontent.com/JimDunphy/ZimbraScripts/master/src/build_zimbra.sh' 
                    exit 0
                    ;;
                --dry-run)
                    dryrun=1
                    ;;
                -V)
                    echo "Version: $buildVersion"
                    exit 0
                    ;;
                --clean)
                    # %%% zimbra-tag-helper has a copy of zm-build.  Probably need to remove that at some point too
                    #     currently removing zm-build in explict tags,tags9 option. What about --dry-run?
                    /bin/rm -rf zm-* j* neko* ant* ical* .staging*
                    exit 0
                    ;;
                --version)
                    version=$2
                    shift
                    ;;
                --builder)
                    builder=$2
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

# check if a specific release version was requested - Format n.n.n[.p[.n]] 

IFS='.' read -ra version_array <<< "$version"
major="${version_array[0]}"
minor="${version_array[1]}"
rev="${version_array[2]}"

if [ -z "${minor}" ] && [ -z "${rev}" ]; then
  echo "Requested latest Zimbra $major release"
else
  release="${version}"
  version="${major}"
  echo "Requested Zimbra $release release"
fi

# tags is a comma seperated list of tags used to make a release to build
case "$version" in
  8)
    if [ ! -f tags_for_8.txt ]; then get_tags_8; fi
    tags="$(cat tags_for_8.txt)"
    if [ -n "$release" ]; then
      strip_newer_tags $tags $release
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | awk -F',' '{print $NF}')
    PATCH_LEVEL=$(echo "$tags" | cut -d ',' -f 1 | awk -F'.' '{print $NF}' | sed 's/[pP]//')
    PATCH_LEVEL="GAP${PATCH_LEVEL}"
    BUILD_RELEASE="JOULE"
    ;;
  9)
    if [ ! -f tags_for_9.txt ]; then get_tags_9; fi
    tags="$(cat tags_for_9.txt)"
    if [ -n "$release" ]; then
      strip_newer_tags $tags $release
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | awk -F',' '{print $NF}')
    PATCH_LEVEL=$(echo "$tags" | cut -d ',' -f 1 | awk -F'.' '{print $NF}' | sed 's/[pP]//')
    PATCH_LEVEL="GAP${PATCH_LEVEL}"
    BUILD_RELEASE="KEPLER"
    ;;
  10)
    if [ ! -f tags_for_10.txt ]; then get_tags; fi
    tags="$(cat tags_for_10.txt)"
    if [ -n "$release" ]; then
      strip_newer_tags $tags $release
    fi
    PATCH_LEVEL="GA"
    LATEST_TAG_VERSION=$(echo "$tags" | cut -d ',' -f 1)
    BUILD_RELEASE="DAFFODIL"
    ;;
  *)
    echo "Possible values: 8 or 9 or 10"
    exit
    ;;
esac


# %%%
# A lot of weird logic that probably doesn't need to be there for --dry-run. If you always do a --clean before issuing a command, 
# none of this would be necessary. 


# pass these on to the Zimbra build.pl script
# 10.0.0 | 9.0.0 | 8.8.15 are possible values
TAGS_STRING=$tags
if  [ -d zm-build ] ; then echo "Warning: did you forget to issue --clean first"; echo performing /bin/rm -rf zm-build;  /bin/rm -rf zm-build; fi
clone_until_success "$tags" >/dev/null 2>&1

# %%% Suggestion for encoding of build for version 10 moving forward. Are there problems?
#     https://forums.zimbra.org/viewtopic.php?p=313419#p313419
#BEGIN version encoding
echo "value of version is: $version"
if [ "$version" == "10" ] && [ ! -z "$builder" ]; then
echo "builder is $builder"
     if [ -z $release ]; then release=$LATEST_TAG_VERSION; fi
     find_tag
     PATCH_LEVEL="GAT${release//./}C${copyTag//./}${builder}"
fi
echo "patch_level is $PATCH_LEVEL"
#END version encoding

# Build the source tree with the specified parameters
if [ $dryrun -eq 1 ]; then

cat << _END_OF_TEXT
#!/bin/sh

git clone --depth 1 --branch "$tag" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="$TAGS_STRING" --build-release-no="$LATEST_TAG_VERSION" --build-type=FOSS --build-release="$BUILD_RELEASE" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=$PATCH_LEVEL


_END_OF_TEXT
exit

else

   cd zm-build
   ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="$TAGS_STRING" --build-release-no="$LATEST_TAG_VERSION" --build-type=FOSS --build-release="$BUILD_RELEASE" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=$PATCH_LEVEL
fi
cd ..

# show completed builds
find BUILDS -name \*.tgz -print

exit
