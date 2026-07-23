import 'package:flutter/material.dart';

/// Frame shapes are one of two fully independent cosmetic layers (the
/// other is glow effects, see avatar_decorations.dart). Each entry is a
/// GPT-generated grayscale/white texture with a transparent background,
/// tinted to the member's own color at runtime via BlendMode.modulate.
///
/// [offsetX]/[offsetY] and [scale] are computed per-texture (alpha-weighted
/// content centroid and RMS spread from that centroid) rather than using
/// one global number for every asset -- a tight wreath and a wide wingspan
/// need genuinely different scale/centering, not just a shared default.
class FrameShapeSpec {
  final String label;
  final String assetPath;
  final double offsetX;
  final double offsetY;
  final double scale;
  /// Independent horizontal-only multiplier on top of [scale], for shapes
  /// that need stretching rather than uniform resizing (e.g. wide wings).
  final double stretchX;
  const FrameShapeSpec({
    required this.label,
    required this.assetPath,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.scale = 1.4,
    this.stretchX = 1.0,
  });
}

const Map<String, FrameShapeSpec> kFrameShapeCatalog = {
  'none': FrameShapeSpec(label: 'None', assetPath: ''),
  'angel_wings': FrameShapeSpec(
    label: 'Angel Wings',
    assetPath: 'assets/frame_shapes/angel_wings.png',
    offsetX: 0.005,
    offsetY: 0.523,
    scale: 0.608,
    stretchX: 1.777,
  ),
  'fairy_wings': FrameShapeSpec(
    label: 'Fairy Wings',
    assetPath: 'assets/frame_shapes/fairy_wings.png',
    offsetX: 0.007,
    offsetY: 0.523,
    scale: 0.608,
    stretchX: 1.777,
  ),
  'butterflies': FrameShapeSpec(
    label: 'Butterflies',
    assetPath: 'assets/frame_shapes/butterflies.png',
    offsetX: -0.025,
    offsetY: 0.023,
    scale: 1.575,
    stretchX: 0.95,
  ),
  'cat_ears': FrameShapeSpec(
    label: 'Cat Ears',
    assetPath: 'assets/frame_shapes/cat_ears.png',
    offsetX: 0.0,
    offsetY: 0.023,
    scale: 1.463,
    stretchX: 0.840,
  ),
  'clouds': FrameShapeSpec(
    label: 'Clouds',
    assetPath: 'assets/frame_shapes/clouds.png',
    offsetX: -0.021,
    offsetY: 0.02,
    scale: 1.489,
    stretchX: 0.95,
  ),
  'cold_steel': FrameShapeSpec(
    label: 'Cold Steel',
    assetPath: 'assets/frame_shapes/cold_steel.png',
    offsetX: -0.05,
    offsetY: 0.05,
    scale: 1.351,
  ),
  'crescent_moon': FrameShapeSpec(
    label: 'Crescent Moon',
    assetPath: 'assets/frame_shapes/crescent_moon.png',
    offsetX: -0.179,
    offsetY: 0.038,
    scale: 1.327,
  ),
  'deep_sea': FrameShapeSpec(
    label: 'Deep Sea',
    assetPath: 'assets/frame_shapes/deep_sea.png',
    offsetX: 0.0,
    offsetY: 0.03,
    scale: 1.44,
  ),
  'digital': FrameShapeSpec(
    label: 'Digital',
    assetPath: 'assets/frame_shapes/digital.png',
    offsetX: -0.01,
    offsetY: 0.009,
    scale: 1.313,
    stretchX: 0.95,
  ),
  'falling_star': FrameShapeSpec(
    label: 'Falling Star',
    assetPath: 'assets/frame_shapes/falling_star.png',
    offsetX: -0.022,
    offsetY: 0.28,
    scale: 0.9,
    stretchX: 1.4,
  ),
  'feathers': FrameShapeSpec(
    label: 'Feathers',
    assetPath: 'assets/frame_shapes/feathers.png',
    offsetX: -0.002,
    offsetY: 0.015,
    scale: 1.35,
  ),
  'flame_wreath': FrameShapeSpec(
    label: 'Flame Wreath',
    assetPath: 'assets/frame_shapes/flame_wreath.png',
    offsetX: -0.021,
    offsetY: 0.007,
    scale: 1.416,
    stretchX: 0.98,
  ),
  'honeycomb': FrameShapeSpec(
    label: 'Honeycomb',
    assetPath: 'assets/frame_shapes/honeycomb.png',
    offsetX: -0.022,
    offsetY: 0.041,
    scale: 1.25,
    stretchX: 0.97,
  ),
  'ice_crystals': FrameShapeSpec(
    label: 'Ice Crystals',
    assetPath: 'assets/frame_shapes/ice_crystals.png',
    offsetX: -0.006,
    offsetY: 0.022,
    scale: 1.352,
  ),
  'laurels': FrameShapeSpec(
    label: 'Laurels',
    assetPath: 'assets/frame_shapes/laurels.png',
    offsetX: -0.005,
    offsetY: 0.007,
    scale: 1.531,
    stretchX: 1.05,
  ),
  'lightning': FrameShapeSpec(
    label: 'Lightning',
    assetPath: 'assets/frame_shapes/lightning.png',
    offsetX: -0.026,
    offsetY: 0.026,
    scale: 1.445,
    stretchX: 0.814,
  ),
  'nebula': FrameShapeSpec(
    label: 'Nebula',
    assetPath: 'assets/frame_shapes/nebula.png',
    offsetX: -0.030,
    offsetY: 0.03,
    scale: 1.4,
  ),
  'rime': FrameShapeSpec(
    label: 'Rime',
    assetPath: 'assets/frame_shapes/rime.png',
    offsetX: -0.02,
    offsetY: 0.03,
    scale: 1.51,
    stretchX: 0.95,
  ),
  'roses': FrameShapeSpec(
    label: 'Roses',
    assetPath: 'assets/frame_shapes/roses.png',
    offsetX: -0.058,
    offsetY: 0.058,
    scale: 1.3,
  ),
  'spell_circle': FrameShapeSpec(
    label: 'Spell Circle',
    assetPath: 'assets/frame_shapes/spell_circle.png',
    offsetX: -0.005,
    offsetY: 0.007,
    scale: 1.87,
  ),
  'trees': FrameShapeSpec(
    label: 'Trees',
    assetPath: 'assets/frame_shapes/trees.png',
    offsetX: -0.008,
    offsetY: 0.010,
    scale: 1.437,
  ),
  'undead': FrameShapeSpec(
    label: 'Undead',
    assetPath: 'assets/frame_shapes/undead.png',
    offsetX: -0.003,
    offsetY: 0.064,
    scale: 1.46,
  ),
  'vines_and_blossoms': FrameShapeSpec(
    label: 'Vines & Blossoms',
    assetPath: 'assets/frame_shapes/vines_and_blossoms.png',
    offsetX: -0.01,
    offsetY: 0.02,
    scale: 1.42,
    stretchX: 0.95,
  ),
  'water': FrameShapeSpec(
    label: 'Water',
    assetPath: 'assets/frame_shapes/water.png',
    offsetX: -0.02,
    offsetY: 0.02,
    scale: 1.35,
    stretchX: 0.98,
  ),
};

