import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../models/character.dart';

class AnimatedCharacterMarker extends StatefulWidget {
  final List<CharacterAction> actions;
  final String userName;
  final bool showName;
  final bool enableClick;
  final double scale;
  final bool isMoving;

  const AnimatedCharacterMarker({
    super.key,
    required this.actions,
    required this.userName,
    this.showName = true,
    this.enableClick = true,
    this.scale = 1.0,
    this.isMoving = false,
  });

  @override
  State<AnimatedCharacterMarker> createState() =>
      _AnimatedCharacterMarkerState();
}

class _AnimatedCharacterMarkerState extends State<AnimatedCharacterMarker> {
  int _currentFrame = 0;
  Timer? _animationTimer;
  CharacterAction? _currentAction;
  bool _playingAction = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentAction = _getAppropriateAction(); // Start with appropriate action
    _restartAnimationTimer();
  }

  @override
  void didUpdateWidget(AnimatedCharacterMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If actions changed (different character selected), reset to new action
    if (oldWidget.actions != widget.actions) {
      _currentAction = _getAppropriateAction();
      _currentFrame = 0;
      _playingAction = false;
      _restartAnimationTimer();
    }
    // If moving state changed, switch to appropriate action
    if (oldWidget.isMoving != widget.isMoving && !_playingAction) {
      _currentAction = _getAppropriateAction();
      _currentFrame = 0;
      _restartAnimationTimer();
    }
  }

  CharacterAction _getAppropriateAction() {
    if (widget.isMoving && widget.actions.length > 1) {
      // Use running action (typically second action)
      return widget.actions[1];
    }
    // Use idle action (first action)
    return widget.actions.first;
  }

  void _restartAnimationTimer() {
    _animationTimer?.cancel();
    if (_currentAction == null) return;

    final frameDuration = _frameDurationForAction(_currentAction!);
    _animationTimer = Timer.periodic(frameDuration, (timer) {
      if (!mounted || _currentAction == null) return;

      var switchedToIdle = false;

      setState(() {
        _currentFrame = (_currentFrame + 1) % _currentAction!.frameCount;

        // If playing an action and reached the end, return to idle
        if (_playingAction && _currentFrame == 0) {
          _playingAction = false;
          _currentAction = widget.actions.first; // Back to idle
          switchedToIdle = true;
        }
      });

      if (switchedToIdle) {
        _restartAnimationTimer();
      }
    });
  }

  Duration _frameDurationForAction(CharacterAction action) {
    final frameCount = action.frameCount.clamp(1, 100);
    // Increased base duration for better performance (less frequent updates)
    const baseDurationMs = 120; // Increased from 90 to 120
    const referenceFrames = 6;
    final multiplier = (frameCount / referenceFrames).clamp(1.0, 2.5);
    final durationMs = (baseDurationMs * multiplier).round();
    return Duration(milliseconds: durationMs);
  }

  void _playRandomAction() {
    if (!widget.enableClick || widget.actions.length <= 1 || _playingAction) {
      return;
    }

    // Get non-idle actions
    final nonIdleActions = widget.actions.skip(1).toList();
    if (nonIdleActions.isEmpty) return;

    // Pick random action
    final randomAction = nonIdleActions[_random.nextInt(nonIdleActions.length)];

    setState(() {
      _playingAction = true;
      _currentAction = randomAction;
      _currentFrame = 0;
    });

    _restartAnimationTimer();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAction == null) {
      return const SizedBox();
    }

    return GestureDetector(
      onTap: widget.enableClick ? _playRandomAction : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Character sprite - just the animation, no border
          Transform.scale(
            scale: widget.scale,
            child: SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(
                _currentAction!.assetPath,
                fit: BoxFit.cover,
                // Decode full sprite sheet so per-frame alignment works
                cacheWidth: 192 * _currentAction!.frameCount,
                cacheHeight: 192,
                filterQuality:
                    FilterQuality.medium, // Balanced quality/performance
                // Sprite sheet: 192x192 per frame, frames horizontally
                // Calculate the offset based on current frame
                alignment: Alignment(
                  _currentAction!.frameCount > 1
                      ? -1.0 +
                            (_currentFrame *
                                2.0 /
                                (_currentAction!.frameCount - 1))
                      : 0.0,
                  0.0,
                ),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.person_fill,
                      color: CupertinoColors.systemBlue,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.showName) ...[
            Transform.translate(
              offset: const Offset(0, -25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
