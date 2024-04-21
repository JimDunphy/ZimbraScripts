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
#         .build.number file is populated with a starting build in the format IIInnnn where III is a three digit builder id number, greater 
#                            than 100 to avoid dropping digits, and nnnn is a starting baseline build counter. e.g. 1010000
#                            The number will be incremented before the build so the first build would be 1010001. File will be created
#                            automatically but can also be done manually.  BuilderID can be changed using --BuilderID \d\d\d
#
#                            Registered Builders
#                            101 - FOSS and build_zimbra.sh
#                            102 - VSherwood
#                            103 - JDunphy
#                            150 - Generic
#
#                            Note: if you want a reserved number, message JDunphy in Zimbra Community forums or via github
#
# Edit: V Sherwood 4/5/2024
#         Enhance script so that specific releases can be requested rather than just the latest release of a particular Zimbra series
#       J Dunphy  4/16/2024 Ref: https://forums.zimbra.org/viewtopic.php?p=313419#p313419
#         --builder switch and some code recommended from V Sherwood. 
#       V Sherwood 4/18/2024
#         Store .build.number, and add the Requested Tag, git Cloned Tag and Builder Identifier to BUILD_RELEASE 
#       J Dunphy 4/21/2024
#         Cleanup and addition of --BuilderID 
#

buildVersion=1.11
copyTag=0.0
builder="FOSS"
default_number=1011000
build_number_file=".build.number"
debug=0

# Initialize builder_id with a default value. Normally read from the file so not used
builder_id=101

function d_echo() {
    if [ "$debug" -eq 1 ]; then
        echo "$@"
    fi
}


# read the first three digits from a file and set builder_id
function read_builder_id() {

    # if we don't have a builder_id then create the default and file
    if [ ! -f "$build_number_file" ]; then update_builder_no; fi

    # establish the builder_id for this
    if [ -f "$build_number_file" ]; then
        # Read the first line of the file, extract the first three digits
        builder_id=$(head -n 1 "$build_number_file" | grep -o '^[0-9]\{3\}')
        d_echo "Found builder_id is $builder_id"
        if [ -z "$builder_id" ]; then
            echo "No three-digit number found at the start of the file."
            #return 1  # Return a non-zero status to indicate failure
            exit
        fi
    fi
}

# update .build.number or create it with defaults
function update_builder_no() {
    if [ ! -f "$build_number_file" ]; then
        # File does not exist, create it and populate it with the default number
        echo $default_number > $build_number_file
    else
        # File exists, replace the first three digits with the value of $builder_id
        sed -i "s/^[0-9]\{3\}/$builder_id/" $build_number_file
    fi
}

# validate input is a three-digit number
function is_three_digit_number() {
    case $1 in
        [0-9][0-9][0-9]) return 0 ;;  # exactly three digits
        *) return 1 ;;                # not exactly three digits
    esac
}

# %%% no longer used
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
        --BuilderID [\d\d\d]    # 3 digit value starting at 101-999, updates .build.number file with value
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

# Pads version components from 'release' and zm_build branch represented by 'copyTag' to two digits and constructs 
#    formatted 'Build Tag' and 'Clone Tag'.
function zero_pad_tag_and_clone_versions()
{
# check if a specific release version was requested - Format n.n.n[.p[.n]] 

echo "Release $release"
IFS='.' read -ra version_array <<< "$release"
major="00${version_array[0]}"
minor="00${version_array[1]}"
patch="00${version_array[2]}"
build_tag="${major: -2}${minor: -2}${patch: -2}${version_array[3]}${version_array[4]}"
echo "Build Tag $build_tag"
echo "CopyTag $copyTag"
IFS='.' read -ra version_array <<< "$copyTag"
major="00${version_array[0]}"
minor="00${version_array[1]}"
patch="00${version_array[2]}"
clone_tag="${major: -2}${minor: -2}${patch: -2}${version_array[3]}${version_array[4]}"
echo "Clone Tag $clone_tag"
}

#======================================================================================================================
#
#   main program logic starts here
#
#======================================================================================================================

dryrun=0
args=$(getopt -l "init,dry-run,tags,tags8,tags9,help,clean,version:,builder:,BuilderID:,debug" -o "hV" -- "$@")
eval set -- "$args"

# Now process each option in a loop
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
                --debug)
                    debug=1
                    shift
                    ;;
                --BuilderID)
                    if [ -z "$2" ] || ! is_three_digit_number "$2"; then
                        echo "Error: --BuilderID requires a three-digit numeric argument."
                        exit 1
                    fi
                    builder_id=$2
                    update_builder_no		# will create if doesn't exist
                    shift 2 
                    ;;
                --upgrade)
                    echo wget 'https://raw.githubusercontent.com/JimDunphy/ZimbraScripts/master/src/build_zimbra.sh' 
                    exit 0
                    ;;
                --dry-run)
                    dryrun=1
                    shift
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
                    shift 2
                    ;;
                --builder)
                    builder=$2
                    shift 2
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
done

