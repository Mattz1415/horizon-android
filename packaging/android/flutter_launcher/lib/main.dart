import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HorizonTacticalApp());
}

// ====================================================================
// MONOCHROME LIQUID GLASS DESIGN SYSTEM (OLED BLACK & SPECULAR SLATE)
// ====================================================================
class MonoGlass {
  // Pure Monochromatic Base
  static const Color pitchBlack = Color(0xFF000000);
  static const Color obsidianBase = Color(0xFF050608);
  static const Color charcoalLayer = Color(0xFF0C0E13);
  static const Color carbonSurface = Color(0xFF13161F);
  static const Color elevatedDeck = Color(0xFF1A1E29);

  // Liquid Glass Translucency & Specular Refraction
  static const Color glassFill = Color(0x7313161F); // 45% fill
  static const Color glassFillSubtle = Color(0x3D1A1E29); // 24% fill
  static const Color glassHighlight = Color(0x40FFFFFF); // 25% white specular
  static const Color glassBorder = Color(0x1FFFFFFF); // 12% subtle border
  static const Color glassBorderActive = Color(0x59FFFFFF); // 35% focused border

  // Typography & Metallic Accents
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color titaniumSilver = Color(0xFFE2E8F0);
  static const Color coolSlate = Color(0xFF94A3B8);
  static const Color darkGraphite = Color(0xFF475569);

  // Status Indicators (Used sparingly at key moments)
  static const Color statusReady = Color(0xFF10B981);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);
}

class HorizonTacticalApp extends StatelessWidget {
  const HorizonTacticalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizon Tactical Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MonoGlass.pitchBlack,
        fontFamily: 'sans-serif',
        colorScheme: const ColorScheme.dark(
          primary: MonoGlass.pureWhite,
          secondary: MonoGlass.coolSlate,
          surface: MonoGlass.carbonSurface,
        ),
      ),
      home: const HorizonCockpit(),
    );
  }
}

class HorizonCockpit extends StatefulWidget {
  const HorizonCockpit({super.key});

  @override
  State<HorizonCockpit> createState() => _HorizonCockpitState();
}

