import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/ocr_parser.dart';
import '../core/plot_detector.dart';
import '../core/plot_model.dart';
import 'plot_editor.dart';
import 'theme.dart';
import 'widgets.dart';

class ScanScreen extends StatefulWidget {
  final PlotStore store;
  const ScanScreen({super.key, required this.store});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  PreparedMap? _map;
  ui.Image? _image;
  NaksaInfo? _info;
  List<Offset> _poly = const [];
  String? _message;
  bool _busyPrep = false, _busyOcr = false;

  Future<void> _pick(ImageSource src) async {
    final XFile? f;
    try {
      f = await _picker.pickImage(source: src, maxWidth: 3000, imageQuality: 92);
    } catch (e) {
      _snack('Could not open ${src == ImageSource.camera ? 'camera' : 'gallery'}: $e');
      return;
    }
    if (f == null) return;
    setState(() {
      _map = null;
      _image = null;
      _info = null;
      _poly = const [];
      _message = null;
      _busyPrep = true;
      _busyOcr = true;
    });
    _runOcr(f.path);
    try {
      final bytes = await f.readAsBytes();
      final m = await prepareMapAsync(bytes);
      final im = await _decode(m.displayJpeg);
      if (!mounted) return;
      setState(() {
        _map = m;
        _image = im;
        _busyPrep = false;
        _message = 'Tap inside your plot to detect its boundary.';
      });
      // Try the centre of the photo automatically.
      _detect(Offset(m.origWidth / 2, m.origHeight / 2), auto: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyPrep = false;
        _message = 'Could not read the image: $e';
      });
    }
  }

  Future<ui.Image> _decode(List<int> bytes) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    return (await codec.getNextFrame()).image;
  }

  Future<void> _runOcr(String path) async {
    final buf = StringBuffer();
    for (final script in [
      TextRecognitionScript.latin,
      TextRecognitionScript.devanagiri
    ]) {
      final rec = TextRecognizer(script: script);
      try {
        final r = await rec.processImage(InputImage.fromFilePath(path));
        buf.writeln(r.text);
      } catch (_) {
        // A script model may be unavailable; continue with the others.
      } finally {
        await rec.close();
      }
    }
    if (!mounted) return;
    setState(() {
      _info = parseNaksaText(buf.toString());
      _busyOcr = false;
    });
  }

  void _detect(Offset seed, {bool auto = false}) {
    final m = _map;
    if (m == null) return;
    final r = detectParcel(m, seed);
    setState(() {
      if (r.polygon.length >= 3) {
        _poly = r.polygon;
        _message = r.error ??
            'Found ${r.polygon.length} corners. Tap another plot to change, '
                'or continue.';
      } else if (!auto) {
        _message = r.error;
      }
    });
  }

  void _openEditor() {
    final m = _map;
    if (m == null) return;
    final pts = _poly.length >= 3
        ? _poly
        : [
            Offset(m.origWidth * .3, m.origHeight * .3),
            Offset(m.origWidth * .7, m.origHeight * .3),
            Offset(m.origWidth * .7, m.origHeight * .7),
            Offset(m.origWidth * .3, m.origHeight * .7),
          ];
    final info = _info;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlotEditorScreen(
        store: widget.store,
        imageBytes: m.displayJpeg,
        initialPoints: pts,
        kitta: info?.kitta ?? '',
        sheet: info?.sheet ?? '',
        location: info?.ward != null ? 'Ward ${info!.ward}' : '',
        mapScale: info?.scale,
        source: 'scan',
      ),
    ));
  }

  void _snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_map == null && !_busyPrep) return _empty(context);
    return Column(
      children: [
        ScreenHeader('Scan naksa',
            subtitle: 'OCR + plot boundary detection',
            trailing: IconButton(
              tooltip: 'New photo',
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.add_a_photo_outlined),
            )),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: const Color(0xFF0E0F12),
                child: _image == null
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(builder: (c, cons) {
                        final im = _image!;
                        final scale = [
                          cons.maxWidth / im.width,
                          cons.maxHeight / im.height
                        ].reduce((a, b) => a < b ? a : b);
                        final w = im.width * scale, h = im.height * scale;
                        final off = Offset(
                            (cons.maxWidth - w) / 2, (cons.maxHeight - h) / 2);
                        return GestureDetector(
                          onTapUp: (d) =>
                              _detect((d.localPosition - off) / scale),
                          child: CustomPaint(
                            size: Size(cons.maxWidth, cons.maxHeight),
                            painter: _ScanPainter(im, _poly, scale, off),
                          ),
                        );
                      }),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message != null)
                Text(_message!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 8),
              _ocrChips(),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Pick from gallery',
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _map == null ? null : _openEditor,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_poly.length >= 3
                          ? 'Use this plot'
                          : 'Draw plot manually'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ocrChips() {
    if (_busyOcr) {
      return const Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Reading text…'),
      ]);
    }
    final i = _info;
    if (i == null || i.isEmpty) {
      return const Text('No scale or kitta number found in the text.',
          style: TextStyle(fontSize: 13));
    }
    Widget chip(String s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3DC),
              borderRadius: BorderRadius.circular(8)),
          child: Text(s,
              style: const TextStyle(
                  color: Color(0xFF6B4500),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        );
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (i.kitta != null) chip('Kitta ${i.kitta}'),
      if (i.scale != null) chip('Scale 1:${i.scale}'),
      if (i.sheet != null) chip('Sheet ${i.sheet}'),
      if (i.ward != null) chip('Ward ${i.ward}'),
      if (i.area != null) chip('Area ${i.area}'),
    ]);
  }

  Widget _empty(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader('Scan naksa',
            subtitle: 'Photo of a cadastral map, Lalpurja or field book'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.document_scanner_outlined,
                      size: 56, color: crimson),
                  const SizedBox(height: 12),
                  const Text('How it works',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final s in const [
                    '1. Photograph the naksa flat, from straight above, in good light.',
                    '2. Text recognition reads the scale (e.g. 1:1250), kitta and sheet numbers.',
                    '3. Tap inside your plot — its boundary is traced from the map lines.',
                    '4. Adjust corners, set the scale from one known side, and get the area.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(s, style: const TextStyle(height: 1.4)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: crimson),
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Take photo'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose from gallery'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: InfoBanner(
              'Areas from a photo are estimates. Confirm with the Malpot / '
              'Napi office before buying or selling land.'),
        ),
      ],
    );
  }
}

class _ScanPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> poly;
  final double scale;
  final Offset off;
  _ScanPainter(this.image, this.poly, this.scale, this.off);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(off.dx, off.dy);
    canvas.scale(scale);
    canvas.drawImage(
        image, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
    if (poly.length < 3) return;
    final path = Path();
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i] * scale + off;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = lineGreen.withValues(alpha: 0.25));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2BD47D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    for (final q in poly) {
      final p = q * scale + off;
      canvas.drawCircle(p, 6, Paint()..color = const Color(0xFF0E0F12));
      canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = const Color(0xFF2BD47D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanPainter o) =>
      o.image != image || o.poly != poly || o.scale != scale || o.off != off;
}
