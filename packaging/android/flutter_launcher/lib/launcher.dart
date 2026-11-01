import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.vasysik.horizon/launcher');
const _progress = EventChannel('com.vasysik.horizon/progress');

class Addon {
  Addon(Map m)
      : type = m['type'] as String? ?? 'mod',
        fileName = m['fileName'] as String? ?? '',
        name = m['name'] as String? ?? '',
        version = m['version'] as String? ?? '',
        description = m['description'] as String? ?? '',
        size = (m['size'] as num?)?.toInt() ?? 0,
        enabled = m['enabled'] == true,
        broken = m['broken'] == true;

  final String type;
  final String fileName;
  final String name;
  final String version;
  final String description;
  final int size;
  final bool enabled;
  final bool broken;
}

class World {
  World(Map m)
      : name = m['name'] as String? ?? '',
        modified = (m['modified'] as num?)?.toInt() ?? 0,
        size = (m['size'] as num?)?.toInt() ?? 0;

  final String name;
  final int modified;
  final int size;
}

class GameOptions {
  GameOptions({
    this.renderDistance = 12,
    this.simulationDistance = 12,
    this.maxFps = 120,
    this.guiScale = 0,
    this.fov = 70,
    this.lodDistance = 0,
    this.overlay = 'off',
  });

  factory GameOptions.from(Map m) => GameOptions(
        renderDistance: (m['renderDistance'] as num?)?.toInt() ?? 12,
        simulationDistance: (m['simulationDistance'] as num?)?.toInt() ?? 12,
        maxFps: (m['maxFps'] as num?)?.toInt() ?? 120,
        guiScale: (m['guiScale'] as num?)?.toInt() ?? 0,
        fov: (m['fov'] as num?)?.toInt() ?? 70,
        lodDistance: (m['lodDistance'] as num?)?.toInt() ?? 0,
        overlay: m['overlay'] as String? ?? 'off',
      );

  int renderDistance;
  int simulationDistance;
  int maxFps;
  int guiScale;
  int fov;
  int lodDistance;
  String overlay;

  Map<String, Object> toMap() => {
        'renderDistance': renderDistance,
        'simulationDistance': simulationDistance,
        'maxFps': maxFps,
        'guiScale': guiScale,
        'fov': fov,
        'lodDistance': lodDistance,
        'overlay': overlay,
      };
}

enum Phase { checking, missing, downloading, paused, ready, failed }

/// Everything the launcher knows, in one place, so pages stay plain views.
class Launcher extends ChangeNotifier {
  Phase phase = Phase.checking;
  String stage = '';
  String detail = '';
  double progress = 0;
  int speed = 0;
  String? error;
  String sha256 = '';

  List<String> accounts = [];
  String account = '';

  int workerThreads = 4;
  String backend = 'vulkan';
  int touchScheme = 0;
  int lastPlayed = 0;

  GameOptions options = GameOptions();
  bool optionsLoaded = false;

  List<Addon>? addons;
  String? addonsError;
  List<World>? worlds;
  String? worldsError;
  Map<String, dynamic>? device;

  final Set<String> installing = {};
  bool launching = false;

  StreamSubscription? _sub;
  Timer? _saveTimer;

  bool get ready => phase == Phase.ready;

