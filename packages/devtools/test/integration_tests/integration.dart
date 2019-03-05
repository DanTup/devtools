// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    show ConsoleAPIEvent, RemoteObject;

import '../support/chrome.dart';
import '../support/cli_test_driver.dart';

const bool verboseTesting = true;

WebdevFixture webdevFixture;
BrowserManager browserManager;

Future<void> waitFor(
  Future<bool> condition(), {
  Duration timeout = const Duration(seconds: 4),
  String timeoutMessage = 'condition not satisfied',
}) async {
  final DateTime end = DateTime.now().add(timeout);

  while (!end.isBefore(DateTime.now())) {
    if (await condition()) {
      return;
    }

    await shortDelay();
  }

  throw timeoutMessage;
}

Future delay() {
  return Future.delayed(const Duration(milliseconds: 500));
}

Future shortDelay() {
  return Future.delayed(const Duration(milliseconds: 100));
}

class DevtoolsManager {
  DevtoolsManager(this.tabInstance, this.baseUri);

  final BrowserTabInstance tabInstance;
  final Uri baseUri;

  Future<void> start(AppFixture appFixture, {Uri overrideUri}) async {
    final Uri baseAppUri =
        baseUri.resolve('index.html?port=${appFixture.servicePort}');
    await tabInstance.tab.navigate('${overrideUri ?? baseAppUri}');

    // wait for app initialization
    await tabInstance.getBrowserChannel();

    // TODO(dantup): Find a better way to wait for something here. This delay
    // fixes the following tests on Windows (list scripts has also been seen to
    // fail elsewhere).
    //     integration logging displays log data [E]
    //     integration logging log screen postpones write when offscreen [E]
    //     integration debugging lists scripts [E]
    // integration debugging pause [E]
    await delay();
  }

  Future<void> switchPage(String page) async {
    await tabInstance.send('switchPage', page);
  }

  Future<String> currentPageId() async {
    final AppResponse response = await tabInstance.send('currentPageId');
    return response.result;
  }
}

class BrowserManager {
  BrowserManager._(this.chromeProcess, this.tab);

  static Future<BrowserManager> create() async {
    final Chrome chrome = Chrome.locate();
    if (chrome == null) {
      throw 'unable to locate Chrome';
    }

    final ChromeProcess chromeProcess = await chrome.start();
    final ChromeTab tab = await chromeProcess.getFirstTab();

    await tab.connect();

    return BrowserManager._(chromeProcess, tab);
  }

  final ChromeProcess chromeProcess;
  final ChromeTab tab;

  Future<BrowserTabInstance> createNewTab() async {
    final String targetId = await this.tab.createNewTarget();

    await delay();

    final ChromeTab tab =
        await chromeProcess.connectToTabId('localhost', targetId);
    await tab.connect(verbose: true);

    await delay();

    await tab.wipConnection.target.activateTarget(targetId);

    await delay();

    return BrowserTabInstance(tab);
  }

  Future<void> teardown() async {
    chromeProcess.kill();
  }
}

class BrowserTabInstance {
  BrowserTabInstance(this.tab) {
    tab.onConsoleAPICalled
        //.where((ConsoleAPIEvent event) => event.type == 'log')
        .listen((ConsoleAPIEvent event) {
      if (event.args.isNotEmpty) {
        final RemoteObject message = event.args.first;
        final String value = '${message.value}';
        if (value.startsWith('[') && value.endsWith(']')) {
          try {
            final dynamic msg =
                jsonDecode(value.substring(1, value.length - 1));
            if (msg is Map) {
              _handleBrowserMessage(msg);
            }
          } catch (_) {
            // ignore
          }
        }
      }
    });
  }

  final ChromeTab tab;

  RemoteObject _remote;

