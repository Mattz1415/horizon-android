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
  runApp(const HorizonApp());
}

// ====================================================================
// MONOCHROME LIQUID GLASS DESIGN TOKENS (HITAM & PUTIH)
// ====================================================================
class MonoGlass {
  // Ultra-Dark Pitch Obsidian & OLED Black
  static const Color pitchBlack = Color(0xFF000000);
  static const Color pitchObsidian = Color(0xFF050507);
  static const Color charcoalMesh = Color(0xFF0B0D11);
  static const Color slateCarbon = Color(0xFF14161C);

  // Liquid Glass Translucency
  static const Color glassSurface = Color(0x9914161C); // rgba(20, 22, 28, 0.60)
  static const Color glassCard = Color(0x731C1F26); // rgba(28, 31, 38, 0.45)
  static const Color glassPill = Color(0x59272A34); // rgba(39, 42, 52, 0.35)

  // Specular Refraction Gradient Edges
  static const Color borderTopLeft = Color(0x47FFFFFF); // rgba(255, 255, 255, 0.28)
  static const Color borderBottomRight = Color(0x0DFFFFFF); // rgba(255, 255, 255, 0.05)

  // High-Contrast Monochrome Accents
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color titaniumSilver = Color(0xFFE4E4E7);
  static const Color coolAshGrey = Color(0xFF9CA3AF);
  static const Color darkMuted = Color(0xFF52525B);

  // Status Indicators
  static const Color statusReady = Color(0xFF10B981);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);
}

class HorizonApp extends StatelessWidget {
  const HorizonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizon Launcher 26.3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MonoGlass.pitchBlack,
        fontFamily: 'sans-serif',
        colorScheme: const ColorScheme.dark(
          primary: MonoGlass.pureWhite,
          secondary: MonoGlass.coolAshGrey,
          surface: MonoGlass.slateCarbon,
        ),
      ),
      home: const HorizonMainShell(),
    );
  }
}

// ====================================================================
// REUSABLE LIQUID GLASS PANEL WITH SPECULAR REFRACTION
// ====================================================================
class LiquidGlassPanel extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? surfaceColor;

  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 14.0,
    this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MonoGlass.borderTopLeft,
            MonoGlass.borderBottomRight,
          ],
        ),
      ),
      padding: const EdgeInsets.all(1.0), // 1px Specular Border
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: surfaceColor ?? MonoGlass.glassSurface,
              borderRadius: BorderRadius.circular(borderRadius - 1.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Text with Tabular Figures enabled for rock-solid numbers
class TabularText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const TabularText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// Tactile Spring Button with Press Bounce
class TactileButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double height;
  final double? width;
  final double borderRadius;

  const TactileButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor = MonoGlass.pureWhite,
    this.borderColor = Colors.transparent,
    this.height = 44.0,
    this.width,
    this.borderRadius = 10.0,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: enabled
                ? (_pressed ? widget.backgroundColor.withOpacity(0.85) : widget.backgroundColor)
                : MonoGlass.charcoalMesh,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: enabled ? widget.borderColor : MonoGlass.borderBottomRight,
              width: 1.0,
            ),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// ====================================================================
// MAIN LANDSCAPE SHELL (5 LIQUID GLASS NAVIGATION RAIL MODULES)
// ====================================================================
class HorizonMainShell extends StatefulWidget {
  const HorizonMainShell({super.key});

  @override
  State<HorizonMainShell> createState() => _HorizonMainShellState();
}

