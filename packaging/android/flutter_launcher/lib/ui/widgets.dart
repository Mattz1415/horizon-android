import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pixel_icon.dart';
import 'tokens.dart';

/// The slow backdrop behind every page: two soft blobs of the brand violet that drift.
/// Glass needs something behind it to bend; a flat page would make the blur invisible.
/// Static when the system asks for reduced motion.
class LiquidBackdrop extends StatefulWidget {
  const LiquidBackdrop({super.key, required this.child, this.energy = 0});

  final Widget child;

  /// 0 when idle, up to 1 while something is downloading: the blobs move a little faster.
  final double energy;

  @override
  State<LiquidBackdrop> createState() => _LiquidBackdropState();
}

class _LiquidBackdropState extends State<LiquidBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 28));

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
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Hz.page),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _BlobPainter(_c.value, widget.energy),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t, this.energy);

  final double t;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final speed = 1 + energy;
    void blob(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
    }

    blob(
      Offset(size.width * (0.78 + 0.08 * math.cos(a * speed)),
          size.height * (0.25 + 0.12 * math.sin(a * speed))),
      size.height * 0.42,
      Hz.face.withOpacity(0.22 + 0.08 * energy),
    );
    blob(
      Offset(size.width * (0.30 + 0.10 * math.sin(a)), size.height * (0.92 + 0.06 * math.cos(a))),
      size.height * 0.36,
      Hz.accent.withOpacity(0.10),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.energy != energy;
}

/// Frosted glass. Used on two surfaces only: the navigation rail and the play panel.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = Hz.r16,
    this.padding = EdgeInsets.zero,
    this.tint = 0.55,
  });

  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;
  final double tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Hz.surface.withOpacity(tint),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.0)],
              stops: const [0, 0.5],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A solid card: most content sits on these, not on glass.
class Plate extends StatelessWidget {
  const Plate({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Hz.plateSoft,
        borderRadius: Hz.r12,
        border: Border.all(color: Hz.line.withOpacity(0.6)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Children fade and rise in one after another, 40 ms apart, when a page opens.
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
              final v = Hz.ease.transform(
                ((_c.value - start) / (end - start)).clamp(0.0, 1.0),
              );
              return Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Press feedback shared by every tappable thing: a short scale down, no ripple splash.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.borderRadius = Hz.r12,
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
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (Hz.face, Colors.white, Colors.transparent),
      BtnKind.secondary => (Hz.plate, Hz.ink, Hz.line),
      BtnKind.quiet => (Colors.transparent, Hz.inkSoft, Colors.transparent),
      BtnKind.danger => (Colors.transparent, Hz.danger, Hz.danger.withOpacity(0.5)),
    };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
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
      borderRadius: Hz.r8,
      child: AnimatedContainer(
        duration: Hz.quick,
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Hz.r8,
          border: Border.all(color: border),
        ),
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
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: Hz.r8,
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Hz.title)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Header of a page: big title, one plain sentence under it.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.lead, this.trailing});

  final String title;
  final String lead;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Hz.display),
              const SizedBox(height: 6),
              Text(lead, style: Hz.body.copyWith(color: Hz.muted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
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
    this.tone = Hz.muted,
  });

  final String icon;
  final String title;
  final String body;
  final Widget? action;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Plate(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Row(
        children: [
          PixelIcon(icon, size: 28, color: tone),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Hz.title.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(body, style: Hz.small),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.text = 'Memuat...'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Plate(
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Hz.accent),
          ),
          const SizedBox(width: 14),
          Text(text, style: Hz.small),
        ],
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
    final shown = format?.call(value) ?? value.round().toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Hz.body.copyWith(color: Hz.ink))),
            Text(shown, style: Hz.mono.copyWith(color: Hz.accent)),
          ],
        ),
        if (hint != null) Text(hint!, style: Hz.small),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: Hz.accent,
            inactiveTrackColor: Hz.plate,
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

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.hint});

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Pressable(
        onTap: () => onChanged(!value),
        borderRadius: Hz.r8,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: Hz.body.copyWith(color: Hz.ink)),
                    if (hint != null) Text(hint!, style: Hz.small),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: Hz.face,
                inactiveThumbColor: Hz.muted,
                inactiveTrackColor: Hz.plate,
                trackOutlineColor: WidgetStateProperty.all(Hz.line),
              ),
            ],
          ),
        ),
      ),
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
    final index = math.max(0, options.indexWhere((o) => o.$1 == value));
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / options.length;
      return Container(
        height: 44,
        decoration: BoxDecoration(color: Hz.surface, borderRadius: Hz.r8, border: Border.all(color: Hz.line)),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Hz.calm(context) ? Duration.zero : Hz.move,
              curve: Hz.ease,
              left: w * index + 3,
              top: 3,
              bottom: 3,
              width: w - 6,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Hz.face, borderRadius: BorderRadius.all(Radius.circular(6))),
              ),
            ),
            Row(
              children: [
                for (final (v, label) in options)
                  Expanded(
                    child: Semantics(
                      selected: v == value,
                      button: true,
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
                              color: v == value ? Colors.white : Hz.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                            child: Text(label, overflow: TextOverflow.ellipsis),
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

/// A short labelled fact, used in the device and storage rows.
class Fact extends StatelessWidget {
  const Fact({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Hz.label),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Hz.body.copyWith(color: color ?? Hz.ink, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Hz.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Text(text, style: Hz.label.copyWith(color: color, fontSize: 11)),
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
    backgroundColor: error ? const Color(0xFF3A1E1F) : Hz.plate,
    shape: RoundedRectangleBorder(
      borderRadius: Hz.r12,
      side: BorderSide(color: error ? Hz.danger.withOpacity(0.6) : Hz.line),
    ),
    duration: Duration(seconds: error ? 6 : 3),
    content: Row(
      children: [
        PixelIcon(error ? 'info-box' : 'check', size: 18, color: error ? Hz.danger : Hz.success),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: Hz.body.copyWith(color: Hz.ink))),
      ],
    ),
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
      backgroundColor: Hz.plateSoft,
      shape: const RoundedRectangleBorder(borderRadius: Hz.r16, side: BorderSide(color: Hz.line)),
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
