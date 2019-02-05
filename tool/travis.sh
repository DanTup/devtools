#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

# Download dart
echo Downloading Dart...
if [[ $TRAVIS_OS_NAME == "osx" ]]; then
    export DART_OS=macos;
elif [[ $TRAVIS_OS_NAME == "linux" ]]; then
    export DART_OS=linux;
else
    export DART_OS=windows;
fi
curl https://storage.googleapis.com/dart-archive/channels/$DART_CHANNEL/latest/sdk/dartsdk-$DART_OS-x64-release.zip > dart-sdk.zip
unzip dart-sdk.zip > /dev/null
echo Adding to PATH
export PATH=$PATH:`pwd`/dart-sdk/bin
if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    export PATH=$PATH:$APPDATA/Roaming/Pub/Cache/bin
else
    export PATH=$PATH:$HOME/.pub-cache/bin
fi

pushd packages/devtools
echo `pwd`

# In GitBash on Windows, we have to call pub.bat so we alias `pub` in this script to call the
# correct one based on the OS.
function pub {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command pub.bat "$@"
    else
        command pub "$@"
    fi
}
function flutter {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command flutter.bat "$@"
    else
        command flutter "$@"
    fi
}

# Print out the versions and ensure we can call both Dart and Pub.
dart --version
pub --version

# Add globally activated packages to the path.
export PATH=$PATH:~/.pub-cache/bin

# Provision our packages.
pub get

if [ "$BOT" = "main" ]; then

    # Verify that dartfmt has been run.
    echo "Checking dartfmt..."

    if [[ $(dartfmt -n --set-exit-if-changed bin/ lib/ test/ web/) ]]; then
        echo "Failed dartfmt check: run dartfmt -w bin/ lib/ test/ web/"
        dartfmt -n --set-exit-if-changed bin/ lib/ test/ web/
        exit 1
    fi

    # Analyze the source.
    pub global activate tuneup && tuneup check

    # Ensure we can build the app.
    pub run webdev build

elif [ "$BOT" = "test_ddc" ]; then

    pub run test --reporter expanded --exclude-tags useFlutterSdk
    pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "test_dart2js" ]; then

    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk
    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "flutter_sdk_tests" ]; then

    # Get Flutter.
    git clone https://github.com/flutter/flutter.git ../flutter
    cd ..
    export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
    flutter config --no-analytics
    flutter doctor

    # We should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart.
    echo "which dart: " `which dart`

    # Return to the devtools directory.
    cd devtools

    # Run tests that require the Flutter SDK.
    pub run test --reporter expanded --tags useFlutterSdk

else

    echo "unknown bot configuration"
    exit 1

fi

popd