  Future<RemoteObject> getBrowserChannel() async {
    final DateTime start = DateTime.now();
    final DateTime end = start.add(const Duration(seconds: 30));

    while (true) {
      try {
        return await _getAppChannelObject();
      } catch (e) {
        if (end.isBefore(DateTime.now())) {
          final Duration duration = DateTime.now().difference(start);
          print('timeout getting the browser channel object ($duration)');
          rethrow;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<RemoteObject> _getAppChannelObject() {
    return tab.wipConnection.runtime.evaluate('devtools');
  }

  int _nextId = 1;

  final Map<int, Completer<AppResponse>> _completers =
      <int, Completer<AppResponse>>{};

  final StreamController<AppEvent> _eventStream =
      StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get onEvent => _eventStream.stream;

  Future<AppResponse> send(String method, [dynamic params]) async {
    print('Send #1');
    _remote ??= await _getAppChannelObject();
    print('Send #2');

    final int id = _nextId++;

    final Completer<AppResponse> completer = Completer<AppResponse>();
    print('Send #3');
    _completers[id] = completer;
    print('Send #3.5');

    try {
      print('Send #4');
      print(DateTime.now());
      try {
        print("Calling window['devtools'].send");
        await tab.wipConnection.runtime.callFunctionOn(
          "window['devtools'].send",
          objectId: _remote.objectId,
          arguments: <dynamic>[method, id, params],
        );
        print("Finished calling window['devtools'].send");
        print(DateTime.now());
      } catch (e) {
        print("Calling window['devtools'].send errored");
        print(DateTime.now());
        print(e);
      }
      print(DateTime.now());
      print('Send #5');

      return completer.future;
    } catch (e, st) {
      print(e);
      print('Send #6 (ERR)');
      _completers.remove(id);
      print('Send #7');
      completer.completeError(e, st);
      print('Send #8');
      rethrow;
    }
  }

  Future<void> close() async {
    // In Headless Chrome, we get Inspector.detached when we close the last
    // target rather than a response.
    await Future.any(<Future<Object>>[
      tab.wipConnection.onNotification
          .firstWhere((n) => n.method == 'Inspector.detached'),
      tab.wipConnection.target.closeTarget(tab.wipTab.id),
    ]);
  }

  void _handleBrowserMessage(Map<dynamic, dynamic> message) {
    if (verboseTesting) {
      print(message);
    }

    print('Handling #0');
    if (message.containsKey('id')) {
      print('Handling #1');
      // handle a response: {id: 1}
      final AppResponse response = AppResponse(message);
      print('Handling #2');
      final Completer<AppResponse> completer = _completers.remove(response.id);
      print('Handling #3');
      if (response.hasError) {
        print('Handling #4');
        completer.completeError(response.error);
      } else {
        print('Handling #5');
        completer.complete(response);
      }
      print('Handling #6');
    } else {
      print('Handling #7');
      // handle an event: {event: app.echo, params: foo}
      _eventStream.add(AppEvent(message));
      print('Handling #8');
    }
    print('Handling #9');
  }
}

class AppEvent {
  AppEvent(this.json);

  final Map<dynamic, dynamic> json;

  String get event => json['event'];

  dynamic get params => json['params'];

  @override
  String toString() => '$event ${params ?? ''}';
}

class AppResponse {
  AppResponse(this.json);

  final Map<dynamic, dynamic> json;

  int get id => json['id'];

  dynamic get result => json['result'];

  bool get hasError => json.containsKey('error');

  AppError get error => AppError(json['error']);

  @override
  String toString() {
    return hasError ? error.toString() : result.toString();
  }
}

class AppError {
  AppError(this.json);

  final Map<dynamic, dynamic> json;

  String get message => json['message'];

  String get stackTrace => json['stackTrace'];

  @override
  String toString() => '$message\n$stackTrace';
}

class WebdevFixture {
  WebdevFixture._(this.process, this.url);

  static Future<WebdevFixture> create({
    bool release = false,
    bool verbose = false,
  }) async {
    // 'pub run webdev serve web'

    final List<String> cliArgs = ['run', 'webdev', 'serve', 'web'];
    if (release) {
      cliArgs.add('--release');
    }

    // Remove the DART_VM_OPTIONS env variable from the child process, so the
    // Dart VM doesn't try and open a service protocol port if
    // 'DART_VM_OPTIONS: --enable-vm-service:63990' was passed in.
    final Map<String, String> environment =
        Map<String, String>.from(Platform.environment);
    if (environment.containsKey('DART_VM_OPTIONS')) {
      environment['DART_VM_OPTIONS'] = '';
    }

    final Process process = await Process.start(
      Platform.isWindows ? 'pub.bat' : 'pub',
      cliArgs,
      environment: environment,
    );
    unawaited(
        process.exitCode.then((code) => print('Pub exited with code $code')));

    final Stream<String> lines =
        process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final Completer<String> hasUrl = Completer<String>();

    lines.listen((String line) {
      if (verbose) {
        print('webdev • ${line.trim()}');
      }

      // Serving `web` on http://localhost:8080
      if (line.startsWith(r'Serving `web`')) {
        final String url = line.substring(line.indexOf('http://'));
        hasUrl.complete(url);
      }
    });

    final String url = await hasUrl.future;

    await delay();

    return WebdevFixture._(process, url);
  }

  final Process process;
  final String url;

  Uri get baseUri => Uri.parse(url);

  Future<void> teardown() async {
    process.kill();
  }
}
