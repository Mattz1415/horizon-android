import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pixel_icon.dart';
import 'tokens.dart';

/// The page behind everything: a sky, a pixel ridge, and a sun on the horizon line.
/// The sun rises with the game files: under the line while they are missing, climbing
/// with the download, up in the sky once the game can start. With reduced motion the
/// ridge and stars hold still and the sun jumps to its place.
class HorizonBackdrop extends StatefulWidget {
  const HorizonBackdrop({super.key, required this.child, required this.rise, this.busy = false});

  final Widget child;

  /// 0 = sun under the horizon, 1 = fully risen.
  final double rise;
  final bool busy;

  @override
  State<HorizonBackdrop> createState() => _HorizonBackdropState();
}

class _HorizonBackdropState extends State<HorizonBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Hz.calm(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final calm = Hz.calm(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Hz.page),
        RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.rise.clamp(0.0, 1.0)),
            duration: calm ? Duration.zero : const Duration(milliseconds: 900),
            curve: Hz.ease,
            builder: (context, rise, _) => AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _HorizonPainter(Hz.p, _c.value, rise, widget.busy),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _HorizonPainter extends CustomPainter {
  _HorizonPainter(this.p, this.t, this.rise, this.busy);

  final Palette p;
  final double t;
  final double rise;
  final bool busy;

  static const _block = 8.0;

  // Fixed pseudo-random so the ridge and the stars look the same on every start.
  static double _h(int i) {
    final x = math.sin(i * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.80;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizon),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.page, p.sky],
        ).createShader(Rect.fromLTWH(0, 0, size.width, horizon)),
    );

    if (p.dark) {
      final star = Paint()..isAntiAlias = false;
      for (var i = 0; i < 46; i++) {
        final x = _h(i) * size.width;
        final y = _h(i + 101) * horizon * 0.75;
        final tw = 0.35 + 0.45 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 3 + i));
        star.color = p.ink.withOpacity(tw * 0.55);
        final s = i % 7 == 0 ? 3.0 : 2.0;
        canvas.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), s, s), star);
      }
    }

    // The sun: a stepped pixel disc, with a soft halo, clipped by the horizon.
    final sunR = math.min(size.height * 0.13, 64.0);
    final sunX = size.width * 0.74;
    final sunY = horizon + sunR * 0.9 - rise * (horizon * 0.42 + sunR);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, horizon));
    canvas.drawCircle(
      Offset(sunX, sunY),
      sunR * 2.4,
      Paint()
        ..color = p.sun.withOpacity(p.dark ? 0.10 : 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sunR),
    );
    final sun = Paint()
      ..color = p.sun.withOpacity(p.dark ? 0.40 : 0.14)
      ..isAntiAlias = false;
    for (var dy = -sunR; dy < sunR; dy += _block / 2) {
      final half = math.sqrt(math.max(0, sunR * sunR - (dy + _block / 4) * (dy + _block / 4)));
      final w = (half / (_block / 2)).floorToDouble() * (_block / 2);
      canvas.drawRect(Rect.fromLTWH(sunX - w, sunY + dy, w * 2, _block / 2), sun);
    }
    canvas.restore();

    // Two ridges of blocks; the far one drifts slowly, the near one a little faster.
    void ridge(double base, double amp, double speed, Color color, int seed) {
      final paint = Paint()
        ..color = color
        ..isAntiAlias = false;
      final shift = (t * speed * size.width) % (_block * 64);
      final cols = (size.width / _block).ceil() + 66;
      final path = Path()..moveTo(-shift, size.height);
      for (var i = 0; i < cols; i++) {
        final k = i % 64;
        final n = (_h(seed + k) * 0.6 + _h(seed + k ~/ 4 + 300) * 0.4);
        final h = (n * amp / _block).round() * _block;
        final x = i * _block - shift;
        path.lineTo(x, base - h);
        path.lineTo(x + _block, base - h);
      }
      path.lineTo(size.width + _block, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }

    ridge(horizon + 2, size.height * 0.10, 0.02, Color.lerp(p.sky, p.land, 0.55)!, 7);
    ridge(horizon + size.height * 0.07, size.height * 0.07, 0.05, p.land, 41);
    canvas.drawRect(
      Rect.fromLTWH(0, horizon + size.height * 0.07, size.width, size.height),
      Paint()..color = p.land,
    );

    // The horizon line with survey ticks, the one ornament that repeats in the UI.
    final line = Paint()..color = p.accent.withOpacity(busy ? 0.55 : 0.30);
    canvas.drawRect(Rect.fromLTWH(0, horizon, size.width, 1), line);
    for (var x = 0.0; x < size.width; x += 48) {
      canvas.drawRect(Rect.fromLTWH(x, horizon - 3, 1, x % 192 == 0 ? 7 : 4), line);
    }
  }

  @override
  bool shouldRepaint(_HorizonPainter old) =>
      old.t != t || old.rise != rise || old.busy != busy || old.p != p;
}

