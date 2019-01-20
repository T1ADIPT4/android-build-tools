#!/bin/bash

# This script will install the Android SDK and NDK, and tell Uno where they are found.
# Note that Java 8 (not 9) is required to install Android SDK.

SDK_VERSION="4333796"

# Begin script
SELF=`echo $0 | sed 's/\\\\/\\//g'`
cd "`dirname "$SELF"`" || exit 1

function fatal-error {
    echo -e "\nERROR: Install failed -- please read output for clues, or open an issue on GitHub." >&2
    echo -e "\nNote that Java 8 (not 9) is required to install Android SDK." >&2
    echo -e "\nTo retry, run:" >&2
    echo -e "\n    bash \"`pwd -P`/install.sh\"\n" >&2
    exit 1
}

trap 'fatal-error' ERR

# Detect platform
case "$(uname -s)" in
Darwin)
    SDK_URL=https://dl.google.com/android/repository/sdk-tools-darwin-$SDK_VERSION.zip
    SDK_DIR=~/Library/Android/sdk
    ;;
Linux)
    SDK_URL=https://dl.google.com/android/repository/sdk-tools-linux-$SDK_VERSION.zip
    SDK_DIR=~/Android/sdk
    ;;
CYGWIN*|MINGW*|MSYS*)
    SDK_URL=https://dl.google.com/android/repository/sdk-tools-windows-$SDK_VERSION.zip
    SDK_DIR=$LOCALAPPDATA/Android/sdk
    IS_WINDOWS=1
    ;;
*)
    echo "ERROR: Unsupported platform $(uname -s)" >&2
    exit 1
    ;;
esac

# Detect JAVA_HOME on Windows
if [[ "$IS_WINDOWS" = 1 && -z "$JAVA_HOME" ]]; then
    root=$PROGRAMFILES/Java

    IFS=$'\n'
    for dir in `ls -1 "$root"`; do
        if [[ "$dir" == jdk1.8.* ]]; then
            export JAVA_HOME=$root/$dir
            echo "Found JDK8 at $JAVA_HOME"
            break
        fi
    done

    if [ -z "$JAVA_HOME" ]; then
        echo "ERROR: The JAVA_HOME variable is not set, and JDK8 was not found in '$root'." >&2
        fatal-error
    fi
fi

# Download SDK
function get-zip {
    url=$1
    dir=$2
    zip=`basename $2`.zip
    rm -rf $zip

    if [ -d $dir ]; then
        echo "Have $dir -- skipping download"
        return
    fi

    echo "Downloading $url"
    curl -s -L $url -o $zip || fatal-error

    echo "Extracting to $dir"
    mkdir -p $dir
    unzip -q $zip -d $dir || fatal-error
    rm -rf $zip
}

get-zip $SDK_URL $SDK_DIR

# Avoid warning from sdkmanager
mkdir -p ~/.android
touch ~/.android/repositories.cfg

# Install packages
function sdkmanager {
    if [ "$IS_WINDOWS" = 1 ]; then
        $SDK_DIR/tools/bin/sdkmanager.bat "$@"
    else
        $SDK_DIR/tools/bin/sdkmanager "$@"
    fi
}

echo "Accepting licenses"
yes | sdkmanager --licenses > /dev/null

function sdkmanager-install {
    if [ -d android-sdk/$1 ]; then
        echo "Have $1 -- skipping install"
    else
        echo "Installing $1"
        yes | sdkmanager $2 > /dev/null
    fi
}

sdkmanager-install ndk-bundle ndk-bundle
sdkmanager-install cmake "cmake;3.6.4111459"

# Emit config file for Uno
# Backticks in .unoconfig can handle unescaped backslashes in Windows paths.
echo "Android.SDK.Directory: \`$SDK_DIR\`" > .unoconfig
echo "Android.NDK.Directory: \`$SDK_DIR/ndk-bundle\`" >> .unoconfig

if [ -n "$JAVA_HOME" ]; then
    echo "Java.JDK.Directory: \`$JAVA_HOME\`" >> .unoconfig
fi

echo -e "\nSaved config:"
cat .unoconfig
