import 'package:flutter/material.dart';

/// One colour set. Every text colour was checked against `page`, `surface` and `raised`
/// (WCAG AA, 4.5:1 or better); the lowest pair in all three is 5.8:1. `onFace` on `face`
/// is 5.75:1 or better.
class Palette {
  const Palette({
    required this.name,
    required this.dark,
    required this.page,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.accent,
    required this.face,
    required this.onFace,
    required this.danger,
    required this.success,
    required this.warn,
    required this.sky,
    required this.land,
    required this.sun,
  });

  final String name;
  final bool dark;
  final Color page;
  final Color surface;
  final Color raised;
  final Color line;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color accent;
  final Color face;
  final Color onFace;
  final Color danger;
  final Color success;
  final Color warn;

  /// Backdrop only: the band above the horizon, the terrain, the sun.
  final Color sky;
  final Color land;
  final Color sun;

  static Palette lerp(Palette a, Palette b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return Palette(
      name: t < 0.5 ? a.name : b.name,
      dark: t < 0.5 ? a.dark : b.dark,
      page: c(a.page, b.page),
      surface: c(a.surface, b.surface),
      raised: c(a.raised, b.raised),
      line: c(a.line, b.line),
      ink: c(a.ink, b.ink),
      inkSoft: c(a.inkSoft, b.inkSoft),
      muted: c(a.muted, b.muted),
      accent: c(a.accent, b.accent),
      face: c(a.face, b.face),
      onFace: c(a.onFace, b.onFace),
      danger: c(a.danger, b.danger),
      success: c(a.success, b.success),
      warn: c(a.warn, b.warn),
      sky: c(a.sky, b.sky),
      land: c(a.land, b.land),
      sun: c(a.sun, b.sun),
    );
  }
}

const malam = Palette(
  name: 'malam',
  dark: true,
  page: Color(0xFF05070B),
  surface: Color(0xFF0B0F17),
  raised: Color(0xFF111723),
  line: Color(0xFF223047),
  ink: Color(0xFFF4F7FB),
  inkSoft: Color(0xFFC9D2DF),
  muted: Color(0xFF93A0B6),
  accent: Color(0xFF5AA2FF),
  face: Color(0xFF1A5FD6),
  onFace: Color(0xFFFFFFFF),
  danger: Color(0xFFFF7A6B),
  success: Color(0xFF3DD68C),
  warn: Color(0xFFF5B94A),
  sky: Color(0xFF0B1A33),
  land: Color(0xFF0A0E15),
  sun: Color(0xFF5AA2FF),
);

const siang = Palette(
  name: 'siang',
  dark: false,
  page: Color(0xFFF7F9FC),
  surface: Color(0xFFFFFFFF),
  raised: Color(0xFFEEF2F8),
  line: Color(0xFFD3DBE7),
  ink: Color(0xFF0B1220),
  inkSoft: Color(0xFF313D4F),
  muted: Color(0xFF4D5B74),
  accent: Color(0xFF0F52BF),
  face: Color(0xFF1A5FD6),
  onFace: Color(0xFFFFFFFF),
  danger: Color(0xFFB32718),
  success: Color(0xFF0D6B43),
  warn: Color(0xFF7A5200),
  sky: Color(0xFFDCE8FA),
  land: Color(0xFFE6ECF4),
  sun: Color(0xFF1A5FD6),
);

const samudra = Palette(
  name: 'samudra',
  dark: true,
  page: Color(0xFF05101F),
  surface: Color(0xFF0A1A2E),
  raised: Color(0xFF102540),
  line: Color(0xFF1F3D63),
  ink: Color(0xFFEEF5FF),
  inkSoft: Color(0xFFC3D4EA),
  muted: Color(0xFF8CA6C4),
  accent: Color(0xFF68B3FF),
  face: Color(0xFF175FBF),
  onFace: Color(0xFFFFFFFF),
  danger: Color(0xFFFF8A76),
  success: Color(0xFF45D894),
  warn: Color(0xFFF7BF57),
  sky: Color(0xFF0E2D52),
  land: Color(0xFF071526),
  sun: Color(0xFFE8F2FF),
);

const palettes = {'malam': malam, 'siang': siang, 'samudra': samudra};

/// Design tokens. Colours read the active palette so the whole tree can change theme
/// (and cross-fade between two) by rebuilding from the root.
class Hz {
  static Palette p = malam;

  /// Rebuild the caller when the palette changes, even when it was built as a const widget.
  static void watch(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HzScope>();

  static Color get page => p.page;
  static Color get surface => p.surface;
  static Color get raised => p.raised;
  static Color get line => p.line;
  static Color get ink => p.ink;
  static Color get inkSoft => p.inkSoft;
  static Color get muted => p.muted;
  static Color get accent => p.accent;
  static Color get face => p.face;
  static Color get onFace => p.onFace;
  static Color get danger => p.danger;
  static Color get success => p.success;
  static Color get warn => p.warn;

  static const quick = Duration(milliseconds: 150);
  static const move = Duration(milliseconds: 260);
  static const enter = Duration(milliseconds: 520);
  static const stagger = Duration(milliseconds: 45);
  static const ease = Cubic(0.2, 0.0, 0.0, 1.0);

  static const r6 = BorderRadius.all(Radius.circular(6));
  static const r10 = BorderRadius.all(Radius.circular(10));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r20 = BorderRadius.all(Radius.circular(20));

  // Scale: 12, 14, 16 (x1.15), 19, 22, 26. Two families plus the mono outlier for figures.
  static TextStyle get display => TextStyle(
        fontFamily: 'PixelifySans',
        fontWeight: FontWeight.w600,
        fontSize: 26,
        height: 1.1,
        color: ink,
      );
  static TextStyle get title => TextStyle(
        fontFamily: 'Geist',
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.3,
        letterSpacing: -0.1,
        color: ink,
      );
  static TextStyle get body => TextStyle(
        fontFamily: 'Geist',
        fontSize: 14,
        height: 1.45,
        color: inkSoft,
      );
  static TextStyle get strong => body.copyWith(color: ink, fontWeight: FontWeight.w500);
  static TextStyle get small => TextStyle(
        fontFamily: 'Geist',
        fontSize: 12,
        height: 1.4,
        color: muted,
      );
  static TextStyle get figure => TextStyle(
        fontFamily: 'GeistMono',
        fontSize: 12,
        height: 1.4,
        color: inkSoft,
      );
  static TextStyle get mono => figure;

  static bool calm(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

String formatBytes(num bytes) {
  if (bytes < 1024) return '${bytes.toInt()} B';
  const units = ['KB', 'MB', 'GB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

String formatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0).replaceAll('.', ',')} rb';
  return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} jt';
}

String formatAgo(int epochMs) {
  if (epochMs <= 0) return 'belum pernah';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(epochMs));
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inHours < 1) return '${d.inMinutes} menit lalu';
  if (d.inDays < 1) return '${d.inHours} jam lalu';
  if (d.inDays < 30) return '${d.inDays} hari lalu';
  final t = DateTime.fromMillisecondsSinceEpoch(epochMs);
  return '${t.day}/${t.month}/${t.year}';
}

class HzScope extends InheritedWidget {
  const HzScope({super.key, required this.palette, required super.child});

  final Palette palette;

  @override
  bool updateShouldNotify(HzScope oldWidget) => oldWidget.palette != palette;
}
