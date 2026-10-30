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
  runApp(const HorizonLauncherApp());
}

// ====================================================================
// LIQUID GLASS COMPACT DESIGN SYSTEM & TOKENS
// ====================================================================
class LiquidColors {
  static const Color pitchObsidian = Color(0xFF050507);
  static const Color charcoalMesh = Color(0xFF0E1015);
  static const Color glassSurface = Color(0x9414161C); // rgba(20, 22, 28, 0.58)
  static const Color glassSurfaceLight = Color(0x7320242C); // rgba(32, 36, 44, 0.45)
  static const Color borderTopLeft = Color(0x38FFFFFF); // rgba(255, 255, 255, 0.22)
  static const Color borderBottomRight = Color(0x0AFFFFFF); // rgba(255, 255, 255, 0.04)
  static const Color titaniumSilver = Color(0xFFE4E4E7);
  static const Color coolAshGrey = Color(0xFF9CA3AF);
  static const Color mutedMercury = Color(0xFFF4F4F6);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
}

class HorizonLauncherApp extends StatelessWidget {
  const HorizonLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizon 26.3 Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: LiquidColors.pitchObsidian,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: LiquidColors.titaniumSilver,
          secondary: LiquidColors.coolAshGrey,
          surface: LiquidColors.glassSurface,
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

// Reusable Liquid Glass Container with specular border and backdrop blur
class LiquidGlassPanel extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;

  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 14.0,
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
            LiquidColors.borderTopLeft,
            LiquidColors.borderBottomRight,
          ],
        ),
      ),
      padding: const EdgeInsets.all(1.0), // 1px Specular Border
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: LiquidColors.glassSurface,
              borderRadius: BorderRadius.circular(borderRadius - 1.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Text with tabular figures enabled for dynamic numbers
class TabularText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const TabularText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? const TextStyle(fontFamily: 'Inter')).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ====================================================================
// MAIN NAVIGATION SHELL (LANDSCAPE-FIRST COMPACT RAIL)
// ====================================================================
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  static const platform = MethodChannel('com.vasysik.horizon/launcher');
  static const progressEventChannel = EventChannel('com.vasysik.horizon/progress');

  int _selectedIndex = 0;
  bool _isPrepared = false;
  String _preparedSha256 = '';
  String _statusMessage = 'Memeriksa resource...';

  // Launcher Global Settings
  int _ramMb = 2048;
  int _workerThreads = 4;
  String _backend = 'vulkan'; // 'vulkan' or 'gles'
  int _touchScheme = 0; // 0: JoystickCrosshair, 1: JoystickTap, 2: DpadCrosshair, 3: DpadTap
  String _activeUsername = 'HorizonPlayer';

  // Downloader state
  double _downloadProgress = 0.0;
  String _downloadStage = 'Standby';
  int _downloadSpeed = 0;
  String _downloadDetail = '';
  bool _isDownloading = false;

  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _checkResources();
    _listenProgress();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _listenProgress() {
    _progressSubscription = progressEventChannel.receiveBroadcastStream().listen((event) {
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
            _downloadDetail = 'Resources 26.3 berhasil diverifikasi.';
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
              backgroundColor: LiquidColors.errorRed,
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
          _statusMessage = _isPrepared ? 'Resources 26.3 Siap' : 'Resources 26.3 Belum Diunduh';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Gagal memverifikasi: $e';
      });
    }
  }

  Future<void> _launchGame() async {
    if (!_isPrepared) {
      setState(() => _selectedIndex = 1); // Ke halaman downloader
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
          backgroundColor: LiquidColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [
              LiquidColors.charcoalMesh,
              LiquidColors.pitchObsidian,
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 1. Compact Glass Navigation Rail
              _buildNavigationRail(),

              const SizedBox(width: 8),

              // 2. Active Screen Content
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildPlayDashboard(),
                    _buildResourceCenter(),
                    _buildAccountsManager(),
                    _buildModsManager(),
                    _buildSettingsInspector(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    final navItems = [
      {'icon': Icons.play_arrow_rounded, 'label': 'Play'},
      {'icon': Icons.cloud_download_rounded, 'label': 'Downloader'},
      {'icon': Icons.person_rounded, 'label': 'Accounts'},
      {'icon': Icons.extension_rounded, 'label': 'Mods & Packs'},
      {'icon': Icons.tune_rounded, 'label': 'Settings'},
    ];

    return LiquidGlassPanel(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      borderRadius: 16,
      child: Column(
        children: [
          // Logo Horizon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LiquidColors.pitchObsidian,
              border: Border.all(color: LiquidColors.borderTopLeft, width: 1.0),
            ),
            child: const Center(
              child: Text(
                'HZ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: LiquidColors.titaniumSilver,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: LiquidColors.borderBottomRight, height: 1),
          const SizedBox(height: 8),

          // Navigation Buttons
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(navItems.length, (index) {
                final isSelected = _selectedIndex == index;
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? LiquidColors.glassSurfaceLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? LiquidColors.borderTopLeft : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          navItems[index]['icon'] as IconData,
                          size: 20,
                          color: isSelected ? LiquidColors.mutedMercury : LiquidColors.coolAshGrey,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          navItems[index]['label'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? LiquidColors.mutedMercury : LiquidColors.coolAshGrey,
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

  // ====================================================================
  // 1. PLAY & TELEMETRY DASHBOARD
  // ====================================================================
  Widget _buildPlayDashboard() {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Row(
        children: [
          // Left Column: Quick Parameters & Telemetry
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Top Status Card
                LiquidGlassPanel(
                  height: 68,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isPrepared ? LiquidColors.successGreen : LiquidColors.errorRed,
                        ),
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
                                color: LiquidColors.mutedMercury,
                              ),
                            ),
                            if (_preparedSha256.isNotEmpty)
                              TabularText(
                                'SHA: ${_preparedSha256.substring(0, 16)}...',
                                style: const TextStyle(fontSize: 10, color: LiquidColors.coolAshGrey),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: LiquidColors.pitchObsidian,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: LiquidColors.borderBottomRight),
                        ),
                        child: TabularText(
                          'MC 26.3',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Compact Config Box
                Expanded(
                  child: LiquidGlassPanel(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // RAM Allocation Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Alokasi RAM', style: TextStyle(fontSize: 12, color: LiquidColors.coolAshGrey)),
                            TabularText('$_ramMb MB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            activeTrackColor: LiquidColors.titaniumSilver,
                            inactiveTrackColor: LiquidColors.charcoalMesh,
                            thumbColor: LiquidColors.mutedMercury,
                          ),
                          child: Slider(
                            value: _ramMb.toDouble(),
                            min: 1024,
                            max: 6144,
                            divisions: 10,
                            onChanged: (v) => setState(() => _ramMb = v.toInt()),
                          ),
                        ),

                        // Thread Workers & Backend
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Worker Threads', style: TextStyle(fontSize: 11, color: LiquidColors.coolAshGrey)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<int>(
                                    value: _workerThreads,
                                    decoration: _compactInputDecoration(),
                                    items: [2, 4, 6, 8].map((t) => DropdownMenuItem(value: t, child: TabularText('$t Core'))).toList(),
                                    onChanged: (v) => setState(() => _workerThreads = v ?? 4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Graphics Backend', style: TextStyle(fontSize: 11, color: LiquidColors.coolAshGrey)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _backend,
                                    decoration: _compactInputDecoration(),
                                    items: const [
                                      DropdownMenuItem(value: 'vulkan', child: Text('Vulkan 1.1')),
                                      DropdownMenuItem(value: 'gles', child: Text('GLES 3.1')),
                                    ],
                                    onChanged: (v) => setState(() => _backend = v ?? 'vulkan'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Touch Scheme Selector
                        const Text('Skema Kontrol Sentuh', style: TextStyle(fontSize: 11, color: LiquidColors.coolAshGrey)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: _touchScheme,
                          decoration: _compactInputDecoration(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Virtual Joystick + Crosshair')),
                            DropdownMenuItem(value: 1, child: Text('Virtual Joystick + Tap World')),
                            DropdownMenuItem(value: 2, child: Text('Classic D-Pad + Crosshair')),
                            DropdownMenuItem(value: 3, child: Text('Classic D-Pad + Tap World')),
                          ],
                          onChanged: (v) => setState(() => _touchScheme = v ?? 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right Column: Big Launch Card & User Profile
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
                        children: [
                          const Text('Active Identity', style: TextStyle(fontSize: 11, color: LiquidColors.coolAshGrey)),
                          Icon(Icons.verified_user_rounded, size: 14, color: LiquidColors.titaniumSilver),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeUsername,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LiquidColors.mutedMercury),
                      ),
                      const Text('Offline UUID mode', style: TextStyle(fontSize: 10, color: LiquidColors.coolAshGrey)),
                    ],
                  ),

                  // Hero Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _launchGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPrepared ? LiquidColors.titaniumSilver : LiquidColors.charcoalMesh,
                        foregroundColor: _isPrepared ? LiquidColors.pitchObsidian : LiquidColors.coolAshGrey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isPrepared ? Icons.play_arrow_rounded : Icons.download_rounded, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            _isPrepared ? 'PLAY 26.3' : 'DOWNLOAD RESOURCES',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
                          ),
                        ],
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
  // 2. RESOURCE CENTER (26.3 DOWNLOADER & SAF IMPORT)
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
                    const Text('Minecraft 26.3 Resource Pipeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    TabularText('Tahap: $_downloadStage', style: const TextStyle(fontSize: 11, color: LiquidColors.coolAshGrey)),
                  ],
                ),
                // SAF Import Button
                OutlinedButton.icon(
                  onPressed: () => platform.invokeMethod('importResourcesZip'),
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Import Prepared Resources (.zip)', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LiquidColors.titaniumSilver,
                    side: const BorderSide(color: LiquidColors.borderTopLeft),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Glass Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 18,
                color: LiquidColors.pitchObsidian,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: _downloadProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [LiquidColors.coolAshGrey, LiquidColors.titaniumSilver],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: TabularText(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _downloadDetail.isNotEmpty ? _downloadDetail : 'Menunggu perintah unduh...',
                    style: const TextStyle(fontSize: 11, color: LiquidColors.coolAshGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_downloadSpeed > 0)
                  TabularText(
                    '${(_downloadSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LiquidColors.titaniumSilver),
                  ),
              ],
            ),

            const Spacer(),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading
                        ? () => platform.invokeMethod('pauseDownload')
                        : () => platform.invokeMethod('startDownload'),
                    icon: Icon(_isDownloading ? Icons.pause_rounded : Icons.download_rounded, size: 18),
                    label: Text(_isDownloading ? 'Pause' : 'Start / Resume Download 26.3', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiquidColors.titaniumSilver,
                      foregroundColor: LiquidColors.pitchObsidian,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _checkResources,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.charcoalMesh,
                    foregroundColor: LiquidColors.titaniumSilver,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(40, 40),
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 18),
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
            const Text('Manajemen Akun & Profil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userController,
                    decoration: _compactInputDecoration(hint: 'Masukkan Username Baru'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (userController.text.trim().isNotEmpty) {
                      setState(() {
                        _activeUsername = userController.text.trim();
                      });
                      userController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Profil aktif diubah ke $_activeUsername')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.titaniumSilver,
                    foregroundColor: LiquidColors.pitchObsidian,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(100, 40),
                  ),
                  child: const Text('Gunakan'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Profil Terdaftar', style: TextStyle(fontSize: 12, color: LiquidColors.coolAshGrey)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  _accountTile(_activeUsername, isCurrent: true),
                  _accountTile('HorizonPlayer'),
                  _accountTile('TesterOffline'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountTile(String name, {bool isCurrent = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? LiquidColors.glassSurfaceLight : LiquidColors.pitchObsidian,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isCurrent ? LiquidColors.borderTopLeft : LiquidColors.borderBottomRight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 20, color: LiquidColors.titaniumSilver),
              const SizedBox(width: 10),
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          if (isCurrent)
            const Text('ACTIVE', style: TextStyle(fontSize: 10, color: LiquidColors.successGreen, fontWeight: FontWeight.bold))
          else
            TextButton(
              onPressed: () => setState(() => _activeUsername = name),
              child: const Text('Pilih', style: TextStyle(fontSize: 11)),
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
                const Text('Mods (.hmod) & Resource Packs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: LiquidColors.pitchObsidian,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LiquidColors.borderBottomRight),
                  ),
                  child: const Text('Arch: arm64-v8a / x86_64', style: TextStyle(fontSize: 10, color: LiquidColors.coolAshGrey)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Mod Install via URL
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: _compactInputDecoration(hint: 'https://example.com/mod.hmod'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    if (urlController.text.trim().isNotEmpty) {
                      platform.invokeMethod('installModFromUrl', {'url': urlController.text.trim()});
                      urlController.clear();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Install', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.titaniumSilver,
                    foregroundColor: LiquidColors.pitchObsidian,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(100, 40),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text('Installed Native Mods', style: TextStyle(fontSize: 12, color: LiquidColors.coolAshGrey)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  _modItem('horizon_coords_hud.hmod', true),
                  _modItem('sodium_compat_wgpu.hmod', true),
                  _modItem('custom_sky_gles.hmod', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modItem(String name, bool enabled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LiquidColors.pitchObsidian,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LiquidColors.borderBottomRight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.extension_outlined, size: 16, color: enabled ? LiquidColors.titaniumSilver : LiquidColors.coolAshGrey),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(fontSize: 11, color: enabled ? LiquidColors.mutedMercury : LiquidColors.coolAshGrey)),
            ],
          ),
          Switch(
            value: enabled,
            activeColor: LiquidColors.titaniumSilver,
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
                const Text('Crash Inspector & Logcat (HorizonRustPanic)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Log',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: logOutput));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Log disalin ke clipboard')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
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
                  color: LiquidColors.pitchObsidian,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LiquidColors.borderBottomRight),
                ),
                child: FutureBuilder<dynamic>(
                  future: platform.invokeMethod('getLogs'),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.toString() ?? 'Tidak ada crash tercatat.';
                    logOutput = data;
                    return SingleChildScrollView(
                      child: Text(
                        data,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: LiquidColors.coolAshGrey,
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
      hintStyle: const TextStyle(fontSize: 11, color: LiquidColors.coolAshGrey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: LiquidColors.pitchObsidian,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LiquidColors.borderBottomRight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LiquidColors.borderBottomRight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LiquidColors.borderTopLeft),
      ),
    );
  }
}
