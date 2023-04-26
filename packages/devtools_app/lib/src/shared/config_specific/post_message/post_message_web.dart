// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:html' as html;

import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage {
  return html.window.onMessage.map(
    (message) => PostMessageEvent(
      origin: message.origin,
      data: message.data,
    ),
  );
}

// VM47:5 Uncaught TypeError: Cannot read properties of undefined (reading 'postMessage')
// at <anonymous>:5:19
void postMessage(Map<String, Object?> message, String origin) =>
    html.window.parent?.postMessage(message, origin);
