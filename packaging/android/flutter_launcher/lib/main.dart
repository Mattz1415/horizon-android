// main.dart
// Dart / Flutter / Horizon Android launcher shell
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HorizonApp());
}

// Palette. Black and grey only: the game supplies the colour, the shell stays quiet.
class Scope {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0D0D0F);
  static const raised = Color(0xFF16161A);
  static const line = Color(0xFF26262C);
  static const text = Color(0xFFF2F2F4);
  static const muted = Color(0xFF8C8C96);
  static const dim = Color(0xFF5A5A64);
  static const accent = Color(0xFFFFFFFF);
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
        scaffoldBackgroundColor: Scope.bg,
        colorScheme: const ColorScheme.dark(
          primary: Scope.accent,
          surface: Scope.surface,
          onSurface: Scope.text,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Scope.text,
          inactiveTrackColor: Scope.line,
          thumbColor: Scope.accent,
          overlayColor: Color(0x22FFFFFF),
          trackHeight: 2,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Scope.accent,
          selectionColor: Color(0x33FFFFFF),
          selectionHandleColor: Scope.accent,
        ),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  static const _channel = MethodChannel('com.vasysik.horizon/launcher');
  static const _progressChannel = EventChannel('com.vasysik.horizon/progress');

  int _tab = 0;
  bool _ready = false;
  String _sha = '';

  bool _busy = false;
  bool _paused = false;
  double _progress = 0;
  double _speed = 0;
  String _stage = '';
  String _error = '';

  String _name = 'Pemain';
  int _ram = 2048;
  int _threads = 4;
  int _lod = 128;
  int _touch = 0;

  List<Map<String, dynamic>> _addons = [];
  String _addonType = 'mod';
  final _url = TextEditingController();
  late final TextEditingController _nameCtl;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: _name);
    _check();
    _listen();
    _loadAddons();
  }

  @override
  void dispose() {
    _url.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('checkResources');
      if (!mounted) return;
      setState(() {
        _ready = r?['isPrepared'] == true;
        _sha = (r?['sha256'] as String?) ?? '';
      });
    } on PlatformException {
      if (mounted) setState(() => _ready = false);
    }
  }

  void _listen() {
    _progressChannel.receiveBroadcastStream().listen((raw) {
      if (!mounted || raw is! Map) return;
      final status = raw['status'];
      setState(() {
        if (status == 'downloading') {
          _busy = true;
          _paused = false;
          _progress = (raw['progress'] as num?)?.toDouble() ?? 0;
          _speed = (raw['speed'] as num?)?.toDouble() ?? 0;
          _stage = (raw['detail'] as String?) ?? (raw['stage'] as String?) ?? '';
          _error = '';
        } else if (status == 'completed') {
          _busy = false;
          _progress = 1;
          _stage = '';
          _ready = true;
          _sha = (raw['sha256'] as String?) ?? _sha;
        } else if (status == 'error') {
          _busy = false;
          _error = (raw['error'] as String?) ?? 'Unduhan gagal.';
        }
      });
    }, onError: (_) {});
  }

  Future<void> _loadAddons() async {
    try {
      final list = await _channel.invokeListMethod<dynamic>('getMods');
      if (!mounted) return;
      setState(() {
        _addons = (list ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } on PlatformException {
      // Nothing installed yet is not an error worth showing.
    }
  }

  Future<void> _download() async {
    if (_busy) {
      await _channel.invokeMethod('pauseDownload');
      if (mounted) setState(() { _busy = false; _paused = true; });
      return;
    }
    setState(() { _busy = true; _paused = false; _error = ''; });
    await _channel.invokeMethod('startDownload');
  }

  Future<void> _import() async {
    await _channel.invokeMethod('importResourcesZip');
  }

  Future<void> _launch() async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod('launchGame', {
        'ramMb': _ram,
        'workerThreads': _threads,
        'backend': 'vulkan',
        'touchScheme': _touch,
        'username': _name,
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Game tidak bisa dimulai.');
    }
  }

  Future<void> _install() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() => _error = '');
    try {
      await _channel.invokeMethod('installModFromUrl', {'url': url, 'type': _addonType});
      _url.clear();
      await _loadAddons();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Pemasangan gagal.');
    }
  }

  Future<void> _toggle(Map<String, dynamic> addon) async {
    await _channel.invokeMethod('toggleMod', {
      'fileName': addon['fileName'],
      'type': addon['type'] ?? 'mod',
    });
    await _loadAddons();
  }

  Future<void> _readLog() async {
    final text = await _channel.invokeMethod<String>('getLogs');
    if (mounted) setState(() => _log = text ?? '');
  }

  Future<void> _clearLog() async {
    await _channel.invokeMethod('clearLogs');
    if (mounted) setState(() => _log = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Scope.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(ready: _ready, tab: _tab, onTab: (i) => setState(() => _tab = i)),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: KeyedSubtree(key: ValueKey(_tab), child: _body()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final wide = MediaQuery.sizeOf(context).width > 720;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 32),
          children: switch (_tab) {
            0 => _play(),
            1 => _files(),
            2 => _addonsScreen(),
            3 => _setup(),
            _ => _logScreen(),
          },
        ),
      ),
    );
  }

  // ---- Play ----------------------------------------------------------------

  List<Widget> _play() {
    return [
      Text(
        _ready ? 'Siap dimainkan' : 'Aset belum lengkap',
        style: const TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w600, color: Scope.text),
      ),
      const SizedBox(height: 8),
      Text(
        _ready
            ? 'Minecraft 26.3, engine Rust. ${_ram ~/ 1024} GB RAM, $_threads thread, jarak $_lod blok.'
            : 'Unduh 773 MB aset 26.3 sekali saja, lalu game jalan offline.',
        style: const TextStyle(fontSize: 14, height: 1.45, color: Scope.muted),
      ),
      const SizedBox(height: 24),
      _Primary(
        label: _ready ? 'Mulai main' : 'Buka aset',
        onTap: _ready ? () => _launch() : () => setState(() => _tab = 1),
      ),
      const SizedBox(height: 10),
      _Ghost(
        label: _ready ? 'Periksa ulang aset' : 'Unduh sekarang',
        onTap: _ready ? () => _check() : () => _download(),
      ),
      if (_busy) ...[
        const SizedBox(height: 22),
        _ProgressBar(value: _progress, speed: _speed, stage: _stage),
      ],
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Notice(_error),
      ],
      const SizedBox(height: 28),
      const _Label('Status'),
      const SizedBox(height: 10),
      _Panel(
        child: Column(
          children: [
            _Kv('Aset', _ready ? 'lengkap' : 'belum ada'),
            if (_sha.isNotEmpty)
              _Kv('Checksum', _sha.length <= 16 ? _sha : _sha.substring(0, 16)),
            const _Kv('Galeri', 'file tersembunyi'),
            const _Kv('Renderer', 'Vulkan 1.2'),
          ],
        ),
      ),
    ];
  }

  // ---- Files ---------------------------------------------------------------

  List<Widget> _files() {
    return [
      const Text('Aset 26.3',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Scope.text)),
      const SizedBox(height: 6),
      Text(
        _ready ? 'Terverifikasi. Game bisa jalan tanpa internet.' : '773 MB, sekali unduh, lanjut jalan offline.',
        style: const TextStyle(fontSize: 14, height: 1.45, color: Scope.muted),
      ),
      const SizedBox(height: 20),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_busy || _paused || _progress > 0) ...[
              _ProgressBar(value: _progress, speed: _speed, stage: _stage),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: _Primary(
                    label: _busy ? 'Jeda' : (_paused ? 'Lanjutkan' : 'Unduh aset'),
                    onTap: _download,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _Ghost(label: 'Impor zip', onTap: _import)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _Label('Kalau unduhan putus'),
      const SizedBox(height: 8),
      const Text(
        'Server utama diblokir? Launcher pindah ke cermin lain sendiri. Unduhan lanjut dari byte terakhir, tidak mulai dari nol.',
        style: TextStyle(fontSize: 13, height: 1.5, color: Scope.muted),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Notice(_error),
      ],
    ];
  }

  // ---- Add-ons -------------------------------------------------------------

  List<Widget> _addonsScreen() {
    final shown = _addons.where((a) => (a['type'] ?? 'mod') == _addonType).toList();
    return [
      const Text('Tambahan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Scope.text)),
      const SizedBox(height: 6),
      const Text('Mod, shader, dan resource pack. Ambil dari tautan.',
          style: TextStyle(fontSize: 14, height: 1.45, color: Scope.muted)),
      const SizedBox(height: 18),
      _Segments(
        options: const ['Mod', 'Shader', 'Pack'],
        index: const ['mod', 'shader', 'pack'].indexOf(_addonType),
        onPick: (i) => setState(() => _addonType = ['mod', 'shader', 'pack'][i]),
      ),
      const SizedBox(height: 16),
      _Panel(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                style: const TextStyle(fontSize: 14, color: Scope.text),
                decoration: const InputDecoration(
                  hintText: 'https://…',
                  hintStyle: TextStyle(color: Scope.dim, fontSize: 14),
                  isDense: true,
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _install(),
              ),
            ),
            const SizedBox(width: 8),
            _Small(label: 'Pasang', onTap: _install),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _Label(_addonType == 'mod' ? 'Terpasang' : 'Tersedia di perangkat'),
      const SizedBox(height: 8),
      if (shown.isEmpty)
        const Text('Belum ada berkas. Tempel tautan di atas untuk memasang.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Scope.dim))
      else
        for (final a in shown)
          _AddonRow(
            name: (a['name'] as String?) ?? 'tanpa nama',
            size: (a['size'] as num?)?.toInt() ?? 0,
            enabled: a['enabled'] == true,
            onToggle: () => _toggle(a),
          ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Notice(_error),
      ],
    ];
  }

  // ---- Setup ---------------------------------------------------------------

  List<Widget> _setup() {
    return [
      const Text('Setelan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Scope.text)),
      const SizedBox(height: 6),
      const Text('Dipakai saat game dimulai.',
          style: TextStyle(fontSize: 14, height: 1.45, color: Scope.muted)),
      const SizedBox(height: 18),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Nama pemain'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtl,
              onChanged: (v) => _name = v.trim().isEmpty ? 'Pemain' : v.trim(),
              style: const TextStyle(fontSize: 14, color: Scope.text),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
            ),
            const _Hair(),
            _Kv('RAM', '$_ram MB'),
            Slider(
              value: _ram.toDouble(),
              min: 1536,
              max: 3584,
              divisions: 16,
              onChanged: (v) => setState(() => _ram = (v ~/ 128) * 128),
            ),
            const _Hair(),
            _Kv('Thread', '$_threads'),
            Slider(
              value: _threads.toDouble(),
              min: 2,
              max: 8,
              divisions: 3,
              onChanged: (v) => setState(() => _threads = v.round()),
            ),
            const _Hair(),
            _Kv('Jarak pandang', '$_lod blok'),
            Slider(
              value: _lod.toDouble(),
              min: 64,
              max: 256,
              divisions: 3,
              onChanged: (v) => setState(() => _lod = v.round()),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _Label('Kontrol'),
      const SizedBox(height: 8),
      _Segments(
        options: const ['Sentuh', 'Mouse', 'Gamepad', 'Keyboard'],
        index: _touch,
        onPick: (i) => setState(() => _touch = i),
      ),
      const SizedBox(height: 10),
      const Text(
        'Layar sentuh memasang tombol PRI, SEC, D-pad, dan hotbar di atas game. Keyboard tetap bisa dibuka lewat tombol KBD.',
        style: TextStyle(fontSize: 13, height: 1.5, color: Scope.dim),
      ),
    ];
  }

  // ---- Log -----------------------------------------------------------------

  List<Widget> _logScreen() {
    return [
      Row(
        children: [
          const Expanded(
            child: Text('Log',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Scope.text)),
          ),
          _Small(label: 'Muat', onTap: _readLog),
          const SizedBox(width: 8),
          _Small(label: 'Hapus', onTap: _clearLog),
        ],
      ),
      const SizedBox(height: 6),
      const Text('3 KB terakhir dari log engine dan crash.',
          style: TextStyle(fontSize: 14, height: 1.45, color: Scope.muted)),
      const SizedBox(height: 16),
      _Panel(
        child: SelectableText(
          _log.isEmpty ? 'Belum ada catatan. Engine belum pernah gagal di perangkat ini.' : _log,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.5,
            color: Scope.muted,
          ),
        ),
      ),
    ];
  }
}

