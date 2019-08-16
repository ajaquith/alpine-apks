#!/bin/bash
#
# Runs an abuild command on an Alpine APK package. Both parameters are supplied
# as a parameter to this script.
#
#
ABUILD_VALID_CMDS="build check checksum clean cleancache cleanoldpkg \
cleanpkg deps fetch index listpkg package prepare \
rootbld rootpkg sanitycheck snapshot sourcecheck \
srcpkg undeps unpack up2date verify"

# Verify that the first param is a package (subdir)
if [ ! -d $PWD/$1 ]
then
  echo "Package not found: $1."
  echo "Usage: ./abuild.sh my-package abuild_command"
  exit 1
fi

# If second param not passed, use -r as abuild command. If supplied, validate.
ABUILD_CMD="-r"
if [ -n "$2" ]
then
  ABUILD_CMD=$2
  if [[ ! " $ABUILD_VALID_CMDS " =~ " $ABUILD_CMD " ]]
  then
    echo "Invalid abuild command: $ABUILD_CMD"
    echo "Usage: ./abuild.sh my-package abuild_command"
    exit 1
  fi
fi

# Rebuild checksums
docker run \
        -e PACKAGER="Andrew Jaquith <ajaquith@apache.org>" \
        -e RSA_PRIVATE_KEY="$(cat ~/.ssh/alpine/alpine-devel@markerbench.com-5d56c244.rsa)" \
        -e RSA_PRIVATE_KEY_NAME="alpine_apk.rsa" \
        -e RSA_PUBLIC_KEY="$(cat ~/.ssh/alpine/alpine-devel@markerbench.com-5d56c244.rsa.pub)" \
        -v $PWD/$1:/package \
        -v $PWD/packages/:/packages \
        -v $PWD/etc/apk/keys:/etc/apk/keys \
        craftdock/apk-builder abuild $ABUILD_CMD