  Future<void> start() async {
    _sub = _progress.receiveBroadcastStream().listen(_onProgress, onError: (_) {});
    await Future.wait([
      checkResources(),
      _loadLauncher(),
      loadOptions(),
      loadAddons(),
      loadWorlds(),
      loadDevice(),
    ]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _onProgress(dynamic p) {
    if (p is! Map) return;
    switch (p['status']) {
      case 'downloading':
        phase = Phase.downloading;
        stage = p['stage'] as String? ?? '';
        progress = ((p['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
        speed = (p['speed'] as num?)?.toInt() ?? 0;
        detail = p['detail'] as String? ?? '';
        error = null;
      case 'completed':
        phase = Phase.ready;
        progress = 1;
        speed = 0;
        sha256 = p['sha256'] as String? ?? '';
        detail = '';
      case 'error':
        phase = Phase.failed;
        error = p['error'] as String? ?? 'Tidak ada keterangan dari perangkat';
        speed = 0;
    }
    notifyListeners();
  }

  Future<void> checkResources() async {
    try {
      final r = await _channel.invokeMethod<Map>('checkResources');
      final ok = r?['isPrepared'] == true;
      sha256 = r?['sha256'] as String? ?? '';
      if (phase != Phase.downloading) phase = ok ? Phase.ready : Phase.missing;
    } on PlatformException catch (e) {
      phase = Phase.failed;
      error = e.message;
    } on MissingPluginException {
      phase = Phase.missing;
    }
    notifyListeners();
  }

  Future<void> startDownload() async {
    phase = Phase.downloading;
    error = null;
    notifyListeners();
    await _call('startDownload');
  }

  Future<void> pauseDownload() async {
    await _call('pauseDownload');
    phase = Phase.paused;
    speed = 0;
    notifyListeners();
  }

  Future<void> importResources() => _call('importResourcesZip');

  Future<void> _loadLauncher() async {
    try {
      final raw = await _channel.invokeMethod<String>('getLauncherSettings') ?? '{}';
      final m = jsonDecode(raw) as Map<String, dynamic>;
      workerThreads = (m['workerThreads'] as num?)?.toInt() ?? 4;
      backend = m['backend'] == 'opengl' ? 'opengl' : 'vulkan';
      touchScheme = ((m['touchScheme'] as num?)?.toInt() ?? 0).clamp(0, 3);
      lastPlayed = (m['lastPlayed'] as num?)?.toInt() ?? 0;
      account = m['account'] as String? ?? '';
    } catch (_) {}
    try {
      final raw = await _channel.invokeMethod<String>('getAccounts') ?? '[]';
      accounts = (jsonDecode(raw) as List).map((e) => e.toString()).where(validName).toList();
    } catch (_) {
      accounts = [];
    }
    if (accounts.isEmpty) accounts = ['HorizonPlayer'];
    if (!accounts.contains(account)) account = accounts.first;
    notifyListeners();
  }

  void _saveLauncher() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      _call('saveLauncherSettings', {
        'json': jsonEncode({
          'workerThreads': workerThreads,
          'backend': backend,
          'touchScheme': touchScheme,
          'lastPlayed': lastPlayed,
          'account': account,
        }),
      });
    });
  }

  void setThreads(int v) {
    workerThreads = v;
    _saveLauncher();
    notifyListeners();
  }

  void setBackend(String v) {
    backend = v;
    _saveLauncher();
    notifyListeners();
  }

  void setTouch(int v) {
    touchScheme = v;
    _saveLauncher();
    notifyListeners();
  }

  /// Vanilla's rule for player names: 3 to 16 of letters, digits and underscore.
  static bool validName(String s) => RegExp(r'^[A-Za-z0-9_]{3,16}$').hasMatch(s);

  Future<void> _saveAccounts() async {
    await _call('saveAccounts', {'json': jsonEncode(accounts)});
    _saveLauncher();
  }

  Future<void> addAccount(String name) async {
    if (!accounts.contains(name)) accounts.add(name);
    account = name;
    notifyListeners();
    await _saveAccounts();
  }

  Future<void> removeAccount(String name) async {
    accounts.remove(name);
    if (accounts.isEmpty) accounts = ['HorizonPlayer'];
    if (!accounts.contains(account)) account = accounts.first;
    notifyListeners();
    await _saveAccounts();
  }

  void selectAccount(String name) {
    account = name;
    _saveLauncher();
    notifyListeners();
  }

  Future<void> loadOptions() async {
    try {
      final m = await _channel.invokeMethod<Map>('getGameOptions');
      if (m != null) options = GameOptions.from(m);
    } catch (_) {}
    optionsLoaded = true;
    notifyListeners();
  }

  Timer? _optTimer;

  void updateOptions(void Function(GameOptions o) edit) {
    edit(options);
    if (options.simulationDistance > options.renderDistance) {
      options.simulationDistance = options.renderDistance.clamp(2, 32);
    }
    notifyListeners();
    _optTimer?.cancel();
    _optTimer = Timer(const Duration(milliseconds: 400), () {
      _call('saveGameOptions', options.toMap());
    });
  }

  Future<void> loadAddons() async {
    try {
      final list = await _channel.invokeMethod<List>('getMods') ?? [];
      addons = list.whereType<Map>().map(Addon.new).toList();
      addonsError = null;
    } on PlatformException catch (e) {
      addonsError = e.message;
    } on MissingPluginException {
      addons = [];
    }
    notifyListeners();
  }

  Future<String?> install(String url, String type, String key) async {
    installing.add(key);
    notifyListeners();
    try {
      await _channel.invokeMethod('installModFromUrl', {'url': url, 'type': type});
      await loadAddons();
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Unduhan gagal';
    } finally {
      installing.remove(key);
      notifyListeners();
    }
  }

  Future<String?> toggle(Addon a) async {
    try {
      await _channel.invokeMethod('toggleMod', {'fileName': a.fileName, 'type': a.type});
      await loadAddons();
      return null;
    } on PlatformException catch (e) {
      return e.message;
    }
  }

  Future<String?> deleteAddon(Addon a) async {
    try {
      await _channel.invokeMethod('deleteAddon', {'fileName': a.fileName, 'type': a.type});
      await loadAddons();
      return null;
    } on PlatformException catch (e) {
      return e.message;
    }
  }

  /// Null when the player closed the picker.
  Future<String?> importAddon() async {
    try {
      final r = await _channel.invokeMethod<Map>('importAddon');
      if (r == null) return null;
      await loadAddons();
      return r['fileName'] as String?;
    } on PlatformException catch (e) {
      throw e.message ?? 'Impor gagal';
    }
  }

  Future<void> loadWorlds() async {
    try {
      final list = await _channel.invokeMethod<List>('getWorlds') ?? [];
      worlds = list.whereType<Map>().map(World.new).toList();
      worldsError = null;
    } on PlatformException catch (e) {
      worldsError = e.message;
    } on MissingPluginException {
      worlds = [];
    }
    notifyListeners();
  }

  Future<String?> deleteWorld(World w) async {
    try {
      await _channel.invokeMethod('deleteWorld', {'name': w.name});
      await loadWorlds();
      return null;
    } on PlatformException catch (e) {
      return e.message;
    }
  }

  Future<void> loadDevice() async {
    try {
      final m = await _channel.invokeMethod<Map>('getDeviceInfo');
      device = m?.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {}
    notifyListeners();
  }

  Future<Map<String, dynamic>> logs() async {
    final m = await _channel.invokeMethod<Map>('getLogs');
    return m?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  Future<void> clearLogs() => _call('clearLogs');

  Future<void> share(String text) => _call('shareText', {'text': text});

  Future<String?> launch() async {
    if (!ready || launching) return null;
    launching = true;
    notifyListeners();
    try {
      _optTimer?.cancel();
      await _call('saveGameOptions', options.toMap());
      await _channel.invokeMethod('launchGame', {
        'ramMb': 2048,
        'workerThreads': workerThreads,
        'backend': backend,
        'touchScheme': touchScheme,
        'username': account,
      });
      lastPlayed = DateTime.now().millisecondsSinceEpoch;
      _saveLauncher();
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Game tidak bisa dibuka';
    } finally {
      // The game opens in its own process; give the button back once it is on screen.
      await Future.delayed(const Duration(seconds: 2));
      launching = false;
      notifyListeners();
    }
  }

  Future<void> _call(String m, [Object? args]) async {
    try {
      await _channel.invokeMethod(m, args);
    } on MissingPluginException {
      if (kDebugMode) debugPrint('no platform for $m');
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('$m: ${e.message}');
    }
  }
}
