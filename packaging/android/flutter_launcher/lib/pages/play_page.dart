import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/pixel_icon.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// The first page: who plays, whether the game files are in place, and the one big button.
class PlayPage extends StatelessWidget {
  const PlayPage({super.key, required this.app, required this.goTo});

  final Launcher app;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 760;
      final hero = _Hero(app: app, goTo: goTo);
      final side = _SideColumn(app: app, goTo: goTo);
      if (!wide) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [Stagger(children: [hero, side])],
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: SingleChildScrollView(child: Stagger(children: [hero]))),
            const SizedBox(width: 20),
            SizedBox(
              width: c.maxWidth * 0.34,
              child: SingleChildScrollView(child: Stagger(children: [side])),
            ),
          ],
        ),
      );
    });
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.app, required this.goTo});

  final Launcher app;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final lastPlayed = app.lastPlayed > 0 ? 'Terakhir main ${formatAgo(app.lastPlayed)}' : 'Belum pernah dimainkan di perangkat ini';
    return Glass(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('HORIZON', style: Hz.pixel.copyWith(color: Hz.accent, fontSize: 18)),
              const SizedBox(width: 10),
              const Tag('Minecraft 26.3'),
              const Spacer(),
              _StatusDot(phase: app.phase),
            ],
          ),
          const SizedBox(height: 18),
          Text('Halo, ${app.account}', style: Hz.display),
          const SizedBox(height: 6),
          Text(lastPlayed, style: Hz.body.copyWith(color: Hz.muted)),
          const SizedBox(height: 22),
          _ResourceState(app: app),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PlayButton(app: app),
              Btn(label: 'Ganti akun', icon: 'user', onTap: () => goTo(3)),
              Btn(label: 'Pengaturan', icon: 'sliders', kind: BtnKind.quiet, onTap: () => goTo(4)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.phase});

  final Phase phase;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (phase) {
      Phase.ready => (Hz.success, 'Siap main'),
      Phase.downloading => (Hz.accent, 'Mengunduh'),
      Phase.paused => (Hz.warn, 'Dijeda'),
      Phase.failed => (Hz.danger, 'Gagal'),
      Phase.missing => (Hz.warn, 'File game belum ada'),
      Phase.checking => (Hz.muted, 'Memeriksa'),
    };
    return Semantics(
      liveRegion: true,
      label: 'Status: $text',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Hz.move,
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: Hz.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// The game files: one block that changes shape with the download state.
class _ResourceState extends StatelessWidget {
  const _ResourceState({required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (app.phase) {
      Phase.ready => _line(
          key: const ValueKey('ready'),
          icon: 'check',
          color: Hz.success,
          title: 'File game lengkap',
          body: app.sha256.isNotEmpty
              ? 'Checksum ${app.sha256.substring(0, app.sha256.length.clamp(0, 12))}'
              : 'Sudah diperiksa di perangkat ini',
        ),
      Phase.checking => _line(
          key: const ValueKey('checking'),
          icon: 'clock',
          color: Hz.muted,
          title: 'Memeriksa file game',
          body: 'Sebentar saja.',
        ),
      Phase.downloading || Phase.paused => _Progress(key: const ValueKey('dl'), app: app),
      Phase.missing => Column(
          key: const ValueKey('missing'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
              icon: 'download',
              color: Hz.warn,
              title: 'File game belum terpasang',
              body: 'Unduh sekali, lalu bisa main tanpa internet. Ukurannya besar, pakai Wi-Fi.',
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              Btn(label: 'Unduh file game', icon: 'download', kind: BtnKind.primary, onTap: app.startDownload),
              Btn(label: 'Impor dari .zip', icon: 'folder', onTap: app.importResources),
            ]),
          ],
        ),
      Phase.failed => Column(
          key: const ValueKey('failed'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
              icon: 'info-box',
              color: Hz.danger,
              title: 'Unduhan berhenti',
              body: app.error ?? 'Tidak ada keterangan dari perangkat.',
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              Btn(label: 'Coba lagi', icon: 'reload', kind: BtnKind.primary, onTap: app.startDownload),
              Btn(label: 'Impor dari .zip', icon: 'folder', onTap: app.importResources),
            ]),
          ],
        ),
    };
    return AnimatedSwitcher(
      duration: Hz.calm(context) ? Duration.zero : Hz.move,
      switchInCurve: Hz.ease,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: child),
      ),
      child: child,
    );
  }

  Widget _line({Key? key, required String icon, required Color color, required String title, required String body}) {
    return Row(
      key: key,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: Hz.r8),
          child: Center(child: PixelIcon(icon, size: 20, color: color)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Hz.body.copyWith(color: Hz.ink, fontWeight: FontWeight.w500)),
              Text(body, style: Hz.small, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({super.key, required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    final paused = app.phase == Phase.paused;
    final pct = (app.progress * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                paused ? 'Dijeda' : (app.stage.isEmpty ? 'Mengunduh file game' : app.stage),
                style: Hz.body.copyWith(color: Hz.ink, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('$pct%', style: Hz.mono.copyWith(color: Hz.accent)),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Progres unduhan',
          value: '$pct persen',
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: app.progress),
              duration: Hz.calm(context) ? Duration.zero : Hz.move,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: paused ? Hz.warn : Hz.accent,
                backgroundColor: Hz.plate,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                app.detail,
                style: Hz.small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!paused && app.speed > 0) Text('${formatBytes(app.speed)}/s', style: Hz.label),
          ],
        ),
        const SizedBox(height: 12),
        paused
            ? Btn(label: 'Lanjutkan', icon: 'play', kind: BtnKind.primary, onTap: app.startDownload)
            : Btn(label: 'Jeda', icon: 'clock', onTap: app.pauseDownload),
      ],
    );
  }
}

