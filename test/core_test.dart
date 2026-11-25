import 'package:converternow/core/geometry.dart';
import 'package:converternow/core/ocr_parser.dart';
import 'package:converternow/core/plot_detector.dart';
import 'package:converternow/core/units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('Nepali units', () {
    test('1 ropani = 16 aana = 5476 sq ft', () {
      expect(ropaniM2 / sqFt, closeTo(5476, 1e-9));
      expect(ropaniM2 / aanaM2, 16);
      expect(bighaM2 / katthaM2, 20);
      expect(katthaM2 / dhurM2, 20);
    });
    test('R-A-P-D breakdown', () {
      final r = Rapd.fromM2(3370 * sqFt);
      expect([r.ropani, r.aana, r.paisa], [0, 9, 3]);
      expect(r.daam, closeTo(1.5, 0.05));
      expect(Rapd.fromM2(ropaniM2).toString(), '1-0-0-0');
      expect(Rapd.fromM2(aanaM2 * 4).toString(), '0-4-0-0');
      expect(Rapd(2, 5, 3, 1.25).toM2(), closeTo(Rapd.fromM2(Rapd(2, 5, 3, 1.25).toM2()).toM2(), 1e-9));
    });
    test('B-K-D breakdown', () {
      expect(Bkd.fromM2(bighaM2 * 1.5).toString(), '1-10-0');
      expect(Bkd.fromM2(dhurM2 * 25).toString(), '0-1-5');
    });
    test('convert & format', () {
      expect(convert(1, area.unit('bigha'), area.unit('kattha')), closeTo(20, 1e-9));
      expect(convert(1, area.unit('bigha'), area.unit('ropani')), closeTo(13.3126, 1e-3));
      expect(fmt(1234567.891, 2), '1,234,567.89');
      expect(parseNum('१२५०'), 1250);
    });
  });

  group('geometry', () {
    test('shoelace', () {
      const q = [Offset(0, 0), Offset(62, 4), Offset(58, 60), Offset(-2, 54)];
      expect(polygonArea(q), closeTo(3370, 1e-9));
    });
    test('quad from tape sides matches heron', () {
      final q = quadFromSides(50, 40, 50, 40, 64.0312)!;
      expect(polygonArea(q), closeTo(2000, 0.5));
      final t = triangleFromSides(3, 4, 5)!;
      expect(polygonArea(t), closeTo(6, 1e-9));
      expect(heron(3, 4, 5), closeTo(6, 1e-9));
      expect(quadFromSides(1, 1, 1, 1, 5), isNull);
    });
  });

  group('OCR parsing', () {
    test('english naksa text', () {
      final i = parseNaksaText('Survey Department\nScale 1:1250\nSheet No. 102-1145\nKitta No. 412\nWard No. 5');
      expect(i.scale, 1250);
      expect(i.kitta, '412');
      expect(i.sheet, '102-1145');
      expect(i.ward, '5');
    });
    test('devanagari lalpurja text', () {
      final i = parseNaksaText('कि.नं. ४१२\nवडा नं. ५\nक्षेत्रफल ०-९-३-१.५\nस्केल १:२५००');
      expect(i.kitta, '412');
      expect(i.ward, '5');
      expect(i.area, '0-9-3-1.5');
      expect(i.scale, 2500);
    });
  });

  group('plot detector', () {
    img.Image sheet() {
      final im = img.Image(width: 600, height: 500);
      img.fill(im, color: img.ColorRgb8(240, 236, 224));
      final ink = img.ColorRgb8(60, 60, 60);
      // Grid of parcels plus an L-shaped parcel around (300,250).
      for (final x in [50, 200, 400, 550]) {
        img.drawLine(im, x1: x, y1: 30, x2: x, y2: 470, color: ink, thickness: 3);
      }
      for (final y in [30, 150, 350, 470]) {
        img.drawLine(im, x1: 50, y1: y, x2: 550, y2: y, color: ink, thickness: 3);
      }
      img.drawString(im, '412', font: img.arial24, x: 280, y: 200, color: ink);
      return im;
    }

    test('finds rectangular parcel from a tap', () {
      final bytes = img.encodePng(sheet());
      final m = prepareMap(bytes);
      final r = detectParcel(m, const Offset(300, 260));
      expect(r.polygon.length, 4, reason: '${r.polygon} ${r.error}');
      final a = polygonArea(r.polygon);
      // Inner parcel 200..400 x 150..350 = 200x200 = 40000 px² (minus line width)
      expect(a, inInclusiveRange(36000, 41000));
    });

    test('rotated parcel', () {
      final im = img.copyRotate(sheet(), angle: 17);
      final m = prepareMap(img.encodePng(im));
      final r = detectParcel(m, Offset(im.width / 2, im.height / 2));
      expect(r.polygon.length, 4, reason: '${r.polygon} ${r.error}');
      expect(polygonArea(r.polygon), inInclusiveRange(36000, 41000));
    });

    test('open area reports error', () {
      final m = prepareMap(img.encodePng(sheet()));
      final r = detectParcel(m, const Offset(10, 10));
      expect(r.polygon, isEmpty);
      expect(r.error, isNotNull);
    });
  });
}
