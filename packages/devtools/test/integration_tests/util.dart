// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

Future delay() {
  return Future.delayed(const Duration(milliseconds: 5));
}

Future shortDelay() {
  return Future.delayed(const Duration(milliseconds: 1));
}
