import 'package:flutter/widgets.dart';

import 'icon_paths.dart';

/// Pixelarticons drawn straight from their SVG path data. The set only uses
/// M/m, H/h, V/v and Z/z, so a tiny parser is enough and no SVG package is needed.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.name, {super.key, this.size = 20, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFFECEDF3);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PixelPainter(_shapes(name), c)),
    );
  }

  static final Map<String, List<Path>> _cache = {};

  static List<Path> _shapes(String name) =>
      _cache.putIfAbsent(name, () => _parse(pixelIconPaths[name] ?? ''));

  static List<Path> _parse(String d) {
    final tokens = RegExp(r'[MmHhVvZz]|-?\d*\.?\d+').allMatches(d).map((m) => m[0]!).toList();
    final shapes = <Path>[];
    Path? path;
    double x = 0, y = 0, sx = 0, sy = 0;
    String cmd = 'M';
    var i = 0;
    double next() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      final t = tokens[i];
      if (RegExp(r'[A-Za-z]').hasMatch(t)) {
        cmd = t;
        i++;
        if (cmd == 'Z' || cmd == 'z') {
          path?.close();
          x = sx;
          y = sy;
        }
        continue;
      }
      switch (cmd) {
        case 'M':
        case 'm':
          final nx = next(), ny = next();
          x = cmd == 'm' ? x + nx : nx;
          y = cmd == 'm' ? y + ny : ny;
          sx = x;
          sy = y;
          path = Path()..moveTo(x, y);
          shapes.add(path);
          // Extra pairs after a move are line-tos, as in SVG; this set never has them.
          cmd = cmd == 'm' ? 'l' : 'L';
        case 'H':
          x = next();
          path?.lineTo(x, y);
        case 'h':
          x += next();
          path?.lineTo(x, y);
        case 'V':
          y = next();
          path?.lineTo(x, y);
        case 'v':
          y += next();
          path?.lineTo(x, y);
        default:
          i++;
      }
    }
    return shapes;
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.shapes, this.color);

  final List<Path> shapes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.scale(s);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    // Each sub-rectangle is filled on its own so winding direction never punches holes.
    for (final p in shapes) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.color != color || old.shapes != shapes;
}
