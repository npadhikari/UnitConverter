/// Unit definitions, including traditional Nepali land, weight and volume
/// units. Every unit is linear: value_in_base = value * factor.
library;

class UnitDef {
  final String id;
  final String name;
  final String symbol;
  final double factor; // to the category's base unit
  final String? nepali;
  const UnitDef(this.id, this.name, this.symbol, this.factor, {this.nepali});
}

class Category {
  final String id;
  final String name;
  final String baseLabel;
  final List<UnitDef> units;
  const Category(this.id, this.name, this.baseLabel, this.units);

  UnitDef unit(String id) => units.firstWhere((u) => u.id == id);
}

// ---- Area (base: m²) ------------------------------------------------------
// Hill system:  1 Ropani = 16 Aana = 64 Paisa = 256 Daam = 5476 sq ft
// Terai system: 1 Bigha = 20 Kattha = 400 Dhur = 72900 sq ft
const double sqFt = 0.09290304;
const double ropaniM2 = 5476 * sqFt; // 508.737
const double aanaM2 = ropaniM2 / 16;
const double paisaM2 = ropaniM2 / 64;
const double daamM2 = ropaniM2 / 256;
const double bighaM2 = 72900 * sqFt; // 6772.63
const double katthaM2 = bighaM2 / 20;
const double dhurM2 = bighaM2 / 400;

const area = Category('area', 'Land / Area', 'm²', [
  UnitDef('sqft', 'Square feet', 'sq ft', sqFt),
  UnitDef('sqm', 'Square metres', 'm²', 1),
  UnitDef('ropani', 'Ropani', 'ropani', ropaniM2, nepali: 'रोपनी'),
  UnitDef('aana', 'Aana', 'aana', aanaM2, nepali: 'आना'),
  UnitDef('paisa', 'Paisa', 'paisa', paisaM2, nepali: 'पैसा'),
  UnitDef('daam', 'Daam', 'daam', daamM2, nepali: 'दाम'),
  UnitDef('bigha', 'Bigha', 'bigha', bighaM2, nepali: 'बिघा'),
  UnitDef('kattha', 'Kattha', 'kattha', katthaM2, nepali: 'कट्ठा'),
  UnitDef('dhur', 'Dhur', 'dhur', dhurM2, nepali: 'धुर'),
  UnitDef('acre', 'Acres', 'ac', 4046.8564224),
  UnitDef('hectare', 'Hectares', 'ha', 10000),
  UnitDef('sqyd', 'Square yards', 'sq yd', 0.83612736),
  UnitDef('sqkm', 'Square kilometres', 'km²', 1e6),
]);

const length = Category('length', 'Length', 'm', [
  UnitDef('m', 'Metres', 'm', 1),
  UnitDef('ft', 'Feet', 'ft', 0.3048),
  UnitDef('in', 'Inches', 'in', 0.0254),
  UnitDef('haat', 'Haat (cubit)', 'haat', 0.4572, nepali: 'हात'),
  UnitDef('yd', 'Yards', 'yd', 0.9144),
  UnitDef('chain', 'Chain (66 ft)', 'ch', 20.1168),
  UnitDef('cm', 'Centimetres', 'cm', 0.01),
  UnitDef('mm', 'Millimetres', 'mm', 0.001),
  UnitDef('km', 'Kilometres', 'km', 1000),
  UnitDef('mi', 'Miles', 'mi', 1609.344),
]);

const mass = Category('mass', 'Weight', 'kg', [
  UnitDef('kg', 'Kilograms', 'kg', 1),
  UnitDef('g', 'Grams', 'g', 0.001),
  UnitDef('tola', 'Tola', 'tola', 0.0116638, nepali: 'तोला'),
  UnitDef('lal', 'Lal', 'lal', 0.000116638, nepali: 'लाल'),
  UnitDef('pau', 'Pau', 'pau', 0.199375, nepali: 'पाउ'),
  UnitDef('ser', 'Ser', 'ser', 0.7975, nepali: 'सेर'),
  UnitDef('dharni', 'Dharni', 'dharni', 2.3925, nepali: 'धार्नी'),
  UnitDef('lb', 'Pounds', 'lb', 0.45359237),
  UnitDef('oz', 'Ounces', 'oz', 0.028349523125),
  UnitDef('t', 'Tonnes', 't', 1000),
]);

const volume = Category('volume', 'Volume', 'L', [
  UnitDef('l', 'Litres', 'L', 1),
  UnitDef('ml', 'Millilitres', 'mL', 0.001),
  UnitDef('mana', 'Mana', 'mana', 4.54609 / 8, nepali: 'माना'),
  UnitDef('pathi', 'Pathi', 'pathi', 4.54609, nepali: 'पाथी'),
  UnitDef('muri', 'Muri', 'muri', 4.54609 * 20, nepali: 'मुरी'),
  UnitDef('m3', 'Cubic metres', 'm³', 1000),
  UnitDef('galus', 'US gallons', 'gal', 3.785411784),
  UnitDef('cuft', 'Cubic feet', 'cu ft', 28.316846592),
]);

const categories = [area, length, mass, volume];

double convert(double value, UnitDef from, UnitDef to) =>
    value * from.factor / to.factor;

/// Ropani-Aana-Paisa-Daam breakdown of an area in m².
class Rapd {
  final int ropani, aana, paisa;
  final double daam;
  const Rapd(this.ropani, this.aana, this.paisa, this.daam);

  factory Rapd.fromM2(double m2) {
    var d = m2 / daamM2;
    // Avoid 3.9999999 style artefacts.
    d = (d * 1e6).roundToDouble() / 1e6;
    final r = d ~/ 256;
    d -= r * 256;
    final a = d ~/ 16;
    d -= a * 16;
    final p = d ~/ 4;
    d -= p * 4;
    return Rapd(r, a, p, d);
  }

  double toM2() =>
      ropani * ropaniM2 + aana * aanaM2 + paisa * paisaM2 + daam * daamM2;

  @override
  String toString() => '$ropani-$aana-$paisa-${fmt(daam, 2)}';
}

/// Bigha-Kattha-Dhur breakdown of an area in m².
class Bkd {
  final int bigha, kattha;
  final double dhur;
  const Bkd(this.bigha, this.kattha, this.dhur);

  factory Bkd.fromM2(double m2) {
    var d = m2 / dhurM2;
    d = (d * 1e6).roundToDouble() / 1e6;
    final b = d ~/ 400;
    d -= b * 400;
    final k = d ~/ 20;
    d -= k * 20;
    return Bkd(b, k, d);
  }

  double toM2() => bigha * bighaM2 + kattha * katthaM2 + dhur * dhurM2;

  @override
  String toString() => '$bigha-$kattha-${fmt(dhur, 2)}';
}

/// Formats a number with thousands separators and up to [dp] decimals.
String fmt(double v, [int dp = 2]) {
  if (v.isNaN || v.isInfinite) return '—';
  final neg = v < 0;
  var s = v.abs().toStringAsFixed(dp);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '${neg ? '-' : ''}$intPart${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// Picks sensible decimals for a converted value.
String fmtAuto(double v) {
  final a = v.abs();
  if (a == 0) return '0';
  if (a >= 1000) return fmt(v, 2);
  if (a >= 1) return fmt(v, 4);
  if (a >= 0.001) return fmt(v, 6);
  return v.toStringAsExponential(4);
}

/// Parses user input, accepting Devanagari digits and thousands separators.
double? parseNum(String s) {
  const dev = '०१२३४५६७८९';
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    final i = dev.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return double.tryParse(b.toString().replaceAll(',', ''));
}