/// Liquid glass, kept to two surfaces: the top bar and the play panel. A blur of what is
/// behind, a thin rim that is brighter along the top edge, and a sheen that leans with
/// the [sheen] value (0..1) so the panel looks lit from where the sun is.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = Hz.r20,
    this.padding = EdgeInsets.zero,
    this.sheen = 0.3,
  });

  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;
  final double sheen;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final p = Hz.p;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: CustomPaint(
          foregroundPainter: _RimPainter(radius, p.dark ? Colors.white : p.face, sheen),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: p.surface.withOpacity(p.dark ? 0.58 : 0.72),
              gradient: LinearGradient(
                begin: Alignment(-1 + sheen * 2, -1),
                end: Alignment(1 - sheen, 1),
                colors: [
                  (p.dark ? Colors.white : p.face).withOpacity(p.dark ? 0.08 : 0.05),
                  Colors.transparent,
                ],
                stops: const [0, 0.55],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  _RimPainter(this.radius, this.color, this.sheen);

  final BorderRadius radius;
  final Color color;
  final double sheen;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = radius.toRRect(rect).deflate(0.5);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.28), color.withOpacity(0.06)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.color != color || old.sheen != sheen;
}

/// Solid surface for most content: lists, forms, panels.
class Plate extends StatelessWidget {
  const Plate({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.accent = false});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  /// Selected or active: the rim turns blue. A signal, never a fill.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return AnimatedContainer(
      duration: Hz.calm(context) ? Duration.zero : Hz.move,
      curve: Hz.ease,
      decoration: BoxDecoration(
        color: (color ?? Hz.surface).withOpacity(Hz.p.dark ? 0.86 : 0.94),
        borderRadius: Hz.r14,
        border: Border.all(color: accent ? Hz.accent.withOpacity(0.7) : Hz.line),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Four short corner marks, like a camera viewfinder; the decoration that frames the
/// main panel and the selected screenshot.
class Brackets extends StatelessWidget {
  const Brackets({super.key, required this.child, this.color, this.inset = 0});

  final Widget child;
  final Color? color;
  final double inset;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return CustomPaint(foregroundPainter: _BracketPainter(color ?? Hz.accent, inset), child: child);
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color, this.inset);

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    const l = 14.0, w = 2.0;
    final a = inset, b = size.width - inset, c = size.height - inset;
    for (final (x, y, dx, dy) in [(a, a, 1.0, 1.0), (b, a, -1.0, 1.0), (a, c, 1.0, -1.0), (b, c, -1.0, -1.0)]) {
      canvas.drawRect(Rect.fromLTWH(dx > 0 ? x : x - l, dy > 0 ? y : y - w, l, w), paint);
      canvas.drawRect(Rect.fromLTWH(dx > 0 ? x : x - w, dy > 0 ? y : y - l, w, l), paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color || old.inset != inset;
}

/// A ruler line with ticks, used under page heads instead of a plain divider.
class Ruler extends StatelessWidget {
  const Ruler({super.key, this.progress});

  /// When set, the ruler fills to this point in blue.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return SizedBox(
      height: 8,
      width: double.infinity,
      child: CustomPaint(painter: _RulerPainter(Hz.line, Hz.accent, progress)),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.line, this.accent, this.progress);

  final Color line;
  final Color accent;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = line;
    final y = size.height - 1;
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    var i = 0;
    for (var x = 0.0; x <= size.width; x += 12, i++) {
      final h = i % 8 == 0 ? 7.0 : (i % 4 == 0 ? 5.0 : 3.0);
      canvas.drawRect(Rect.fromLTWH(x, y - h + 1, 1, h), p);
    }
    if (progress != null) {
      canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width * progress!.clamp(0, 1), 2), Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.progress != progress || old.line != line || old.accent != accent;
}

/// Children fade and rise in one after another when a page opens.
class Stagger extends StatefulWidget {
  const Stagger({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  State<Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Hz.calm(context)) {
      _c.value = 1;
      return;
    }
    if (_c.value == 0 && !_c.isAnimating) {
      final n = widget.children.length;
      _c.duration = Hz.enter + Hz.stagger * math.max(0, math.min(n, 10) - 1);
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final n = widget.children.length;
    final total = _c.duration?.inMilliseconds ?? Hz.enter.inMilliseconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) SizedBox(height: widget.spacing),
          AnimatedBuilder(
            animation: _c,
            child: widget.children[i],
            builder: (context, child) {
              final start = (Hz.stagger.inMilliseconds * math.min(i, 9)) / total;
              final end = math.min(1.0, start + Hz.enter.inMilliseconds / total);
              final v = Hz.ease.transform(((_c.value - start) / (end - start)).clamp(0.0, 1.0));
              return Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Press feedback shared by every tappable thing: a short scale down, a visible focus ring.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.borderRadius = Hz.r10,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final BorderRadius borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                }
              : null,
          child: AnimatedScale(
            scale: _down && !Hz.calm(context) ? 0.97 : 1,
            duration: Hz.quick,
            curve: Hz.ease,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: _focused ? Border.all(color: Hz.accent, width: 2) : null,
              ),
              child: Opacity(opacity: enabled ? 1 : 0.45, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

enum BtnKind { primary, secondary, quiet, danger }

class Btn extends StatelessWidget {
  const Btn({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = BtnKind.secondary,
    this.busy = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final BtnKind kind;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (Hz.face, Hz.onFace, Colors.transparent),
      BtnKind.secondary => (Hz.raised, Hz.ink, Hz.line),
      BtnKind.quiet => (Colors.transparent, Hz.inkSoft, Colors.transparent),
      BtnKind.danger => (Colors.transparent, Hz.danger, Hz.danger.withOpacity(0.5)),
    };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          PixelIcon(icon!, size: 16, color: fg),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Hz.body.copyWith(color: fg, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
    return Pressable(
      onTap: busy ? null : onTap,
      semanticLabel: label,
      borderRadius: Hz.r10,
      child: AnimatedContainer(
        duration: Hz.quick,
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: bg, borderRadius: Hz.r10, border: Border.all(color: border)),
        child: content,
      ),
    );
  }
}

/// Square icon-only button; always carries a tooltip and a semantic label.
class IconBtn extends StatelessWidget {
  const IconBtn({super.key, required this.icon, required this.label, required this.onTap, this.color});

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: Hz.r10,
        child: SizedBox.square(
          dimension: 44,
          child: Center(child: PixelIcon(icon, size: 18, color: color ?? Hz.inkSoft)),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Expanded(child: Text(text, style: Hz.title)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Head of a page: the title in the pixel face, one plain sentence, a ruler under it.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.lead, this.trailing});

  final String title;
  final String lead;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Hz.display),
                  const SizedBox(height: 4),
                  Text(lead, style: Hz.body.copyWith(color: Hz.muted)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        const Ruler(),
      ],
    );
  }
}

/// What a list shows when it has nothing, failed, or is still loading.
class StateBlock extends StatelessWidget {
  const StateBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.tone,
  });

  final String icon;
  final String title;
  final String body;
  final Widget? action;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Plate(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          PixelIcon(icon, size: 28, color: tone ?? Hz.muted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Hz.title.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text(body, style: Hz.small),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), Flexible(flex: 0, child: action!)],
        ],
      ),
    );
  }
}

