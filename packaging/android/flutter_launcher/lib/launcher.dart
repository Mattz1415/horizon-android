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

/// One project from the Horizon registry (horizon-rust/horizon-mods, the source of
/// playhorizon.dev/mods). Only sandboxed `.hmod` files and resource packs run on
/// Android; native mods are built into the desktop game by the desktop launcher.
class RegistryItem {
  RegistryItem(Map m)
      : id = m['id'] as String? ?? '',
        kind = m['kind'] as String? ?? 'mod',
        name = m['name'] as String? ?? '',
        summary = m['summary'] as String? ?? '',
        description = m['description'] as String? ?? '',
        authors = (m['authors'] as List? ?? const []).map((e) => '$e').toList(),
        license = m['license'] as String? ?? '',
        source = m['source'] as String? ?? '',
        icon = m['icon'] as String?,
        downloads = (m['downloads'] as num?)?.toInt(),
        versions = (m['versions'] as List? ?? const []).whereType<Map>().map(RegistryVersion.new).toList();

  final String id;
  final String kind;
  final String name;
  final String summary;
  final String description;
  final List<String> authors;
  final String license;
  final String source;
  final String? icon;
  final int? downloads;
  final List<RegistryVersion> versions;

  /// The newest version this phone can run, or null.
  RegistryVersion? get androidVersion {
    for (final v in versions) {
      if (kind == 'mod' && v.fileName.endsWith('.hmod')) return v;
      if (kind == 'resourcepack' && v.fileName.endsWith('.zip')) return v;
    }
    return null;
  }

  bool get runsOnAndroid => androidVersion != null;
  String get type => kind == 'resourcepack' ? 'pack' : 'mod';
  String get page => 'https://playhorizon.dev/mods/$id';
  RegistryVersion? get latest => versions.isEmpty ? null : versions.first;
}

class RegistryVersion {
  RegistryVersion(Map m)
      : version = m['version'] as String? ?? '',
        published = m['published'] as String? ?? '',
        changelog = m['changelog'] as String? ?? '',
        game = m['game'] as String? ?? '',
        fileName = (m['file'] as Map?)?['name'] as String? ?? '',
        url = (m['file'] as Map?)?['url'] as String? ?? '',
        size = ((m['file'] as Map?)?['size'] as num?)?.toInt() ?? 0,
        sha256 = (m['file'] as Map?)?['sha256'] as String? ?? '';

  final String version;
  final String published;
  final String changelog;
  final String game;
  final String fileName;
  final String url;
  final int size;
  final String sha256;
}

class Screenshot {
  Screenshot(Map m)
      : path = m['path'] as String? ?? '',
        name = m['name'] as String? ?? '',
        modified = (m['modified'] as num?)?.toInt() ?? 0,
        size = (m['size'] as num?)?.toInt() ?? 0;

  final String path;
  final String name;
  final int modified;
  final int size;
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

  /// 'auto' follows the clock: siang from 06:00 to 18:00, malam otherwise.
  String theme = 'auto';

  GameOptions options = GameOptions();
  bool optionsLoaded = false;

  List<Addon>? addons;
  String? addonsError;
  List<World>? worlds;
  String? worldsError;
  Map<String, dynamic>? device;

  List<RegistryItem>? registry;
  String? registryError;
  bool registryCached = false;
  int registryFetched = 0;
  bool registryLoading = false;

  List<Screenshot>? screenshots;
  String? screenshotsError;

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
      loadScreenshots(),
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
      final t = m['theme'] as String? ?? 'auto';
      theme = t == 'auto' || palettesKnown.contains(t) ? t : 'auto';
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
          'theme': theme,
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

  static const palettesKnown = {'malam', 'siang', 'samudra'};

  void setTheme(String v) {
    theme = v;
    _saveLauncher();
    notifyListeners();
  }

  /// Quick presets from the play page; each one only sets values inside the game's own ranges.
  void applyPreset(String preset) {
    updateOptions((o) {
      switch (preset) {
        case 'hemat':
          o.renderDistance = 6;
          o.simulationDistance = 6;
          o.maxFps = 60;
          o.lodDistance = 0;
        case 'jauh':
          o.renderDistance = 24;
          o.simulationDistance = 12;
          o.maxFps = 120;
          o.lodDistance = 128;
        default:
          o.renderDistance = 12;
          o.simulationDistance = 10;
          o.maxFps = 90;
          o.lodDistance = 0;
      }
    });
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

  Future<void> loadRegistry() async {
    if (registryLoading) return;
    registryLoading = true;
    notifyListeners();
    try {
      final r = await _channel.invokeMethod<Map>('fetchRegistry');
      final m = jsonDecode(r?['json'] as String? ?? '{}') as Map<String, dynamic>;
      final revoked = {for (final e in (m['revoked'] as List? ?? const [])) if (e is Map) '${e['id'] ?? e['file'] ?? ''}'};
      registry = (m['projects'] as List? ?? const [])
          .whereType<Map>()
          .map(RegistryItem.new)
          .where((p) => p.id.isNotEmpty && !revoked.contains(p.id))
          .toList();
      registryCached = r?['cached'] == true;
      registryFetched = (r?['fetched'] as num?)?.toInt() ?? 0;
      registryError = null;
    } on PlatformException catch (e) {
      registryError = e.message ?? 'Katalog tidak bisa dimuat';
    } on MissingPluginException {
      registry = [];
    } on FormatException {
      registryError = 'Isi katalog tidak terbaca';
    } finally {
      registryLoading = false;
      notifyListeners();
    }
  }

  Future<String?> installRegistry(RegistryItem p) async {
    final v = p.androidVersion;
    if (v == null) return 'Tidak tersedia untuk Android';
    return install(v.url, p.type, p.id, sha256: v.sha256, fileName: v.fileName);
  }

  Future<void> loadScreenshots() async {
    try {
      final list = await _channel.invokeMethod<List>('getScreenshots') ?? [];
      screenshots = list.whereType<Map>().map(Screenshot.new).toList();
      screenshotsError = null;
    } on PlatformException catch (e) {
      screenshotsError = e.message;
    } on MissingPluginException {
      screenshots = [];
    }
    notifyListeners();
  }

  Future<String?> deleteScreenshot(Screenshot s) async {
    try {
      await _channel.invokeMethod('deleteScreenshot', {'name': s.name});
      await loadScreenshots();
      return null;
    } on PlatformException catch (e) {
      return e.message;
    }
  }

  Future<String?> openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
      return null;
    } on PlatformException catch (e) {
      return e.message;
    } on MissingPluginException {
      return null;
    }
  }

  Future<String?> install(String url, String type, String key, {String? sha256, String? fileName}) async {
    installing.add(key);
    notifyListeners();
    try {
      await _channel.invokeMethod('installModFromUrl', {
        'url': url,
        'type': type,
        if (sha256 != null) 'sha256': sha256,
        if (fileName != null) 'fileName': fileName,
      });
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
