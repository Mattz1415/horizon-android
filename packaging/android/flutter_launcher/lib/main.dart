// main.dart
// Dart / Flutter / Horizon Android launcher shell
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HorizonApp());
}

class Scope {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0D0D10);
  static const raised = Color(0xFF15151A);
  static const line = Color(0xFF24242B);
  static const text = Color(0xFFEEEEF0);
  static const muted = Color(0xFF8E8E98);
  static const dim = Color(0xFF555560);
  static const accent = Color(0xFFFFFFFF);
  static const ok = Color(0xFF66BB6A);
  static const warn = Color(0xFFFFA726);
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

  int _tab = 0; // 0: Aset, 1: Addon, 2: Setelan, 3: Log
  bool _ready = false;
  String _sha = '';

  bool _busy = false;
  bool _paused = false;
  double _progress = 0;
  double _speed = 0;
  String _stage = '';
  String _error = '';

  String _name = 'Player';
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
        _addons = (list ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } on PlatformException {
      // Mod kosong tidak perlu dialog error
    }
  }

  Future<void> _toggleDownload() async {
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
    if (!_ready) {
      setState(() => _tab = 0);
      return;
    }
    try {
      await _channel.invokeMethod('launchGame', {
        'ramMb': _ram,
        'workerThreads': _threads,
        'backend': 'vulkan',
        'touchScheme': _touch,
        'username': _name,
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Gagal memulai game.');
    }
  }

  Future<void> _installAddon() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() => _error = '');
    try {
      await _channel.invokeMethod('installModFromUrl', {
        'url': url,
        'type': _addonType,
      });
      _url.clear();
      await _loadAddons();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Pemasangan gagal.');
    }
  }

  Future<void> _toggleAddon(Map<String, dynamic> addon) async {
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kolom kiri: cockpit peluncuran utama (lebar tetap, padat)
              SizedBox(
                width: 250,
                child: _buildLaunchDeck(),
              ),
              const SizedBox(width: 12),
              // Kolom kanan: tab detail & pengaturan
              Expanded(
                child: _buildWorkDeck(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Kiri: Launch Deck ---
  Widget _buildLaunchDeck() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Scope.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Scope.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Horizon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Scope.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Scope.raised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Scope.line),
                ),
                child: const Text(
                  '26.3',
                  style: TextStyle(fontSize: 10, color: Scope.muted, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ready ? Scope.ok : Scope.warn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Info hardware & runtime
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Scope.raised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _MiniRow('Pemain', _name),
                _MiniRow('Memori', '$_ram MB'),
                _MiniRow('Thread', '$_threads core'),
                _MiniRow('LOD', '$_lod blok'),
              ],
            ),
          ),
          if (_busy || _paused || _progress > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progress <= 0 ? null : _progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Scope.line,
                valueColor: const AlwaysStoppedAnimation(Scope.accent),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _stage.isEmpty ? (_busy ? 'Mengunduh' : 'Jeda') : _stage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Scope.muted),
                  ),
                ),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Scope.text),
                ),
              ],
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Scope.warn),
            ),
          ],
          const Spacer(),
          // Tombol Aksi Utama
          if (_ready)
            _Btn(
              label: 'Mulai Game',
              primary: true,
              height: 44,
              onTap: _launch,
            )
          else
            _Btn(
              label: _busy ? 'Jeda Unduh' : (_paused ? 'Lanjut Unduh' : 'Unduh Aset (773 MB)'),
              primary: true,
              height: 44,
              onTap: _toggleDownload,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Btn(
                  label: 'Periksa',
                  primary: false,
                  height: 34,
                  onTap: _check,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Btn(
                  label: 'Impor Zip',
                  primary: false,
                  height: 34,
                  onTap: _import,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Kanan: Work Deck (Tabs) ---
  Widget _buildWorkDeck() {
    const tabs = ['Aset', 'Tambahan', 'Setelan', 'Log'];
    return Container(
      decoration: BoxDecoration(
        color: Scope.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Scope.line),
      ),
      child: Column(
        children: [
          // Nav Bar
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Scope.line)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  InkWell(
                    onTap: () => setState(() => _tab = i),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _tab == i ? Scope.accent : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _tab == i ? FontWeight.w600 : FontWeight.w400,
                          color: _tab == i ? Scope.text : Scope.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Tab Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: switch (_tab) {
                0 => _paneAssets(),
                1 => _paneAddons(),
                2 => _paneSettings(),
                _ => _paneLogs(),
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 0: Aset ---
  Widget _paneAssets() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _RowItem('Status aset', _ready ? 'Lengkap & terverifikasi' : 'Belum lengkap'),
        _RowItem('Ukuran bundle', '773 MB'),
        if (_sha.isNotEmpty)
          _RowItem('Checksum SHA256', _sha.length <= 16 ? _sha : _sha.substring(0, 16)),
        _RowItem('Proteksi galeri', '.nomedia aktif'),
        _RowItem('Mirror unduhan', '3 CDN otomatis (failover)'),
        _RowItem('Mode transfer', 'HTTP Range resumable'),
        const SizedBox(height: 10),
        const Text(
          'Aset berisi tekstur Minecraft 26.3, audio game, kontrol Bedrock, dan data worldgen. Jika server terputus, unduhan dilanjutkan dari byte terakhir.',
          style: TextStyle(fontSize: 11, height: 1.4, color: Scope.dim),
        ),
      ],
    );
  }

  // --- Tab 1: Tambahan (Mods/Shaders/Packs) ---
  Widget _paneAddons() {
    final shown = _addons.where((a) => (a['type'] ?? 'mod') == _addonType).toList();
    return Column(
      children: [
        Row(
          children: [
            _Pill(
              label: 'Mod (.hmod)',
              active: _addonType == 'mod',
              onTap: () => setState(() => _addonType = 'mod'),
            ),
            const SizedBox(width: 6),
            _Pill(
              label: 'Shader (.hshader)',
              active: _addonType == 'shader',
              onTap: () => setState(() => _addonType = 'shader'),
            ),
            const SizedBox(width: 6),
            _Pill(
              label: 'Resource Pack (.zip)',
              active: _addonType == 'pack',
              onTap: () => setState(() => _addonType = 'pack'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Scope.raised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Scope.line),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _url,
                  style: const TextStyle(fontSize: 12, color: Scope.text),
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    hintStyle: TextStyle(color: Scope.dim, fontSize: 12),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Btn(
              label: 'Pasang',
              primary: false,
              height: 36,
              onTap: _installAddon,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada ${_addonType == 'mod' ? 'mod' : (_addonType == 'shader' ? 'shader' : 'resource pack')} terpasang.',
                    style: const TextStyle(fontSize: 11, color: Scope.dim),
                  ),
                )
              : ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Scope.line),
                  itemBuilder: (_, i) {
                    final item = shown[i];
                    final name = (item['name'] as String?) ?? 'file';
                    final size = ((item['size'] as num?)?.toInt() ?? 0) ~/ 1024;
                    final enabled = item['enabled'] == true;
                    return InkWell(
                      onTap: () => _toggleAddon(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: enabled ? Scope.text : Scope.dim,
                                    ),
                                  ),
                                  Text('$size KB', style: const TextStyle(fontSize: 10, color: Scope.dim)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: enabled ? Scope.raised : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: enabled ? Scope.text : Scope.line),
                              ),
                              child: Text(
                                enabled ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: enabled ? Scope.text : Scope.dim,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Tab 2: Setelan ---
  Widget _paneSettings() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text('Nama pemain', style: TextStyle(fontSize: 12, color: Scope.muted)),
            ),
            Expanded(
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Scope.raised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Scope.line),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _nameCtl,
                  onChanged: (v) => _name = v.trim().isEmpty ? 'Player' : v.trim(),
                  style: const TextStyle(fontSize: 12, color: Scope.text),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SliderRow(
          label: 'Alokasi RAM',
          valueText: '$_ram MB',
          value: _ram.toDouble(),
          min: 1536,
          max: 3584,
          divisions: 16,
          onChanged: (v) => setState(() => _ram = (v ~/ 128) * 128),
        ),
        _SliderRow(
          label: 'Thread CPU',
          valueText: '$_threads core',
          value: _threads.toDouble(),
          min: 2,
          max: 8,
          divisions: 3,
          onChanged: (v) => setState(() => _threads = v.round()),
        ),
        _SliderRow(
          label: 'Jarak LOD',
          valueText: '$_lod blok',
          value: _lod.toDouble(),
          min: 64,
          max: 256,
          divisions: 3,
          onChanged: (v) => setState(() => _lod = v.round()),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text('Kontrol', style: TextStyle(fontSize: 12, color: Scope.muted)),
            ),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: _Pill(
                        label: ['Sentuh', 'Mouse', 'Pad', 'Kbd'][i],
                        active: _touch == i,
                        onTap: () => setState(() => _touch = i),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Tab 3: Log ---
  Widget _paneLogs() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Catatan crash & engine (3 KB terakhir)',
                style: TextStyle(fontSize: 11, color: Scope.muted)),
            Row(
              children: [
                _Btn(label: 'Muat', primary: false, height: 28, onTap: _readLog),
                const SizedBox(width: 6),
                _Btn(label: 'Bersihkan', primary: false, height: 28, onTap: _clearLog),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Scope.raised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Scope.line),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _log.isEmpty ? 'Belum ada catatan log. Engine beroperasi normal.' : _log,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.4,
                  color: Scope.muted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Komponen Visual Ringkas ---

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.primary,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? Scope.accent : Scope.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary ? Scope.accent : Scope.line),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary ? Scope.bg : Scope.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? Scope.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? Scope.text : Scope.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? Scope.text : Scope.muted,
          ),
        ),
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 11, color: Scope.muted)),
          Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Scope.text)),
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 12, color: Scope.muted)),
          Text(v, style: const TextStyle(fontSize: 12, color: Scope.text, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Scope.muted)),
                Text(valueText, style: const TextStyle(fontSize: 11, color: Scope.text, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