/// Loading: a row of blocks that light up one by one, a small nod to a chunk loading.
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.text = 'Memuat...'});

  final String text;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Plate(
      child: Row(children: [
        const BlockLoader(),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: Hz.small)),
      ]),
    );
  }
}

class BlockLoader extends StatefulWidget {
  const BlockLoader({super.key});

  @override
  State<BlockLoader> createState() => _BlockLoaderState();
}

class _BlockLoaderState extends State<BlockLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Hz.calm(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Semantics(
      label: 'Memuat',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 3),
                color: Hz.accent.withOpacity(((_c.value * 4).floor() % 4) == i ? 1 : 0.25),
              ),
          ],
        ),
      ),
    );
  }
}

/// A slider row with its live value shown in mono on the right.
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
    this.hint,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final shown = format?.call(value) ?? value.round().toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: Hz.body.copyWith(color: Hz.ink))),
          Text(shown, style: Hz.figure.copyWith(color: Hz.accent)),
        ]),
        if (hint != null) Text(hint!, style: Hz.small),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: Hz.accent,
            inactiveTrackColor: Hz.raised,
            thumbColor: Hz.ink,
            overlayColor: Hz.accent.withOpacity(0.16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: shown,
            semanticFormatterCallback: (_) => '$label $shown',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class HzSwitch extends StatelessWidget {
  const HzSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Hz.onFace,
      activeTrackColor: Hz.face,
      inactiveThumbColor: Hz.muted,
      inactiveTrackColor: Hz.raised,
      trackOutlineColor: WidgetStateProperty.all(Hz.line),
    );
  }
}