# Processing continues with the only possible options to get here: --builder, --BuilderID, --version

# BuilderID should exit if they are not building a version. They were only updating .build.number
if [[ -n "$builder_id" && -z "$version" ]]; then
    d_echo "quietly existing as we only one to set builder id"
    exit 1
fi

# check if a specific release version was requested - Format n.n.n[.p[.n]] 
IFS='.' read -ra version_array <<< "$version"
major="${version_array[0]}"
minor="${version_array[1]}"
rev="${version_array[2]}"

if [ -z "${minor}" ] && [ -z "${rev}" ]; then
  d_echo "Requested latest Zimbra $major release"
else
  release="${version}"
  version="${major}"
  d_echo "Requested Zimbra $release release"
fi

# tags is a comma seperated list of tags used to make a release to build
case "$version" in
  8)
    if [ ! -f tags_for_8.txt ]; then get_tags_8; fi
    tags="$(cat tags_for_8.txt)"
    if [ -n "$release" ]; then
      strip_newer_tags
    else
      release=$(echo "$tags" | cut -d ',' -f 1)
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | awk -F',' '{print $NF}')
    PATCH_LEVEL="GA"
    BUILD_RELEASE="JOULE"
    ;;
  9)
    if [ ! -f tags_for_9.txt ]; then get_tags_9; fi
    tags="$(cat tags_for_9.txt)"
    if [ -n "$release" ]; then
      strip_newer_tags
    else
      release=$(echo "$tags" | cut -d ',' -f 1)
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | awk -F',' '{print $NF}')
    PATCH_LEVEL="GA"
    BUILD_RELEASE="KEPLER"
    ;;
  10)
    if [ ! -f tags_for_10.txt ]; then get_tags; fi
    tags="$(cat tags_for_10.txt)"
    if [ -n "$release" ]; then
      strip_newer_tags
    else
      release=$(echo "$tags" | cut -d ',' -f 1)
    fi
    LATEST_TAG_VERSION=$(echo "$tags" | cut -d ',' -f 1)
    PATCH_LEVEL="GA"
    BUILD_RELEASE="DAFFODIL"
    ;;
  *)
    echo "Possible values: 8 or 9 or 10"
    exit
    ;;
esac

# pass these on to the Zimbra build.pl script
# 10.0.0 | 9.0.0 | 8.8.15 are possible values
TAGS_STRING=$tags

# Not cacheing this anymore... we will always regenerate the branch even for --dry-run
if  [ -d zm-build ] ; then d_echo "Warning: did you forget to issue --clean first"; d_echo performing /bin/rm -rf zm-build;  /bin/rm -rf zm-build; fi
clone_until_success "$tags" >/dev/null 2>&1

# pads release version and zm_build branch to two digits and constructs formatted $build_tag and $clone_tag
zero_pad_tag_and_clone_versions

# Add the Requested Tag, git Cloned Tag and Builder Identifier to BUILD_RELEASE.
# This will be used in naming the .tgz file output
BUILD_RELEASE="${BUILD_RELEASE}_T${build_tag}C${clone_tag}$builder"

#---------------------------------------------------------------------
# .build.number file contains 7 digits. The first 3 digits represent the builder_id and the other 4 the build no.
#  This file is passed to zm-build/build.pl that will look for it or creates it if absent. It will +1 increment contents.
#  If this file doesn't exist then create a default entry represent FOSS builder id + starting build no.
#  If the file does exist then set $builder_id to value of the first 3 digits
#---------------------------------------------------------------------
read_builder_id

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

  # Copy .build.number into the cloned zm-build. build.pl will increment the number and save it back before the build starts
  cp .build.number zm-build
  cd zm-build
  ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="$TAGS_STRING" --build-release-no="$LATEST_TAG_VERSION" --build-type=FOSS --build-release="$BUILD_RELEASE" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=$PATCH_LEVEL
  # Copy this .build.number back to the parent folder so --clean will not wipe it out.
  cp ${build_number_file} ..
fi
cd ..

# Log the build
build="$(cat "$build_number_file")"
build_tgz="$(ls -1 BUILDS | grep FOSS-$build)"
build_ts="$(date +%Y%m%d-%H%M%S)"
echo "$build_ts  $build  $build_tgz" >> ./builds.log
# show completed builds
find BUILDS -name \*.tgz -print

exit 0