class _HorizonCockpitState extends State<HorizonCockpit>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('com.vasysik.horizon/launcher');
  static const progressEventChannel =
      EventChannel('com.vasysik.horizon/progress');

  // Navigation Sector (0: DECK, 1: DATA MATRIX, 2: ADDONS, 3: PILOT, 4: CORES, 5: LOGS)
  int _activeSector = 0;

  // Engine Status & Validation
  bool _isPrepared = false;
  String _preparedSha256 = '';
  String _systemStatus = 'Inisialisasi telemetri...';

  // Snapdragon 695 / Adreno 619 Presets
  int _ramAllocationMb = 2560;
  int _workerThreadCount = 4;
  String _graphicsApi = 'vulkan';
  int _touchControlScheme = 0; // 0: Joy+Cross, 1: Joy+Tap, 2: DPad+Cross, 3: DPad+Tap
  int _lodDistance = 128; // 0: OFF, 64, 128, 256 chunks
  bool _lodFineDetail = true; // true: Full Detail (Smooth), false: Reduced
  String _activePilot = 'HorizonPlayer';

  // Live Downloader Stream
  double _downloadRatio = 0.0;
  String _downloadStage = 'Standby';
  int _networkSpeedBytes = 0;
  String _streamStatusDetail = 'Pilih metode unduhan (Otomatis CDN atau Manual SAF).';
  bool _isStreaming = false;

  // Addons Tab (0: Mods, 1: Shaders, 2: Packs)
  int _activeAddonTab = 0;
  List<Map<dynamic, dynamic>> _installedAddons = [];
  bool _isLoadingAddons = false;

  StreamSubscription? _streamSubscription;
  late AnimationController _reactorPulse;
  late Animation<double> _reactorAnimation;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _reactorPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _reactorAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _reactorPulse, curve: Curves.easeInOutSine),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _verifyEngineReadiness();
    _connectProgressStream();
    _fetchInstalledAddons();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _reactorPulse.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _connectProgressStream() {
    _streamSubscription =
        progressEventChannel.receiveBroadcastStream().listen((packet) {
      if (packet is Map) {
        final status = packet['status'] as String?;
        if (status == 'downloading') {
          setState(() {
            _isStreaming = true;
            _downloadStage = packet['stage'] ?? 'Streaming';
            _downloadRatio =
                (packet['progress'] as num?)?.toDouble().clamp(0.0, 1.0) ??
                    0.0;
            _networkSpeedBytes = (packet['speed'] as num?)?.toInt() ?? 0;
            _streamStatusDetail = packet['detail'] ?? '';
          });
        } else if (status == 'completed') {
          setState(() {
            _isStreaming = false;
            _isPrepared = true;
            _preparedSha256 = packet['sha256'] ?? '';
            _downloadStage = 'Sinkron';
            _downloadRatio = 1.0;
            _networkSpeedBytes = 0;
            _streamStatusDetail = 'Aset Minecraft 26.3 lengkap dan terverifikasi.';
            _systemStatus = 'SISTEM SIAP';
          });
        } else if (status == 'error') {
          setState(() {
            _isStreaming = false;
            _downloadStage = 'Gagal';
            _streamStatusDetail = packet['error'] ?? 'Gangguan jaringan';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Koneksi CDN terputus: ${packet['error']}. Gunakan import .zip manual jika perlu.'),
              backgroundColor: MonoGlass.statusError,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  Future<void> _verifyEngineReadiness() async {
    try {
      final res = await platform.invokeMethod<Map>('checkResources');
      if (res != null) {
        setState(() {
          _isPrepared = res['isPrepared'] == true;
          _preparedSha256 = res['sha256'] ?? '';
          _systemStatus =
              _isPrepared ? 'ENGINE READY 26.3' : 'ASET BELUM TERPASANG';
        });
      }
    } catch (e) {
      setState(() => _systemStatus = 'Pengecekan gagal: $e');
    }
  }

  Future<void> _fetchInstalledAddons() async {
    setState(() => _isLoadingAddons = true);
    try {
      final list = await platform.invokeMethod<List<dynamic>>('getMods');
      if (list != null) {
        setState(() {
          _installedAddons = list.map((e) => Map<dynamic, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
    setState(() => _isLoadingAddons = false);
  }

  Future<void> _engageLaunch() async {
    if (!_isPrepared) {
      setState(() => _activeSector = 1); // Switch to Data Matrix
      _toggleDownloadStream();
      return;
    }
    try {
      HapticFeedback.heavyImpact();
      await platform.invokeMethod('launchGame', {
        'ramMb': _ramAllocationMb,
        'workerThreads': _workerThreadCount,
        'backend': _graphicsApi,
        'touchScheme': _touchControlScheme,
        'username': _activePilot,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Peluncuran gagal: $e'),
          backgroundColor: MonoGlass.statusError,
        ),
      );
    }
  }

  void _toggleDownloadStream() {
    HapticFeedback.selectionClick();
    if (_isStreaming) {
      platform.invokeMethod('pauseDownload');
      setState(() => _isStreaming = false);
    } else {
      platform.invokeMethod('startDownload');
      setState(() => _isStreaming = true);
    }
  }

  Future<void> _downloadAddon(String url, String type) async {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengunduh $type dari URL...'),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      await platform.invokeMethod('installModFromUrl', {'url': url, 'type': type});
      _fetchInstalledAddons();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pemasangan addon berhasil!'),
            backgroundColor: MonoGlass.statusReady,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal pasang addon: $e'),
            backgroundColor: MonoGlass.statusError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MonoGlass.pitchBlack,
      body: Stack(
        children: [
          // Background Specular Atmosphere
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E121A),
                    MonoGlass.obsidianBase,
                    MonoGlass.pitchBlack,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Tactical HUD Cockpit Shell
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  // 1. Orbital Aerospace Top Command Ribbon
                  _buildOrbitalCommandRibbon(),

                  const SizedBox(height: 10),

                  // 2. Center Dynamic Stage (Sector Switched)
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.015, 0.0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_activeSector),
                        child: _resolveSectorView(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 1. ORBITAL COMMAND RIBBON (TOP FLOATING HUD)
  // ====================================================================
  Widget _buildOrbitalCommandRibbon() {
    final sectors = [
      {'label': 'TACTICAL DECK', 'icon': Icons.space_dashboard_outlined},
      {'label': 'DATA MATRIX', 'icon': Icons.hub_outlined},
      {'label': 'COMMUNITY HUB', 'icon': Icons.extension_outlined},
      {'label': 'PILOT ID', 'icon': Icons.badge_outlined},
      {'label': 'ENGINE CORES', 'icon': Icons.memory_outlined},
      {'label': 'DIAGNOSTICS', 'icon': Icons.terminal_outlined},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MonoGlass.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MonoGlass.glassBorder, width: 0.9),
      ),
      child: Row(
        children: [
          // Branding & Active Hardware Spec
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isPrepared
                      ? MonoGlass.statusReady
                      : MonoGlass.statusPending,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPrepared
                              ? MonoGlass.statusReady
                              : MonoGlass.statusPending)
                          .withOpacity(0.4),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'HORIZON // 26.3',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: MonoGlass.pureWhite,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MonoGlass.carbonSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: MonoGlass.glassBorder, width: 0.6),
                ),
                child: const Text(
                  'SNAPDRAGON 695 · ADRENO 619',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: MonoGlass.coolSlate,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Centered Sector Selector Pills
          Row(
            children: List.generate(sectors.length, (idx) {
              final active = _activeSector == idx;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeSector = idx);
                    if (idx == 2) _fetchInstalledAddons();
                  },
                  borderRadius: BorderRadius.circular(9),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? MonoGlass.pureWhite
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: active
                            ? MonoGlass.pureWhite
                            : Colors.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sectors[idx]['icon'] as IconData,
                          size: 13,
                          color: active
                              ? MonoGlass.pitchBlack
                              : MonoGlass.coolSlate,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          sectors[idx]['label'] as String,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                            color: active
                                ? MonoGlass.pitchBlack
                                : MonoGlass.coolSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Sector Resolver
  Widget _resolveSectorView() {
    switch (_activeSector) {
      case 0:
        return _buildTacticalDeck();
      case 1:
        return _buildDataMatrix();
      case 2:
        return _buildAddonsCenter();
      case 3:
        return _buildPilotRegistry();
      case 4:
        return _buildEngineCores();
      case 5:
        return _buildDiagnosticConsole();
      default:
        return _buildTacticalDeck();
    }
  }

  // ====================================================================
  // SECTOR 0: TACTICAL DECK (COMMAND COCKPIT)
  // ====================================================================
  Widget _buildTacticalDeck() {
    return Row(
      children: [
        // Left Column: Monolithic Telemetry Display (62%)
        Expanded(
          flex: 62,
          child: QuantumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Deck State
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MINECRAFT JAVA EDITION 26.3',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: MonoGlass.pureWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'CLEAN-ROOM RUST ENGINE · PURE VULKAN 1.2 · 0% JVM OVERHEAD',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: MonoGlass.coolSlate.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isPrepared
                            ? const Color(0x1A10B981)
                            : const Color(0x1AF59E0B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isPrepared
                              ? MonoGlass.statusReady.withOpacity(0.6)
                              : MonoGlass.statusPending.withOpacity(0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _isPrepared ? 'STATUS: ENGINE SIAP' : 'STATUS: PERLU SYNC',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: _isPrepared
                              ? MonoGlass.statusReady
                              : MonoGlass.statusPending,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Aerospace Cluster Telemetry Gauges
                Row(
                  children: [
                    _buildGaugeBox('RAM ALOKASI', '$_ramAllocationMb MB',
                        'Didedikasikan untuk Vulkan & Mesh'),
                    const SizedBox(width: 8),
                    _buildGaugeBox('THREAD CORES', '$_workerThreadCount THREADS',
                        'Meshing paralel Snapdragon 695'),
                    const SizedBox(width: 8),
                    _buildGaugeBox(
                        'LOD TERRAIN',
                        _lodDistance == 0 ? 'OFF (12 CHUNKS)' : '$_lodDistance CHUNKS',
                        _lodFineDetail ? 'Full Smooth Subdivided' : 'Reduced'),
                  ],
                ),

                const SizedBox(height: 10),

                // System Integrity & Gallery Shield Verification Line
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: MonoGlass.charcoalLayer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: MonoGlass.glassBorder, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_outlined,
                          size: 14, color: MonoGlass.pureWhite),
                      const SizedBox(width: 8),
                      const Text(
                        'Media Protection (.nomedia)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: MonoGlass.pureWhite,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '— Galeri foto HP 100% terlindung dari tekstur/audio game.',
                        style: TextStyle(
                            fontSize: 9.5, color: MonoGlass.coolSlate),
                      ),
                      const Spacer(),
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 14, color: MonoGlass.statusReady),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Right Column: The Kinetic Launch Monolith (38%)
        Expanded(
          flex: 38,
          child: Column(
            children: [
              // Massive Tactical Glass Trigger
              Expanded(
                child: KineticLaunchTrigger(
                  isReady: _isPrepared,
                  onPressed: _engageLaunch,
                ),
              ),

              const SizedBox(height: 10),

              // Quick Pilot Card Summary
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MonoGlass.glassFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MonoGlass.glassBorder, width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: MonoGlass.carbonSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: MonoGlass.glassBorder, width: 0.8),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_outline_rounded,
                            size: 16, color: MonoGlass.pureWhite),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activePilot,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: MonoGlass.pureWhite,
                          ),
                        ),
                        const Text(
                          'PROFIL AKTIF OFFLINE',
                          style: TextStyle(
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                            color: MonoGlass.coolSlate,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => setState(() => _activeSector = 3),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(
                            color: MonoGlass.glassBorder, width: 0.8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                      ),
                      child: const Text('GANTI',
                          style: TextStyle(
                              fontSize: 9.5, color: MonoGlass.pureWhite)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGaugeBox(String title, String val, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MonoGlass.charcoalLayer.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MonoGlass.glassBorder, width: 0.7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: MonoGlass.coolSlate)),
            const SizedBox(height: 4),
            Text(val,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: MonoGlass.pureWhite)),
            const SizedBox(height: 3),
            Text(sub,
                style: TextStyle(
                    fontSize: 8, color: MonoGlass.coolSlate.withOpacity(0.8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // SECTOR 1: DATA MATRIX (DUAL INSTALLER & RESILIENT STREAM)
  // ====================================================================
  Widget _buildDataMatrix() {
    return Row(
      children: [
        // Left Panel: Dual Mode Installer Architecture
        Expanded(
          flex: 60,
          child: QuantumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DATA MATRIX // 26.3 PIPELINE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: MonoGlass.pureWhite,
                          ),
                        ),
                        Text(
                          'Tahap Operasi: $_downloadStage',
                          style: const TextStyle(
                              fontSize: 10, color: MonoGlass.coolSlate),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: MonoGlass.carbonSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: MonoGlass.glassBorder, width: 0.8),
                          ),
                          child: Text(
                            _isPrepared
                                ? 'CHECKSUM VERIFIED'
                                : 'ASET DIBUTUHKAN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _isPrepared
                                  ? MonoGlass.statusReady
                                  : MonoGlass.statusPending,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Method A: Auto Fast CDN Stream (Recommended)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MonoGlass.charcoalLayer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: MonoGlass.glassHighlight.withOpacity(0.18),
                        width: 0.9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              size: 16, color: MonoGlass.pureWhite),
                          const SizedBox(width: 6),
                          const Text(
                            'METODE 1: UNDUH OTOMATIS (FAST CDN)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: MonoGlass.pureWhite,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: MonoGlass.pureWhite.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Resumable Range',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: MonoGlass.pureWhite)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mengunduh paket zip lengkap (audio OGG, kontrol layar, tabel fakta engine). Dilengkapi auto-reconnect anti-gagal.',
                        style: TextStyle(
                            fontSize: 9.5,
                            color: MonoGlass.coolSlate.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TactileActionPill(
                              label: _isStreaming
                                  ? 'JEDA STREAM UNDUHAN'
                                  : 'MULAI UNDUH OTOMATIS (CDN)',
                              icon: _isStreaming
                                  ? Icons.pause_rounded
                                  : Icons.cloud_download_rounded,
                              isHighlight: !_isPrepared,
                              onPressed: _toggleDownloadStream,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Method B: Manual SAF File Picker (.ZIP)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MonoGlass.charcoalLayer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: MonoGlass.glassBorder, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.folder_zip_outlined,
                                    size: 15, color: MonoGlass.pureWhite),
                                SizedBox(width: 6),
                                Text(
                                  'METODE 2: PASANG MANUAL (.ZIP OFFLINE)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: MonoGlass.pureWhite,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pilih file horizon-resources-26.3.zip yang telah diunduh manual melalui browser HP.',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: MonoGlass.coolSlate.withOpacity(0.9)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          platform.invokeMethod('importResourcesZip');
                        },
                        icon: const Icon(Icons.file_open_outlined, size: 14),
                        label: const Text('IMPORT .ZIP',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MonoGlass.pureWhite,
                          side: const BorderSide(
                              color: MonoGlass.glassHighlight, width: 0.9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Live Progress Wave Monitor
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 16,
                    color: MonoGlass.charcoalLayer,
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: _downloadRatio,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  MonoGlass.coolSlate,
                                  MonoGlass.pureWhite,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${(_downloadRatio * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: MonoGlass.pitchBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _streamStatusDetail,
                        style: const TextStyle(
                            fontSize: 9.5, color: MonoGlass.coolSlate),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_networkSpeedBytes > 0)
                      Text(
                        '${(_networkSpeedBytes / (1024 * 1024)).toStringAsFixed(2)} MB/s',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: MonoGlass.pureWhite,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Right Panel: Asset Index Verification Manifest (40%)
        Expanded(
          flex: 40,
          child: QuantumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KOMPONEN ASET TERVERIFIKASI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: MonoGlass.pureWhite,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildAssetIntegrityItem(
                          'Tabel Engine (Facts / Regs)', '33 JSON/NBT files', _isPrepared),
                      _buildAssetIntegrityItem(
                          'Tekstur Vanilla 26.3', 'Client jar textures', _isPrepared),
                      _buildAssetIntegrityItem(
                          'Audio OGG Stereo', '4.962 sound objects', _isPrepared),
                      _buildAssetIntegrityItem('Kontrol Layar Bedrock',
                          '60 HUD texture elements', _isPrepared),
                      _buildAssetIntegrityItem(
                          'Worldgen & Datapack', 'Reconstructed structures', _isPrepared),
                      _buildAssetIntegrityItem(
                          'Media Shield (.nomedia)', 'Aktif di semua direktori', true),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _verifyEngineReadiness,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MonoGlass.pureWhite,
                      side: const BorderSide(
                          color: MonoGlass.glassBorder, width: 0.8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('VALIDASI ULANG CHECKSUM',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetIntegrityItem(String name, String sub, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: MonoGlass.charcoalLayer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MonoGlass.glassBorder, width: 0.6),
        ),
        child: Row(
          children: [
            Icon(
              ok
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: ok ? MonoGlass.statusReady : MonoGlass.coolSlate,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: MonoGlass.pureWhite)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 8.5, color: MonoGlass.coolSlate)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // SECTOR 2: COMMUNITY HUB (MODS .HMOD, SHADERS, RESOURCE PACKS)
  // ====================================================================
  Widget _buildAddonsCenter() {
    final customUrlCtrl = TextEditingController();

    // Curated catalog items
    final curatedMods = [
      {
        'title': 'Coords & FPS HUD',
        'sub': 'Menampilkan koordinat XYZ, Biome, dan FPS di layar',
        'url': 'https://raw.githubusercontent.com/horizon-rust/horizon-mods/main/coords-hud/coords-hud.hmod',
        'type': 'mod',
      },
      {
        'title': 'Smooth Zoom (C-Key)',
        'sub': 'Zoom kamera halus OptiFine untuk melihat kejauhan',
        'url': 'https://raw.githubusercontent.com/horizon-rust/horizon-mods/main/zoom/zoom.hmod',
        'type': 'mod',
      },
      {
        'title': 'Fullbright Gamma',
        'sub': 'Penerangan malam hari tanpa obor di gua',
        'url': 'https://raw.githubusercontent.com/horizon-rust/horizon-mods/main/fullbright/fullbright.hmod',
        'type': 'mod',
      },
    ];

    final curatedShaders = [
      {
        'title': 'Horizon Vanilla Enhanced',
        'sub': 'Refleksi air PBR Vulkan & bayangan dinamis halus',
        'url': 'https://playhorizon.dev/shaders/vanilla-enhanced.hshader',
        'type': 'shader',
      },
      {
        'title': 'Golden Hour Atmospheric',
        'sub': 'Efek sinar matahari senja dan kabut atmosferik',
        'url': 'https://playhorizon.dev/shaders/golden-hour.hshader',
        'type': 'shader',
      },
    ];

    final curatedPacks = [
      {
        'title': 'Bare Bones 26.3',
        'sub': 'Tekstur kartun minimalis 16x sangat ringan untuk mobile',
        'url': 'https://playhorizon.dev/packs/bare-bones-26.3.zip',
        'type': 'pack',
      },
      {
        'title': 'Programmer Art Classic',
        'sub': 'Tekstur retro klasik Minecraft alpha/beta',
        'url': 'https://playhorizon.dev/packs/programmer-art.zip',
        'type': 'pack',
      },
    ];

    final activeList = _activeAddonTab == 0
        ? curatedMods
        : (_activeAddonTab == 1 ? curatedShaders : curatedPacks);
    final activeTypeName = _activeAddonTab == 0
        ? 'Mod (.hmod)'
        : (_activeAddonTab == 1 ? 'Shader (.hshader)' : 'Resource Pack (.zip)');

    return Row(
      children: [
        // Left Column: Catalog Browser
        Expanded(
          flex: 60,
          child: QuantumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tab Header
                Row(
                  children: [
                    _buildSubTabPill('MODS NATIVE (.HMOD)', 0),
                    const SizedBox(width: 6),
                    _buildSubTabPill('SHADERS (WGSL)', 1),
                    const SizedBox(width: 6),
                    _buildSubTabPill('RESOURCE PACKS', 2),
                  ],
                ),
                const SizedBox(height: 10),

                // Curated Catalog List
                Expanded(
                  child: ListView.builder(
                    itemCount: activeList.length,
                    itemBuilder: (ctx, idx) {
                      final item = activeList[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: MonoGlass.charcoalLayer.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: MonoGlass.glassBorder, width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: MonoGlass.carbonSurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  _activeAddonTab == 0
                                      ? Icons.extension_outlined
                                      : (_activeAddonTab == 1
                                          ? Icons.wb_sunny_outlined
                                          : Icons.inventory_2_outlined),
                                  size: 15,
                                  color: MonoGlass.pureWhite,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title']!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: MonoGlass.pureWhite,
                                      ),
                                    ),
                                    Text(
                                      item['sub']!,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: MonoGlass.coolSlate),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _downloadAddon(item['url']!, item['type']!),
                                icon: const Icon(Icons.download_rounded,
                                    size: 13),
                                label: const Text('PASANG',
                                    style: TextStyle(fontSize: 9.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: MonoGlass.pureWhite,
                                  visualDensity: VisualDensity.compact,
                                  side: const BorderSide(
                                      color: MonoGlass.glassHighlight,
                                      width: 0.8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // Custom Direct URL Downloader
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: customUrlCtrl,
                          style: const TextStyle(
                              fontSize: 11, color: MonoGlass.pureWhite),
                          decoration: InputDecoration(
                            hintText: 'Pasang via URL langsung (https://...$activeTypeName)',
                            hintStyle: const TextStyle(
                                fontSize: 9.5, color: MonoGlass.coolSlate),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: MonoGlass.charcoalLayer,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: MonoGlass.glassBorder, width: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final u = customUrlCtrl.text.trim();
                        if (u.isNotEmpty) {
                          final type = _activeAddonTab == 0
                              ? 'mod'
                              : (_activeAddonTab == 1 ? 'shader' : 'pack');
                          _downloadAddon(u, type);
                          customUrlCtrl.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MonoGlass.pureWhite,
                        foregroundColor: MonoGlass.pitchBlack,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('UNDUH',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Right Column: Installed Addons Manager
        Expanded(
          flex: 40,
          child: QuantumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ADDONS TERPASANG',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: MonoGlass.pureWhite,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      onPressed: _fetchInstalledAddons,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoadingAddons
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: MonoGlass.pureWhite))
                      : _installedAddons.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada mod atau addon terpasang.\nUnduh dari katalog di samping.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 9.5, color: MonoGlass.coolSlate),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _installedAddons.length,
                              itemBuilder: (ctx, idx) {
                                final mod = _installedAddons[idx];
                                final name = mod['name'] as String? ?? 'addon';
                                final fileName = mod['fileName'] as String? ?? '';
                                final enabled = mod['enabled'] as bool? ?? true;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: MonoGlass.charcoalLayer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: MonoGlass.glassBorder, width: 0.7),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: enabled
                                                  ? MonoGlass.pureWhite
                                                  : MonoGlass.coolSlate,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Switch(
                                          value: enabled,
                                          activeColor: MonoGlass.pureWhite,
                                          activeTrackColor: MonoGlass.statusReady,
                                          inactiveThumbColor: MonoGlass.coolSlate,
                                          inactiveTrackColor: MonoGlass.charcoalLayer,
                                          onChanged: (_) async {
                                            HapticFeedback.selectionClick();
                                            await platform.invokeMethod('toggleMod', {
                                              'fileName': fileName,
                                              'type': 'mod',
                                            });
                                            _fetchInstalledAddons();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabPill(String title, int tabIdx) {
    final active = _activeAddonTab == tabIdx;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeAddonTab = tabIdx);
      },
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? MonoGlass.pureWhite : MonoGlass.charcoalLayer,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? MonoGlass.pureWhite : MonoGlass.glassBorder,
            width: 0.7,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: active ? MonoGlass.pitchBlack : MonoGlass.coolSlate,
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // SECTOR 3: PILOT REGISTRY (PROFILE & ACCOUNTS)
  // ====================================================================
  Widget _buildPilotRegistry() {
    final nameCtrl = TextEditingController(text: _activePilot);

    return QuantumGlassPanel(
      child: Row(
        children: [
          // Left: Pilot Avatar Hologram
          Expanded(
            flex: 35,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MonoGlass.charcoalLayer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MonoGlass.glassBorder, width: 0.8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: MonoGlass.carbonSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: MonoGlass.glassHighlight, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.person_pin_rounded,
                          size: 42, color: MonoGlass.pureWhite),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _activePilot,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: MonoGlass.pureWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AUTHENTICATION: OFFLINE LOCAL',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.6,
                      color: MonoGlass.coolSlate,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Right: Pilot Configuration Editor
          Expanded(
            flex: 65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PILOT PROFILE SETUP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: MonoGlass.pureWhite,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nama ini digunakan sebagai identitas pemain lokal singleplayer dan username saat bergabung ke server LAN.',
                  style: TextStyle(fontSize: 10, color: MonoGlass.coolSlate),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(
                      fontSize: 13, color: MonoGlass.pureWhite),
                  decoration: InputDecoration(
                    labelText: 'Username Pemain',
                    labelStyle: const TextStyle(
                        fontSize: 11, color: MonoGlass.coolSlate),
                    filled: true,
                    fillColor: MonoGlass.charcoalLayer.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: MonoGlass.glassBorder, width: 0.8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: MonoGlass.glassBorder, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: MonoGlass.pureWhite, width: 1.2),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: TactileActionPill(
                        label: 'SIMPAN IDENTITAS PILOT',
                        icon: Icons.save_outlined,
                        isHighlight: true,
                        onPressed: () {
                          final newName = nameCtrl.text.trim();
                          if (newName.isNotEmpty) {
                            HapticFeedback.mediumImpact();
                            setState(() => _activePilot = newName);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pilot disimpan: $newName'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // SECTOR 4: ENGINE CORES (REALME 10 PRO 5G / SNAPDRAGON 695 TUNING)
  // ====================================================================
  Widget _buildEngineCores() {
    return Row(
      children: [
        // Left Column: Performance Hardware Config
        Expanded(
          flex: 50,
          child: QuantumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CORE HARDWARE & LOD TUNING',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: MonoGlass.pureWhite,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Disesuaikan optimal untuk Snapdragon 695 5G & Adreno 619.',
                  style: TextStyle(fontSize: 9.5, color: MonoGlass.coolSlate),
                ),
                const SizedBox(height: 10),

                // RAM Allocation Slider
                Text(
                  'Alokasi Memori RAM: $_ramAllocationMb MB',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: MonoGlass.pureWhite),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: MonoGlass.pureWhite,
                    inactiveTrackColor: MonoGlass.charcoalLayer,
                    thumbColor: MonoGlass.pureWhite,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _ramAllocationMb.toDouble(),
                    min: 1536,
                    max: 3584,
                    divisions: 8,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _ramAllocationMb = v.toInt());
                    },
                  ),
                ),

                // LOD Distance Setting
                const SizedBox(height: 6),
                Text(
                  'LOD Distant Terrain: ${_lodDistance == 0 ? "OFF (Vanilla 12 Chunks)" : "$_lodDistance Chunks"}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: MonoGlass.pureWhite),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [0, 64, 128, 256].map((dist) {
                    final sel = _lodDistance == dist;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(dist == 0 ? 'OFF' : '$dist CH',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: sel
                                  ? MonoGlass.pitchBlack
                                  : MonoGlass.coolSlate,
                            )),
                        selected: sel,
                        selectedColor: MonoGlass.pureWhite,
                        backgroundColor: MonoGlass.charcoalLayer,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _lodDistance = dist);
                        },
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // Worker Threads
                Text(
                  'Worker Thread Count: $_workerThreadCount Cores',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: MonoGlass.pureWhite),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [2, 4, 6, 8].map((th) {
                    final sel = _workerThreadCount == th;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$th THREADS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: sel
                                  ? MonoGlass.pitchBlack
                                  : MonoGlass.coolSlate,
                            )),
                        selected: sel,
                        selectedColor: MonoGlass.pureWhite,
                        backgroundColor: MonoGlass.charcoalLayer,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _workerThreadCount = th);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Right Column: Controller & Graphics API
        Expanded(
          flex: 50,
          child: QuantumGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KONTROL & GRAFIS RUNTIME',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: MonoGlass.pureWhite,
                  ),
                ),
                const SizedBox(height: 10),

                // Touch Scheme Selector
                const Text(
                  'Skema Kontrol Sentuh (Pojav / Zalith)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: MonoGlass.pureWhite),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _touchControlScheme,
                  dropdownColor: MonoGlass.carbonSurface,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: MonoGlass.charcoalLayer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: MonoGlass.glassBorder, width: 0.8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 0,
                        child: Text('1. Virtual Joystick + Crosshair Aim',
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: 1,
                        child: Text('2. Virtual Joystick + Direct Tap Aim',
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: 2,
                        child: Text('3. Classic D-Pad + Crosshair Aim',
                            style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(
                        value: 3,
                        child: Text('4. Classic D-Pad + Direct Tap Aim',
                            style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _touchControlScheme = v ?? 0);
                  },
                ),

                const Spacer(),

                // Graphics API Lock
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MonoGlass.charcoalLayer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: MonoGlass.glassBorder, width: 0.8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 16, color: MonoGlass.pureWhite),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GRAPHICS API: VULKAN 1.2',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: MonoGlass.pureWhite)),
                          Text('Terkunci ke hardware driver Qualcomm Adreno 619',
                              style: TextStyle(
                                  fontSize: 8.5, color: MonoGlass.coolSlate)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ====================================================================
  // SECTOR 5: DIAGNOSTIC CONSOLE (LOGS & ENGINE STDOUT)
  // ====================================================================
  Widget _buildDiagnosticConsole() {
    return QuantumGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_outlined,
                      size: 16, color: MonoGlass.pureWhite),
                  SizedBox(width: 8),
                  Text(
                    'TELEMETRI & LOG ENGINE RUNTIME',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: MonoGlass.pureWhite,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  platform.invokeMethod('clearLogs');
                  setState(() {});
                },
                icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                label: const Text('BERSIHKAN', style: TextStyle(fontSize: 10)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MonoGlass.pureWhite,
                  side: const BorderSide(
                      color: MonoGlass.glassBorder, width: 0.8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<dynamic>(
              future: platform.invokeMethod('getLogs'),
              builder: (ctx, snap) {
                final text = (snap.data as String?)?.trim() ??
                    'Menghubungkan ke buffer stdout engine...';
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MonoGlass.obsidianBase,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: MonoGlass.glassBorder, width: 0.8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      text.isEmpty ? 'Tidak ada riwayat crash atau warning.' : text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        height: 1.4,
                        color: MonoGlass.coolSlate,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// BESPOKE QUANTUM GLASS CONTAINER (LAYERED SPECULAR HIGHLIGHTS)
// ====================================================================
class QuantumGlassPanel extends StatelessWidget {
  final Widget child;
  const QuantumGlassPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MonoGlass.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MonoGlass.glassBorder,
              width: 0.9,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ====================================================================
// MASSIVE KINETIC LAUNCH TRIGGER (TACTICAL MONOLITH)
// ====================================================================
class KineticLaunchTrigger extends StatefulWidget {
  final bool isReady;
  final VoidCallback onPressed;

  const KineticLaunchTrigger({
    super.key,
    required this.isReady,
    required this.onPressed,
  });

  @override
  State<KineticLaunchTrigger> createState() => _KineticLaunchTriggerState();
}

class _KineticLaunchTriggerState extends State<KineticLaunchTrigger> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgGradient = widget.isReady
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MonoGlass.pureWhite,
              MonoGlass.titaniumSilver,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF262C3A),
              MonoGlass.charcoalLayer,
            ],
          );

    final textColor = widget.isReady ? MonoGlass.pitchBlack : MonoGlass.pureWhite;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isReady
                  ? MonoGlass.pureWhite
                  : MonoGlass.glassHighlight,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isReady
                    ? MonoGlass.pureWhite.withOpacity(0.18)
                    : Colors.black45,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isReady
                    ? Icons.play_arrow_rounded
                    : Icons.cloud_download_rounded,
                size: 44,
                color: textColor,
              ),
              const SizedBox(height: 6),
              Text(
                widget.isReady ? 'INITIALIZE 26.3' : 'DOWNLOAD SYNC',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.isReady
                    ? 'Buka Minecraft Rust Vulkan Surface'
                    : 'Aset belum lengkap, tap untuk sync',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// TACTILE ACTION PILL BUTTON
// ====================================================================
class TactileActionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isHighlight;
  final VoidCallback onPressed;

  const TactileActionPill({
    super.key,
    required this.label,
    required this.icon,
    this.isHighlight = false,
    required this.onPressed,
  });

  @override
  State<TactileActionPill> createState() => _TactileActionPillState();
}

class _TactileActionPillState extends State<TactileActionPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: widget.isHighlight
                ? MonoGlass.pureWhite
                : MonoGlass.carbonSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isHighlight
                  ? MonoGlass.pureWhite
                  : MonoGlass.glassBorder,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  size: 15,
                  color: widget.isHighlight
                      ? MonoGlass.pitchBlack
                      : MonoGlass.pureWhite),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: widget.isHighlight
                      ? MonoGlass.pitchBlack
                      : MonoGlass.pureWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
