// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../support/cli_test_driver.dart';
import 'integration.dart';

void loggingTests() {
  CliAppFixture appFixture;
  BrowserTabInstance tabInstance;

  setUp(() async {
    print('setUp #1');
    appFixture = await CliAppFixture.create('test/fixtures/logging_app.dart');
    print('setUp #2');
    tabInstance = await browserManager.createNewTab();
    print('setUp #3');
  });

  tearDown(() async {
    print('tearDown #1');
    await tabInstance?.close();
    print('tearDown #2');
    await appFixture?.teardown();
    print('tearDown #3');
  });

  test('displays log data', () async {
    print('test #1');
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    print('test #2');
    await tools.start(appFixture);
    await tools.switchPage('logging');

    print('test #4');
    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');

    // Cause app to log.
    print('test #6');
    final LoggingManager logs = LoggingManager(tools);
    print('test #7');
    await logs.clearLogs();
    print('test #8');
    expect(await logs.logCount(), 0);
    print('test #9');
    await appFixture.invoke('controller.emitLog()');

    // Verify the log data shows up in the UI.
    print('test #10');
    await waitFor(() async => await logs.logCount() > 0);
    print('test #11');
    expect(await logs.logCount(), greaterThan(0));
    print('test #12');
  });

  test('log screen postpones write when offscreen', () async {
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logging');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');

    final LoggingManager logs = LoggingManager(tools);

    // Verify that the log is empty.
    expect(await logs.logCount(), 0);

    // Switch to a different page.
    await tools.switchPage('timeline');

    // Cause app to log.
    await appFixture.invoke('controller.emitLog()');

    // Verify that the log is empty.
    expect(await logs.logCount(), 0);

    // Switch to the logs page.
    await tools.switchPage('logging');

    // Verify the log data shows up in the UI.
    await waitFor(() async => await logs.logCount() > 0);
    expect(await logs.logCount(), greaterThan(0));
  }, skip: true);
}

class LoggingManager {
  LoggingManager(this.tools);

  final DevtoolsManager tools;

  Future<void> clearLogs() async {
    await tools.tabInstance.send('logging.clearLogs');
  }

  Future<int> logCount() async {
    print('Requesting logCount');
    final AppResponse response =
        await tools.tabInstance.send('logging.logCount');
    print('Got logCount!');
    return response.result;
  }
}
