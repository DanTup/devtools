// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:test/test.dart';

import 'app.dart';
import 'debugger.dart';
import 'integration.dart';
import 'logging.dart';

void main() {
  group('integration', () {
    setUpAll(() async {
      print('setUpAll #1');
      final bool testInReleaseMode =
          Platform.environment['WEBDEV_RELEASE'] == 'true';

      print('setUpAll #2');
      webdevFixture =
          await WebdevFixture.create(release: testInReleaseMode, verbose: true);
      print('setUpAll #3');
      browserManager = await BrowserManager.create();
      print('setUpAll #4');
    });

    tearDownAll(() async {
      print('tearDownAll #1');
      await browserManager?.teardown();
      print('tearDownAll #2');
      await webdevFixture?.teardown();
      print('tearDownAll #3');
    });

    group('app', appTests);
    group('logging', loggingTests);
    group('debugging', debuggingTests);
  }, timeout: const Timeout.factor(15));
}
