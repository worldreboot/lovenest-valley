part of '../../simple_enhanced_farm_game.dart';

extension PlayerCameraNpcExtension on SimpleEnhancedFarmGame {
  Future<void> _spawnPlayer() async {
    bool playerSpawned = false;
    try {
      final objectGroups = _mapParser.getObjectGroups();
      for (final group in objectGroups) {
        if (group.name == 'SpawnPoint') {
          for (final obj in group.objects) {
            if (obj.name == 'Spawn') {
              player = Player();
              player.position = Vector2(obj.x, obj.y);
              player.onPositionChanged = (position, {animationState}) => _handlePlayerPositionChange(position);
              world.add(player);
              playerSpawned = true;
              break;
            }
          }
        }
      }
    } catch (_) {}
    if (!playerSpawned) {
      final spawnX = 488.0;
      final spawnY = 181.0;
      player = Player();
      player.position = Vector2(spawnX, spawnY);
      player.onPositionChanged = (position, {animationState}) => _handlePlayerPositionChange(position);
      world.add(player);
    }
    if (player.animation != null) {}
  }

  Future<void> _addNPCsAndObjects() async {
    final owlX = 22;
    final owlY = 14;
    final owlImage = await images.load('owl.png');
    final owlNotiImage = await images.load('owl_noti.png');
    final frameWidth = 382.0;
    final frameHeight = 478.0;
    final spriteSheet = SpriteSheet(image: owlImage, srcSize: Vector2(frameWidth, frameHeight));
    final idleSprite = spriteSheet.getSprite(0, 0);
    final notificationSprite = Sprite(owlNotiImage);
    final scale = 0.10;
    final owlSize = Vector2(frameWidth * scale, frameHeight * scale);
    final owlNpc = OwlNpcComponent(
      position: Vector2(owlX * SimpleEnhancedFarmGame.tileSize, owlY * SimpleEnhancedFarmGame.tileSize),
      size: owlSize,
      idleSprite: idleSprite,
      notificationSprite: notificationSprite,
      onTapOwl: () async {
        final dailyQuestion = await QuestionService.fetchDailyQuestion();
        if (dailyQuestion != null) {
          onOwlTapped?.call(dailyQuestion);
        }
      },
    );
    world.add(owlNpc);
    // Block all tiles covered by the owl footprint (top-left anchored)
    final owlCoverW = (owlSize.x / SimpleEnhancedFarmGame.tileSize).ceil();
    final owlCoverH = (owlSize.y / SimpleEnhancedFarmGame.tileSize).ceil();
    for (int dy = 0; dy < owlCoverH; dy++) {
      for (int dx = 0; dx < owlCoverW; dx++) {
        final gx = owlX + dx;
        final gy = owlY + dy;
        if (gx >= 0 && gx < SimpleEnhancedFarmGame.mapWidth && gy >= 0 && gy < SimpleEnhancedFarmGame.mapHeight) {
          owlPositions.add(GridPos(gx, gy));
          _pathfindingGrid.setObstacle(gx, gy, true);
        }
      }
    }
    final dailyQuestion = await QuestionService.fetchDailyQuestion();
    if (dailyQuestion != null) {
      final hasCollected = await DailyQuestionSeedCollectionService.hasUserCollectedSeed(dailyQuestion.id);
      owlNpc.showNotification(!hasCollected);
    } else {
      owlNpc.showNotification(false);
    }
    // Bonfire auto-spawn disabled
  }

  void _setupCamera() {
    camera.world = world;
    camera.follow(player);
    camera.viewfinder.position = player.position;
    camera.viewfinder.add(CameraBoundsBehavior());
    camera.viewfinder.zoom = 2.0;
  }

  Future<void> _initializeMultiplayer() async {
    _farmPlayerService = FarmPlayerService();
    _userId = SupabaseConfig.currentUserId;
    if (_userId == null) return;

    // Subscribe to partner destinations
    _movementSub = _farmPlayerService
        .subscribeToPlayerDestinationBroadcast(farmId)
        .listen((destination) {
      if (destination.userId == _userId) return; // ignore self

      // Ensure we have a SmoothPlayer for this user
      if (!otherPlayers.containsKey(destination.userId)) {
        final other = SmoothPlayer()
          ..opacity = 1.0
          ..priority = 3000;
        // Start at the destination tile center
        other.position = Vector2(
          destination.targetGridX * SimpleEnhancedFarmGame.tileSize + SimpleEnhancedFarmGame.tileSize / 2,
          destination.targetGridY * SimpleEnhancedFarmGame.tileSize + SimpleEnhancedFarmGame.tileSize / 2,
        );
        otherPlayers[destination.userId] = other;
        world.add(other);
      }

      final otherPlayer = otherPlayers[destination.userId]!;
      // Move to the tile center using tile size provided by sender
      final target = Vector2(
        destination.targetGridX * destination.tileSize + destination.tileSize / 2,
        destination.targetGridY * destination.tileSize + destination.tileSize / 2,
      );
      otherPlayer.moveToPosition(target, tileSize: destination.tileSize);

      // Update animation if provided
      if (destination.animationState != null) {
        switch (destination.animationState) {
          case 'up':
            otherPlayer.updateDirection(PlayerDirection.up);
            break;
          case 'down':
            otherPlayer.updateDirection(PlayerDirection.down);
            break;
          case 'left':
            otherPlayer.updateDirection(PlayerDirection.left);
            break;
          case 'right':
            otherPlayer.updateDirection(PlayerDirection.right);
            break;
          case 'idle':
          default:
            otherPlayer.updateDirection(PlayerDirection.idle);
        }
      }
    });

    // World-position streaming removed: deterministic movement uses destinations only

    // Broadcast our current target grid at a low interval and forward to AoE debounce handler
    // Reuse player's onPositionChanged callback to publish grid destinations
    // De-dupe by grid and throttle to ~10 Hz
    int? _lastGridX;
    int? _lastGridY;
    DateTime? _lastBroadcastAt;
    player.onPositionChanged = (pos, {animationState}) {
      if (_userId == null) return;
      final gx = (pos.x / SimpleEnhancedFarmGame.tileSize).floor();
      final gy = (pos.y / SimpleEnhancedFarmGame.tileSize).floor();
      final now = DateTime.now();
      final shouldDeDupe = (_lastGridX == gx && _lastGridY == gy);
      final shouldThrottle = _lastBroadcastAt != null &&
          now.difference(_lastBroadcastAt!).inMilliseconds < 100; // 10 Hz

      if (!shouldDeDupe && !shouldThrottle) {
        _lastGridX = gx;
        _lastGridY = gy;
        _lastBroadcastAt = now;
        _farmPlayerService.broadcastPlayerDestination(
          farmId: farmId,
          userId: _userId!,
          targetGridX: gx,
          targetGridY: gy,
          animationState: player.currentDirection.name,
          tileSize: SimpleEnhancedFarmGame.tileSize,
        );
      }
      // Ensure local movement debounce updates AoE highlights
      _handlePlayerPositionChange(pos);

      // No continuous world-position broadcast (deterministic path)
    };
  }

  // Use the class implementation of _handlePlayerPositionChange from SimpleEnhancedFarmGame
}


