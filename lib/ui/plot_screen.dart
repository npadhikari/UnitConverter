import 'package:material_ui/material_ui.dart';

import '../core/geometry.dart';
import '../core/plot_model.dart';
import '../core/units.dart';
import 'plot_editor.dart';
import 'widgets.dart';

/// Plot tab: draw on a blank grid, or compute from tape measurements.
class PlotScreen extends StatefulWidget {
  final PlotStore store;
  const PlotScreen({super.key, required this.store});

  @override
  State<PlotScreen> createState() => _PlotScreenState();
}

class _PlotScreenState extends State<PlotScreen> {
  bool _quad = true;
  LenUnit _unit = LenUnit.ft;
  final _c = {
    for (final k in ['ab', 'bc', 'cd', 'da', 'ac']) k: TextEditingController()
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(String k) {
    final v = parseNum(_c[k]!.text);
    return v == null || v <= 0 ? null : v * _unit.meters;
  }

  /// Returns polygon in metres, or null if inputs are incomplete/invalid.
  (List<Offset>?, String?) _shape() {
    final ab = _v('ab'), bc = _v('bc'), cd = _v('cd'), da = _v('da'), ac = _v('ac');
    if (_quad) {
      if ([ab, bc, cd, da, ac].contains(null)) return (null, null);
      final q = quadFromSides(ab!, bc!, cd!, da!, ac!);
      if (q == null) {
        return (null, 'These lengths cannot form a plot — check the diagonal.');
      }
      return (q, null);
    }
    if ([ab, bc, ac].contains(null)) return (null, null);
    final t = triangleFromSides(ab!, bc!, ac!);
    if (t == null) return (null, 'These three sides cannot form a triangle.');
    return (t, null);
  }

  void _openDraw(List<Offset> pts, {String source = 'draw'}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlotEditorScreen(
        store: widget.store,
        initialPoints: pts,
        metersPerUnit: 1,
        source: source,
      ),
    ));
  }

  Widget _field(String k, String label) => TextField(
        controller: _c[k],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            InputDecoration(labelText: label, suffixText: _unit.label),
        onChanged: (_) => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final (shape, err) = _shape();
    final area = shape == null ? null : polygonArea(shape);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader('Map plotter',
            subtitle: 'Draw a plot or use tape measurements'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(Icons.grid_on),
              title: const Text('Draw on a grid',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Start from a 20 × 15 m rectangle; drag, add or delete corners.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openDraw(const [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 15),
                Offset(0, 15),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Tape measurements',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      _quad
                          ? 'Measure the 4 sides A→B→C→D and the diagonal A–C. '
                              'The plot is split into two triangles (Heron’s formula).'
                          : 'Measure the 3 sides of the triangle.',
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: true, label: Text('4 sides')),
                            ButtonSegment(value: false, label: Text('Triangle')),
                          ],
                          selected: {_quad},
                          onSelectionChanged: (s) =>
                              setState(() => _quad = s.first),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field('ab', 'Side AB')),
                    const SizedBox(width: 8),
                    Expanded(child: _field('bc', 'Side BC')),
                  ]),
                  const SizedBox(height: 10),
                  if (_quad) ...[
                    Row(children: [
                      Expanded(child: _field('cd', 'Side CD')),
                      const SizedBox(width: 8),
                      Expanded(child: _field('da', 'Side DA')),
                    ]),
                    const SizedBox(height: 10),
                    _field('ac', 'Diagonal AC'),
                  ] else
                    _field('ac', 'Side CA'),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (area != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: HillCard(area),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TeraiCard(area),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ValueTable([
              ('Square feet', fmt(area / sqFt, 2)),
              ('Square metres', fmt(area, 2)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FilledButton.icon(
              onPressed: () => _openDraw(shape!, source: 'tape'),
              icon: const Icon(Icons.pentagon_outlined),
              label: const Text('Open in plotter & save'),
            ),
          ),
        ],
      ],
    );
  }
}
