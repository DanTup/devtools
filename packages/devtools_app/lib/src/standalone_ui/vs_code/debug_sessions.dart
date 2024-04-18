// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/constants.dart';
import '../../shared/screen.dart';
import '../api/vs_code_api.dart';

class DebugSessions extends StatelessWidget {
  const DebugSessions(this.api, this.sessions, {super.key});

  final VsCodeApi api;
  final List<VsCodeDebugSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Debug Sessions',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (sessions.isEmpty)
          const Text('Begin a debug session to use DevTools.')
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              // TODO(dantup): Fixed width icons+menu?
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final session in sessions)
                TableRow(
                  children: [
                    Text(
                      '${session.name} (${session.flutterMode})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (api.capabilities.openDevToolsPage)
                      _DevToolsMenu(api: api, session: session),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class _DevToolsMenu extends StatelessWidget {
  const _DevToolsMenu({required this.api, required this.session});

  final VsCodeApi api;
  final VsCodeDebugSession session;

  @override
  Widget build(BuildContext context) {
    // TODO(dantup): What to show if mode is unknown (null)?
    final mode = session.flutterMode;
    final isDebug = mode == 'debug';
    final isProfile = mode == 'profile';
    // final isRelease = mode == 'release' || mode == 'jit_release';
    final isFlutter = session.debuggerType?.contains('Flutter') ?? false;

    return Row(
      children: [
        IconButton(
          onPressed: api.capabilities.hotReload && (isDebug || !isFlutter)
              ? () => unawaited(api.hotReload(session.id))
              : null,
          tooltip: 'Hot Reload',
          icon: Icon(hotReloadIcon, size: actionsIconSize),
        ),
        IconButton(
          onPressed: api.capabilities.hotRestart && (isDebug || !isFlutter)
              ? () => unawaited(api.hotRestart(session.id))
              : null,
          tooltip: 'Hot Restart',
          icon: Icon(hotRestartIcon, size: actionsIconSize),
        ),
        MenuAnchor(
          // TODO(dantup): How to flip the menu to be anchored from the right
          //  and expand to the left?
          style: const MenuStyle(
            alignment: AlignmentDirectional.bottomEnd,
          ),
          menuChildren: [
            // TODO(dantup): Ensure the order matches the DevTools tab bar (if
            //  possible, share this order).
            // TODO(dantup): Make these conditions use the real screen
            //  conditions and/or verify if these conditions are correct.
            _devToolsButton(
              ScreenMetaData.inspector,
              enabled: isFlutter && isDebug,
            ),
            _devToolsButton(
              ScreenMetaData.cpuProfiler,
              enabled: isDebug || isProfile,
            ),
            _devToolsButton(
              ScreenMetaData.memory,
              enabled: isDebug || isProfile,
            ),
            _devToolsButton(
              ScreenMetaData.performance,
            ),
            _devToolsButton(
              ScreenMetaData.network,
              enabled: isDebug,
            ),
            _devToolsButton(
              ScreenMetaData.logging,
            ),
            // TODO(dantup): Check other screens (like appSize) work embedded and
            //  add here.
          ],
          builder: (context, controller, child) => IconButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            tooltip: 'DevTools',
            // TODO(dantup): Icon for DevTools menu?
            icon: Icon(
              Icons.toys_outlined,
              size: actionsIconSize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _devToolsButton(
    ScreenMetaData screen, {
    bool enabled = true,
  }) {
    return TextButton.icon(
      onPressed: enabled
          ? () => unawaited(api.openDevToolsPage(session.id, page: screen.id))
          : null,
      label: Text(screen.title ?? screen.id),
      icon: Icon(screen.icon, size: actionsIconSize),
    );
  }
}
