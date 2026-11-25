/// Computer-vision pipeline that finds a parcel outline on a photo of a
/// cadastral map. It is a pure-Dart port of the classic OpenCV recipe:
///
///   resize → grayscale → Gaussian blur → adaptive threshold (cv::adaptiveThreshold)
///   → dilate (cv::dilate) → flood fill from the tapped seed (cv::floodFill)
///   → border following (cv::findContours) → polygon approximation
///   (cv::approxPolyDP, Douglas–Peucker).
///
/// Pure Dart keeps the APK free of native OpenCV binaries and runs in an
/// isolate so the UI stays smooth.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'geometry.dart';

/// Decoded working image shared between detection calls.
class PreparedMap {
  final int width, height; // working size
  final double scaleToOriginal; // multiply working px by this
  final Uint8List lineMask; // 1 = ink/line pixel (after dilation)
  final int origWidth, origHeight; // display image size
  final Uint8List displayJpeg; // orientation-corrected image shown in the UI
  PreparedMap(this.width, this.height, this.scaleToOriginal, this.lineMask,
      this.origWidth, this.origHeight, this.displayJpeg);
}

class DetectResult {
  final List<Offset> polygon; // in ORIGINAL image pixels
  final String? error;
  DetectResult(this.polygon, [this.error]);
}

const int _maxSide = 1000;

/// Decodes and binarises the image. Heavy; call via [prepareMapAsync].
PreparedMap prepareMap(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  var src = img.bakeOrientation(decoded);
  // The display copy (max 2000 px) defines the coordinate system used by
  // the editor; detection runs on a smaller working copy.
  final ds = math.min(1.0, 2000 / math.max(src.width, src.height));
  if (ds < 1) {
    src = img.copyResize(src,
        width: (src.width * ds).round(),
        height: (src.height * ds).round(),
        interpolation: img.Interpolation.average);
  }
  final displayJpeg = img.encodeJpg(src, quality: 88);
  final ow = src.width, oh = src.height;
  final s = math.min(1.0, _maxSide / math.max(ow, oh));
  final work = s < 1
      ? img.copyResize(src,
          width: (ow * s).round(),
          height: (oh * s).round(),
          interpolation: img.Interpolation.average)
      : src;
  final w = work.width, h = work.height;

  // Grayscale.
  final gray = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = work.getPixel(x, y);
      gray[y * w + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }
  }
  final blurred = _boxBlur(gray, w, h, 1);

  // Adaptive mean threshold using an integral image (window 31, C = 12).
  final integ = Float64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0.0;
    for (var x = 0; x < w; x++) {
      row += blurred[y * w + x];
      integ[(y + 1) * (w + 1) + x + 1] = integ[y * (w + 1) + x + 1] + row;
    }
  }
  const r = 15;
  const c = 12.0;
  final mask = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(h - 1, y + r);
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - r), x1 = math.min(w - 1, x + r);
      final area = (x1 - x0 + 1) * (y1 - y0 + 1);
      final sum = integ[(y1 + 1) * (w + 1) + x1 + 1] -
          integ[y0 * (w + 1) + x1 + 1] -
          integ[(y1 + 1) * (w + 1) + x0] +
          integ[y0 * (w + 1) + x0];
      if (blurred[y * w + x] < sum / area - c) mask[y * w + x] = 1;
    }
  }
  final dilated = _dilate(mask, w, h, 1);
  return PreparedMap(w, h, ow / w, dilated, ow, oh, displayJpeg);
}

Future<PreparedMap> prepareMapAsync(Uint8List bytes) =>
    compute(prepareMap, bytes);

