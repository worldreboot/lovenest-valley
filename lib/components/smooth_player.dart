import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest/components/player.dart';

class SmoothPlayer extends Player {
  // Remote-only lightweight interpolation state
  Vector2? _remoteTargetPosition;
  Vector2? _remoteInterpolationStart;
  double _remoteInterpolationTime = 0.0;
  static const double _remoteInterpolationDuration = 0.12; // seconds

  // Animation smoothing (network-driven)
  PlayerDirection _targetDirection = PlayerDirection.idle;
  double _directionInterpolationProgress = 0.0;
  static const double _directionInterpolationDuration = 0.05; // seconds

  SmoothPlayer() : super();

  @override
  // ignore: must_call_super
  void update(double dt) {
    // Intentionally DO NOT call super.update(dt) to avoid local pathfinding,
    // broadcasting, and other heavy logic intended for the local player.

    // Interpolate towards the latest network target
    if (_remoteTargetPosition != null) {
      if (_remoteInterpolationStart == null) {
        _remoteInterpolationStart = position.clone();
        _remoteInterpolationTime = 0.0;
      }

      _remoteInterpolationTime += dt;
      final t = (_remoteInterpolationTime / _remoteInterpolationDuration).clamp(0.0, 1.0);

      final start = _remoteInterpolationStart!;
      final end = _remoteTargetPosition!;
      final newPos = start + (end - start) * t;

      // Update velocity approximation for animation
      final newVelocity = (newPos - position) / (dt > 0 ? dt : 1.0);
      velocity = newVelocity;

      position = newPos;

      if (t >= 1.0) {
        // Arrived
        _remoteInterpolationStart = null;
        _remoteInterpolationTime = 0.0;
        velocity = Vector2.zero();
      }
    } else {
      velocity = Vector2.zero();
    }

    // Update animation selection based on current velocity
    updateAnimation();

    // Apply network-driven direction smoothing (optional)
    if (_targetDirection != currentDirection) {
      _directionInterpolationProgress += dt / _directionInterpolationDuration;
      if (_directionInterpolationProgress >= 1.0) {
        currentDirection = _targetDirection;
        _directionInterpolationProgress = 0.0;
        updateAnimation();
      }
    }
  }

  // Set a new network target position (world coordinates)
  void moveToPosition(Vector2 targetPosition, {Vector2? velocity, double? tileSize}) {
    _remoteTargetPosition = targetPosition;
    _remoteInterpolationStart = null; // reset for fresh interpolation
  }

  // Update direction smoothly from network state
  void updateDirection(PlayerDirection newDirection) {
    if (newDirection != _targetDirection) {
      _targetDirection = newDirection;
      _directionInterpolationProgress = 0.0;
    }
  }

  // Remote players ignore local input entirely
  @override
  KeyEventResult handleKeyEvent(Set<LogicalKeyboardKey> keysPressed) {
    return KeyEventResult.ignored;
  }

  // Disable direct movement APIs that would trigger pathfinding/broadcast
  @override
  void moveTowards(Vector2 target) {
    // Ignore for remote players; movement is network-driven.
  }
}