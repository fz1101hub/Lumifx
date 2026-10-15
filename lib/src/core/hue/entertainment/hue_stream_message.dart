import 'dart:convert';
import 'dart:typed_data';

import '../../effects/engine/light_frame.dart';

/// Maximum channels in one HueStream message.
const hueStreamMaxChannels = 20;

/// Encodes a HueStream v2 message (Hue Entertainment API) in the
/// CIE xy + brightness color space:
///
/// ```text
/// "HueStream" | 0x02 0x00 | seq | 0x00 0x00 | color space | 0x00 | area id (36)
/// then per channel: channel id (1) | x (2) | y (2) | brightness (2), big endian
/// ```
Uint8List encodeHueStreamMessage({
  required String areaId,
  required Map<int, LightFrame> channels,
  int sequence = 0,
}) {
  final id = ascii.encode(areaId);
  if (id.length != 36) {
    throw ArgumentError.value(areaId, 'areaId', 'Expected a 36-char UUID');
  }
  if (channels.length > hueStreamMaxChannels) {
    throw ArgumentError('At most $hueStreamMaxChannels channels per message');
  }

  final out = BytesBuilder(copy: false)
    ..add(ascii.encode('HueStream'))
    ..add(const [0x02, 0x00]) // API version 2.0
    ..addByte(sequence & 0xFF)
    ..add(const [0x00, 0x00]) // reserved
    ..addByte(0x01) // color space: xy + brightness
    ..addByte(0x00) // reserved
    ..add(id);

  void u16(double unit) {
    final v = (unit.clamp(0.0, 1.0) * 0xFFFF).round();
    out.add([v >> 8, v & 0xFF]);
  }

  channels.forEach((channel, frame) {
    if (channel < 0 || channel > 0xFF) {
      throw ArgumentError.value(channel, 'channel', 'must be 0..255');
    }
    final xy = frame.color.toXy();
    out.addByte(channel);
    u16(xy.x);
    u16(xy.y);
    u16(frame.brightness);
  });
  return out.takeBytes();
}