/// Finds the parcel that contains [seedOriginal] (original image pixels).
DetectResult detectParcel(PreparedMap m, Offset seedOriginal) {
  final w = m.width, h = m.height;
  var sx = (seedOriginal.dx / m.scaleToOriginal).round();
  var sy = (seedOriginal.dy / m.scaleToOriginal).round();
  if (sx < 0 || sy < 0 || sx >= w || sy >= h) {
    return DetectResult(const [], 'Tap inside the image.');
  }
  // If the tap landed on a line, step to the nearest free pixel.
  if (m.lineMask[sy * w + sx] == 1) {
    var found = false;
    for (var rad = 1; rad < 12 && !found; rad++) {
      for (var dy = -rad; dy <= rad && !found; dy++) {
        for (var dx = -rad; dx <= rad && !found; dx++) {
          final x = sx + dx, y = sy + dy;
          if (x >= 0 && y >= 0 && x < w && y < h && m.lineMask[y * w + x] == 0) {
            sx = x;
            sy = y;
            found = true;
          }
        }
      }
    }
    if (!found) return DetectResult(const [], 'Tap inside a plot, not on a line.');
  }

  // Flood fill (4-connected, scanline stack).
  final region = Uint8List(w * h);
  final stack = <int>[sy * w + sx];
  var count = 0;
  var touchesBorder = false;
  final limit = (w * h * 0.6).round();
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    if (region[i] == 1 || m.lineMask[i] == 1) continue;
    region[i] = 1;
    count++;
    if (count > limit) {
      return DetectResult(const [],
          'The area is not closed. Retake the photo closer, or draw the plot manually.');
    }
    final x = i % w, y = i ~/ w;
    if (x == 0 || y == 0 || x == w - 1 || y == h - 1) touchesBorder = true;
    if (x > 0) stack.add(i - 1);
    if (x < w - 1) stack.add(i + 1);
    if (y > 0) stack.add(i - w);
    if (y < h - 1) stack.add(i + w);
  }
  if (touchesBorder) {
    return DetectResult(const [],
        'That area runs off the photo edge. Tap inside a closed plot, or retake the photo with the whole plot visible.');
  }
  if (count < 60) {
    return DetectResult(const [], 'That area is too small — tap inside the plot.');
  }

  // Close small holes left by labels/digits inside the parcel.
  final closed = _erode(_dilate(region, w, h, 2), w, h, 2);
  final contour = _traceContour(closed, w, h);
  if (contour.length < 8) {
    return DetectResult(const [], 'Could not trace the plot boundary.');
  }
  final per = polygonPerimeter(contour);
  var poly = simplifyClosed(contour, math.max(2.0, per * 0.012));
  poly = dropCollinear(poly, degTol: 10);
  // The fill stops at the inner edge of the line; push the outline outward
  // by the dilation radius so corners sit on the map lines.
  poly = _offsetOutward(poly, 1.5);
  final scaled = [
    for (final p in poly) Offset(p.dx * m.scaleToOriginal, p.dy * m.scaleToOriginal)
  ];
  return DetectResult(scaled);
}

/// Moore-neighbour border following on a binary mask.
List<Offset> _traceContour(Uint8List mask, int w, int h) {
  int start = -1;
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] == 1) {
      start = i;
      break;
    }
  }
  if (start < 0) return const [];
  const dx = [1, 1, 0, -1, -1, -1, 0, 1];
  const dy = [0, 1, 1, 1, 0, -1, -1, -1];
  bool on(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && mask[y * w + x] == 1;

  final out = <Offset>[];
  var cx = start % w, cy = start ~/ w;
  final sx = cx, sy = cy;
  var dir = 7; // came from the west-ish
  var guard = 0;
  do {
    out.add(Offset(cx.toDouble(), cy.toDouble()));
    var found = false;
    for (var k = 0; k < 8; k++) {
      final d = (dir + 6 + k) % 8; // start left of previous direction
      final nx = cx + dx[d], ny = cy + dy[d];
      if (on(nx, ny)) {
        cx = nx;
        cy = ny;
        dir = d;
        found = true;
        break;
      }
    }
    if (!found) break;
    guard++;
  } while ((cx != sx || cy != sy) && guard < w * h);
  return out;
}

List<Offset> _offsetOutward(List<Offset> p, double d) {
  if (p.length < 3) return p;
  var cx = 0.0, cy = 0.0;
  for (final q in p) {
    cx += q.dx;
    cy += q.dy;
  }
  final c = Offset(cx / p.length, cy / p.length);
  return [
    for (final q in p)
      () {
        final v = q - c;
        final len = v.distance;
        return len == 0 ? q : q + v / len * d;
      }()
  ];
}

Float32List _boxBlur(Float32List src, int w, int h, int r) {
  final tmp = Float32List(w * h), out = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0, n = 0;
      for (var k = -r; k <= r; k++) {
        final xx = x + k;
        if (xx >= 0 && xx < w) {
          s += src[y * w + xx];
          n++;
        }
      }
      tmp[y * w + x] = s / n;
    }
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0, n = 0;
      for (var k = -r; k <= r; k++) {
        final yy = y + k;
        if (yy >= 0 && yy < h) {
          s += tmp[yy * w + x];
          n++;
        }
      }
      out[y * w + x] = s / n;
    }
  }
  return out;
}

Uint8List _dilate(Uint8List m, int w, int h, int r) {
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (m[y * w + x] == 0) continue;
      for (var dy = -r; dy <= r; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -r; dx <= r; dx++) {
          final xx = x + dx;
          if (xx >= 0 && xx < w) out[yy * w + xx] = 1;
        }
      }
    }
  }
  return out;
}

Uint8List _erode(Uint8List m, int w, int h, int r) {
  final inv = Uint8List(w * h);
  for (var i = 0; i < m.length; i++) {
    inv[i] = m[i] == 1 ? 0 : 1;
  }
  final d = _dilate(inv, w, h, r);
  for (var i = 0; i < d.length; i++) {
    d[i] = d[i] == 1 ? 0 : 1;
  }
  return d;
}
