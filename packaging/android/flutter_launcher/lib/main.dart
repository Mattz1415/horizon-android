import 'dart:async';

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

class HorizonApp extends StatefulWidget {
  const HorizonApp({super.key});

  @override
  State<HorizonApp> createState() => _HorizonAppState();
}

class _HorizonAppState extends State<HorizonApp> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final app = Launcher();
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Palette _from = malam;
  Palette _to = malam;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_retheme);
    _fade.addListener(() => setState(() => Hz.p = Palette.lerp(_from, _to, Hz.ease.transform(_fade.value))));
    // Auto theme follows the clock; check once a minute.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _retheme());
    app.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the game: worlds, logs, screenshots and options may have changed in there.
    if (state == AppLifecycleState.resumed) {
      app.loadWorlds();
      app.loadOptions();
      app.loadAddons();
      app.loadDevice();
      app.loadScreenshots();
      _retheme();
    }
  }

  Palette _wanted() {
    if (app.theme == 'auto') {
      final h = DateTime.now().hour;
      return h >= 6 && h < 18 ? siang : malam;
    }
    return palettes[app.theme] ?? malam;
  }

  void _retheme() {
    final next = _wanted();
    if (next.name == _to.name) return;
    _from = Hz.p;
    _to = next;
    final calm = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (calm) {
      _fade.value = 1;
      setState(() => Hz.p = next);
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _fade.dispose();
    app.removeListener(_retheme);
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Hz.p;
    return HzScope(
      palette: p,
      child: MaterialApp(
        title: 'Horizon',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: p.dark ? Brightness.dark : Brightness.light,
          fontFamily: 'Geist',
          scaffoldBackgroundColor: p.page,
          colorScheme: (p.dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
            primary: p.face,
            onPrimary: p.onFace,
            secondary: p.accent,
            surface: p.surface,
            onSurface: p.ink,
            error: p.danger,
          ),
          tooltipTheme: TooltipThemeData(
            decoration: BoxDecoration(color: p.raised, borderRadius: Hz.r10, border: Border.all(color: p.line)),
            textStyle: Hz.small.copyWith(color: p.ink),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: p.accent,
            selectionColor: p.accent.withOpacity(0.35),
            selectionHandleColor: p.accent,
          ),
        ),
        home: Shell(app: app),
      ),
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
  _Dest('package', 'Mod'),
  _Dest('globe', 'Dunia'),
  _Dest('user', 'Akun'),
  _Dest('sliders', 'Atur'),
  _Dest('terminal', 'Log'),
];

class Shell extends StatefulWidget {
  const Shell({super.key, required this.app});

  final Launcher app;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  Launcher get app => widget.app;

  void _go(int i) => setState(() => _index = i);

  Widget _page() => switch (_index) {
        1 => AddonsPage(app: app),
        2 => WorldsPage(app: app),
        3 => ProfilePage(app: app),
        4 => SettingsPage(app: app),
        5 => LogsPage(app: app),
        _ => PlayPage(app: app, goTo: _go),
      };

  double _rise() => switch (app.phase) {
        Phase.ready => 1,
        Phase.downloading || Phase.paused => 0.15 + 0.7 * app.progress,
        Phase.checking => 0.1,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => HorizonBackdrop(
          rise: _rise(),
          busy: app.phase == Phase.downloading,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _TopBar(index: _index, onTap: _go, app: app),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Hz.calm(context) ? Duration.zero : Hz.move,
                    switchInCurve: Hz.ease,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
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

/// One glass bar across the top: the wordmark, the six places as tabs with a blue
/// horizon line that slides under the picked one, and a theme switch.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.index, required this.onTap, required this.app});

  final int index;
  final ValueChanged<int> onTap;
  final Launcher app;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final labels = w >= 720;
    return Glass(
      radius: Hz.r14,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 14),
              child: Text('Horizon', style: Hz.display.copyWith(fontSize: 19, color: Hz.ink)),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final itemW = c.maxWidth / _dests.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: Hz.calm(context) ? Duration.zero : Hz.move,
                      curve: Hz.ease,
                      left: itemW * index + 10,
                      width: itemW - 20,
                      bottom: 0,
                      height: 2,
                      child: ColoredBox(color: Hz.accent),
                    ),
                    Row(children: [
                      for (var i = 0; i < _dests.length; i++)
                        SizedBox(
                          width: itemW,
                          child: _Tab(
                            key: ValueKey('nav-$i'),
                            dest: _dests[i],
                            selected: i == index,
                            showLabel: labels,
                            badge: i == 0 && app.phase == Phase.downloading,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ]),
                  ],
                );
              }),
            ),
            const SizedBox(width: 6),
            _ThemeButton(app: app),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.dest,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.badge = false,
  });

  final _Dest dest;
  final bool selected;
  final bool showLabel;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Hz.ink : Hz.muted;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: badge ? '${dest.label}, sedang mengunduh' : dest.label,
        child: Pressable(
          onTap: onTap,
          semanticLabel: dest.label,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                badge ? const _Spinner() : PixelIcon(dest.icon, size: 18, color: selected ? Hz.accent : color),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dest.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: Hz.body.copyWith(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                    ),
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

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: Hz.calm(context)
          ? PixelIcon('download', size: 16, color: Hz.accent)
          : CircularProgressIndicator(strokeWidth: 2, color: Hz.accent),
    );
  }
}

/// Cycles auto, malam, siang, samudra. The icon says what is on now.
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.app});

  final Launcher app;

  static const _order = ['auto', 'malam', 'siang', 'samudra'];
  static const _names = {'auto': 'Otomatis', 'malam': 'Malam', 'siang': 'Siang', 'samudra': 'Samudra'};

  @override
  Widget build(BuildContext context) {
    final next = _order[(_order.indexOf(app.theme) + 1) % _order.length];
    return IconBtn(
      icon: app.theme == 'auto' ? 'clock' : (app.theme == 'siang' ? 'zap' : 'star'),
      label: 'Tema ${_names[app.theme]}, ketuk untuk ${_names[next]}',
      color: Hz.ink,
      onTap: () => app.setTheme(next),
    );
  }
}
