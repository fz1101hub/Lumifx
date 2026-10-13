import 'dart:math' as math;
import 'dart:typed_data';

/// In-place iterative radix-2 FFT. [re] and [im] must have the same
/// power-of-two length.
void fft(Float64List re, Float64List im) {
  final n = re.length;
  if (n != im.length || n == 0 || (n & (n - 1)) != 0) {
    throw ArgumentError('FFT length must be a power of two');
  }

  // Bit-reversal permutation.
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }

  for (var size = 2; size <= n; size <<= 1) {
    final half = size >> 1;
    final angle = -2 * math.pi / size;
    final stepRe = math.cos(angle);
    final stepIm = math.sin(angle);
    for (var start = 0; start < n; start += size) {
      var wRe = 1.0;
      var wIm = 0.0;
      for (var k = 0; k < half; k++) {
        final a = start + k;
        final b = a + half;
        final tRe = re[b] * wRe - im[b] * wIm;
        final tIm = re[b] * wIm + im[b] * wRe;
        re[b] = re[a] - tRe;
        im[b] = im[a] - tIm;
        re[a] += tRe;
        im[a] += tIm;
        final nextRe = wRe * stepRe - wIm * stepIm;
        wIm = wRe * stepIm + wIm * stepRe;
        wRe = nextRe;
      }
    }
  }
}
