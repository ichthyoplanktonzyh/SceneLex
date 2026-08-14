import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'review_reaction.dart';

/// Full-surface overlay that renders the active rating reactions.
/// Hit-testing and semantics are disabled; the host surface dismisses the
/// layer on touch (see ReviewPage).
class ReviewReactionLayer extends StatelessWidget {
  const ReviewReactionLayer({
    super.key,
    required this.events,
    required this.reducedMotion,
  });

  final List<ReviewReactionEvent> events;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final event in events)
              _ReviewReactionEventView(
                key: ValueKey(event.id),
                event: event,
                reducedMotion: reducedMotion,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewReactionEventView extends StatefulWidget {
  const _ReviewReactionEventView({
    super.key,
    required this.event,
    required this.reducedMotion,
  });

  final ReviewReactionEvent event;
  final bool reducedMotion;

  @override
  State<_ReviewReactionEventView> createState() =>
      _ReviewReactionEventViewState();
}

class _ReviewReactionEventViewState extends State<_ReviewReactionEventView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final duration = widget.reducedMotion
        ? const Duration(milliseconds: 340)
        : Duration(
            milliseconds: reviewReactionAnimationDurationMillis(
              widget.event.variant,
            ),
          );
    _controller = AnimationController(vsync: this, duration: duration);
    if (widget.reducedMotion) {
      _controller.value = reducedMotionAnimationProgress;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = reviewReactionLottieAssetPath(widget.event.variant);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final side =
            _shortestSide * reviewReactionFrameScale(widget.event.variant);
        return Opacity(
          // Reference fade: in over the first 10%, out over the last 22%.
          opacity: reviewReactionOpacity(progress),
          child: Align(
            // Vertical center at 75% of the surface (reference anchor).
            alignment: const Alignment(0, 0.5),
            child: SizedBox(
              width: side,
              height: side,
              child: assetPath == null
                  ? const SizedBox.shrink()
                  : Lottie.asset(
                      assetPath,
                      controller: _controller,
                      repeat: false,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
            ),
          ),
        );
      },
    );
  }

  double get _shortestSide {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    return shortest <= 0 ? 360 : shortest;
  }
}
