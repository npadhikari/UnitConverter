import 'package:material_ui/material_ui.dart';

import '../core/plot_model.dart';
import '../core/units.dart';
import 'report_screen.dart';
import 'widgets.dart';

class SavedScreen extends StatelessWidget {
  final PlotStore store;
  const SavedScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final plots = store.plots;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader('Saved plots',
                subtitle: plots.isEmpty
                    ? 'Nothing saved yet'
                    : '${plots.length} plot${plots.length == 1 ? '' : 's'} on this phone'),
            if (plots.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Plots you save from Scan or Plot appear here, with their '
                  'area report and PDF export.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final p in plots)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    leading: SizedBox(
                      width: 52,
                      height: 52,
                      child: CustomPaint(painter: PlotThumbPainter(p.points)),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${fmt(p.areaM2 / sqFt, 1)} sq ft · '
                        '${Rapd.fromM2(p.areaM2)} R-A-P-D'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            ReportScreen(store: store, plotId: p.id))),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
