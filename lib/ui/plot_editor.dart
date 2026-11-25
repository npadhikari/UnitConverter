import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../core/geometry.dart';
import '../core/plot_model.dart';
import '../core/units.dart';
import 'report_screen.dart';
import 'theme.dart';
import 'widgets.dart';

enum EditTool { move, add, delete }

/// Interactive plotter. Points are stored in "units": image pixels when a
/// map photo is the background, metres otherwise. [metersPerUnit] converts.
class PlotEditorScreen extends StatefulWidget {
  final PlotStore store;
  final Uint8List? imageBytes;
  final List<Offset> initialPoints;
  final double? metersPerUnit;
  final LandPlot? existing;
  final String kitta, sheet, location, source;
  final int? mapScale;

  const PlotEditorScreen({
    super.key,
    required this.store,
    required this.initialPoints,
    this.imageBytes,
    this.metersPerUnit,
    this.existing,
    this.kitta = '',
    this.sheet = '',
    this.location = '',
    this.source = 'draw',
    this.mapScale,
  });

  @override
  State<PlotEditorScreen> createState() => _PlotEditorScreenState();
}

class _PlotEditorScreenState extends State<PlotEditorScreen> {
  late List<Offset> _pts = List.of(widget.initialPoints);
  final List<List<Offset>> _undo = [];
  double? _mpu; // metres per unit
  ui.Image? _image;
  EditTool _tool = EditTool.move;
  LenUnit _len = LenUnit.ft;

  // View transform: screen = unit * _zoom + _pan
  double _zoom = 1;
  Offset _pan = Offset.zero;
  bool _fitted = false;
  Size _viewSize = Size.zero;

  // Gesture state
  int? _dragIndex;
  double _startZoom = 1;
  Offset _startFocalUnits = Offset.zero;

  @override
  void initState() {
    super.initState();
    _mpu = widget.metersPerUnit;
    if (widget.imageBytes != null) {
      ui.decodeImageFromList(widget.imageBytes!, (im) {
        if (mounted) setState(() => _image = im);
      });
    }
  }

  bool get _hasImage => widget.imageBytes != null;

  Offset _toScreen(Offset u) => u * _zoom + _pan;
  Offset _toUnits(Offset s) => (s - _pan) / _zoom;

  void _fit(Size size) {
    Rect bounds;
    if (_hasImage && _image != null) {
      bounds = Rect.fromLTWH(
          0, 0, _image!.width.toDouble(), _image!.height.toDouble());
    } else if (_pts.isNotEmpty) {
      bounds = _boundsOf(_pts).inflate(_boundsOf(_pts).longestSide * 0.25 + 1);
    } else {
      bounds = const Rect.fromLTWH(0, 0, 30, 30);
    }
    final z = math.min(size.width / bounds.width, size.height / bounds.height);
    _zoom = z;
    _pan = Offset(size.width / 2, size.height / 2) - bounds.center * z;
  }

