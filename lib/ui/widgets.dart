import 'package:material_ui/material_ui.dart';

import '../core/units.dart';
import 'theme.dart';

/// Large heading used at the top of each tab.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const ScreenHeader(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: t.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Dark card with Ropani-Aana-Paisa-Daam figures.
class HillCard extends StatelessWidget {
  final double m2;
  const HillCard(this.m2, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = Rapd.fromM2(m2);
    return _BreakdownCard(
      title: 'Hill system · पहाड',
      code: 'R-A-P-D',
      dark: true,
      values: [
        ('${r.ropani}', 'Ropani'),
        ('${r.aana}', 'Aana'),
        ('${r.paisa}', 'Paisa'),
        (fmt(r.daam, 2), 'Daam'),
      ],
    );
  }
}

/// Card with Bigha-Kattha-Dhur figures.
class TeraiCard extends StatelessWidget {
  final double m2;
  const TeraiCard(this.m2, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = Bkd.fromM2(m2);
    return _BreakdownCard(
      title: 'Terai system · तराई',
      code: 'B-K-D',
      dark: false,
      values: [
        ('${b.bigha}', 'Bigha'),
        ('${b.kattha}', 'Kattha'),
        (fmt(b.dhur, 2), 'Dhur'),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title, code;
  final bool dark;
  final List<(String, String)> values;
  const _BreakdownCard(
      {required this.title,
      required this.code,
      required this.dark,
      required this.values});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = dark ? Colors.white : cs.onSurface;
    final sub = dark ? const Color(0xFFB9BCC4) : cs.onSurfaceVariant;
    final num = dark ? Colors.white : cs.secondary;
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
              Text(code, style: TextStyle(color: sub, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final v in values)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(v.$1,
                            style: TextStyle(
                                color: num,
                                fontSize: 28,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(v.$2, style: TextStyle(color: sub, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (dark) {
      return Container(
        decoration: BoxDecoration(
            color: ink, borderRadius: BorderRadius.circular(16)),
        child: body,
      );
    }
    return Card(child: body);
  }
}

/// Simple two-column table of label/value rows inside a card.
class ValueTable extends StatelessWidget {
  final List<(String, String)> rows;
  const ValueTable(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : Border(
                          bottom:
                              BorderSide(color: cs.outlineVariant, width: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(rows[i].$1,
                            style: TextStyle(color: cs.onSurfaceVariant))),
                    SelectableText(rows[i].$2,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// All common representations of an area, for reports.
List<(String, String)> areaRows(double m2) => [
      ('Square feet', fmt(m2 / sqFt, 2)),
      ('Square metres', fmt(m2, 2)),
      ('Ropani-Aana-Paisa-Daam', Rapd.fromM2(m2).toString()),
      ('Bigha-Kattha-Dhur', Bkd.fromM2(m2).toString()),
      ('Aana (decimal)', fmt(m2 / aanaM2, 3)),
      ('Kattha (decimal)', fmt(m2 / katthaM2, 3)),
      ('Acres', fmt(m2 / 4046.8564224, 4)),
      ('Hectares', fmt(m2 / 10000, 4)),
    ];

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  const InfoBanner(this.text,
      {super.key, this.icon = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A3220) : const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? const Color(0xFF5A4A20) : const Color(0xFFF1DFB4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18,
              color: dark ? const Color(0xFFF1D58A) : const Color(0xFF8A6A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: dark
                        ? const Color(0xFFF1E4C0)
                        : const Color(0xFF5A4300))),
          ),
        ],
      ),
    );
  }
}

/// Unit chips used by length unit toggles.
enum LenUnit {
  ft('ft', 0.3048),
  m('m', 1),
  haat('haat', 0.4572);

  final String label;
  final double meters;
  const LenUnit(this.label, this.meters);
}

Color sideLabelColor(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white : ink;
