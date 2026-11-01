import 'package:flutter/material.dart';

/// Colours from crates/horizon-theme (dark palette). Contrast of every text colour
/// against `page` and `plate` was checked: the lowest pair is accent on plate at 4.96:1.
class Hz {
  static const page = Color(0xFF0F0D17);
  static const surface = Color(0xFF1A1727);
  static const plateSoft = Color(0xFF221E34);
  static const plate = Color(0xFF2B2641);
  static const line = Color(0xFF3A3354);
  static const ink = Color(0xFFECEDF3);
  static const inkSoft = Color(0xFFC5C7D1);
  static const muted = Color(0xFFA29CB8);
  static const accent = Color(0xFF9A86FF);
  static const face = Color(0xFF5B3FD6);
  static const danger = Color(0xFFF07A68);
  static const success = Color(0xFF45C27A);
  static const warn = Color(0xFFF0B84F);

  static const quick = Duration(milliseconds: 150);
  static const move = Duration(milliseconds: 240);
  static const enter = Duration(milliseconds: 600);
  static const stagger = Duration(milliseconds: 40);
  static const ease = Cubic(0.2, 0.0, 0.0, 1.0);

  static const r8 = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));

  static const display = TextStyle(
    fontFamily: 'Geist',
    fontWeight: FontWeight.w500,
    fontSize: 30,
    height: 1.1,
    letterSpacing: -0.6,
    color: ink,
  );
  static const title = TextStyle(
    fontFamily: 'Geist',
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 1.25,
    letterSpacing: -0.2,
    color: ink,
  );
  static const body = TextStyle(
    fontFamily: 'Geist',
    fontSize: 14,
    height: 1.45,
    color: inkSoft,
  );
  static const small = TextStyle(
    fontFamily: 'Geist',
    fontSize: 12.5,
    height: 1.4,
    color: muted,
  );
  static const label = TextStyle(
    fontFamily: 'GeistMono',
    fontSize: 11.5,
    letterSpacing: 0.4,
    color: muted,
  );
  static const mono = TextStyle(
    fontFamily: 'GeistMono',
    fontSize: 12,
    height: 1.5,
    color: inkSoft,
  );
  static const pixel = TextStyle(
    fontFamily: 'PixelifySans',
    fontWeight: FontWeight.w600,
    fontSize: 22,
    letterSpacing: 0.5,
    color: ink,
  );

  static bool calm(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
