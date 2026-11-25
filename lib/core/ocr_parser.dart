/// Extracts useful fields from OCR text of a Nepali cadastral map (naksa),
/// a Lalpurja (land ownership certificate) or a field book.
library;

class NaksaInfo {
  int? scale; // 1:N
  String? kitta;
  String? sheet;
  String? ward;
  String? area; // area printed on the document, raw text
  final List<String> lines;
  NaksaInfo(this.lines);

  bool get isEmpty =>
      scale == null && kitta == null && sheet == null && ward == null &&
      area == null;
}

const _devDigits = '०१२३४५६७८९';

/// Converts Devanagari digits to ASCII digits.
String asciiDigits(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _devDigits.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

NaksaInfo parseNaksaText(String raw) {
  final text = asciiDigits(raw);
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final info = NaksaInfo(lines);

  // Scale: "1:1250", "1 : 2500", "Scale 1/500", "स्केल १:१२५०"
  final scaleRe = RegExp(r'1\s*[:/]\s*([0-9][0-9,]{2,5})');
  const common = [500, 600, 1000, 1200, 1250, 2400, 2500, 4800, 5000, 10000];
  for (final m in scaleRe.allMatches(text)) {
    final n = int.tryParse(m.group(1)!.replaceAll(',', ''));
    if (n != null && n >= 100 && n <= 50000) {
      info.scale = n;
      if (common.contains(n)) break;
    }
  }

  // Kitta (plot) number: "Kitta No. 412", "कि.नं. ४१२", "Plot No 412", "K.No 412"
  final kittaRe = RegExp(
      r'(?:kitta|kita|plot|parcel|k\.?\s*no|कि\.?\s*नं|कित्ता)[^0-9]{0,8}([0-9]{1,6})',
      caseSensitive: false);
  final km = kittaRe.firstMatch(text);
  if (km != null) info.kitta = km.group(1);

  // Sheet number: "Sheet No. 102-1145", "सिट नं. 102-1145", "Map sheet 2887-07"
  final sheetRe = RegExp(
      r'(?:sheet|सिट|शिट)[^0-9]{0,10}([0-9]{2,5}(?:\s*[-/]\s*[0-9]{1,5}){0,2})',
      caseSensitive: false);
  final sm = sheetRe.firstMatch(text);
  if (sm != null) info.sheet = sm.group(1)!.replaceAll(' ', '');

  // Ward: "Ward No. 5", "वडा नं. ५"
  final wardRe =
      RegExp(r'(?:ward|वडा)[^0-9]{0,8}([0-9]{1,2})', caseSensitive: false);
  final wm = wardRe.firstMatch(text);
  if (wm != null) info.ward = wm.group(1);

  // Area printed on a Lalpurja: "0-9-3-1.5", "क्षेत्रफल 0-4-2-0", "1-5-10" (B-K-D)
  final rapd = RegExp(r'\b(\d{1,3})\s*-\s*(\d{1,2})\s*-\s*(\d{1,2})(?:\s*-\s*(\d{1,2}(?:\.\d+)?))?\b');
  for (final m in rapd.allMatches(text)) {
    // Skip things that are clearly sheet numbers (already matched) or dates.
    final s = m.group(0)!;
    if (info.sheet != null && s.replaceAll(' ', '').startsWith(info.sheet!)) {
      continue;
    }
    final a = int.parse(m.group(2)!), p = int.parse(m.group(3)!);
    if (m.group(4) != null ? (a < 16 && p < 4) : (a < 20 && p < 20)) {
      info.area = s.replaceAll(' ', '');
      break;
    }
  }
  // Area in sq m: "Area 313.08 sq.m", "क्षेत्रफल ३१३.०८ व.मि."
  if (info.area == null) {
    final sqm = RegExp(
        r'([0-9]+(?:\.[0-9]+)?)\s*(?:sq\.?\s*m|m2|m²|व\.?\s*मि)',
        caseSensitive: false);
    final am = sqm.firstMatch(text);
    if (am != null) info.area = '${am.group(1)} m²';
  }
  return info;
}
