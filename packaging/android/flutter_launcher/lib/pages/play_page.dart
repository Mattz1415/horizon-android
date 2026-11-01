import 'dart:io';

import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/pixel_icon.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// The first page. Left: the console, framed in corner brackets, with the player,
/// the game-file state and the one big button. Right: a tall strip with the last
/// world and the last screenshot, so the way back into the game is one tap.
class PlayPage extends StatelessWidget {
  const PlayPage({super.key, required this.app, required this.goTo});

  final Launcher app;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 760;
      final console = _Console(app: app, goTo: goTo);
      final strip = _Strip(app: app, goTo: goTo);
      if (!wide) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [Stagger(children: [console, strip])],
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SingleChildScrollView(child: Stagger(children: [console]))),
            const SizedBox(width: 14),
            SizedBox(
              width: (c.maxWidth * 0.30).clamp(240.0, 360.0),
              child: SingleChildScrollView(child: Stagger(children: [strip])),
            ),
          ],
        ),
      );
    });
  }
}

class _Console extends StatelessWidget {
  const _Console({required this.app, required this.goTo});

  final Launcher app;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final lastPlayed =
        app.lastPlayed > 0 ? 'Terakhir main ${formatAgo(app.lastPlayed)}' : 'Belum pernah dimainkan di perangkat ini';
    return Brackets(
      inset: 6,
      child: Glass(
        sheen: app.ready ? 0.15 : 0.6,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Minecraft 26.3 di Horizon', style: Hz.small),
            const SizedBox(height: 6),
            Text(app.account, style: Hz.display.copyWith(fontSize: 30), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(lastPlayed, style: Hz.body.copyWith(color: Hz.muted)),
            const SizedBox(height: 18),
            _ResourceState(app: app),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PlayButton(app: app),
                Btn(label: 'Ganti akun', icon: 'user', onTap: () => goTo(3)),
              ],
            ),
            const SizedBox(height: 18),
            _Presets(app: app, goTo: goTo),
          ],
        ),
      ),
    );
  }
}

/// Three quick setups for the next session, with what each one changes said out loud.
class _Presets extends StatelessWidget {
  const _Presets({required this.app, required this.goTo});

  final Launcher app;
  final ValueChanged<int> goTo;

  String _current() {
    final o = app.options;
    if (o.renderDistance == 6 && o.simulationDistance == 6 && o.maxFps == 60 && o.lodDistance == 0) return 'hemat';
    if (o.renderDistance == 12 && o.simulationDistance == 10 && o.maxFps == 90 && o.lodDistance == 0) return 'seimbang';
    if (o.renderDistance == 24 && o.simulationDistance == 12 && o.maxFps == 120 && o.lodDistance == 128) return 'jauh';
    return 'custom';
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current();
    final o = app.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('Setelan sesi berikutnya', style: Hz.title.copyWith(fontSize: 14))),
          Btn(label: 'Detail', icon: 'sliders', kind: BtnKind.quiet, onTap: () => goTo(4)),
        ]),
        const SizedBox(height: 6),
        Segmented<String>(
          options: [
            ('hemat', 'Hemat baterai'),
            ('seimbang', 'Seimbang'),
            ('jauh', 'Pandangan jauh'),
            if (cur == 'custom') ('custom', 'Kustom'),
          ],
          value: cur,
          onChanged: (v) {
            if (v != 'custom') app.applyPreset(v);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Render ${o.renderDistance} chunk, simulasi ${o.simulationDistance}, '
          '${o.maxFps >= 260 ? 'FPS tanpa batas' : 'FPS maks ${o.maxFps}'}, '
          '${o.lodDistance == 0 ? 'LOD mati' : 'LOD ${o.lodDistance} chunk'}, '
          '${app.backend == 'opengl' ? 'OpenGL ES' : 'Vulkan'}.',
          style: Hz.small,
        ),
      ],
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
          title: 'File game lengkap, siap main',
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              Btn(label: 'Coba lagi', icon: 'reload', kind: BtnKind.primary, onTap: app.startDownload),
              Btn(label: 'Impor dari .zip', icon: 'folder', onTap: app.importResources),
            ]),
          ],
        ),
    };
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: Hz.calm(context) ? Duration.zero : Hz.move,
        switchInCurve: Hz.ease,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: child),
        ),
        child: child,
      ),
    );
  }

  Widget _line({Key? key, required String icon, required Color color, required String title, required String body}) {
    return Row(
      key: key,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.6)), borderRadius: Hz.r10),
          child: Center(child: PixelIcon(icon, size: 20, color: color)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Hz.strong),
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
        Row(children: [
          Expanded(
            child: Text(
              paused ? 'Dijeda' : (app.stage.isEmpty ? 'Mengunduh file game' : app.stage),
              style: Hz.strong,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$pct%', style: Hz.figure.copyWith(color: Hz.accent)),
        ]),
        const SizedBox(height: 8),
        Semantics(
          label: 'Progres unduhan',
          value: '$pct persen',
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: app.progress),
            duration: Hz.calm(context) ? Duration.zero : Hz.move,
            builder: (context, v, _) => _BlockBar(value: v, color: paused ? Hz.warn : Hz.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(app.detail, style: Hz.small, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (!paused && app.speed > 0) Text('${formatBytes(app.speed)}/s', style: Hz.figure),
        ]),
        const SizedBox(height: 10),
        paused
            ? Btn(label: 'Lanjutkan', icon: 'play', kind: BtnKind.primary, onTap: app.startDownload)
            : Btn(label: 'Jeda', icon: 'clock', onTap: app.pauseDownload),
      ],
    );
  }
}

