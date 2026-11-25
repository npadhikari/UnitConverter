import 'package:material_ui/material_ui.dart';

import '../core/units.dart';
import 'theme.dart';
import 'widgets.dart';

class ConvertScreen extends StatefulWidget {
  final VoidCallback onScan;
  const ConvertScreen({super.key, required this.onScan});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

/// Input modes for the area category besides single units.
enum _Composite { none, rapd, bkd }

class _ConvertScreenState extends State<ConvertScreen> {
  Category _cat = area;
  String _unitId = 'sqft';
  _Composite _composite = _Composite.none;
  final _value = TextEditingController(text: '1');
  // Composite fields: R, A, P, D  or  B, K, D.
  final _parts = List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    _value.dispose();
    for (final c in _parts) {
      c.dispose();
    }
    super.dispose();
  }

  double _baseValue() {
    if (_cat.id == 'area' && _composite != _Composite.none) {
      double p(int i) => parseNum(_parts[i].text) ?? 0;
      if (_composite == _Composite.rapd) {
        return p(0) * ropaniM2 + p(1) * aanaM2 + p(2) * paisaM2 + p(3) * daamM2;
      }
      return p(0) * bighaM2 + p(1) * katthaM2 + p(2) * dhurM2;
    }
    final v = parseNum(_value.text) ?? 0;
    return v * _cat.unit(_unitId).factor;
  }

  void _setCategory(Category c) {
    setState(() {
      _cat = c;
      _unitId = c.units.first.id;
      _composite = _Composite.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseValue();
    final cs = Theme.of(context).colorScheme;
    final isArea = _cat.id == 'area';

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenHeader('Converter NOW',
            subtitle: 'Nepal land edition · जग्गा नाप'),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.name),
                    selected: c == _cat,
                    onSelected: (_) => _setCategory(c),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ENTER VALUE',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  if (isArea && _composite != _Composite.none)
                    _compositeFields()
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _value,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                                fontSize: 34, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _unitId,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final u in _cat.units)
                              DropdownMenuItem(
                                  value: u.id,
                                  child: Text(u.nepali == null
                                      ? u.symbol
                                      : '${u.name} ${u.nepali}')),
                          ],
                          onChanged: (v) => setState(() => _unitId = v!),
                        ),
                      ],
                    ),
                  if (isArea) ...[
                    const SizedBox(height: 12),
                    SegmentedButton<_Composite>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: _Composite.none, label: Text('Single unit')),
                        ButtonSegment(
                            value: _Composite.rapd, label: Text('R-A-P-D')),
                        ButtonSegment(
                            value: _Composite.bkd, label: Text('B-K-D')),
                      ],
                      selected: {_composite},
                      onSelectionChanged: (s) => setState(() {
                        _composite = s.first;
                        for (final c in _parts) {
                          c.clear();
                        }
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (isArea) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: HillCard(base),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TeraiCard(base),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ValueTable([
            for (final u in _cat.units)
              if (!(isArea && _composite == _Composite.none && u.id == _unitId))
                (
                  u.nepali == null ? u.name : '${u.name} (${u.nepali})',
                  '${fmtAuto(base / u.factor)} ${u.symbol}'
                ),
          ]),
        ),
        if (isArea)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: crimson,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onScan,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.document_scanner, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scan a naksa or Lalpurja',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            Text('Detect plot outline, scale and kitta no.',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_cat.id != 'area' && _cat.id != 'length')
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: InfoBanner(
                'Traditional Nepali weight and volume units vary by region; '
                'the values used are the common standard ones.'),
          ),
      ],
    );
  }

  Widget _compositeFields() {
    final labels = _composite == _Composite.rapd
        ? const ['Ropani', 'Aana', 'Paisa', 'Daam']
        : const ['Bigha', 'Kattha', 'Dhur'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _parts[i],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              decoration: InputDecoration(labelText: labels[i], hintText: '0'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ],
    );
  }
}
