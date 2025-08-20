import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A placeable gift object that renders a network sprite and supports tap/long press.
class GiftObject extends SpriteComponent with TapCallbacks {
  final String giftId;
  final String? spriteUrl;
  final String? description;
  final double tileSize;
  final bool Function(int gridX, int gridY) isPlayerAdjacent;
  final Future<void> Function(String giftId) onPickUp; // return to inventory and remove from world

  // Long press detection
  int? _downEpochMs;
  static const double longPressThresholdMs = 500;

  GiftObject({
    required this.giftId,
    required this.spriteUrl,
    required this.description,
    required Vector2 position,
    required Vector2 size,
    required this.tileSize,
    required this.isPlayerAdjacent,
    required this.onPickUp,
  }) : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
  }

  Future<void> _loadSprite() async {
    try {
      if (spriteUrl != null && spriteUrl!.startsWith('http')) {
        final res = await http.get(Uri.parse(spriteUrl!));
        if (res.statusCode == 200) {
          final bytes = res.bodyBytes;
          final completer = Completer<ui.Image>();
          ui.decodeImageFromList(bytes, (ui.Image img) => completer.complete(img));
          final image = await completer.future;
          sprite = Sprite(image);
          return;
        }
      }
    } catch (_) {}
    // Fallback to a default gift asset if network fails
    try {
      sprite = await Sprite.load('gift_1.png');
    } catch (_) {}
  }

  @override
  void onTapDown(TapDownEvent event) {
    _downEpochMs = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final up = DateTime.now().millisecondsSinceEpoch;
    final duration = _downEpochMs != null ? (up - _downEpochMs!) : 0;

    final gridX = (position.x / tileSize).floor();
    final gridY = (position.y / tileSize).floor();
    final adjacent = isPlayerAdjacent(gridX, gridY);

    if (duration >= longPressThresholdMs) {
      // Long press: pick up if adjacent
      if (adjacent) {
        onPickUp(giftId);
      }
      return;
    }

    // Short tap: show a transient text bubble above
    if (description != null && description!.isNotEmpty) {
      final bubble = _InfoBubble(description!, tileSize);
      bubble.position = Vector2(position.x + size.x / 2, position.y - 8);
      parent?.add(bubble);
    }
  }
}

class _InfoBubble extends PositionComponent with HasGameRef {
  final String text;
  final double tileSize;
  late final TextComponent _label;

  _InfoBubble(this.text, this.tileSize);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    _label = TextComponent(
      text: text,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final bg = RectangleComponent(
      size: Vector2(_label.width + 16, _label.height + 10),
      paint: Paint()..color = Colors.black.withOpacity(0.7),
      anchor: Anchor.center,
    );
    add(bg);
    _label.position = Vector2.zero();
    _label.anchor = Anchor.center;
    add(_label);

    // Auto-remove after 2.5s
    Future.delayed(const Duration(milliseconds: 2500), () {
      removeFromParent();
    });
  }
}


