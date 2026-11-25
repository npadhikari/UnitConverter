import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Polygon area by the shoelace formula (absolute value, same units²).
double polygonArea(List<Offset> p) {
  if (p.length < 3) return 0;
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s.abs() / 2;
}

double polygonPerimeter(List<Offset> p) {
  if (p.length < 2) return 0;
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    s += (p[(i + 1) % p.length] - p[i]).distance;
  }
  return s;
}

/// Triangle area from three sides (Heron). Returns NaN if impossible.
double heron(double a, double b, double c) {
  final s = (a + b + c) / 2;
  final v = s * (s - a) * (s - b) * (s - c);
  if (v < 0 || a <= 0 || b <= 0 || c <= 0) return double.nan;
  return math.sqrt(v);
}

/// Third vertex of a triangle with base P0->P1, sides r0 from P0 and r1
/// from P1, on the left (side = 1) or right (side = -1) of the base.
Offset? triangleApex(Offset p0, Offset p1, double r0, double r1, int side) {
  final d = (p1 - p0).distance;
  if (d == 0) return null;
  final a = (r0 * r0 - r1 * r1 + d * d) / (2 * d);
  final h2 = r0 * r0 - a * a;
  if (h2 < -1e-9) return null;
  final h = math.sqrt(math.max(0, h2));
  final ux = (p1.dx - p0.dx) / d, uy = (p1.dy - p0.dy) / d;
  final mx = p0.dx + a * ux, my = p0.dy + a * uy;
  return Offset(mx - side * h * uy, my + side * h * ux);
}

/// Douglas–Peucker simplification of a closed contour.
List<Offset> simplifyClosed(List<Offset> pts, double eps) {
  if (pts.length < 4) return pts;
  // Split the ring at the two most distant points to get two open chains.
  var i0 = 0, i1 = 0;
  var best = -1.0;
  final first = pts[0];
  for (var i = 0; i < pts.length; i++) {
    final d = (pts[i] - first).distanceSquared;
    if (d > best) {
      best = d;
      i0 = i;
    }
  }
  best = -1;
  for (var i = 0; i < pts.length; i++) {
    final d = (pts[i] - pts[i0]).distanceSquared;
    if (d > best) {
      best = d;
      i1 = i;
    }
  }
  final a = math.min(i0, i1), b = math.max(i0, i1);
  final chain1 = pts.sublist(a, b + 1);
  final chain2 = [...pts.sublist(b), ...pts.sublist(0, a + 1)];
  final s1 = _dp(chain1, eps);
  final s2 = _dp(chain2, eps);
  return [...s1.sublist(0, s1.length - 1), ...s2.sublist(0, s2.length - 1)];
}

List<Offset> _dp(List<Offset> pts, double eps) {
  if (pts.length < 3) return pts;
  final a = pts.first, b = pts.last;
  var maxD = -1.0;
  var idx = 0;
  for (var i = 1; i < pts.length - 1; i++) {
    final d = _segDist(pts[i], a, b);
    if (d > maxD) {
      maxD = d;
      idx = i;
    }
  }
  if (maxD > eps) {
    final l = _dp(pts.sublist(0, idx + 1), eps);
    final r = _dp(pts.sublist(idx), eps);
    return [...l.sublist(0, l.length - 1), ...r];
  }
  return [a, b];
}

double _segDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.distanceSquared;
  if (len2 == 0) return (p - a).distance;
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Distance from point to segment (exposed for hit testing).
double distanceToSegment(Offset p, Offset a, Offset b) => _segDist(p, a, b);

/// Removes vertices whose interior angle is nearly straight.
List<Offset> dropCollinear(List<Offset> p, {double degTol = 8}) {
  if (p.length <= 3) return p;
  final out = <Offset>[];
  for (var i = 0; i < p.length; i++) {
    final prev = p[(i - 1 + p.length) % p.length];
    final cur = p[i];
    final next = p[(i + 1) % p.length];
    final v1 = cur - prev, v2 = next - cur;
    final cross = v1.dx * v2.dy - v1.dy * v2.dx;
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final ang = math.atan2(cross.abs(), dot) * 180 / math.pi;
    if (ang > degTol) out.add(cur);
  }
  return out.length >= 3 ? out : p;
}

/// Builds a quadrilateral A,B,C,D from tape measurements: sides AB, BC, CD,
/// DA and diagonal AC. Coordinates in the same unit as inputs.
List<Offset>? quadFromSides(
    double ab, double bc, double cd, double da, double ac) {
  const a = Offset(0, 0);
  final c = Offset(ac, 0);
  final b = triangleApex(a, c, ab, bc, -1);
  final d = triangleApex(a, c, da, cd, 1);
  if (b == null || d == null) return null;
  return [a, b, c, d];
}

List<Offset>? triangleFromSides(double ab, double bc, double ca) {
  const a = Offset(0, 0);
  final b = Offset(ab, 0);
  final c = triangleApex(a, b, ca, bc, 1);
  if (c == null) return null;
  return [a, b, c];
}
