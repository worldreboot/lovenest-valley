import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flame/effects.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lovenest/services/seashell_service.dart';

class SeashellObject extends SpriteComponent with TapCallbacks {
  final String audioUrl;
  final String id;
  final VoidCallback? onPlayAudio;
  final bool highlightUnheard;
  SpriteComponent? _notification;
  
  SeashellObject({
    required Vector2 position,
    required Vector2 size,
    required this.audioUrl,
    required this.id,
    this.onPlayAudio,
    this.highlightUnheard = false,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    // Load the seashell sprite
    sprite = await Sprite.load('seashell.png');
    if (highlightUnheard) {
      await _addNotification();
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    print('Seashell tapped! Playing audio: $audioUrl');
    
    // Call the callback to play audio
    onPlayAudio?.call();
    
    // Also play audio directly here as a fallback
    _playAudio();
    
    // Mark as heard and remove notification if present
    SeashellService.markSeashellHeard(id);
    _removeNotification();
    
    return true; // Consume the tap event
  }

  Future<void> _playAudio() async {
    try {
      final player = AudioPlayer();
      await player.play(UrlSource(audioUrl));
      
      // Clean up when done
      player.onPlayerComplete.listen((event) {
        player.dispose();
      });
      
      print('Playing seashell audio: $audioUrl');
    } catch (e) {
      print('Error playing seashell audio: $e');
    }
  }

  Future<void> _addNotification() async {
    final notiSprite = await Sprite.load('owl_noti.png');
    final comp = SpriteComponent(
      sprite: notiSprite,
      size: Vector2(size.x * 0.7, size.y * 0.7),
      position: Vector2(size.x / 2, -size.y * 0.2), // hover above shell
      anchor: Anchor.center,
      priority: priority + 1,
    );
    // Gentle bobbing animation
    comp.add(
      SequenceEffect([
        MoveByEffect(Vector2(0, -4), EffectController(duration: 0.6, reverseDuration: 0.6, repeatCount: 1)),
      ], infinite: true),
    );
    add(comp);
    _notification = comp;
  }

  void _removeNotification() {
    _notification?.removeFromParent();
    _notification = null;
  }


} 