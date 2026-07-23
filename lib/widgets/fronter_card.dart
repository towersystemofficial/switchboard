import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/front_entry.dart';
import '../providers/system_provider.dart';
import 'member_avatar.dart';

/// Card showing everyone currently fronting. Collapsed, it's just the
/// gradient + a row of avatars (always a single row, overlapping like
/// GitHub collaborator avatars rather than wrapping). Tapping the card
/// expands it into a per-person list, each row carrying its own avatar,
/// name, role, since-time, and remove button.
class FronterCard extends StatefulWidget {
  final List<FrontEntry> activeEntries;
  final Member? Function(String memberId) memberFor;
  final String? Function(String? filename) avatarPathFor;
  final void Function(String memberId)? onRemove;

  const FronterCard({
    super.key,
    required this.activeEntries,
    required this.memberFor,
    required this.avatarPathFor,
    this.onRemove,
  });

  @override
  State<FronterCard> createState() => _FronterCardState();
}

class _FronterCardState extends State<FronterCard> {
  static const double _avatarDiameter = 52.0;

  // MemberAvatar's own decoration (color ring / frame shape / glow) draws
  // outside the raw avatar circle -- this mirrors its ring-width math so
  // the layout box is sized to actually contain it. +2 is a small buffer
  // so the decoration's edge doesn't touch the box boundary with zero
  // margin (which can clip a pixel or two to rounding).
  static double _coreOuterDiameter(double radius) {
    final ringWidth = (radius * 0.09).clamp(2.0, 4.0);
    final ringOuterRadius = radius + ringWidth * 2;
    // 1.4 is the frame-shape catalog's own default scale -- sizes for the
    // common case rather than the extreme (Spell Circle goes up to 1.87),
    // so this compact row doesn't balloon for every member just to cover
    // the handful of larger outlier shapes. Those now bleed gracefully
    // past this box instead of being boxed in and clipped.
    return ringOuterRadius * 2 * 1.4;
  }

  static final double _avatarOuterSize = _coreOuterDiameter(_avatarDiameter / 2) + 2;

  Timer? _timer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.activeEntries;
    final members = entries.map((e) => widget.memberFor(e.memberId)).toList();
    final colors = members.map((m) => m?.color ?? Colors.grey.shade400).toList();

    List<Color> gradientColors;
    if (colors.isEmpty) {
      gradientColors = [Colors.grey.shade400, Colors.grey.shade300];
    } else if (colors.length == 1) {
      gradientColors = [_lighten(colors.first, 0.10), _darken(colors.first, 0.16)];
    } else {
      gradientColors = colors;
    }

    final hasFronters = entries.isNotEmpty;

    return GestureDetector(
      onTap: hasFronters ? () => setState(() => _expanded = !_expanded) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (colors.isNotEmpty ? colors.first : Colors.grey).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasFronters ? 'CURRENTLY FRONTING (${entries.length})' : 'CURRENTLY FRONTING',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (hasFronters)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasFronters)
              const Text(
                'No one set',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              )
            else
              // AnimatedCrossFade clips both children to its own computed
              // box internally, no matter what clipBehavior is set further
              // down the tree -- that was cropping decorations regardless
              // of how the avatar row itself was sized. AnimatedSize can
              // actually turn its clip off, at the cost of losing the
              // opacity cross-fade blend (this is now a plain resize).
              AnimatedSize(
                duration: context.watch<SystemProvider>().reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                child: _expanded ? _buildDetailList(entries, members) : _buildAvatarRow(members),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarRow(List<Member?> members) {
    const desiredGap = 10.0;
    final count = members.length;

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      double step;
      if (count <= 1) {
        step = _avatarOuterSize;
      } else {
        final naturalWidth = _avatarOuterSize + (count - 1) * (_avatarOuterSize + desiredGap);
        if (naturalWidth <= maxWidth) {
          step = _avatarOuterSize + desiredGap;
        } else {
          step = (maxWidth - _avatarOuterSize) / (count - 1);
          final minStep = _avatarOuterSize * 0.35;
          if (step < minStep) step = minStep;
        }
      }

      final totalWidth = _avatarOuterSize + (count - 1) * step;
      final needsScroll = totalWidth > maxWidth + 0.5;

      final stack = SizedBox(
        width: needsScroll ? totalWidth : maxWidth,
        height: _avatarOuterSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < count; i++)
              Positioned(
                left: i * step,
                top: 0,
                child: _avatarWithRing(members[i]),
              ),
          ],
        ),
      );

      if (needsScroll) {
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: stack);
      }
      return stack;
    });
  }

  Widget _avatarWithRing(Member? member) {
    // No separate white border here anymore -- MemberAvatar's own
    // decoration (color ring / frame shape / glow) is the only ring now,
    // this box just needs to be sized to fit it without clipping.
    return SizedBox(
      width: _avatarOuterSize,
      height: _avatarOuterSize,
      child: Center(
        child: MemberAvatar(
          member: member,
          radius: _avatarDiameter / 2,
          avatarFullPath: widget.avatarPathFor(member?.avatarFilename),
          showColorRing: true,
        ),
      ),
    );
  }

  Widget _buildDetailList(List<FrontEntry> entries, List<Member?> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _avatarWithRing(members[i]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        members[i]?.name ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (members[i]?.roleDisplay.isNotEmpty == true) members[i]!.roleDisplay,
                          'Since ${context.watch<SystemProvider>().formatTime(entries[i].start)} '
                              '(${_formatDuration(entries[i].duration)})',
                        ].join(' \u2022 '),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => widget.onRemove!(entries[i].memberId),
                    tooltip: 'Stop fronting',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}