// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage =>
    throw UnsupportedError('unsupported platform');

void postMessage(Map<String, Object?> message, String origin) =>
    throw UnsupportedError('unsupported platform');
