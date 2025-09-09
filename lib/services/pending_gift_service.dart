import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/models/inventory.dart';

class PendingGiftService {
  static const String _prefsKey = 'pending_gift_deliveries_v1';

  /// Schedule a gift delivery for the next day by storing the generation job ID locally
  static Future<void> scheduleGiftDelivery({
    required String jobId,
    String? description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final String deliverOn = _nextDay(today);

    final List<dynamic> existing = jsonDecode(prefs.getString(_prefsKey) ?? '[]');
    existing.add({
      'jobId': jobId,
      'description': description ?? '',
      'deliverOn': deliverOn,
      'delivered': false,
    });
    await prefs.setString(_prefsKey, jsonEncode(existing));
  }

  /// Sync due gifts by updating DB rows to 'completed' when their generation jobs are finished.
  /// Does NOT add to inventory; use the Gifts Inbox UI to collect.
  static Future<int> syncDueGifts() async {
    final int updatedFromDb = await _syncFromDatabase();
    final int updatedFromLocal = await _syncFromLocal();
    return updatedFromDb + updatedFromLocal;
  }

  static Future<int> _syncFromDatabase() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return 0;
    final today = DateTime.now().toUtc();
    final todayDateStr = DateTime.utc(today.year, today.month, today.day).toIso8601String().substring(0, 10);

    int updatedCount = 0;
    try {
      final List<dynamic> gifts = await SupabaseConfig.client
          .from('gifts')
          .select('id, job_id, status, deliver_on, sprite_url')
          .eq('user_id', userId)
          .or('status.eq.scheduled,status.eq.generating')
          .lte('deliver_on', todayDateStr);

      for (final g in gifts) {
        final String giftId = g['id'] as String;
        final String? jobId = g['job_id'] as String?;
        String? spriteUrl = g['sprite_url'] as String?;
        String status = (g['status'] as String?) ?? 'generating';

        // If sprite not set, try to read job completion
        if (spriteUrl == null && jobId != null) {
          final job = await SupabaseConfig.client
              .from('generation_jobs')
              .select('status, final_image_url')
              .eq('id', jobId)
              .maybeSingle();
          if (job != null && job['status'] == 'completed') {
            spriteUrl = job['final_image_url'] as String?;
            await SupabaseConfig.client
                .from('gifts')
                .update({
                  'sprite_url': spriteUrl,
                  'status': 'completed',
                })
                .eq('id', giftId);
            status = 'completed';
            updatedCount += 1;
          }
        }
      }
    } catch (e) {
      debugPrint('[PendingGiftService] DB sync error: $e');
    }
    return updatedCount;
  }

  static Future<int> _syncFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final List<dynamic> entries = jsonDecode(prefs.getString(_prefsKey) ?? '[]');
    bool changed = false;
    int updatedCount = 0;

    for (final entry in entries) {
      if (entry is Map<String, dynamic>) {
        final bool delivered = entry['delivered'] == true;
        final String? deliverOn = entry['deliverOn'] as String?;
        final String? jobId = entry['jobId'] as String?;
        if (!delivered && jobId != null && deliverOn != null && deliverOn.compareTo(today) <= 0) {
          // Check generation job status
          final job = await SupabaseConfig.client
              .from('generation_jobs')
              .select('status, final_image_url')
              .eq('id', jobId)
              .maybeSingle();

          if (job != null && job['status'] == 'completed') {
            final String? spriteUrl = job['final_image_url'] as String?;
            if (spriteUrl != null) {
              // Mark as synced locally to avoid repeated checks
              entry['delivered'] = true;
              changed = true;
              updatedCount += 1;
            }
          }
        }
      }
    }

    if (changed) {
      await prefs.setString(_prefsKey, jsonEncode(entries));
    }

    return updatedCount;
  }

  /// Fetch gifts ready to collect (completed and due), not yet delivered.
  static Future<List<Map<String, dynamic>>> fetchCollectibleGifts() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return [];
    final today = DateTime.now().toUtc();
    final todayDateStr = DateTime.utc(today.year, today.month, today.day).toIso8601String().substring(0, 10);
    try {
      final List<dynamic> rows = await SupabaseConfig.client
          .from('gifts')
          .select('id, prompt, sprite_url, created_at, deliver_on')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .lte('deliver_on', todayDateStr)
          .order('created_at', ascending: false);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[PendingGiftService] fetchCollectibleGifts error: $e');
      return [];
    }
  }

  /// Collect a specific gift: checks inventory space, adds item, and marks delivered.
  static Future<bool> collectGift({
    required String giftId,
    required String? spriteUrl,
    required InventoryManager inventoryManager,
  }) async {
    // Pre-check space
    final hasEmpty = inventoryManager.slots.any((s) => s == null);
    if (!hasEmpty) {
      return false;
    }
    final added = await inventoryManager.addItem(InventoryItem(
      id: 'gift_$giftId',
      name: 'Gift',
      iconPath: spriteUrl,
      quantity: 1,
    ));
    if (!added) return false;
    try {
      await SupabaseConfig.client
          .from('gifts')
          .update({
            'status': 'delivered',
            'delivered_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', giftId);
    } catch (e) {
      debugPrint('[PendingGiftService] collectGift update error: $e');
    }
    return true;
  }

  static String _nextDay(String yyyymmdd) {
    final date = DateTime.parse(yyyymmdd);
    final next = date.add(const Duration(days: 1));
    return next.toIso8601String().substring(0, 10);
  }
}


