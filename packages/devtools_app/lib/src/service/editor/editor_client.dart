// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dtd/dtd.dart';

import 'api_classes.dart';

/// A client to access services provided by an editor over DTD.
///
/// Changes made to the editor services/events should be considered carefully to
/// ensure they are not breaking changes to already-shipped editors.
class EditorClient {
  EditorClient(this._dtd) {
    unawaited(initialized); // Trigger async initialization.
  }

  final DartToolingDaemon _dtd;
  late final initialized = _initialize();

  Future<void> _initialize() async {
    final editorKindMap = EditorEventKind.values.asNameMap();
    _dtd.onEvent(editorStreamName).listen((data) {
      final kind = editorKindMap[data.kind];
      switch (kind) {
        case null:
          // Unknown event. Use null here so we get exhaustiveness checking for
          // the rest.
          break;
        case EditorEventKind.deviceAdded:
          _eventController.add(DeviceAddedEvent.fromJson(data.data));
        case EditorEventKind.deviceRemoved:
          _eventController.add(DeviceRemovedEvent.fromJson(data.data));
        case EditorEventKind.deviceChanged:
          _eventController.add(DeviceChangedEvent.fromJson(data.data));
        case EditorEventKind.deviceSelected:
          _eventController.add(DeviceSelectedEvent.fromJson(data.data));
        case EditorEventKind.debugSessionStarted:
          _eventController.add(DebugSessionStartedEvent.fromJson(data.data));
        case EditorEventKind.debugSessionChanged:
          _eventController.add(DebugSessionChangedEvent.fromJson(data.data));
        case EditorEventKind.debugSessionStopped:
          _eventController.add(DebugSessionStoppedEvent.fromJson(data.data));
      }
    });

    await _dtd.streamListen(editorServiceName);
  }

  /// Close the connection to DTD.
  Future<void> close() => _dtd.close();

  // TODO(dantup): Fix these
  final supportsGetDevices = true;
  final supportsSelectDevice = true;
  final supportsHotReload = true;
  final supportsHotRestart = true;
  final supportsOpenDevToolsPage = true;
  final supportsOpenDevToolsExternally = true;

  /// A stream of [EditorEvent]s from the editor.
  Stream<EditorEvent> get event => _eventController.stream;
  final _eventController = StreamController<EditorEvent>();

  Future<List<EditorDevice>> getDevices() async {
    final response = await _call(
      EditorMethod.getDevices,
    );
    return (response.result['devices'] as List)
        .cast<Map<String, Object?>>()
        .map(EditorDevice.fromJson)
        .toList(growable: false);
  }

  /// Gets the set of currently active debug sessions from the editor.
  Future<List<EditorDebugSession>> getDebugSessions() async {
    final response = await _call(
      EditorMethod.getDebugSessions,
    );
    return (response.result['debugSessions'] as List)
        .cast<Map<String, Object?>>()
        .map(EditorDebugSession.fromJson)
        .toList(growable: false);
  }

  Future<void> selectDevice(EditorDevice? device) async {
    await _call(
      EditorMethod.selectDevice,
      params: {'deviceId': device?.id},
    );
  }

  Future<void> hotReload(String debugSessionId) async {
    await _call(
      EditorMethod.hotReload,
      params: {'debugSessionId': debugSessionId},
    );
  }

  Future<void> hotRestart(String debugSessionId) async {
    await _call(
      EditorMethod.hotRestart,
      params: {'debugSessionId': debugSessionId},
    );
  }

  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
  }) async {
    await _call(
      EditorMethod.openDevToolsPage,
      params: {
        'debugSessionId': debugSessionId,
        'page': page,
        'forceExternal': forceExternal,
      },
    );
  }

  Future<void> enablePlatformType(String platformType) async {
    await _call(
      EditorMethod.enablePlatformType,
      params: {'platformType': platformType},
    );
  }

  Future<DTDResponse> _call(
    EditorMethod method, {
    Map<String, Object?>? params,
  }) {
    return _dtd.call(
      editorServiceName,
      method.name,
      params: params,
    );
  }
}
