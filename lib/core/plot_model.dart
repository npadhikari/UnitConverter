import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'geometry.dart';

/// A saved land parcel. [points] are in metres (x right, y down).
class LandPlot {
  final String id;
  String name;
  String kitta;
  String sheet;
  String location;
  int? mapScale; // e.g. 1250 for 1:1250
  String source; // 'scan' | 'tape' | 'draw'
  List<Offset> points;
  DateTime created;

  LandPlot({
    required this.id,
    required this.name,
    this.kitta = '',
    this.sheet = '',
    this.location = '',
    this.mapScale,
    this.source = 'draw',
    required this.points,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  double get areaM2 => polygonArea(points);
  double get perimeterM => polygonPerimeter(points);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kitta': kitta,
        'sheet': sheet,
        'location': location,
        'mapScale': mapScale,
        'source': source,
        'points': [for (final p in points) [p.dx, p.dy]],
        'created': created.toIso8601String(),
      };

  factory LandPlot.fromJson(Map<String, dynamic> j) => LandPlot(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Plot',
        kitta: j['kitta'] as String? ?? '',
        sheet: j['sheet'] as String? ?? '',
        location: j['location'] as String? ?? '',
        mapScale: j['mapScale'] as int?,
        source: j['source'] as String? ?? 'draw',
        points: [
          for (final p in (j['points'] as List))
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())
        ],
        created: DateTime.tryParse(j['created'] as String? ?? ''),
      );
}

/// Persists plots in SharedPreferences as JSON.
class PlotStore extends ChangeNotifier {
  static const _key = 'plots_v1';
  final List<LandPlot> plots = [];
  bool loaded = false;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    plots.clear();
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          plots.add(LandPlot.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {/* ignore corrupt data */}
    }
    plots.sort((a, b) => b.created.compareTo(a.created));
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode([for (final p in plots) p.toJson()]));
    notifyListeners();
  }

  Future<void> upsert(LandPlot p) async {
    final i = plots.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      plots[i] = p;
    } else {
      plots.insert(0, p);
    }
    await _save();
  }

  Future<void> remove(String id) async {
    plots.removeWhere((e) => e.id == id);
    await _save();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