// ---- Chrome ----------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.ready, required this.tab, required this.onTab});

  final bool ready;
  final int tab;
  final ValueChanged<int> onTab;

  static const _tabs = ['Main', 'Aset', 'Tambahan', 'Setelan', 'Log'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Horizon',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600, color: Scope.text, letterSpacing: -0.2)),
              const SizedBox(width: 10),
              Text(ready ? 'siap' : 'aset kosong',
                  style: const TextStyle(fontSize: 12, color: Scope.muted)),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _TabButton(
                      label: _tabs[i],
                      active: tab == i,
                      onTap: () => onTab(i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Scope.line),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? Scope.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Scope.text : Scope.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Scope.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Scope.line, width: 1),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, color: Scope.muted, fontWeight: FontWeight.w500),
      );
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Scope.muted),
                overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: const TextStyle(fontSize: 13, color: Scope.text)),
        ],
      ),
    );
  }
}

class _Hair extends StatelessWidget {
  const _Hair();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, thickness: 1, color: Scope.line),
      );
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Scope.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Scope.bg)),
        ),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Scope.line, width: 1),
          ),
          child: Text(label, style: const TextStyle(fontSize: 15, color: Scope.text)),
        ),
      ),
    );
  }
}

class _Small extends StatelessWidget {
  const _Small({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Scope.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Scope.line, width: 1),
          ),
          child: Text(label, style: const TextStyle(fontSize: 13, color: Scope.text)),
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.options, required this.index, required this.onPick});

  final List<String> options;
  final int index;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Scope.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Scope.line, width: 1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onPick(i),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Scope.raised : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                      color: i == index ? Scope.text : Scope.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.speed, required this.stage});

  final double value;
  final double speed;
  final String stage;

  @override
  Widget build(BuildContext context) {
    final mb = speed / (1024 * 1024);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value <= 0 ? null : value.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Scope.line,
            valueColor: const AlwaysStoppedAnimation(Scope.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(stage.isEmpty ? 'Mengunduh' : stage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Scope.muted)),
            ),
            Text(
              '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%  ${mb.toStringAsFixed(1)} MB/s',
              style: const TextStyle(fontSize: 12, color: Scope.text),
            ),
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Scope.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Scope.line, width: 1),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45, color: Scope.text)),
    );
  }
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({
    required this.name,
    required this.size,
    required this.enabled,
    required this.onToggle,
  });

  final String name;
  final int size;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final kb = (size / 1024).round();
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled ? Scope.text : Scope.dim,
                      )),
                  const SizedBox(height: 2),
                  Text('$kb KB', style: const TextStyle(fontSize: 11, color: Scope.dim)),
                ],
              ),
            ),
            Text(
              enabled ? 'aktif' : 'mati',
              style: TextStyle(fontSize: 12, color: enabled ? Scope.text : Scope.dim),
            ),
          ],
        ),
      ),
    );
  }
}
