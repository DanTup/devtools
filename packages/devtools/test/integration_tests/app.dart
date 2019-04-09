// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../support/cli_test_driver.dart';
import 'integration.dart';

void appTests() {
  CliAppFixture appFixture;
  BrowserTabInstance tabInstance;

  setUp(() async {
    print('${DateTime.now()} SU1');
    appFixture = await CliAppFixture.create('test/fixtures/logging_app.dart');
    print('${DateTime.now()} SU2');
    tabInstance = await browserManager.createNewTab();
    print('${DateTime.now()} SU3');
  });

  tearDown(() async {
    print('${DateTime.now()} TD1');
    await tabInstance?.close();
    print('${DateTime.now()} TD2');
    await appFixture?.teardown();
    print('${DateTime.now()} TD3');
  });

  test('can switch pages', () async {
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('logging');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'logging');
  });

  test('connect dialog displays', () async {
    print('${DateTime.now()} CDD1');
    // start with no port
    final Uri baseAppUri = webdevFixture.baseUri.resolve('index.html');
    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    print('${DateTime.now()} CDD2');
    await tools.start(appFixture, overrideUri: baseAppUri);
    print('${DateTime.now()} CDD3');

    final ConnectDialogManager connectDialog = ConnectDialogManager(tools);
    print('${DateTime.now()} CDD4');

    // make sure the connect dialog displays
    print('${DateTime.now()} CDD5');
    await waitFor(() async => await connectDialog.isVisible());
    print('${DateTime.now()} CDD6');

    // have it connect to a port
    print('${DateTime.now()} CDD7');
    await connectDialog.connectTo(appFixture.serviceUri);
    print('${DateTime.now()} CDD8');

    // make sure the connect dialog becomes hidden
    print('${DateTime.now()} CDD9');
    await waitFor(() async => !(await connectDialog.isVisible()));
    print('${DateTime.now()} CDD10');
  });
}

class ConnectDialogManager {
  ConnectDialogManager(this.tools);

  final DevtoolsManager tools;

  Future<bool> isVisible() async {
    final AppResponse response =
        await tools.tabInstance.send('connectDialog.isVisible');
    return response.result;
  }

  Future connectTo(Uri uri) async {
    // We have to convert to String here as this goes over JSON.
    await tools.tabInstance.send('connectDialog.connectTo', uri.toString());
  }
}
