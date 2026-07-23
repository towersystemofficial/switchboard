import 'dart:async';
import 'package:flutter/material.dart';

/// A single stop in a lightweight guided tour: highlights [targetKey]'s
/// widget on the real, live screen with a spotlight cutout + tooltip card.
/// This is narration, not interaction pass-through -- taps on the
/// highlighted widget are NOT forwarded, so word each step as "this is
/// where X lives" rather than "tap this now". Use [onEnter] to puppet
/// whatever screen state the target depends on (switch tabs, open a menu)
/// before it gets measured.
class TourStep {
  const TourStep({
    this.targetKey,
    required this.title,
    required this.body,
    this.onEnter,
    this.settleDelay = Duration.zero,
    this.spotlightPadding = const EdgeInsets.all(6),
    this.spotlightRadius = const Radius.circular(12),
  });

  /// Leave null for a step with nothing specific to point at -- it just
  /// shows the description card centered over a dimmed background.
  final GlobalKey? targetKey;
  final String title;
  final String body;

  /// Runs right before this step is measured/shown.
  final VoidCallback? onEnter;

  /// Extra time to wait after [onEnter] before measuring the target --
  /// use this for steps that trigger an animation (e.g. a menu expanding).
  final Duration settleDelay;

  final EdgeInsets spotlightPadding;
  final Radius spotlightRadius;
}

/// Starts a guided tour over whatever screen is currently live. [context]
/// just needs to be attached to the app's Overlay -- it does not need to
/// belong to the screen being toured.
Future<void> startTour(BuildContext context, List<TourStep> steps) {
  final overlayState = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  final completer = Completer<void>();

  entry = OverlayEntry(
    builder: (_) => _TourOverlay(
      steps: steps,
      onFinished: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );

  overlayState.insert(entry);
  return completer.future;
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps, required this.onFinished});
  final List<TourStep> steps;
  final VoidCallback onFinished;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _index = 0;
  Rect? _targetRect;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Defer to after this frame finishes building -- step 0's onEnter can
    // call setState on a *different*, already-built widget (e.g. to
    // switch tabs), and doing that synchronously while this overlay is
    // still mounting trips Flutter's "setState() called during build"
    // guard, silently aborting the tour before it shows anything.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToStep(0));
  }

  Future<void> _goToStep(int i) async {
    if (!mounted) return;
    setState(() {
      _index = i;
      _targetRect = null;
      _ready = false;
    });

    final step = widget.steps[i];
    try {
      step.onEnter?.call();
    } catch (_) {
      // Don't let a misbehaving onEnter silently kill the whole tour.
    }
    if (step.settleDelay > Duration.zero) {
      await Future.delayed(step.settleDelay);
    }
    await Future.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;

    if (step.targetKey == null) {
      setState(() => _ready = true);
      return;
    }

    final box = step.targetKey!.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      // Target isn't on screen -- skip rather than show a broken tour.
      _next();
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & box.size;
      _ready = true;
    });
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinished();
    } else {
      _goToStep(_index + 1);
    }
  }

  void _back() {
    if (_index == 0) return;
    _goToStep(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final size = MediaQuery.of(context).size;
    final padding = step.spotlightPadding;

    final rect = _targetRect == null
        ? null
        : Rect.fromLTRB(
            _targetRect!.left - padding.left,
            _targetRect!.top - padding.top,
            _targetRect!.right + padding.right,
            _targetRect!.bottom + padding.bottom,
          );

    Widget? card;
    if (_ready) {
      final tourCard = _TourCard(
        title: step.title,
        body: step.body,
        index: _index,
        total: widget.steps.length,
        onNext: _next,
        onBack: _index > 0 ? _back : null,
        onSkip: widget.onFinished,
      );

      if (rect == null) {
        card = Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: tourCard,
            ),
          ),
        );
      } else {
        final tooltipBelow = rect.center.dy < size.height / 2;
        card = Positioned(
          left: 20,
          right: 20,
          top: tooltipBelow ? rect.bottom + 16 : null,
          bottom: tooltipBelow ? null : (size.height - rect.top + 16),
          child: tourCard,
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(rect: rect, radius: step.spotlightRadius),
              ),
            ),
          ),
          if (card != null) card,
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.title,
    required this.body,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final String title;
  final String body;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${index + 1}/$total',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const Spacer(),
                if (!isLast) TextButton(onPressed: onSkip, child: const Text('Skip')),
                if (onBack != null) TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton(onPressed: onNext, child: Text(isLast ? 'Done' : 'Next')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.rect, required this.radius});
  final Rect? rect;
  final Radius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    if (rect == null) {
      canvas.drawRect(Offset.zero & size, scrimPaint);
      return;
    }
    final fullPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(rect!, radius));
    final combined = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(combined, scrimPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect!, radius), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.radius != radius;
}