/// Builds the widget for a frame shape -- a tinted, offset- and
/// scale-corrected texture, sized off [ringOuterRadius].
Widget buildFrameShape({
  required String frameShapeId,
  required Color color,
  required double ringOuterRadius,
  Color? gradientTopColor,
}) {
  final spec = kFrameShapeCatalog[frameShapeId];
  if (spec == null || spec.assetPath.isEmpty) return const SizedBox.shrink();

  final size = ringOuterRadius * 2 * spec.scale;

  Widget image = Image.asset(
    spec.assetPath,
    fit: BoxFit.contain,
    width: size,
    height: size,
  );

  // Flat single-color tint, or a top-to-bottom gradient tint (group view)
  // -- same idea as the ring's own gradient, just applied as a shader mask
  // since Image's simple color/colorBlendMode params only support flat color.
  if (gradientTopColor != null) {
    image = ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientTopColor, color],
      ).createShader(bounds),
      blendMode: BlendMode.modulate,
      child: image,
    );
  } else {
    image = ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.modulate),
      child: image,
    );
  }

  return OverflowBox(
    maxWidth: size,
    maxHeight: size,
    child: Transform.translate(
      offset: Offset(spec.offsetX * size, spec.offsetY * size),
      child: Transform(
        transform: Matrix4.identity()..scaleByDouble(spec.stretchX, 1.0, 1.0, 1.0),
        alignment: Alignment.center,
        child: SizedBox(width: size, height: size, child: image),
      ),
    ),
  );
}