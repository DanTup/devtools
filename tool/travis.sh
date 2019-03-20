#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -e

pushd packages/devtools
echo `pwd`

# Print out the Dart version in use.
dart --version

# Add globally activated packages to the path.
export PATH=$PATH:~/.pub-cache/bin

# We should be using dart from /Users/travis/dart-sdk/bin/dart.
echo "which dart: " `which dart`

# Provision our packages.
pub get
pub global activate webdev

function setupFlutter() {
    # For faster builds, the flutter folders is included in the Travis cache.
    # This code needs to clone it if it doesn't exist, but otherwise fetch
    # and update to latest. Flutter's own logic will take care of refreshing
    # what's in the cache folder if required. If there are no changes,
    # it'll save re-downloading the SDK and other components.
    #
    # Note: This would work better against dev/beta/stable that don't change
    # as often as master!
    mkdir -p flutter
    cd flutter
    if [[ ! -d .git ]]; then
      git init;
      git remote add origin https://github.com/flutter/flutter.git;
    fi
    git fetch
    git reset --hard origin/master
    git checkout origin/master
    cd ..
}

if [ "$BOT" = "main" ]; then

    # Verify that dartfmt has been run.
    echo "Checking dartfmt..."

    if [[ $(dartfmt -n --set-exit-if-changed bin/ lib/ test/ web/) ]]; then
        echo "Failed dartfmt check: run dartfmt -w bin/ lib/ test/ web/"
        dartfmt -n --set-exit-if-changed bin/ lib/ test/ web/
        exit 1
    fi

    # Make sure the app versions are in sync.
    dart tool/version_check.dart

    # Analyze the source.
    pub global activate tuneup && tuneup check

    # Ensure we can build the app.
    pub run build_runner build -o web:build --release

elif [ "$BOT" = "test_ddc" ]; then

    pub run test --reporter expanded --exclude-tags useFlutterSdk
    pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "test_dart2js" ]; then

    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk
    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "flutter_sdk_tests" ]; then

    # Get Flutter.
    cd ..
    export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
    time (
        setupFlutter
        flutter config --no-analytics
        flutter doctor
    )

    # We should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart.
    echo "which dart: " `which dart`

    # Return to the devtools directory.
    cd devtools

    # Run tests that require the Flutter SDK.
    pub run test -j1 --reporter expanded --tags useFlutterSdk

else

    echo "unknown bot configuration"
    exit 1

fi

popd
