import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../providers/system_provider.dart';
import 'avatar_decorations.dart';
import 'avatar_frame_shapes.dart';

class MemberAvatar extends StatelessWidget {
  final Member? member;
  final double radius;
  final String? avatarFullPath;
  final bool showFrontingBadge;
  final bool showColorRing;

  /// If set (with [showColorRing] true), draws a top-to-bottom gradient
  /// ring from this color down to the member's own color, instead of a
  /// solid ring in the member's color. Used in Group view.
  final Color? gradientRingTopColor;

  const MemberAvatar({
    super.key,
    required this.member,
    this.radius = 24,
    this.avatarFullPath,
    this.showFrontingBadge = false,
    this.showColorRing = false,
    this.gradientRingTopColor,
  });

  Widget _core() {
    if (member == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.person_outline, size: radius, color: Colors.grey.shade600),
      );
    }
    final path = avatarFullPath;
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(radius: radius, backgroundImage: FileImage(File(path)));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: member!.color,
      child: Text(
        member!.initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );
  }

  double _channelLuminance(int v) {
    final c = v / 255.0;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  double _luminance(Color c) {
    return 0.2126 * _channelLuminance((c.r * 255.0).round().clamp(0, 255).toInt()) +
        0.7152 * _channelLuminance((c.g * 255.0).round().clamp(0, 255).toInt()) +
        0.0722 * _channelLuminance((c.b * 255.0).round().clamp(0, 255).toInt());
  }

  Color _contrastColor(Color background) {
    return _luminance(background) > 0.4 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = context.watch<SystemProvider>();
    final decorationsEnabled = systemProvider.decorationsEnabled;

    final core = _core();
    final ringWidth = (radius * 0.09).clamp(2.0, 4.0);
    final hasRing = showColorRing && member != null;
    final outerRadius = radius + (hasRing ? ringWidth * 2 : 0);
    final outerDiameter = outerRadius * 2;

    final glowEffectId = (hasRing && decorationsEnabled) ? member!.glowEffectId : 'none';
    final frameShapeId = (hasRing && decorationsEnabled) ? member!.frameShapeId : 'none';
    final hasGlowEffect = glowEffectId != 'none';
    final hasFrameShape = frameShapeId != 'none';

    Widget ring;
    if (hasRing && !hasFrameShape) {
      // Drawn as an actual stroke (not a filled disc) so the gap between
      // the ring and the avatar stays transparent, same as the original.
      ring = SizedBox(
        width: outerDiameter,
        height: outerDiameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(outerDiameter, outerDiameter),
              painter: _RingPainter(
                avatarRadius: radius,
                ringWidth: ringWidth,
                baseColor: member!.color,
                gradientTopColor: gradientRingTopColor,
              ),
            ),
            core,
          ],
        ),
      );
    } else if (hasRing) {
      // A frame shape is active -- it provides its own visual border, so
      // skip the plain colored ring stroke rather than let it compete
      // with the shape's own art. Layout stays the same size either way.
      ring = SizedBox(width: outerDiameter, height: outerDiameter, child: Center(child: core));
    } else {
      ring = core;
    }

    final needsOverlay = hasGlowEffect || hasFrameShape || showFrontingBadge;
    if (!needsOverlay) return ring;

    final badgeSize = (radius * 0.55).clamp(8.0, 18.0) + 3;
    final badgeRadius = badgeSize / 2;
    final badgeColor = member?.color ?? Colors.green.shade500;
    final arrowColor = _contrastColor(badgeColor);
    final borderColor = Theme.of(context).colorScheme.surface;

    // Overlap is measured against the actual avatar circle (radius), not
    // the ring's outer edge -- unchanged from before, decorations don't
    // affect this math at all.
    final distanceFromCenter = radius + badgeRadius / 3;
    final diag = distanceFromCenter * 0.70710678; // cos(45deg) == sin(45deg)
    final badgeLeft = outerRadius + diag - badgeRadius;
    final badgeTop = outerRadius + diag - badgeRadius;

    return SizedBox(
      width: outerDiameter,
      height: outerDiameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasGlowEffect)
            SizedBox(
              width: outerDiameter,
              height: outerDiameter,
              child: CustomPaint(
                painter: GlowEffectPainter(
                  glowEffectId: glowEffectId,
                  color: member!.color,
                  ringOuterRadius: outerRadius,
                ),
              ),
            ),
          ring,
          if (hasFrameShape)
            buildFrameShape(
              frameShapeId: frameShapeId,
              color: member!.color,
              ringOuterRadius: outerRadius,
              gradientTopColor: gradientRingTopColor,
            ),
          if (showFrontingBadge)
            Positioned(
              left: badgeLeft,
              top: badgeTop,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor,
                  border: Border.all(color: borderColor, width: 4),
                ),
                child: Icon(Icons.arrow_upward_rounded, size: badgeSize * 0.65, color: arrowColor),
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws the color ring as an actual stroke (leaving a transparent gap
/// between it and the avatar), with an optional top-to-bottom gradient
/// (group view).
class _RingPainter extends CustomPainter {
  final double avatarRadius;
  final double ringWidth;
  final Color baseColor;
  final Color? gradientTopColor;

  _RingPainter({
    required this.avatarRadius,
    required this.ringWidth,
    required this.baseColor,
    this.gradientTopColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // One ringWidth of transparent gap, then one ringWidth of visible
    // stroke -- so the stroke's centerline sits 1.5 ringWidths out from
    // the avatar's own edge.
    final strokeRadius = avatarRadius + ringWidth * 1.5;
    final rect = Rect.fromCircle(center: center, radius: strokeRadius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    if (gradientTopColor != null) {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientTopColor!, baseColor],
      ).createShader(rect);
    } else {
      paint.color = baseColor;
    }

    canvas.drawCircle(center, strokeRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.avatarRadius != avatarRadius ||
      oldDelegate.ringWidth != ringWidth ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.gradientTopColor != gradientTopColor;
}