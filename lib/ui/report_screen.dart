import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/plot_model.dart';
import '../core/units.dart';
import 'plot_editor.dart';
import 'theme.dart';
import 'widgets.dart';

class ReportScreen extends StatefulWidget {
  final PlotStore store;
  final String plotId;
  const ReportScreen({super.key, required this.store, required this.plotId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _hill = true;
  LenUnit _len = LenUnit.ft;

  LandPlot? get _plot {
    final i = widget.store.plots.indexWhere((p) => p.id == widget.plotId);
    return i < 0 ? null : widget.store.plots[i];
  }

  Future<void> _delete(LandPlot p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete plot?'),
        content: Text('"${p.name}" will be removed from this phone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.remove(p.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _edit(LandPlot p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlotEditorScreen(
        store: widget.store,
        existing: p,
        initialPoints: p.points,
        metersPerUnit: 1,
        kitta: p.kitta,
      ),
    ));
  }

  Future<void> _sharePdf(LandPlot p) async {
    try {
      final bytes = await buildPlotPdf(p);
      final dir = await getTemporaryDirectory();
      final safe = p.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
      final f = File('${dir.path}/$safe-report.pdf');
      await f.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'application/pdf')],
        subject: '${p.name} — land area report',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not export: $e')));
      }
    }
  }

  Future<void> _shareText(LandPlot p) async {
    final a = p.areaM2;
    await SharePlus.instance.share(ShareParams(
      text: '${p.name}${p.kitta.isNotEmpty ? ' (Kitta ${p.kitta})' : ''}\n'
          'Area: ${fmt(a / sqFt, 1)} sq ft · ${fmt(a, 2)} m²\n'
          'R-A-P-D: ${Rapd.fromM2(a)} · B-K-D: ${Bkd.fromM2(a)}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final p = _plot;
        if (p == null) {
          return Scaffold(
              appBar: AppBar(), body: const Center(child: Text('Not found')));
        }
        final a = p.areaM2;
        final r = Rapd.fromM2(a), b = Bkd.fromM2(a);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plot report'),
            actions: [
              IconButton(
                  tooltip: 'Edit outline',
                  onPressed: () => _edit(p),
                  icon: const Icon(Icons.edit_outlined)),
              IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(p),
                  icon: const Icon(Icons.delete_outline)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10)),
                        child: CustomPaint(painter: PlotThumbPainter(p.points)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            if (p.kitta.isNotEmpty) Text('Kitta ${p.kitta}'),
                            if (p.sheet.isNotEmpty) Text('Sheet ${p.sheet}'),
                            if (p.location.isNotEmpty) Text(p.location),
                            Text(
                                [
                                  if (p.mapScale != null)
                                    'Scale 1:${p.mapScale}',
                                  '${p.points.length} corners',
                                  _sourceLabel(p.source),
                                ].join(' · '),
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: ink, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        foregroundColor: Colors.white,
                        selectedForegroundColor: ink,
                        selectedBackgroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment(value: true, label: Text('Hill')),
                        ButtonSegment(value: false, label: Text('Terai')),
                      ],
                      selected: {_hill},
                      onSelectionChanged: (s) =>
                          setState(() => _hill = s.first),
                    ),
                    const SizedBox(height: 12),
                    Text(_hill ? '$r' : '$b',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w600)),
                    Text(
                        _hill
                            ? 'Ropani – Aana – Paisa – Daam'
                            : 'Bigha – Kattha – Dhur',
                        style: const TextStyle(
                            color: Color(0xFFB9BCC4), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ValueTable(areaRows(a)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                      child: Text('Sides',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15))),
                  SegmentedButton<LenUnit>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                    segments: const [
                      ButtonSegment(value: LenUnit.ft, label: Text('ft')),
                      ButtonSegment(value: LenUnit.m, label: Text('m')),
                      ButtonSegment(value: LenUnit.haat, label: Text('haat')),
                    ],
                    selected: {_len},
                    onSelectionChanged: (s) => setState(() => _len = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueTable([
                for (final s in sideLengths(p))
                  (s.$1, '${fmt(s.$2 / _len.meters, 2)} ${_len.label}'),
                ('Perimeter', '${fmt(p.perimeterM / _len.meters, 2)} ${_len.label}'),
              ]),
              const SizedBox(height: 12),
              const InfoBanner(
                  'Calculated estimate. Verify with the Malpot / Napi (survey) '
                  'office before buying or selling.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareText(p),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: crimson),
                      onPressed: () => _sharePdf(p),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _sourceLabel(String s) => switch (s) {
      'scan' => 'from scan',
      'tape' => 'from tape',
      _ => 'drawn',
    };

List<(String, double)> sideLengths(LandPlot p) {
  final n = p.points.length;
  return [
    for (var i = 0; i < n; i++)
      (
        '${String.fromCharCode(65 + i % 26)}–${String.fromCharCode(65 + (i + 1) % n % 26)}',
        (p.points[(i + 1) % n] - p.points[i]).distance
      )
  ];
}

class PlotThumbPainter extends CustomPainter {
  final List<Offset> pts;
  PlotThumbPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 3) return;
    final t = fitPoints(pts, size.width, size.height, 10);
    final path = Path()..addPolygon(t, true);
    canvas.drawPath(path, Paint()..color = crimson.withValues(alpha: 0.14));
    canvas.drawPath(
        path,
        Paint()
          ..color = crimson
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant PlotThumbPainter o) => o.pts != pts;
}

/// Scales points to fit a w×h box with padding, preserving aspect ratio.
List<Offset> fitPoints(List<Offset> pts, double w, double h, double pad) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  final bw = math.max(maxX - minX, 1e-9), bh = math.max(maxY - minY, 1e-9);
  final s = math.min((w - 2 * pad) / bw, (h - 2 * pad) / bh);
  final ox = (w - bw * s) / 2, oy = (h - bh * s) / 2;
  return [for (final p in pts) Offset(ox + (p.dx - minX) * s, oy + (p.dy - minY) * s)];
}

/// Builds a one-page A4 PDF report for a plot.
Future<List<int>> buildPlotPdf(LandPlot p) async {
  final doc = pw.Document(title: p.name, author: 'Converter NOW');
  final a = p.areaM2;
  final sides = sideLengths(p);
  final pts = fitPoints(p.points, 300, 300, 24);
  final red = PdfColor.fromInt(0xFFC8102E);

  // Side labels at edge midpoints.
  final n = pts.length;
  final svgLabels = StringBuffer();
  for (var i = 0; i < n; i++) {
    final m = (pts[i] + pts[(i + 1) % n]) / 2;
    svgLabels.write(
        '<text x="${m.dx.toStringAsFixed(1)}" y="${m.dy.toStringAsFixed(1)}" '
        'font-size="10" fill="#16181D" text-anchor="middle">'
        '${fmt(sides[i].$2 / 0.3048, 1)} ft</text>');
    svgLabels.write(
        '<text x="${(pts[i].dx + 4).toStringAsFixed(1)}" y="${(pts[i].dy - 4).toStringAsFixed(1)}" '
        'font-size="11" font-weight="bold" fill="#C8102E">${String.fromCharCode(65 + i % 26)}</text>');
  }
  final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300">'
      '<polygon points="${pts.map((q) => '${q.dx.toStringAsFixed(1)},${q.dy.toStringAsFixed(1)}').join(' ')}" '
      'fill="#F9E1E5" stroke="#C8102E" stroke-width="2"/>$svgLabels</svg>';

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (c) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Land area report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
            [
              p.name,
              if (p.kitta.isNotEmpty) 'Kitta ${p.kitta}',
              if (p.sheet.isNotEmpty) 'Sheet ${p.sheet}',
              if (p.location.isNotEmpty) p.location,
              if (p.mapScale != null) 'Scale 1:${p.mapScale}',
            ].join('  |  '),
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        pw.Divider(color: red, thickness: 2),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SvgImage(svg: svg, width: 230, height: 230),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Area', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('${fmt(a / sqFt, 1)} sq ft',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${fmt(a, 2)} sq m'),
                  pw.SizedBox(height: 10),
                  pw.Text('Hill (R-A-P-D): ${Rapd.fromM2(a)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Terai (B-K-D): ${Bkd.fromM2(a)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('All units',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Unit', 'Value'],
          data: [for (final r in areaRows(a)) [r.$1, r.$2]],
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {1: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 14),
        pw.Text('Sides',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Side', 'Feet', 'Metres', 'Haat'],
          data: [
            for (final s in sides)
              [
                s.$1.replaceAll('–', '-'),
                fmt(s.$2 / 0.3048, 2),
                fmt(s.$2, 2),
                fmt(s.$2 / 0.4572, 2)
              ],
            [
              'Perimeter',
              fmt(p.perimeterM / 0.3048, 2),
              fmt(p.perimeterM, 2),
              fmt(p.perimeterM / 0.4572, 2)
            ],
          ],
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight
          },
        ),
        pw.Spacer(),
        pw.Text(
            'Estimate generated by Converter NOW on '
            '${DateTime.now().toString().substring(0, 16)}. '
            'Verify with the Malpot / Napi office before any transaction.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ),
  ));
  return doc.save();
}
