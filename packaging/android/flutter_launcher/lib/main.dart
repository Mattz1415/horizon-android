import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'launcher.dart';
import 'pages/addons_page.dart';
import 'pages/logs_page.dart';
import 'pages/play_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'pages/worlds_page.dart';
import 'ui/pixel_icon.dart';
import 'ui/tokens.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HorizonApp());
}

class HorizonApp extends StatelessWidget {
  const HorizonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Geist',
        scaffoldBackgroundColor: Hz.page,
        colorScheme: const ColorScheme.dark(
          primary: Hz.accent,
          onPrimary: Hz.page,
          secondary: Hz.accent,
          surface: Hz.surface,
          onSurface: Hz.ink,
          error: Hz.danger,
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(color: Hz.plate, borderRadius: Hz.r8, border: Border.all(color: Hz.line)),
          textStyle: Hz.small.copyWith(color: Hz.ink),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Hz.accent,
          selectionColor: Hz.accent.withOpacity(0.35),
          selectionHandleColor: Hz.accent,
        ),
      ),
      home: const Shell(),
    );
  }
}

class _Dest {
  const _Dest(this.icon, this.label);

  final String icon;
  final String label;
}

const _dests = [
  _Dest('play', 'Main'),
  _Dest('package', 'Add-on'),
  _Dest('globe', 'Dunia'),
  _Dest('user', 'Akun'),
  _Dest('sliders', 'Pengaturan'),
  _Dest('terminal', 'Log'),
];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final app = Launcher();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the game: worlds, logs and options may have changed in there.
    if (state == AppLifecycleState.resumed) {
      app.loadWorlds();
      app.loadOptions();
      app.loadAddons();
      app.loadDevice();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.dispose();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  Widget _page() => switch (_index) {
        1 => AddonsPage(app: app),
        2 => WorldsPage(app: app),
        3 => ProfilePage(app: app),
        4 => SettingsPage(app: app),
        5 => LogsPage(app: app),
        _ => PlayPage(app: app, goTo: _go),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => LiquidBackdrop(
          energy: app.phase == Phase.downloading ? 1 : 0,
          child: SafeArea(
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  child: _Rail(index: _index, onTap: _go, app: app),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Hz.calm(context) ? Duration.zero : Hz.move,
                    switchInCurve: Hz.ease,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                    child: KeyedSubtree(key: ValueKey(_index), child: _page()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical glass rail: landscape screens are short, so navigation goes on the side.
/// The selected marker slides between items instead of jumping.
class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.onTap, required this.app});

  final int index;
  final ValueChanged<int> onTap;
  final Launcher app;

  static const _item = 56.0;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 420;
    final itemH = compact ? 46.0 : _item;
    return Glass(
      radius: Hz.r16,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('H', style: Hz.pixel.copyWith(color: Hz.accent, fontSize: compact ? 18 : 22)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: Hz.calm(context) ? Duration.zero : Hz.move,
                      curve: Hz.ease,
                      top: index * itemH,
                      left: 0,
                      right: 0,
                      height: itemH,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Hz.face.withOpacity(0.85),
                          borderRadius: Hz.r12,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        for (var i = 0; i < _dests.length; i++)
                          _RailItem(
                            key: ValueKey('nav-$i'),
                            dest: _dests[i],
                            selected: i == index,
                            height: itemH,
                            compact: compact,
                            badge: i == 0 && app.phase == Phase.downloading,
                            onTap: () => onTap(i),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.dest,
    required this.selected,
    required this.height,
    required this.compact,
    required this.onTap,
    this.badge = false,
  });

  final _Dest dest;
  final bool selected;
  final double height;
  final bool compact;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Hz.inkSoft;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: dest.label,
        child: Pressable(
          onTap: onTap,
          semanticLabel: dest.label,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(clipBehavior: Clip.none, children: [
                  PixelIcon(dest.icon, size: 20, color: color),
                  if (badge)
                    const Positioned(
                      right: -4,
                      top: -2,
                      child: SizedBox.square(
                        dimension: 7,
                        child: DecoratedBox(decoration: BoxDecoration(color: Hz.warn, shape: BoxShape.circle)),
                      ),
                    ),
                ]),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    dest.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: Hz.label.copyWith(fontSize: 10.5, color: color, letterSpacing: 0),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
