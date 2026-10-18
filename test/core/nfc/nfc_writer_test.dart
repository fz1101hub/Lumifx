import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/nfc/nfc_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.lumifx/nfc');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('writes through the channel and reads back how it went', () async {
    final calls = <MethodCall>[];
    var answer = 'written';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isAvailable' || 'isEnabled' => true,
        'write' => answer,
        _ => null,
      };
    });
    final nfc = ChannelNfcWriter(supported: true);
    expect(await nfc.isAvailable(), isTrue);
    expect(await nfc.isEnabled(), isTrue);
    expect(await nfc.write('lumifx://app/bedtime'), NfcWriteResult.written);
    expect(calls.last.arguments, {'uri': 'lumifx://app/bedtime'});
    answer = 'readOnly';
    expect(await nfc.write('lumifx://app/stop'), NfcWriteResult.readOnly);
    answer = 'something new';
    expect(await nfc.write('lumifx://app/stop'), NfcWriteResult.failed);
  });

  test('without the platform side there is no NFC', () async {
    final unsupported = ChannelNfcWriter(supported: false);
    expect(await unsupported.isAvailable(), isFalse);
    expect(await unsupported.write('lumifx://app/stop'),
        NfcWriteResult.unavailable);
    // Supported, but nothing answers on the channel.
    final silent = ChannelNfcWriter(supported: true);
    expect(await silent.isAvailable(), isFalse);
    expect(await silent.write('lumifx://app/stop'), NfcWriteResult.unavailable);
  });
}
