import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Glow effects are one of two fully independent cosmetic layers (the
/// other is frame shapes, see avatar_frame_shapes.dart). All tinted to
/// each member's own color -- no fixed palettes. Kept procedural for now;
/// [assetPath] exists so a texture-based effect can be dropped in later
/// without changing the calling code.
class GlowEffectSpec {
  final String label;
  final String shape;
  final String? assetPath;
  const GlowEffectSpec({required this.label, required this.shape, this.assetPath});
}

const Map<String, GlowEffectSpec> kGlowEffectCatalog = {
  'none': GlowEffectSpec(label: 'None', shape: 'none'),
  'glow_halo': GlowEffectSpec(label: 'Halo', shape: 'ring'),
  'wispy_swirl': GlowEffectSpec(label: 'Wisp', shape: 'wispy'),
  'star_halo': GlowEffectSpec(label: 'Star', shape: 'star'),
  'constellation': GlowEffectSpec(label: 'Constellation', shape: 'constellation'),
  'nebula': GlowEffectSpec(label: 'Nebula', shape: 'nebula'),
};

/// Builds the widget for a glow effect -- an asset-based tinted texture if
/// one's been set for this id, otherwise the procedural painter.
Widget buildGlowEffect({
  required String glowEffectId,
  required Color color,
  required double ringOuterRadius,
}) {
  final spec = kGlowEffectCatalog[glowEffectId];
  if (spec == null || spec.shape == 'none') return const SizedBox.shrink();

  if (spec.assetPath != null) {
    final size = ringOuterRadius * 2 * 2.3;
    return OverflowBox(
      maxWidth: size,
      maxHeight: size,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          spec.assetPath!,
          color: color,
          colorBlendMode: BlendMode.srcIn,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  final outerDiameter = ringOuterRadius * 2;
  return SizedBox(
    width: outerDiameter,
    height: outerDiameter,
    child: CustomPaint(
      painter: GlowEffectPainter(glowEffectId: glowEffectId, color: color, ringOuterRadius: ringOuterRadius),
    ),
  );
}

/// Renders whichever glow effect `glowEffectId` points to, tinted to
/// [color] and scaled off [ringOuterRadius].
class GlowEffectPainter extends CustomPainter {
  final String glowEffectId;
  final Color color;
  final double ringOuterRadius;

  GlowEffectPainter({required this.glowEffectId, required this.color, required this.ringOuterRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final spec = kGlowEffectCatalog[glowEffectId];
    if (spec == null || spec.shape == 'none') return;
    final center = Offset(size.width / 2, size.height / 2);
    switch (spec.shape) {
      case 'ring':
        _paintHalo(canvas, center);
        break;
      case 'star':
        _paintStar(canvas, center);
        break;
      case 'wispy':
        _paintWispy(canvas, center);
        break;
      case 'constellation':
        _paintConstellation(canvas, center);
        break;
      case 'nebula':
        _paintNebula(canvas, center);
        break;
    }
  }

  void _paintHalo(Canvas canvas, Offset center) {
    // Ambient glow only -- the ring border itself is drawn separately by
    // _RingPainter in member_avatar.dart, so this must never compete with
    // or redraw over it.
    for (final f in [1.4, 1.25, 1.12]) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringOuterRadius * 0.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, ringOuterRadius * f, glowPaint);
    }
  }

  void _paintStar(Canvas canvas, Offset center) {
    const pointCount = 4;
    final outerR = ringOuterRadius * 2.1;
    // Deeper concave scoop than before, but still kept just outside the
    // ring's own radius (1.0) so the curve never dips behind the avatar.
    final scoopR = ringOuterRadius * 1.02;
    final path = Path();
    for (var i = 0; i < pointCount; i++) {
      final angle = (math.pi * 2 / pointCount) * i - math.pi / 2;
      final pt = center + Offset(math.cos(angle), math.sin(angle)) * outerR;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
      final nextAngle = (math.pi * 2 / pointCount) * (i + 1) - math.pi / 2;
      final midAngle = (angle + nextAngle) / 2;
      final control = center + Offset(math.cos(midAngle), math.sin(midAngle)) * scoopR;
      final next = center + Offset(math.cos(nextAngle), math.sin(nextAngle)) * outerR;
      path.quadraticBezierTo(control.dx, control.dy, next.dx, next.dy);
    }
    path.close();

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95),
          Color.lerp(color, Colors.white, 0.25)!.withValues(alpha: 0.75),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerR))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }

  void _paintWispy(Canvas canvas, Offset center) {
    final light = Color.lerp(color, Colors.white, 0.5)!;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, ringOuterRadius * 1.1, glowPaint);

    final rand = math.Random(glowEffectId.hashCode);
    for (var i = 0; i < 3; i++) {
      final startAngle = rand.nextDouble() * 2 * math.pi;
      final sweep = math.pi * (0.6 + rand.nextDouble() * 0.5);
      final r = ringOuterRadius * (0.9 + rand.nextDouble() * 0.25);
      final path = Path();
      const steps = 24;
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final angle = startAngle + sweep * t;
        final wobble = math.sin(t * math.pi * 3) * ringOuterRadius * 0.06;
        final pt = center + Offset(math.cos(angle), math.sin(angle)) * (r + wobble);
        if (s == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      final strandPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringOuterRadius * 0.09
        ..strokeCap = StrokeCap.round
        ..color = (i == 0 ? light : color).withValues(alpha: 0.75 - i * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawPath(path, strandPaint);
    }

    for (final angle in [0.3, 1.9, 3.4, 4.8]) {
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * ringOuterRadius;
      final sparklePaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(pos, ringOuterRadius * 0.045, sparklePaint);
    }
  }

  /// Scattered glowing dots with a few faint connecting lines, like a
  /// small star map.
  void _paintConstellation(Canvas canvas, Offset center) {
    final rand = math.Random(42);
    final points = <Offset>[];
    for (var i = 0; i < 9; i++) {
      final angle = rand.nextDouble() * 2 * math.pi;
      final r = ringOuterRadius * (0.95 + rand.nextDouble() * 0.5);
      points.add(center + Offset(math.cos(angle), math.sin(angle)) * r);
    }
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length - 1; i += 2) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final glowDot = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (var i = 0; i < points.length; i++) {
      final s = i.isEven ? ringOuterRadius * 0.05 : ringOuterRadius * 0.03;
      canvas.drawCircle(points[i], s * 1.8, glowDot);
      canvas.drawCircle(points[i], s, dotPaint);
    }
  }

  /// A dense particle cloud -- many small dots of varying size/opacity
  /// over a faint haze, like stardust.
  void _paintNebula(Canvas canvas, Offset center) {
    final haze = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, ringOuterRadius * 1.3, haze);

    final rand = math.Random(7);
    for (var i = 0; i < 24; i++) {
      final angle = rand.nextDouble() * 2 * math.pi;
      final r = ringOuterRadius * (0.9 + rand.nextDouble() * 0.7);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * r;
      final size = ringOuterRadius * (0.015 + rand.nextDouble() * 0.03);
      final opacity = 0.4 + rand.nextDouble() * 0.5;
      canvas.drawCircle(pos, size, Paint()..color = Colors.white.withValues(alpha: opacity));
    }
  }

  @override
  bool shouldRepaint(covariant GlowEffectPainter oldDelegate) =>
      oldDelegate.glowEffectId != glowEffectId ||
      oldDelegate.color != color ||
      oldDelegate.ringOuterRadius != ringOuterRadius;
}