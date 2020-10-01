// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'auto_dispose_mixin.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'inspector/flutter_widget.dart';
import 'notifications.dart';
import 'url_utils.dart';

/// Widget that requires business logic to be loaded before building its
/// [builder].
///
/// See [_InitializerState.build] for the logic that determines whether the
/// business logic is loaded.
///
/// Use this widget to wrap pages that require [service.serviceManager] to be
/// connected. As we require additional services to be available, add them
/// here.
class Initializer extends StatefulWidget {
  const Initializer({
    Key key,
    @required this.url,
    @required this.builder,
    this.allowConnectionScreenOnDisconnect = true,
  })  : assert(builder != null),
        super(key: key);

  /// The builder for the widget's children.
  ///
  /// Will only be built if [_InitializerState._checkLoaded] is true.
  final WidgetBuilder builder;

  /// The url to attempt to load a vm service from.
  ///
  /// If null, the app will navigate to the [ConnectScreen].
  final String url;

  /// Whether to allow navigating to the connection screen upon disconnect.
  final bool allowConnectionScreenOnDisconnect;

  @override
  _InitializerState createState() {
    print('creating state for initialier');
    return _InitializerState();
  }
}

class _InitializerState extends State<Initializer>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  /// Checks if the [service.serviceManager] is connected.
  ///
  /// This is a method and not a getter to communicate that its value may
  /// change between successive calls.
  bool _checkLoaded() => serviceManager.hasConnection;

  bool _dependenciesLoaded = false;

  OverlayEntry currentDisconnectedOverlay;
  StreamSubscription<bool> disconnectedOverlayReconnectSubscription;

  @override
  void initState() {
    print('INIT: 11111');
    super.initState();

    /// Ensure that we loaded the inspector dependencies before attempting to
    /// build the Provider.
    print('INIT: 22222');
    ensureInspectorDependencies().then((_) {
      print('INIT: 22222-22222');
      if (!mounted) return;
      setState(() {
        _dependenciesLoaded = true;
      });
    });

    // If we become disconnected, attempt to reconnect.
    autoDispose(
      serviceManager.onStateChange.where((connected) => !connected).listen((_) {
        print('INIT: 333333-333333');
        // Try to reconnect (otherwise, will fall back to showing the disconnected
        // overlay).
        _attemptUrlConnection();
      }),
    );
    // Trigger a rebuild when the connection becomes available. This is done
    // by onConnectionAvailable and not onStateChange because we also need
    // to have queried what type of app this is before we load the UI.
    autoDispose(
      serviceManager.onConnectionAvailable.listen((_) {
        print('INIT: 4444-4444');
        setState(() {
          print('INIT: 4444-4444-4444');
        });
      }),
    );

    print('55555555');
    _attemptUrlConnection();
  }

  Future<void> _attemptUrlConnection() async {
    print('ATTEMPT: 111111');
    if (widget.url == null) {
      print('ATTEMPT: 22222');
      _handleNoConnection();
      return;
    }

    print('ATTEMPT: 33333');
    final uri = normalizeVmServiceUri(widget.url);
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (message, error) {
        print('ATTEMPT: 44444-444444');
        Notifications.of(context).push('$message, $error');
      },
    );

    print('ATTEMPT: 555555');
    if (!connected) {
      print('ATTEMPT: 66666666-6666666');
      _handleNoConnection();
    }
  }

  /// Shows a "disconnected" overlay if the [service.serviceManager] is not currently connected.
  void _handleNoConnection() {
    print('handling no connection!');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkLoaded() &&
          ModalRoute.of(context).isCurrent &&
          currentDisconnectedOverlay == null) {
        Overlay.of(context).insert(_createDisconnectedOverlay());

        // Set up a subscription to hide the overlay if we become reconnected.
        disconnectedOverlayReconnectSubscription = serviceManager.onStateChange
            .where((connected) => connected)
            .listen((_) => hideDisconnectedOverlay());
        autoDispose(disconnectedOverlayReconnectSubscription);
      }
    });
  }

  void hideDisconnectedOverlay() {
    currentDisconnectedOverlay?.remove();
    currentDisconnectedOverlay = null;
    disconnectedOverlayReconnectSubscription?.cancel();
    disconnectedOverlayReconnectSubscription = null;
  }

  OverlayEntry _createDisconnectedOverlay() {
    final theme = Theme.of(context);
    currentDisconnectedOverlay = OverlayEntry(
      builder: (context) => Container(
        // TODO(dantup): Change this to a theme colour and ensure it works in both dart/light themes
        color: const Color.fromRGBO(128, 128, 128, 0.5),
        child: Center(
          child: Column(
            children: [
              const Spacer(),
              Text('Disconnected', style: theme.textTheme.headline3),
              if (widget.allowConnectionScreenOnDisconnect)
                RaisedButton(
                    onPressed: () {
                      hideDisconnectedOverlay();
                      Navigator.of(context).popAndPushNamed(homeScreenId);
                    },
                    child: const Text('Connect to Another App'))
              else
                Text(
                  'Run a new debug session to reconnect',
                  style: theme.textTheme.bodyText2,
                ),
              const Spacer(),
              RaisedButton(
                onPressed: hideDisconnectedOverlay,
                child: const Text('Review History'),
              ),
            ],
          ),
        ),
      ),
    );
    return currentDisconnectedOverlay;
  }

  @override
  Widget build(BuildContext context) {
    return _checkLoaded() && _dependenciesLoaded
        ? widget.builder(context)
        : const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
  }
}

/// Loads the widgets.json file from Flutter's [rootBundle].
///
/// This will fail if called in a test run with `--platform chrome`.
/// Tests that call this method should be annotated `@TestOn('vm')`.
Future<void> ensureInspectorDependencies() async {
  // TODO(jacobr): move this rootBundle loading code into
  // InspectorController once the dart:html app is removed and Flutter
  // conventions for loading assets can be the default.
  if (Catalog.instance == null) {
    final json = await rootBundle.loadString('web/widgets.json');
    // ignore: invalid_use_of_visible_for_testing_member
    Catalog.setCatalog(Catalog.decode(json));
  }
}
