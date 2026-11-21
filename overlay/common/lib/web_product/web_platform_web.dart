// ignore_for_file: depend_on_referenced_packages
// Browser side of web_platform.dart (package:web). Every call is guarded: a browser that blocks storage or the network
// simply behaves as if nothing was stored or fetched.
import 'dart:js_interop';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:web/web.dart' as web;

String? storageGet(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } on Object {
    return null;
  }
}

void storageSet(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } on Object {
    // Blocked or full: forget it.
  }
}

Future<String?> fetchText(String url) async {
  try {
    final res = await web.window.fetch(url.toJS).toDart;
    if (!res.ok) return null;
    return (await res.text().toDart).toDart;
  } on Object {
    return null;
  }
}

/// Leaves this build for another page (a different slug, or the catalog).
void navigateTo(String url) => web.window.location.href = url;

/// Rewrites the address bar without reloading, so a reload or a shared link reopens what is on screen.
void replaceHash(String hash) {
  try {
    web.window.history.replaceState(null, '', hash);
  } on Object {
    // Not available: the address just stays as it was.
  }
}

/// Stops Flutter from rewriting the address bar (it would turn `#/game/sudoku` into `#/` after a dialog closes, so a
/// reload would lose the link). Call once at the start of main(), before the link is read.
void keepAddressAsIs() => setUrlStrategy(null);