class _HorizonMainShellState extends State<HorizonMainShell>
    with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.vasysik.horizon/launcher');
  static const progressEventChannel = EventChannel('com.vasysik.horizon/progress');

  int _selectedNav = 0;
  bool _isPrepared = false;
  String _preparedSha256 = '';
  String _statusMessage = 'Memeriksa resource 26.3...';

  // Engine Preferences (Realme 10 Pro 5G Tuned: Snapdragon 695 / Adreno 619)
  int _ramMb = 2560;
  int _workerThreads = 4;
  String _backend = 'vulkan';
  int _touchScheme = 0;
  String _activeUsername = 'HorizonPlayer';

  // Downloader Live State
  double _downloadProgress = 0.0;
  String _downloadStage = 'Standby';
  int _downloadSpeed = 0;
  String _downloadDetail = 'Pilih metode unduhan (Otomatis CDN atau Pasang Manual).';
  bool _isDownloading = false;

  StreamSubscription? _progressSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkResources();
    _listenProgress();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _listenProgress() {
    _progressSubscription =
        progressEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final status = event['status'] as String?;
        if (status == 'downloading') {
          setState(() {
            _isDownloading = true;
            _downloadStage = event['stage'] ?? 'Mengunduh';
            _downloadProgress = (event['progress'] as num?)?.toDouble() ?? 0.0;
            _downloadSpeed = (event['speed'] as num?)?.toInt() ?? 0;
            _downloadDetail = event['detail'] ?? '';
          });
        } else if (status == 'completed') {
          setState(() {
            _isDownloading = false;
            _isPrepared = true;
            _preparedSha256 = event['sha256'] ?? '';
            _downloadStage = 'Selesai';
            _downloadProgress = 1.0;
            _downloadSpeed = 0;
            _downloadDetail = 'Resources 26.3 berhasil diverifikasi!';
            _statusMessage = 'Resources 26.3 Siap';
          });
        } else if (status == 'error') {
          setState(() {
            _isDownloading = false;
            _downloadStage = 'Error';
            _downloadDetail = event['error'] ?? 'Terjadi kesalahan unduhan';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${event['error']}'),
              backgroundColor: MonoGlass.statusError,
            ),
          );
        }
      }
    });
  }

  Future<void> _checkResources() async {
    try {
      final res = await platform.invokeMethod<Map>('checkResources');
      if (res != null) {
        setState(() {
          _isPrepared = res['isPrepared'] == true;
          _preparedSha256 = res['sha256'] ?? '';
          _statusMessage = _isPrepared
              ? 'Resources 26.3 Siap'
              : 'Resources 26.3 Belum Diunduh';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Status: $e';
      });
    }
  }

  Future<void> _launchGame() async {
    if (!_isPrepared) {
      setState(() => _selectedNav = 1); // Pindah ke Downloader
      _startOrPauseDownload();
      return;
    }
    try {
      await platform.invokeMethod('launchGame', {
        'ramMb': _ramMb,
        'workerThreads': _workerThreads,
        'backend': _backend,
        'touchScheme': _touchScheme,
        'username': _activeUsername,
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

  void _startOrPauseDownload() {
    if (_isDownloading) {
      platform.invokeMethod('pauseDownload');
      setState(() => _isDownloading = false);
    } else {
      platform.invokeMethod('startDownload');
      setState(() => _isDownloading = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.6),
            radius: 1.3,
            colors: [
              MonoGlass.charcoalMesh,
              MonoGlass.pitchBlack,
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 1. Compact Glass Navigation Rail (Sidebar)
              _buildCompactNavRail(),

              const SizedBox(width: 8),

              // 2. Animated Content Body
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.02, 0.0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedNav),
                    child: _buildCurrentPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactNavRail() {
    final navItems = [
      {'icon': Icons.play_arrow_rounded, 'label': 'Play'},
      {'icon': Icons.cloud_download_outlined, 'label': 'Downloader'},
      {'icon': Icons.account_circle_outlined, 'label': 'Accounts'},
      {'icon': Icons.extension_outlined, 'label': 'Mods'},
      {'icon': Icons.terminal_rounded, 'label': 'Logs'},
    ];

    return LiquidGlassPanel(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      borderRadius: 16,
      child: Column(
        children: [
          // Logo Header
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MonoGlass.pitchObsidian,
              border: Border.all(color: MonoGlass.borderTopLeft, width: 1.0),
            ),
            child: const Center(
              child: Text(
                'HZ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.0,
                  color: MonoGlass.pureWhite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: MonoGlass.borderBottomRight, height: 1),
          const SizedBox(height: 6),

          // Navigation Buttons
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(navItems.length, (index) {
                final isSelected = _selectedNav == index;
                return InkWell(
                  onTap: () => setState(() => _selectedNav = index),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MonoGlass.pureWhite.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? MonoGlass.borderTopLeft
                            : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          navItems[index]['icon'] as IconData,
                          size: 19,
                          color: isSelected
                              ? MonoGlass.pureWhite
                              : MonoGlass.coolAshGrey,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          navItems[index]['label'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected
                                ? MonoGlass.pureWhite
                                : MonoGlass.coolAshGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedNav) {
      case 0:
        return _buildPlayDashboard();
      case 1:
        return _buildResourceCenter();
      case 2:
        return _buildAccountsManager();
      case 3:
        return _buildModsManager();
      case 4:
        return _buildSettingsInspector();
      default:
        return _buildPlayDashboard();
    }
  }

  // ====================================================================
  // 1. PLAY & TELEMETRY DASHBOARD
  // ====================================================================
  Widget _buildPlayDashboard() {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Row(
        children: [
          // Left Sub-Panel: Parameters & Telemetry
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Top Verification Card with Breathing Beacon
                LiquidGlassPanel(
                  height: 64,
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isPrepared
                                  ? MonoGlass.statusReady.withOpacity(_pulseAnimation.value)
                                  : MonoGlass.statusPending.withOpacity(_pulseAnimation.value),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isPrepared
                                          ? MonoGlass.statusReady
                                          : MonoGlass.statusPending)
                                      .withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _statusMessage,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MonoGlass.pureWhite,
                              ),
                            ),
                            if (_preparedSha256.isNotEmpty)
                              TabularText(
                                'SHA: ${_preparedSha256.length >= 16 ? _preparedSha256.substring(0, 16) : _preparedSha256}...',
                                style: const TextStyle(
                                    fontSize: 10, color: MonoGlass.coolAshGrey),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MonoGlass.pitchBlack,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: MonoGlass.borderBottomRight),
                        ),
                        child: const TabularText(
                          'MC 26.3 RUST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: MonoGlass.pureWhite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Settings Box
                Expanded(
                  child: LiquidGlassPanel(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // RAM Allocation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Alokasi RAM',
                                style: TextStyle(
                                    fontSize: 11, color: MonoGlass.coolAshGrey)),
                            TabularText('$_ramMb MB',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: MonoGlass.pureWhite)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            activeTrackColor: MonoGlass.pureWhite,
                            inactiveTrackColor: MonoGlass.charcoalMesh,
                            thumbColor: MonoGlass.pureWhite,
                          ),
                          child: Slider(
                            value: _ramMb.toDouble(),
                            min: 1024,
                            max: 6144,
                            divisions: 10,
                            onChanged: (v) => setState(() => _ramMb = v.toInt()),
                          ),
                        ),

                        // Thread Workers & Graphics Backend
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Worker Threads',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: MonoGlass.coolAshGrey)),
                                  const SizedBox(height: 3),
                                  DropdownButtonFormField<int>(
                                    value: _workerThreads,
                                    decoration: _compactInputDecoration(),
                                    items: [2, 4, 6, 8]
                                        .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: TabularText(t == 4
                                                ? '$t Core (Snapdragon)'
                                                : '$t Core')))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _workerThreads = v ?? 4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Graphics Backend',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: MonoGlass.coolAshGrey)),
                                  const SizedBox(height: 3),
                                  DropdownButtonFormField<String>(
                                    value: _backend,
                                    decoration: _compactInputDecoration(),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'vulkan',
                                          child: Text('Vulkan 1.1')),
                                      DropdownMenuItem(
                                          value: 'gles',
                                          child: Text('OpenGL ES 3.1')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _backend = v ?? 'vulkan'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Touch Control Scheme
                        const Text('Skema Kontrol Sentuh (Realme 10 Pro 5G)',
                            style: TextStyle(
                                fontSize: 10, color: MonoGlass.coolAshGrey)),
                        const SizedBox(height: 3),
                        DropdownButtonFormField<int>(
                          value: _touchScheme,
                          decoration: _compactInputDecoration(),
                          items: const [
                            DropdownMenuItem(
                                value: 0,
                                child: Text('1. Virtual Joystick + Crosshair')),
                            DropdownMenuItem(
                                value: 1,
                                child: Text('2. Virtual Joystick + Tap World')),
                            DropdownMenuItem(
                                value: 2,
                                child: Text('3. Classic D-Pad + Crosshair')),
                            DropdownMenuItem(
                                value: 3,
                                child: Text('4. Classic D-Pad + Tap World')),
                          ],
                          onChanged: (v) =>
                              setState(() => _touchScheme = v ?? 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right Sub-Panel: Active Profile & Hero Launch Button
          Expanded(
            flex: 2,
            child: LiquidGlassPanel(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Active Identity',
                              style: TextStyle(
                                  fontSize: 10, color: MonoGlass.coolAshGrey)),
                          Icon(Icons.shield_outlined,
                              size: 14, color: MonoGlass.pureWhite),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeUsername,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: MonoGlass.pureWhite,
                        ),
                      ),
                      const Text('Offline UUID mode',
                          style: TextStyle(
                              fontSize: 9, color: MonoGlass.coolAshGrey)),
                    ],
                  ),

                  // Hero Action CTA
                  TactileButton(
                    onPressed: _launchGame,
                    backgroundColor: _isPrepared
                        ? MonoGlass.pureWhite
                        : MonoGlass.charcoalMesh,
                    borderColor: _isPrepared
                        ? Colors.transparent
                        : MonoGlass.borderTopLeft,
                    height: 52,
                    borderRadius: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPrepared
                              ? Icons.play_arrow_rounded
                              : Icons.cloud_download_outlined,
                          size: 22,
                          color: _isPrepared
                              ? MonoGlass.pitchBlack
                              : MonoGlass.pureWhite,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPrepared ? 'PLAY 26.3' : 'DOWNLOAD RESOURCES',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.8,
                            color: _isPrepared
                                ? MonoGlass.pitchBlack
                                : MonoGlass.pureWhite,
                          ),
                        ),
                      ],
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
  // 2. RESOURCE CENTER (DOWNLOADER & SAF IMPORT)
  // ====================================================================
  Widget _buildResourceCenter() {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: LiquidGlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pusat Aset & Data Game 26.3',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: MonoGlass.pureWhite)),
                    TabularText('Tahap: $_downloadStage',
                        style: const TextStyle(
                            fontSize: 11, color: MonoGlass.coolAshGrey)),
                  ],
                ),
                // Quick status indicator badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPrepared ? const Color(0x2210B981) : const Color(0x22F59E0B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPrepared ? MonoGlass.statusReady : MonoGlass.statusPending,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isPrepared ? MonoGlass.statusReady : MonoGlass.statusPending,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPrepared ? 'Aset Siap' : 'Aset Belum Siap',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isPrepared ? MonoGlass.statusReady : MonoGlass.statusPending,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dua Opsi Instalasi (Otomatis & Manual)
            Row(
              children: [
                // Opsi 1: Otomatis via Fast CDN
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MonoGlass.glassCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MonoGlass.borderTopLeft, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: MonoGlass.pureWhite),
                            const SizedBox(width: 4),
                            const Text('Otomatis (Fast CDN)',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: MonoGlass.pureWhite)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MonoGlass.pureWhite.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Rekomendasi',
                                  style: TextStyle(fontSize: 8, color: MonoGlass.pureWhite)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Unduh 1 file paket zip utuh (audio, kontrol sentuh, dan tabel engine). Otomatis diekstrak.',
                          style: TextStyle(fontSize: 9, color: MonoGlass.coolAshGrey),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        TactileButton(
                          onPressed: _startOrPauseDownload,
                          backgroundColor: MonoGlass.pureWhite,
                          height: 34,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isDownloading ? Icons.pause_rounded : Icons.cloud_download_rounded,
                                size: 14,
                                color: MonoGlass.pitchBlack,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isDownloading ? 'JEDA UNDUHAN' : 'UNDUH OTOMATIS (CDN)',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: MonoGlass.pitchBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Opsi 2: Pasang Manual (Import .ZIP via File Picker)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MonoGlass.glassCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MonoGlass.borderTopLeft, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_zip_outlined, size: 14, color: MonoGlass.pureWhite),
                            const SizedBox(width: 4),
                            const Text('Pasang Manual (.ZIP)',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: MonoGlass.pureWhite)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MonoGlass.coolAshGrey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Offline Ready',
                                  style: TextStyle(fontSize: 8, color: MonoGlass.coolAshGrey)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pilih file zip horizon-resources-26.3.zip yang telah diunduh manual ke memori HP.',
                          style: TextStyle(fontSize: 9, color: MonoGlass.coolAshGrey),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        TactileButton(
                          onPressed: () => platform.invokeMethod('importResourcesZip'),
                          backgroundColor: MonoGlass.charcoalMesh,
                          borderColor: MonoGlass.borderTopLeft,
                          height: 34,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 14, color: MonoGlass.pureWhite),
                              SizedBox(width: 6),
                              Text(
                                'IMPORT FILE .ZIP (SAF)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: MonoGlass.pureWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Animated Liquid Glass Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 18,
                color: MonoGlass.pitchBlack,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: _downloadProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              MonoGlass.coolAshGrey,
                              MonoGlass.pureWhite,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: TabularText(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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
                    _downloadDetail,
                    style: const TextStyle(
                        fontSize: 10, color: MonoGlass.coolAshGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_downloadSpeed > 0)
                  TabularText(
                    '${(_downloadSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: MonoGlass.pureWhite),
                  ),
              ],
            ),

            const Spacer(),

            // Bottom bar: Gallery protection status & Verify button
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: MonoGlass.coolAshGrey),
                const SizedBox(width: 4),
                const Text(
                  'Gallery Shield (.nomedia) Aktif',
                  style: TextStyle(fontSize: 10, color: MonoGlass.coolAshGrey),
                ),
                const Spacer(),
                TactileButton(
                  onPressed: _checkResources,
                  backgroundColor: MonoGlass.charcoalMesh,
                  borderColor: MonoGlass.borderTopLeft,
                  width: 100,
                  height: 32,
                  child: const Text('CEK STATUS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: MonoGlass.pureWhite)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // 3. ACCOUNTS & PROFILES MANAGER
  // ====================================================================
  Widget _buildAccountsManager() {
    final userController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: LiquidGlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manajemen Akun & Profil',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: MonoGlass.pureWhite)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userController,
                    decoration:
                        _compactInputDecoration(hint: 'Masukkan Username Baru'),
                  ),
                ),
                const SizedBox(width: 8),
                TactileButton(
                  onPressed: () {
                    if (userController.text.trim().isNotEmpty) {
                      setState(() {
                        _activeUsername = userController.text.trim();
                      });
                      userController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Profil aktif diubah ke $_activeUsername')),
                      );
                    }
                  },
                  backgroundColor: MonoGlass.pureWhite,
                  width: 90,
                  height: 40,
                  child: const Text('PILIH',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: MonoGlass.pitchBlack)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Profil Terdaftar',
                style: TextStyle(fontSize: 11, color: MonoGlass.coolAshGrey)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  _accountCard(_activeUsername, isCurrent: true),
                  _accountCard('Steve'),
                  _accountCard('Alex'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(String name, {bool isCurrent = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? MonoGlass.glassCard : MonoGlass.pitchBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? MonoGlass.borderTopLeft : MonoGlass.borderBottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 18, color: MonoGlass.pureWhite),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MonoGlass.pureWhite)),
            ],
          ),
          if (isCurrent)
            const Text('ACTIVE',
                style: TextStyle(
                    fontSize: 9,
                    color: MonoGlass.statusReady,
                    fontWeight: FontWeight.bold))
          else
            TextButton(
              onPressed: () => setState(() => _activeUsername = name),
              child: const Text('Gunakan', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // ====================================================================
  // 4. MODS (.HMOD) & RESOURCE PACKS MANAGER
  // ====================================================================
  Widget _buildModsManager() {
    final urlController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: LiquidGlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mods (.hmod) & Resource Packs',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MonoGlass.pureWhite)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MonoGlass.pitchBlack,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: MonoGlass.borderBottomRight),
                  ),
                  child: const Text('Arch: arm64-v8a / x86_64',
                      style:
                          TextStyle(fontSize: 9, color: MonoGlass.coolAshGrey)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: _compactInputDecoration(
                        hint: 'https://example.com/mod.hmod'),
                  ),
                ),
                const SizedBox(width: 8),
                TactileButton(
                  onPressed: () {
                    if (urlController.text.trim().isNotEmpty) {
                      platform.invokeMethod('installModFromUrl',
                          {'url': urlController.text.trim()});
                      urlController.clear();
                    }
                  },
                  backgroundColor: MonoGlass.pureWhite,
                  width: 90,
                  height: 40,
                  child: const Text('INSTALL',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: MonoGlass.pitchBlack)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text('Native Mods Terpasang',
                style: TextStyle(fontSize: 11, color: MonoGlass.coolAshGrey)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  _modItemTile('horizon_coords_hud.hmod', true),
                  _modItemTile('sodium_compat_wgpu.hmod', true),
                  _modItemTile('custom_sky_gles.hmod', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modItemTile(String name, bool enabled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MonoGlass.pitchBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MonoGlass.borderBottomRight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.extension_rounded,
                  size: 16,
                  color: enabled ? MonoGlass.pureWhite : MonoGlass.darkMuted),
              const SizedBox(width: 8),
              Text(name,
                  style: TextStyle(
                      fontSize: 11,
                      color: enabled
                          ? MonoGlass.pureWhite
                          : MonoGlass.coolAshGrey)),
            ],
          ),
          Switch(
            value: enabled,
            activeColor: MonoGlass.pureWhite,
            onChanged: (v) {
              platform.invokeMethod('toggleMod', {'fileName': name});
            },
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 5. ENGINE SETTINGS & CRASH INSPECTOR
  // ====================================================================
  Widget _buildSettingsInspector() {
    String logOutput = "Memuat crash.log...";

    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: LiquidGlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Crash Inspector & Logcat (HorizonRustPanic)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MonoGlass.pureWhite)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy Log',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: logOutput));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Log disalin ke clipboard')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      tooltip: 'Clear Log',
                      onPressed: () => platform.invokeMethod('clearLogs'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MonoGlass.pitchBlack,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MonoGlass.borderBottomRight),
                ),
                child: FutureBuilder<dynamic>(
                  future: platform.invokeMethod('getLogs'),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.toString() ??
                        'Tidak ada crash tercatat (Engine normal).';
                    logOutput = data;
                    return SingleChildScrollView(
                      child: Text(
                        data,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: MonoGlass.coolAshGrey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _compactInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: MonoGlass.coolAshGrey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: MonoGlass.pitchBlack,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MonoGlass.borderBottomRight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MonoGlass.borderBottomRight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MonoGlass.borderTopLeft),
      ),
    );
  }
}
