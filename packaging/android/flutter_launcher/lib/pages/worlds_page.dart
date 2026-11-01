import 'dart:io';

import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/pixel_icon.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// Worlds on this phone, and the screenshots taken in them with F2.
class WorldsPage extends StatefulWidget {
  const WorldsPage({super.key, required this.app});

  final Launcher app;

  @override
  State<WorldsPage> createState() => _WorldsPageState();
}

class _WorldsPageState extends State<WorldsPage> {
  String _tab = 'worlds';

  Launcher get app => widget.app;

  Future<void> _reload() => _tab == 'worlds' ? app.loadWorlds() : app.loadScreenshots();

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final shots = app.screenshots?.length;
    return RefreshIndicator(
      color: Hz.accent,
      backgroundColor: Hz.raised,
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Stagger(children: [
            PageHeader(
              title: 'Dunia',
              lead: 'Dunia singleplayer dan screenshot dari perangkat ini. Tarik ke bawah untuk memuat ulang.',
              trailing: IconBtn(icon: 'reload', label: 'Muat ulang', onTap: _reload),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 340,
                child: Segmented<String>(
                  options: [('worlds', 'Dunia'), ('shots', shots == null ? 'Screenshot' : 'Screenshot ($shots)')],
                  value: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: Hz.calm(context) ? Duration.zero : Hz.move,
              child: _tab == 'worlds'
                  ? _Worlds(key: const ValueKey('w'), app: app)
                  : _Gallery(key: const ValueKey('s'), app: app),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Worlds extends StatelessWidget {
  const _Worlds({super.key, required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final worlds = app.worlds;
    if (app.worldsError != null) {
      return StateBlock(
        icon: 'info-box',
        tone: Hz.danger,
        title: 'Folder dunia tidak terbaca',
        body: app.worldsError!,
        action: Btn(label: 'Muat ulang', icon: 'reload', onTap: app.loadWorlds),
      );
    }
    if (worlds == null) return const LoadingBlock(text: 'Membaca folder saves...');
    if (worlds.isEmpty) {
      return const StateBlock(
        icon: 'globe',
        title: 'Belum ada dunia',
        body: 'Buka game lalu pilih Singleplayer untuk membuat dunia pertama. Dunia baru muncul di sini.',
      );
    }
    final total = worlds.fold<int>(0, (s, w) => s + w.size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${worlds.length} dunia, ${formatBytes(total)} total', style: Hz.small),
        const SizedBox(height: 10),
        for (final w in worlds) ...[
          _WorldRow(app: app, world: w),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _WorldRow extends StatelessWidget {
  const _WorldRow({required this.app, required this.world});

  final Launcher app;
  final World world;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Plate(
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Hz.raised, borderRadius: Hz.r10, border: Border.all(color: Hz.line)),
            child: Center(child: PixelIcon('globe', size: 20, color: Hz.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(world.name, style: Hz.strong, overflow: TextOverflow.ellipsis),
                Text('Dimainkan ${formatAgo(world.modified)}, ${formatBytes(world.size)}', style: Hz.small),
              ],
            ),
          ),
          IconBtn(
            icon: 'trash',
            label: 'Hapus ${world.name}',
            color: Hz.danger,
            onTap: () async {
              final ok = await confirm(
                context,
                title: 'Hapus dunia "${world.name}"?',
                body: 'Semua bangunan dan inventaris di dunia ini hilang selamanya. Tidak bisa dibatalkan.',
                action: 'Hapus selamanya',
              );
              if (!ok) return;
              final err = await app.deleteWorld(world);
              if (context.mounted) toast(context, err ?? '${world.name} dihapus', error: err != null);
            },
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({super.key, required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final shots = app.screenshots;
    if (app.screenshotsError != null) {
      return StateBlock(
        icon: 'info-box',
        tone: Hz.danger,
        title: 'Folder screenshot tidak terbaca',
        body: app.screenshotsError!,
        action: Btn(label: 'Muat ulang', icon: 'reload', onTap: app.loadScreenshots),
      );
    }
    if (shots == null) return const LoadingBlock(text: 'Membaca folder screenshots...');
    if (shots.isEmpty) {
      return const StateBlock(
        icon: 'image',
        title: 'Belum ada screenshot',
        body: 'Di dalam game, ketuk tombol F2 di layar. Gambarnya muncul di sini dan di galeri HP.',
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
      final w = (c.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < shots.length; i++)
            SizedBox(
              width: w,
              child: Pressable(
                onTap: () => _open(context, i),
                semanticLabel: 'Screenshot ${formatAgo(shots[i].modified)}, buka',
                borderRadius: Hz.r10,
                child: ClipRRect(
                  borderRadius: Hz.r10,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.file(
                      File(shots[i].path),
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: Hz.raised,
                        child: Center(child: PixelIcon('image', size: 20, color: Hz.muted)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  void _open(BuildContext context, int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _Viewer(app: app, start: index),
    );
  }
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.app, required this.start});

  final Launcher app;
  final int start;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late int _i = widget.start;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final shots = widget.app.screenshots ?? const <Screenshot>[];
    if (shots.isEmpty) return const SizedBox.shrink();
    _i = _i.clamp(0, shots.length - 1);
    final s = shots[_i];
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${s.name}, ${formatAgo(s.modified)}, ${formatBytes(s.size)}',
                    style: Hz.small.copyWith(color: const Color(0xFFE6ECF4)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconBtn(
                  icon: 'trash',
                  label: 'Hapus screenshot ini',
                  color: Hz.danger,
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: 'Hapus screenshot?',
                      body: '${s.name} dihapus dari folder game. Salinan di galeri HP tetap ada.',
                      action: 'Hapus',
                    );
                    if (!ok) return;
                    final err = await widget.app.deleteScreenshot(s);
                    if (!context.mounted) return;
                    toast(context, err ?? 'Screenshot dihapus', error: err != null);
                    if ((widget.app.screenshots ?? const []).isEmpty) {
                      Navigator.pop(context);
                    } else {
                      setState(() {});
                    }
                  },
                ),
                IconBtn(
                  icon: 'close',
                  label: 'Tutup',
                  color: const Color(0xFFF4F7FB),
                  onTap: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: Row(children: [
                  IconBtn(
                    icon: 'arrow-left',
                    label: 'Sebelumnya',
                    color: const Color(0xFFF4F7FB),
                    onTap: _i > 0 ? () => setState(() => _i--) : null,
                  ),
                  Expanded(
                    child: Center(
                      child: Brackets(
                        inset: -6,
                        child: AnimatedSwitcher(
                          duration: Hz.calm(context) ? Duration.zero : Hz.quick,
                          child: InteractiveViewer(
                            key: ValueKey(s.path),
                            maxScale: 4,
                            child: Image.file(
                              File(s.path),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  Text('Gambar tidak terbaca', style: Hz.body.copyWith(color: const Color(0xFFE6ECF4))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconBtn(
                    icon: 'chevron-right',
                    label: 'Berikutnya',
                    color: const Color(0xFFF4F7FB),
                    onTap: _i < shots.length - 1 ? () => setState(() => _i++) : null,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
