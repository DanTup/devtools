// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../api/vs_code_api.dart';

class Devices extends StatelessWidget {
  const Devices(
    this.api, {
    required this.devices,
    required this.unsupportedDevices,
    required this.selectedDeviceId,
    super.key,
  });

  final VsCodeApi api;
  final List<VsCodeDevice> devices;
  final List<VsCodeDevice> unsupportedDevices;
  final String? selectedDeviceId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Devices',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (devices.isEmpty)
          const Text('Connect a device or enable web/desktop platforms.')
        else
          ListView.builder(
            itemCount: devices.length,
            itemExtent: defaultListItemHeight,
            itemBuilder: (_, index) {
              final device = devices[index];
              return TextButton(
                child: Text(device.name),
                onPressed: () => unawaited(api.selectDevice(device.id)),
              );
            },
          ),
        // Table(
        //   columnWidths: const {
        //     0: FlexColumnWidth(3),
        //     1: FlexColumnWidth(),
        //   },
        //   defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        //   children: [
        //     for (final device in devices)
        //       _createDeviceRow(
        //         device,
        //         isSelected: device.id == selectedDeviceId,
        //       ),
        //   ],
        // ),
      ],
    );
  }
}