/// Segmented choice with a sliding highlight under the picked option.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final index = math.max(0, options.indexWhere((o) => o.$1 == value));
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / options.length;
      return Container(
        height: 44,
        decoration: BoxDecoration(color: Hz.surface, borderRadius: Hz.r10, border: Border.all(color: Hz.line)),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Hz.calm(context) ? Duration.zero : Hz.move,
              curve: Hz.ease,
              left: w * index + 3,
              top: 3,
              bottom: 3,
              width: w - 6,
              child: DecoratedBox(decoration: BoxDecoration(color: Hz.face, borderRadius: Hz.r6)),
            ),
            Row(
              children: [
                for (final (v, label) in options)
                  Expanded(
                    child: Semantics(
                      selected: v == value,
                      button: true,
                      label: label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(v);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Hz.quick,
                            style: Hz.small.copyWith(
                              color: v == value ? Hz.onFace : Hz.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// A short labelled fact: sentence-case label above, the value under it.
class Fact extends StatelessWidget {
  const Fact({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Hz.small),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Hz.strong.copyWith(color: color ?? Hz.ink),
        ),
      ],
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final c = color ?? Hz.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: Hz.r6,
        border: Border.all(color: c.withOpacity(0.45)),
      ),
      child: Text(text, style: Hz.small.copyWith(color: c, fontSize: 11.5), maxLines: 1),
    );
  }
}

/// Toast from the bottom; errors stay longer and carry the reason the platform gave.
void toast(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    width: 460,
    backgroundColor: Hz.raised,
    shape: RoundedRectangleBorder(
      borderRadius: Hz.r14,
      side: BorderSide(color: error ? Hz.danger.withOpacity(0.7) : Hz.line),
    ),
    duration: Duration(seconds: error ? 6 : 3),
    content: Row(children: [
      PixelIcon(error ? 'info-box' : 'check', size: 18, color: error ? Hz.danger : Hz.success),
      const SizedBox(width: 12),
      Expanded(child: Text(message, style: Hz.body.copyWith(color: Hz.ink))),
    ]),
  ));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => Dialog(
      backgroundColor: Hz.surface,
      shape: RoundedRectangleBorder(borderRadius: Hz.r20, side: BorderSide(color: Hz.line)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Hz.title),
              const SizedBox(height: 8),
              Text(body, style: Hz.body),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Btn(label: 'Batal', kind: BtnKind.quiet, onTap: () => Navigator.pop(context, false)),
                  const SizedBox(width: 8),
                  Btn(
                    label: action,
                    kind: danger ? BtnKind.danger : BtnKind.primary,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}