/// Progress drawn as a row of blocks that fill one by one.
class _BlockBar extends StatelessWidget {
  const _BlockBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      width: double.infinity,
      child: CustomPaint(painter: _BlockBarPainter(value, color, Hz.raised)),
    );
  }
}

class _BlockBarPainter extends CustomPainter {
  _BlockBarPainter(this.value, this.color, this.empty);

  final double value;
  final Color color;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final n = (size.width / 12).floor().clamp(8, 80);
    final w = (size.width - gap * (n - 1)) / n;
    final filled = value * n;
    for (var i = 0; i < n; i++) {
      final f = (filled - i).clamp(0.0, 1.0);
      final r = Rect.fromLTWH(i * (w + gap), 0, w, size.height);
      canvas.drawRect(r, Paint()..color = empty);
      if (f > 0) canvas.drawRect(Rect.fromLTWH(r.left, 0, w * f, size.height), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BlockBarPainter old) => old.value != value || old.color != color || old.empty != empty;
}

/// The one button that matters. A slow light sweeps across it while it is ready.
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.app});

  final Launcher app;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

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
    if (widget.app.ready && !widget.app.launching && !Hz.calm(context)) {
      if (!_c.isAnimating) _c.repeat();
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
    return Pressable(
      onTap: enabled ? _go : null,
      semanticLabel: app.ready ? 'Main sebagai ${app.account}' : 'Main, butuh file game dulu',
      borderRadius: Hz.r14,
      child: ClipRRect(
        borderRadius: Hz.r14,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            foregroundPainter: _SweepPainter(_c.value, Hz.onFace),
            child: child,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            color: Hz.face,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (app.launching)
                  SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Hz.onFace))
                else
                  PixelIcon('play', size: 22, color: Hz.onFace),
                const SizedBox(width: 12),
                Text(
                  app.launching ? 'Membuka game' : 'Main',
                  style: Hz.display.copyWith(color: Hz.onFace, fontSize: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    // The sweep crosses in the first 40% of the loop, then rests.
    final k = (t / 0.4).clamp(0.0, 1.0);
    if (k >= 1) return;
    final x = -size.width * 0.4 + k * size.width * 1.8;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withOpacity(0), color.withOpacity(0.18), color.withOpacity(0)],
        ).createShader(Rect.fromLTWH(x, 0, size.width * 0.4, size.height)),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t;
}

class _Strip extends StatelessWidget {
  const _Strip({required this.app, required this.goTo});

  final Launcher app;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final mods = app.addons?.where((a) => a.type == 'mod' && a.enabled).length;
    final shader = app.addons?.where((a) => a.type == 'shader' && a.enabled).map((a) => a.name).firstOrNull;
    final worlds = app.worlds;
    final shot = app.screenshots?.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Plate(
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Dunia terakhir', style: Hz.title.copyWith(fontSize: 14))),
                IconBtn(icon: 'chevron-right', label: 'Lihat semua dunia', onTap: () => goTo(2)),
              ]),
              if (worlds == null)
                Text('Memuat...', style: Hz.small)
              else if (worlds.isEmpty)
                Text('Belum ada dunia. Buat dari menu Singleplayer di dalam game.', style: Hz.small)
              else
                for (final w in worlds.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4, right: 10),
                    child: Row(children: [
                      PixelIcon('globe', size: 16, color: Hz.muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(w.name, style: Hz.body.copyWith(color: Hz.ink), overflow: TextOverflow.ellipsis)),
                      Text(formatAgo(w.modified), style: Hz.small),
                    ]),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (shot != null) ...[
          Semantics(
            label: 'Screenshot terbaru, ${formatAgo(shot.modified)}. Buka galeri',
            button: true,
            child: Pressable(
              onTap: () => goTo(2),
              borderRadius: Hz.r14,
              child: ClipRRect(
                borderRadius: Hz.r14,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(
                      File(shot.path),
                      fit: BoxFit.cover,
                      cacheWidth: 480,
                      errorBuilder: (_, __, ___) => ColoredBox(color: Hz.raised),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.72)],
                          ),
                        ),
                        child: Text('Screenshot ${formatAgo(shot.modified)}',
                            style: Hz.small.copyWith(color: const Color(0xFFF4F7FB))),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Plate(
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Yang ikut dimuat', style: Hz.title.copyWith(fontSize: 14))),
                IconBtn(icon: 'chevron-right', label: 'Buka mod', onTap: () => goTo(1)),
              ]),
              Wrap(spacing: 22, runSpacing: 10, children: [
                Fact(label: 'Mod aktif', value: mods == null ? '...' : '$mods'),
                Fact(label: 'Shader', value: shader ?? 'Tidak ada'),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