  Rect _boundsOf(List<Offset> p) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final q in p) {
      minX = math.min(minX, q.dx);
      minY = math.min(minY, q.dy);
      maxX = math.max(maxX, q.dx);
      maxY = math.max(maxY, q.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  int? _hitVertex(Offset screen) {
    int? best;
    var bestD = 30.0;
    for (var i = 0; i < _pts.length; i++) {
      final d = (_toScreen(_pts[i]) - screen).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _pushUndo() {
    _undo.add(List.of(_pts));
    if (_undo.length > 50) _undo.removeAt(0);
  }

  void _onTap(Offset screen) {
    final u = _toUnits(screen);
    if (_tool == EditTool.add) {
      _pushUndo();
      setState(() {
        if (_pts.length < 3) {
          _pts.add(u);
        } else {
          // Insert on the nearest edge.
          var bestI = 0;
          var bestD = double.infinity;
          for (var i = 0; i < _pts.length; i++) {
            final d =
                distanceToSegment(u, _pts[i], _pts[(i + 1) % _pts.length]);
            if (d < bestD) {
              bestD = d;
              bestI = i;
            }
          }
          _pts.insert(bestI + 1, u);
        }
      });
    } else if (_tool == EditTool.delete) {
      final i = _hitVertex(screen);
      if (i != null && _pts.length > 3) {
        _pushUndo();
        setState(() => _pts.removeAt(i));
      }
    }
  }

  double? get _areaM2 =>
      _mpu == null || _pts.length < 3 ? null : polygonArea(_pts) * _mpu! * _mpu!;

  String _sideName(int i) =>
      '${String.fromCharCode(65 + i % 26)}${String.fromCharCode(65 + (i + 1) % _pts.length % 26)}';

  Future<void> _calibrate() async {
    if (_pts.length < 2) return;
    final res = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _CalibrateSheet(
        sides: [
          for (var i = 0; i < _pts.length; i++)
            (_sideName(i), (_pts[(i + 1) % _pts.length] - _pts[i]).distance)
        ],
        mapScale: widget.mapScale,
        isImage: _hasImage,
      ),
    );
    if (res != null && res > 0) setState(() => _mpu = res);
  }

  Future<void> _save() async {
    final a = _areaM2;
    if (a == null) return;
    final pts = [for (final p in _pts) p * _mpu!];
    // Normalise so the plot starts near the origin.
    final b = _boundsOf(pts);
    final norm = [for (final p in pts) p - b.topLeft];
    final ex = widget.existing;
    final nameCtl = TextEditingController(
        text: ex?.name ??
            (widget.kitta.isNotEmpty
                ? 'Kitta ${widget.kitta}'
                : 'Plot ${widget.store.plots.length + 1}'));
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save plot'),
        content: TextField(
          controller: nameCtl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, nameCtl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final plot = LandPlot(
      id: ex?.id ?? PlotStore.newId(),
      name: name.isEmpty ? 'Plot' : name,
      kitta: ex?.kitta ?? widget.kitta,
      sheet: ex?.sheet ?? widget.sheet,
      location: ex?.location ?? widget.location,
      mapScale: ex?.mapScale ?? widget.mapScale,
      source: ex?.source ?? widget.source,
      points: norm,
      created: ex?.created,
    );
    await widget.store.upsert(plot);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ReportScreen(store: widget.store, plotId: plot.id)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final area = _areaM2;
    final title = widget.kitta.isNotEmpty
        ? 'Kitta ${widget.kitta}'
        : (widget.existing?.name ?? 'Map plotter');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          SegmentedButton<LenUnit>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: LenUnit.ft, label: Text('ft')),
              ButtonSegment(value: LenUnit.m, label: Text('m')),
            ],
            selected: {_len},
            onSelectionChanged: (s) => setState(() => _len = s.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(builder: (context, cons) {
                  final size = Size(cons.maxWidth, cons.maxHeight);
                  if (!_fitted || size != _viewSize) {
                    if (!_hasImage || _image != null) {
                      _fit(size);
                      _fitted = true;
                      _viewSize = size;
                    }
                  }
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onTap(d.localPosition),
                    onScaleStart: (d) {
                      _dragIndex = _tool == EditTool.move && d.pointerCount == 1
                          ? _hitVertex(d.localFocalPoint)
                          : null;
                      if (_dragIndex != null) _pushUndo();
                      _startZoom = _zoom;
                      _startFocalUnits = _toUnits(d.localFocalPoint);
                    },
                    onScaleUpdate: (d) {
                      setState(() {
                        if (_dragIndex != null) {
                          _pts[_dragIndex!] = _toUnits(d.localFocalPoint);
                        } else {
                          _zoom = (_startZoom * d.scale).clamp(0.02, 400.0);
                          _pan = d.localFocalPoint - _startFocalUnits * _zoom;
                        }
                      });
                    },
                    onScaleEnd: (_) => _dragIndex = null,
                    child: CustomPaint(
                      size: size,
                      painter: _PlotPainter(
                        pts: _pts,
                        image: _image,
                        zoom: _zoom,
                        pan: _pan,
                        mpu: _mpu,
                        len: _len,
                        dark: Theme.of(context).brightness == Brightness.dark,
                        showGrid: !_hasImage,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<EditTool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: EditTool.move,
                          icon: Icon(Icons.open_with),
                          label: Text('Move')),
                      ButtonSegment(
                          value: EditTool.add,
                          icon: Icon(Icons.add_location_alt_outlined),
                          label: Text('Add')),
                      ButtonSegment(
                          value: EditTool.delete,
                          icon: Icon(Icons.remove_circle_outline),
                          label: Text('Delete')),
                    ],
                    selected: {_tool},
                    onSelectionChanged: (s) => setState(() => _tool = s.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Undo',
                  onPressed: _undo.isEmpty
                      ? null
                      : () => setState(() => _pts = _undo.removeLast()),
                  icon: const Icon(Icons.undo),
                ),
                IconButton.outlined(
                  tooltip: 'Fit to screen',
                  onPressed: () => setState(() => _fit(_viewSize)),
                  icon: const Icon(Icons.fit_screen),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: area == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _pts.length < 3
                              ? 'Add at least 3 corners (use Add, then tap).'
                              : 'Set the scale: give the real length of one side.',
                          style: const TextStyle(
                              color: Color(0xFFB9BCC4), fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _pts.length >= 3 ? _calibrate : null,
                          icon: const Icon(Icons.straighten),
                          label: const Text('Set scale'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('CALCULATED AREA',
                                  style: TextStyle(
                                      color: Color(0xFFB9BCC4),
                                      fontSize: 12,
                                      letterSpacing: 0.6,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Flexible(
                              child: Text(
                                  '${_pts.length} corners · '
                                  '${fmt(polygonPerimeter(_pts) * _mpu! / _len.meters, 1)} ${_len.label} around',
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFFB9BCC4), fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                                _len == LenUnit.m
                                    ? fmt(area, 2)
                                    : fmt(area / sqFt, 1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text(_len == LenUnit.m ? 'm²' : 'sq ft',
                                style: const TextStyle(
                                    color: Color(0xFFB9BCC4), fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill('${Rapd.fromM2(area)} R-A-P-D'),
                            _pill('${Bkd.fromM2(area)} B-K-D'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                        color: Color(0xFF5B606B))),
                                onPressed: _calibrate,
                                child: const Text('Rescale'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: crimson,
                                    foregroundColor: Colors.white),
                                onPressed: _save,
                                child: const Text('Save & report'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      backgroundColor: cs.surface,
    );
  }

  Widget _pill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(s,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      );
}

class _PlotPainter extends CustomPainter {
  final List<Offset> pts;
  final ui.Image? image;
  final double zoom;
  final Offset pan;
  final double? mpu;
  final LenUnit len;
  final bool dark;
  final bool showGrid;

  _PlotPainter({
    required this.pts,
    required this.image,
    required this.zoom,
    required this.pan,
    required this.mpu,
    required this.len,
    required this.dark,
    required this.showGrid,
  });

  Offset s(Offset u) => u * zoom + pan;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = dark ? const Color(0xFF202227) : Colors.white);

    if (image != null) {
      canvas.save();
      canvas.translate(pan.dx, pan.dy);
      canvas.scale(zoom);
      canvas.drawImage(image!, Offset.zero,
          Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
    }

    if (showGrid) _drawGrid(canvas, size);

    if (pts.isEmpty) return;
    final path = Path()..moveTo(s(pts[0]).dx, s(pts[0]).dy);
    for (final p in pts.skip(1)) {
      path.lineTo(s(p).dx, s(p).dy);
    }
    if (pts.length > 2) path.close();
    canvas.drawPath(
        path, Paint()..color = crimson.withValues(alpha: 0.14));
    canvas.drawPath(
        path,
        Paint()
          ..color = crimson
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);

    // Side lengths.
    if (mpu != null && pts.length >= 2) {
      for (var i = 0; i < pts.length; i++) {
        if (pts.length == 2 && i == 1) break;
        final a = pts[i], b = pts[(i + 1) % pts.length];
        final lenM = (b - a).distance * mpu!;
        final mid = s((a + b) / 2);
        _label(canvas, mid, '${fmt(lenM / len.meters, 1)} ${len.label}',
            bg: ink, fg: Colors.white);
      }
    }

    // Vertices + letters.
    for (var i = 0; i < pts.length; i++) {
      final p = s(pts[i]);
      canvas.drawCircle(p, 9, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          9,
          Paint()
            ..color = crimson
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      _text(canvas, p + const Offset(10, -24), String.fromCharCode(65 + i % 26),
          crimson, 14, FontWeight.w700);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    if (mpu == null) return;
    // Choose a metric step that is ~24-80 px on screen.
    final pxPerM = zoom / mpu!;
    var step = 1.0;
    for (final st in [0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500]) {
      step = st.toDouble();
      if (step * pxPerM >= 24) break;
    }
    final minor = Paint()
      ..color = dark ? const Color(0xFF2A2D33) : const Color(0xFFEFEDE6)
      ..strokeWidth = 1;
    final tl = (Offset.zero - pan) / zoom * mpu!;
    final br = (Offset(size.width, size.height) - pan) / zoom * mpu!;
    for (var x = (tl.dx / step).floor() * step; x <= br.dx; x += step) {
      final sx = x / mpu! * zoom + pan.dx;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), minor);
    }
    for (var y = (tl.dy / step).floor() * step; y <= br.dy; y += step) {
      final sy = y / mpu! * zoom + pan.dy;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), minor);
    }
    // Scale bar.
    final barPx = step * pxPerM;
    final y = size.height - 18;
    final p = Paint()
      ..color = muted
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(16, y), Offset(16 + barPx, y), p);
    canvas.drawLine(Offset(16, y - 5), Offset(16, y + 5), p);
    canvas.drawLine(Offset(16 + barPx, y - 5), Offset(16 + barPx, y + 5), p);
    _text(canvas, Offset(22 + barPx, y - 8), '${fmt(step, 1)} m', muted, 11,
        FontWeight.w500);
  }

  void _label(Canvas c, Offset center, String t,
      {required Color bg, required Color fg}) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center, width: tp.width + 16, height: tp.height + 8),
        const Radius.circular(12));
    c.drawRRect(r, Paint()..color = bg.withValues(alpha: 0.88));
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _text(Canvas c, Offset at, String t, Color col, double size,
      FontWeight w) {
    final tp = TextPainter(
      text: TextSpan(
          text: t, style: TextStyle(color: col, fontSize: size, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant _PlotPainter o) => true;
}

/// Bottom sheet to derive metres-per-unit from one known side length.
class _CalibrateSheet extends StatefulWidget {
  final List<(String, double)> sides; // name, length in units
  final int? mapScale;
  final bool isImage;
  const _CalibrateSheet(
      {required this.sides, required this.mapScale, required this.isImage});

  @override
  State<_CalibrateSheet> createState() => _CalibrateSheetState();
}

class _CalibrateSheetState extends State<_CalibrateSheet> {
  int _side = 0;
  bool _paper = false;
  LenUnit _unit = LenUnit.ft;
  final _len = TextEditingController();
  late final _scale =
      TextEditingController(text: widget.mapScale?.toString() ?? '1250');

  double? _result() {
    final v = parseNum(_len.text);
    if (v == null || v <= 0) return null;
    final sidePx = widget.sides[_side].$2;
    if (sidePx <= 0) return null;
    double meters;
    if (_paper) {
      final n = parseNum(_scale.text);
      if (n == null || n <= 0) return null;
      meters = v / 1000 * n; // mm on paper × scale
    } else {
      meters = v * _unit.meters;
    }
    return meters / sidePx;
  }

  @override
  Widget build(BuildContext context) {
    final r = _result();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Set scale',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              widget.isImage
                  ? 'Enter the real length of one side (from a tape or the Lalpurja), '
                      'or measure it on the paper map with a ruler.'
                  : 'Enter the real length of one side; the whole shape is scaled to match.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (widget.isImage)
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Real length')),
                ButtonSegment(value: true, label: Text('Ruler on map')),
              ],
              selected: {_paper},
              onSelectionChanged: (s) => setState(() => _paper = s.first),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < widget.sides.length; i++)
                ChoiceChip(
                  label: Text('Side ${widget.sides[i].$1}'),
                  selected: _side == i,
                  onSelected: (_) => setState(() => _side = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _len,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: _paper
                          ? 'Length on paper (mm)'
                          : 'Length of side ${widget.sides[_side].$1}'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              if (_paper)
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _scale,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Scale 1 :', hintText: '1250'),
                    onChanged: (_) => setState(() {}),
                  ),
                )
              else
                DropdownButton<LenUnit>(
                  value: _unit,
                  items: [
                    for (final u in LenUnit.values)
                      DropdownMenuItem(value: u, child: Text(u.label)),
                  ],
                  onChanged: (u) => setState(() => _unit = u!),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: r == null ? null : () => Navigator.pop(context, r),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