/// The one button that matters. A faint breathing glow while it is ready, nothing otherwise.
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.app});

  final Launcher app;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.app.ready && !Hz.calm(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final err = await widget.app.launch();
    if (err != null && mounted) toast(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final enabled = app.ready && !app.launching;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Hz.r12,
          boxShadow: enabled
              ? [BoxShadow(color: Hz.face.withOpacity(0.25 + 0.2 * _c.value), blurRadius: 18 + 10 * _c.value)]
              : const [],
        ),
        child: child,
      ),
      child: Pressable(
        onTap: enabled ? _go : null,
        semanticLabel: app.ready ? 'Main sebagai ${app.account}' : 'Main, butuh file game dulu',
        child: Container(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: const BoxDecoration(color: Hz.face, borderRadius: Hz.r12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (app.launching)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                const PixelIcon('play', size: 22, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                app.launching ? 'Membuka game' : 'Main',
                style: Hz.title.copyWith(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.app, required this.goTo});

  final Launcher app;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final mods = app.addons?.where((a) => a.type == 'mod' && a.enabled).length;
    final shader = app.addons?.where((a) => a.type == 'shader' && a.enabled).map((a) => a.name).firstOrNull;
    final o = app.options;
    final worlds = app.worlds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Plate(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Saat main nanti', style: Hz.title.copyWith(fontSize: 15))),
                IconBtn(icon: 'sliders', label: 'Ubah pengaturan', onTap: () => goTo(4)),
              ]),
              const SizedBox(height: 6),
              Wrap(
                spacing: 22,
                runSpacing: 12,
                children: [
                  Fact(label: 'JARAK RENDER', value: '${o.renderDistance} chunk'),
                  Fact(label: 'LOD', value: o.lodDistance == 0 ? 'Mati' : '${o.lodDistance} chunk'),
                  Fact(label: 'FPS MAKS', value: o.maxFps >= 260 ? 'Tanpa batas' : '${o.maxFps}'),
                  Fact(label: 'GRAFIS', value: app.backend == 'opengl' ? 'OpenGL ES' : 'Vulkan'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Plate(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Add-on aktif', style: Hz.title.copyWith(fontSize: 15))),
                IconBtn(icon: 'package', label: 'Buka add-on', onTap: () => goTo(1)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 22, runSpacing: 12, children: [
                Fact(label: 'MOD', value: mods == null ? '...' : '$mods aktif'),
                Fact(label: 'SHADER', value: shader ?? 'Tidak ada'),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Plate(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Dunia terakhir', style: Hz.title.copyWith(fontSize: 15))),
                IconBtn(icon: 'globe', label: 'Lihat semua dunia', onTap: () => goTo(2)),
              ]),
              const SizedBox(height: 4),
              if (worlds == null)
                const Text('Memuat...', style: Hz.small)
              else if (worlds.isEmpty)
                const Text('Belum ada dunia. Buat dari menu di dalam game.', style: Hz.small)
              else
                for (final w in worlds.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const PixelIcon('globe', size: 16, color: Hz.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(w.name, style: Hz.body.copyWith(color: Hz.ink), overflow: TextOverflow.ellipsis),
                      ),
                      Text(formatAgo(w.modified), style: Hz.label),
                    ]),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
