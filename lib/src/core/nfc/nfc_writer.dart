import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How writing a sticker went.
enum NfcWriteResult {
  written,

  /// The sticker is locked.
  readOnly,

  /// The link does not fit on the sticker.
  tooSmall,

  /// Not a sticker that holds links (NDEF).
  notNdef,

  /// NFC is off or missing.
  unavailable,

  /// Moved away too soon, or another error.
  failed,

  cancelled,
}

/// Writes `lumifx://` links on NFC stickers: touching one later opens the
/// link. Android writes them itself (see NfcChannel.kt); on iPhone the
/// Shortcuts app's NFC automation opens the link instead.
abstract interface class NfcWriter {
  /// Whether this phone can write stickers.
  Future<bool> isAvailable();

  /// Whether NFC is switched on.
  Future<bool> isEnabled();

  /// Waits for a sticker near the phone and writes [uri] on it.
  Future<NfcWriteResult> write(String uri);

  /// Stops waiting for a sticker.
  Future<void> cancel();

  /// Opens the system's NFC settings.
  Future<void> openSettings();
}

class NoNfcWriter implements NfcWriter {
  const NoNfcWriter();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<NfcWriteResult> write(String uri) async => NfcWriteResult.unavailable;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> openSettings() async {}
}

class ChannelNfcWriter implements NfcWriter {
  ChannelNfcWriter({@visibleForTesting bool? supported})
      : _supported = supported ?? Platform.isAndroid;

  static const _channel = MethodChannel('com.lumifx/nfc');

  final bool _supported;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!_supported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> isAvailable() async =>
      await _invoke<bool>('isAvailable') ?? false;

  @override
  Future<bool> isEnabled() async => await _invoke<bool>('isEnabled') ?? false;

  @override
  Future<NfcWriteResult> write(String uri) async {
    final outcome = await _invoke<String>('write', {'uri': uri});
    return NfcWriteResult.values.asNameMap()[outcome] ??
        (outcome == null ? NfcWriteResult.unavailable : NfcWriteResult.failed);
  }

  @override
  Future<void> cancel() => _invoke<void>('cancel');

  @override
  Future<void> openSettings() => _invoke<void>('openSettings');
}
