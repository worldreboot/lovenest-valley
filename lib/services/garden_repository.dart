import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import '../models/memory_garden/seed.dart';
import '../models/memory_garden/couple.dart';
import '../models/memory_garden/water_reply.dart';

class GardenRepository {
  static const String _seedsTable = 'seeds';
  static const String _couplesTable = 'couples';
  static const String _watersTable = 'waters_and_replies';
  static const String _storageBucket = 'memory-media';

  const GardenRepository();

  /// Get the current user's couple information
  Future<Couple?> getUserCouple() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return null;

    // Return mock couple for testing
    if (SupabaseConfig.isTestingMode && SupabaseConfig.currentUser == null) {
      return Couple(
        id: SupabaseConfig.mockCoupleId,
        user1Id: SupabaseConfig.mockUserId,
        user2Id: SupabaseConfig.mockPartnerId,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );
    }

    final response = await SupabaseConfig.client
        .from(_couplesTable)
        .select()
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .maybeSingle();

    return response != null ? Couple.fromJson(response) : null;
  }

  /// Create a new couple relationship
  Future<Couple> createCouple(String partnerUserId) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final coupleData = {
      'id': const Uuid().v4(),
      'user1_id': userId,
      'user2_id': partnerUserId,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await SupabaseConfig.client
        .from(_couplesTable)
        .insert(coupleData)
        .select()
        .single();

    return Couple.fromJson(response);
  }

  /// Get real-time stream of seeds for the user's garden
  Stream<List<Seed>> getGardenStream() async* {
    final couple = await getUserCouple();
    if (couple == null) {
      yield [];
      return;
    }

    // Return empty stream for testing mode
    if (SupabaseConfig.isTestingMode && SupabaseConfig.currentUser == null) {
      yield <Seed>[];
      return;
    }

    yield* SupabaseConfig.client
        .from(_seedsTable)
        .stream(primaryKey: ['id'])
        .eq('couple_id', couple.id)
        .order('created_at')
        .map((data) => data.map((json) => Seed.fromJson(json)).toList());
  }

  /// Get all seeds for the current user's garden (non-streaming)
  Future<List<Seed>> getGardenSeeds() async {
    final couple = await getUserCouple();
    if (couple == null) return [];

    // Return empty list for testing mode
    if (SupabaseConfig.isTestingMode && SupabaseConfig.currentUser == null) {
      return <Seed>[];
    }

    final response = await SupabaseConfig.client
        .from(_seedsTable)
        .select()
        .eq('couple_id', couple.id)
        .order('created_at');

    return response.map<Seed>((json) => Seed.fromJson(json)).toList();
  }

  /// Plant a new seed with media upload
  Future<Seed> plantSeed({
    required MediaType mediaType,
    required PlotPosition plotPosition,
    File? mediaFile,
    Uint8List? mediaBytes,
    String? textContent,
    required String secretHope,
    String? questionId, // <-- add this
  }) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final couple = await getUserCouple();
    // Allow planting daily question seeds even if not in a couple
    if (couple == null && !(mediaType == MediaType.text && questionId != null)) {
      throw Exception('No couple relationship found');
    }

    // Return mock seed for testing mode
    if (SupabaseConfig.isTestingMode && SupabaseConfig.currentUser == null) {
      return Seed(
        id: const Uuid().v4(),
        coupleId: couple?.id ?? '',
        planterId: userId,
        mediaType: mediaType,
        mediaUrl: null,
        textContent: textContent,
        secretHope: secretHope,
        state: SeedState.sprout,
        growthScore: 0,
        plotPosition: plotPosition,
        bloomVariantSeed: null,
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
      );
    }

    // Upload media if provided
    String? mediaUrl;
    if (mediaFile != null || mediaBytes != null) {
      mediaUrl = await _uploadMedia(
        coupleId: couple?.id ?? '', // Use couple.id or a default if couple is null
        mediaType: mediaType,
        file: mediaFile,
        bytes: mediaBytes,
      );
    }

    // Prepare seed data
    final seedData = {
      'couple_id': couple?.id, // can be null for daily question seeds
      'planter_id': userId,
      'media_type': mediaType.name,
      'media_url': mediaUrl,
      'text_content': textContent,
      'secret_hope': secretHope,
      'state': 'sprout',
      'growth_score': 0,
      'plot_x': plotPosition.x,
      'plot_y': plotPosition.y,
      'bloom_variant_seed': null,
      'question_id': questionId,
    };

    final response = await SupabaseConfig.client
        .from(_seedsTable)
        .insert(seedData)
        .select()
        .single();

    return Seed.fromJson(response);
  }

  /// Water a sprout or add interaction
  Future<WaterReply> waterSprout({
    required String seedId,
    required InteractionType type,
    File? mediaFile,
    Uint8List? mediaBytes,
    String? textContent,
  }) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final couple = await getUserCouple();
    if (couple == null) throw Exception('No couple relationship found');

    // Return mock water reply for testing mode
    if (SupabaseConfig.isTestingMode && SupabaseConfig.currentUser == null) {
      return WaterReply(
        id: const Uuid().v4(),
        seedId: seedId,
        userId: SupabaseConfig.mockUserId,
        type: type,
        contentUrl: null, // No actual media upload in testing
        textContent: textContent,
        createdAt: DateTime.now(),
      );
    }

    // Upload media if provided
    String? contentUrl;
    if (mediaFile != null || mediaBytes != null) {
      contentUrl = await _uploadMedia(
        coupleId: couple.id,
        mediaType: type == InteractionType.replyVoice 
            ? MediaType.voice 
            : MediaType.photo,
        file: mediaFile,
        bytes: mediaBytes,
      );
    }

    // Create interaction record
    final interactionData = {
      'id': const Uuid().v4(),
      'seed_id': seedId,
      'user_id': userId,
      'type': _typeToString(type),
      'content_url': contentUrl,
      'text_content': textContent,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await SupabaseConfig.client
        .from(_watersTable)
        .insert(interactionData)
        .select()
        .single();

    // Update seed's last_updated_at and potentially growth_score
    await _updateSeedGrowth(seedId);

    return WaterReply.fromJson(response);
  }

  /// Get all interactions for a specific seed
  Future<List<WaterReply>> getSeedInteractions(String seedId) async {
    // Return empty list for testing mode
    if (SupabaseConfig.isTestingMode && SupabaseConfig.currentUser == null) {
      return <WaterReply>[];
    }

    final response = await SupabaseConfig.client
        .from(_watersTable)
        .select()
        .eq('seed_id', seedId)
        .order('created_at');

    return response.map<WaterReply>((json) => WaterReply.fromJson(json)).toList();
  }

  /// Find an empty plot position
  Future<PlotPosition?> findEmptyPlotPosition() async {
    final seeds = await getGardenSeeds();
    final occupiedPositions = seeds.map((s) => s.plotPosition).toSet();

    // Simple grid layout: 10x10 grid
    for (int x = 0; x < 10; x++) {
      for (int y = 0; y < 10; y++) {
        final position = PlotPosition(x.toDouble(), y.toDouble());
        if (!occupiedPositions.contains(position)) {
          return position;
        }
      }
    }
    return null; // Garden is full
  }

  /// Generate bloom variant seed for procedural generation
  String generateBloomVariantSeed(Seed seed) {
    final input = '${seed.mediaType.name}_${seed.growthScore}_${seed.id}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Upload media file to Supabase Storage
  Future<String> _uploadMedia({
    required String coupleId,
    required MediaType mediaType,
    File? file,
    Uint8List? bytes,
  }) async {
    if (file == null && bytes == null) {
      throw ArgumentError('Either file or bytes must be provided');
    }

    final userId = SupabaseConfig.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getExtensionForMediaType(mediaType, file);
    final filename = '${timestamp}_${const Uuid().v4()}$extension';
    final filePath = '$coupleId/$filename';

    // Upload to storage
    if (file != null) {
      await SupabaseConfig.client.storage
          .from(_storageBucket)
          .upload(filePath, file);
    } else if (bytes != null) {
      await SupabaseConfig.client.storage
          .from(_storageBucket)
          .uploadBinary(filePath, bytes);
    }

    // Return the storage path (not the full URL)
    return filePath;
  }

  /// Get the file extension for a media type
  String _getExtensionForMediaType(MediaType mediaType, File? file) {
    if (file != null) {
      return path.extension(file.path);
    }

    switch (mediaType) {
      case MediaType.photo:
        return '.jpg';
      case MediaType.voice:
        return '.m4a';
      case MediaType.text:
        return '.txt';
      case MediaType.link:
        return '.url';
    }
  }

  /// Update seed growth based on interactions
  Future<void> _updateSeedGrowth(String seedId) async {
    // Get interaction count for this seed
    final interactions = await getSeedInteractions(seedId);
    final waterCount = interactions.where((i) => i.type == InteractionType.water).length;
    
    // Simple growth logic: every 2 waters increases growth score
    final newGrowthScore = (waterCount / 2).floor();

    await SupabaseConfig.client
        .from(_seedsTable)
        .update({
          'growth_score': newGrowthScore,
          'last_updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', seedId);
  }

  /// Get public URL for media file
  Future<String?> getMediaUrl(String? mediaPath) async {
    if (mediaPath == null) return null;
    
    try {
      return SupabaseConfig.client.storage
          .from(_storageBucket)
          .getPublicUrl(mediaPath);
    } catch (e) {
      return null;
    }
  }

  /// Check if both partners have watered a seed (for bloom eligibility)
  Future<bool> hasBeenWateredByBothPartners(String seedId) async {
    final couple = await getUserCouple();
    if (couple == null) return false;

    final interactions = await getSeedInteractions(seedId);
    final waterInteractions = interactions.where((i) => i.type == InteractionType.water);
    
    final user1Watered = waterInteractions.any((i) => i.userId == couple.user1Id);
    final user2Watered = waterInteractions.any((i) => i.userId == couple.user2Id);
    
    return user1Watered && user2Watered;
  }

  /// Convert InteractionType to string for database storage
  String _typeToString(InteractionType type) {
    switch (type) {
      case InteractionType.water:
        return 'water';
      case InteractionType.replyVoice:
        return 'reply_voice';
      case InteractionType.replyText:
        return 'reply_text';
      case InteractionType.reaction:
        return 'reaction';
    }
  }

  /// Send a couple invite (creates a pending invite in farm_invites)
  Future<void> sendCoupleInvite({required String partnerUserId, required String partnerUsername}) async {
    // Deprecated: farm_invites is replaced by couple_invites and RPCs. Kept for backward compat but no-op.
    debugPrint('[GardenRepository] sendCoupleInvite is deprecated. Use CoupleLinkService.createInvite instead.');
  }

  /// Accept couple invite flow has moved to RPC redeem_couple_invite. Deprecated here.
  Future<Couple> acceptCoupleInvite({required String inviterId, required String inviteId}) async {
    throw UnimplementedError('Use CoupleLinkService.redeem(code) instead');
  }
  
  /// Connect invitee to inviter's farm for real-time multiplayer interactions
  /// Note: The inviter becomes User 1 in the couple relationship
  // Kept for backward compatibility; may be referenced by older flows.
  // ignore: unused_element
  Future<void> _connectToPartnerFarm(String inviterId, String inviteeId) async {
    try {
      debugPrint('[GardenRepository] Connecting invitee to partner farm: inviterId=$inviterId, inviteeId=$inviteeId');
      debugPrint('[GardenRepository] Inviter will be User 1 in the couple relationship');
      
      final client = SupabaseConfig.client;
      
      // 1. Get inviter's farm (this will be User 1's farm)
      var inviterFarm = await client
          .from('farms')
          .select('id')
          .eq('owner_id', inviterId)
          .maybeSingle();
      
      if (inviterFarm == null) {
        debugPrint('[GardenRepository] No farm found for inviter (User 1), creating one');
        // Create a farm for the inviter if they don't have one
        final newFarm = await client
            .from('farms')
            .insert({
              'owner_id': inviterId,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        inviterFarm = newFarm;
      }
      
      final inviterFarmId = inviterFarm['id'] as String;
      debugPrint('[GardenRepository] Using inviter farm (User 1\'s farm): $inviterFarmId');
      
      // 2. Remove any existing farm for the invitee (they'll share User 1's farm)
      final inviteeFarm = await client
          .from('farms')
          .select('id')
          .eq('owner_id', inviteeId)
          .maybeSingle();
      
      if (inviteeFarm != null) {
        final inviteeFarmId = inviteeFarm['id'] as String;
        debugPrint('[GardenRepository] Removing invitee farm: $inviteeFarmId');
        
        // Delete invitee's farm tiles first
        await client
            .from('farm_tiles')
            .delete()
            .eq('farm_id', inviteeFarmId);
        
        // Delete invitee's farm
        await client
            .from('farms')
            .delete()
            .eq('id', inviteeFarmId);
      }
      
      // 3. Update inviter's farm to include invitee as partner_id
      await client
          .from('farms')
          .update({'partner_id': inviteeId})
          .eq('id', inviterFarmId);
      
      debugPrint('[GardenRepository] Successfully connected invitee to User 1\'s farm with partner_id set');
      debugPrint('[GardenRepository] Both users will now load User 1\'s farm: $inviterFarmId');
      
    } catch (e) {
      debugPrint('[GardenRepository] Error connecting to partner farm: $e');
      // Don't throw here - the couple creation was successful, this is just for real-time features
    }
  }
} 