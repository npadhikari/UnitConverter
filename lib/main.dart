import 'package:material_ui/material_ui.dart';

import 'core/plot_model.dart';
import 'ui/convert_screen.dart';
import 'ui/plot_screen.dart';
import 'ui/saved_screen.dart';
import 'ui/scan_screen.dart';
import 'ui/theme.dart';

final plotStore = PlotStore();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  plotStore.load();
  runApp(const ConverterApp());
}

class ConverterApp extends StatelessWidget {
  const ConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Converter NOW',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      ConvertScreen(onScan: () => _go(1)),
      ScanScreen(store: plotStore),
      PlotScreen(store: plotStore),
      SavedScreen(store: plotStore),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.swap_horiz), label: 'Convert'),
          NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(Icons.document_scanner),
              label: 'Scan'),
          NavigationDestination(
              icon: Icon(Icons.pentagon_outlined),
              selectedIcon: Icon(Icons.pentagon),
              label: 'Plot'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Saved'),
        ],
      ),
    );
  }
}
