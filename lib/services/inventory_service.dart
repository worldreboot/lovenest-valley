import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/models/inventory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class InventoryService {
  static const int maxSlots = 4;

  /// Load inventory from backend for current user
  static Future<List<InventoryItem?>> loadInventory() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      debugPrint('[InventoryService] 🔍 Current user ID: $userId');
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return List.filled(maxSlots, null);
      }

      debugPrint('[InventoryService] 📦 Loading inventory for user: $userId');

      final response = await SupabaseConfig.client
          .from('user_inventory')
          .select('*')
          .eq('user_id', userId)
          .order('slot_index');

      debugPrint('[InventoryService] 📊 Backend response: $response');

      final List<InventoryItem?> inventory = List.filled(maxSlots, null);

      for (final item in response) {
        final slotIndex = item['slot_index'] as int? ?? 0;
        if (slotIndex >= 0 && slotIndex < maxSlots) {
          inventory[slotIndex] = InventoryItem(
            id: item['item_id'],
            name: item['item_name'],
            iconPath: item['icon_path'],
            quantity: item['quantity'] ?? 1,
            itemColor: item['item_color_hex'] != null 
                ? _parseColor(item['item_color_hex']) 
                : null,
          );
        }
      }

      // Enrich daily question seeds missing color/icon from daily_question_seeds as source of truth
      try {
        final userId = SupabaseConfig.currentUserId;
        final Map<String, int> slotByQuestionId = {};
        final List<String> needColorQids = [];
        const prefix = 'daily_question_seed_';
        for (int i = 0; i < inventory.length; i++) {
          final invItem = inventory[i];
          if (invItem == null) continue;
          if (invItem.itemColor != null && invItem.iconPath != null) continue;
          final itemId = invItem.id;
          if (itemId.startsWith(prefix) && itemId.length > prefix.length) {
            final qid = itemId.substring(prefix.length);
            needColorQids.add(qid);
            slotByQuestionId[qid] = i;
          }
        }
        if (userId != null && needColorQids.isNotEmpty) {
          final colorRows = await SupabaseConfig.client
              .from('daily_question_seeds')
              .select('question_id, seed_color_hex')
              .eq('user_id', userId)
              .inFilter('question_id', needColorQids);
          final Map<String, String?> qidToHex = {
            for (final row in colorRows) row['question_id'] as String: row['seed_color_hex'] as String?
          };
          for (final entry in slotByQuestionId.entries) {
            final qid = entry.key;
            final slot = entry.value;
            final hex = qidToHex[qid];
            if (hex == null) continue;
            final updated = inventory[slot]!.copyWith(
              itemColor: _parseColor(hex),
              iconPath: inventory[slot]!.iconPath ?? 'assets/images/items/seeds.png',
            );
            inventory[slot] = updated;
            // Persist appearance so future loads are fast
            await updateItemAppearance(
              itemId: updated.id,
              iconPath: updated.iconPath,
              itemColor: updated.itemColor,
            );
          }
        }
      } catch (e) {
        debugPrint('[InventoryService] ⚠️ Enrichment of daily seed colors failed (non-fatal): $e');
      }

      debugPrint('[InventoryService] ✅ Loaded ${inventory.where((item) => item != null).length} items');
      debugPrint('[InventoryService] 📋 Inventory slots: ${inventory.map((item) => item?.name ?? 'null').toList()}');
      return inventory;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error loading inventory: $e');
      return List.filled(maxSlots, null);
    }
  }

  /// Add item to inventory (backend)
  static Future<bool> addItem(InventoryItem item, int slotIndex) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return false;
      }

      debugPrint('[InventoryService] ➕ Adding item to slot $slotIndex: ${item.name}');

      // Check if slot is occupied
      try {
        final existingItem = await SupabaseConfig.client
            .from('user_inventory')
            .select('id')
            .eq('user_id', userId)
            .eq('slot_index', slotIndex)
            .maybeSingle();

        if (existingItem != null) {
          debugPrint('[InventoryService] ❌ Slot $slotIndex is occupied');
          return false;
        }
      } catch (e) {
        // If we get multiple rows (shouldn't happen with the new constraint), 
        // clean up and try again
        if (e.toString().contains('multiple (or no) rows returned')) {
          debugPrint('[InventoryService] ⚠️ Multiple items found in slot $slotIndex, cleaning up...');
          await SupabaseConfig.client
              .from('user_inventory')
              .delete()
              .eq('user_id', userId)
              .eq('slot_index', slotIndex);
          debugPrint('[InventoryService] ✅ Cleaned up duplicate items in slot $slotIndex');
        } else {
          debugPrint('[InventoryService] ❌ Error checking slot occupancy: $e');
          return false;
        }
      }

      // Insert new item
      await SupabaseConfig.client
          .from('user_inventory')
          .insert({
            'user_id': userId,
            'item_id': item.id,
            'item_name': item.name,
            'icon_path': item.iconPath,
            'quantity': item.quantity,
            'item_color_hex': item.itemColor != null 
                ? '#${item.itemColor!.value.toRadixString(16).padLeft(8, '0')}'
                : null,
            'slot_index': slotIndex,
          });

      debugPrint('[InventoryService] ✅ Item added successfully');
      return true;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error adding item: $e');
      return false;
    }
  }

  /// Update item quantity in inventory (backend)
  static Future<bool> updateItemQuantity(String itemId, int newQuantity) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return false;
      }

      debugPrint('[InventoryService] 🔄 Updating quantity for item $itemId to $newQuantity');

      if (newQuantity <= 0) {
        // Remove item if quantity is 0 or less
        await SupabaseConfig.client
            .from('user_inventory')
            .delete()
            .eq('user_id', userId)
            .eq('item_id', itemId);
        debugPrint('[InventoryService] ✅ Item removed (quantity <= 0)');
      } else {
        // Update quantity
        await SupabaseConfig.client
            .from('user_inventory')
            .update({
              'quantity': newQuantity,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('item_id', itemId);
        debugPrint('[InventoryService] ✅ Quantity updated');
      }

      return true;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error updating item quantity: $e');
      return false;
    }
  }

  /// Update item icon path in inventory (backend)
  static Future<bool> updateItemIconPath(String itemId, String iconPath) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return false;
      }

      debugPrint('[InventoryService] 🖼️ Updating icon for item $itemId to $iconPath');

      await SupabaseConfig.client
          .from('user_inventory')
          .update({'icon_path': iconPath})
          .eq('user_id', userId)
          .eq('item_id', itemId);

      return true;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error updating item icon: $e');
      return false;
    }
  }

  /// Update item appearance (icon path and/or color) in inventory (backend)
  static Future<bool> updateItemAppearance({
    required String itemId,
    String? iconPath,
    Color? itemColor,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return false;
      }

      final Map<String, dynamic> update = {};
      if (iconPath != null) {
        update['icon_path'] = iconPath;
      }
      if (itemColor != null) {
        update['item_color_hex'] = '#${itemColor.value.toRadixString(16).padLeft(8, '0')}';
      }
      if (update.isEmpty) return true;

      debugPrint('[InventoryService] 🖼️ Updating appearance for $itemId: $update');
      await SupabaseConfig.client
          .from('user_inventory')
          .update(update)
          .eq('user_id', userId)
          .eq('item_id', itemId);
      return true;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error updating item appearance: $e');
      return false;
    }
  }

  /// Remove item from inventory (backend)
  static Future<bool> removeItem(String itemId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return false;
      }

      debugPrint('[InventoryService] 🗑️ Removing item: $itemId');

      await SupabaseConfig.client
          .from('user_inventory')
          .delete()
          .eq('user_id', userId)
          .eq('item_id', itemId);

      debugPrint('[InventoryService] ✅ Item removed successfully');
      return true;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error removing item: $e');
      return false;
    }
  }

  /// Move item to different slot (backend)
  static Future<bool> moveItem(String itemId, int newSlotIndex) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return false;
      }

      debugPrint('[InventoryService] 🔄 Moving item $itemId to slot $newSlotIndex');

      await SupabaseConfig.client
          .from('user_inventory')
          .update({
            'slot_index': newSlotIndex,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('item_id', itemId);

      debugPrint('[InventoryService] ✅ Item moved successfully');
      return true;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error moving item: $e');
      return false;
    }
  }

  /// Clear all inventory for current user (backend)
  static Future<bool> clearInventory() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[InventoryService] ❌ No current user ID');
        return false;
      }

      debugPrint('[InventoryService] 🗑️ Clearing inventory for user: $userId');

      await SupabaseConfig.client
          .from('user_inventory')
          .delete()
          .eq('user_id', userId);

      debugPrint('[InventoryService] ✅ Inventory cleared successfully');
      return true;
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error clearing inventory: $e');
      return false;
    }
  }

  /// Parse color from hex string
  static Color _parseColor(String hexString) {
    try {
      // Remove # if present
      final hex = hexString.startsWith('#') ? hexString.substring(1) : hexString;
      final value = int.parse(hex, radix: 16);
      return Color(value);
    } catch (e) {
      debugPrint('[InventoryService] ❌ Error parsing color: $e');
      return Colors.grey;
    }
  }

  /// Subscribe to real-time inventory changes
  static void subscribeToInventoryChanges(Function(List<InventoryItem?>) onInventoryChanged) {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      debugPrint('[InventoryService] ❌ No current user ID for subscription');
      return;
    }

    debugPrint('[InventoryService] 📡 Subscribing to inventory changes for user: $userId');

    // For now, we'll use a simpler approach without real-time
    // Real-time can be implemented later when needed
    debugPrint('[InventoryService] 📡 Real-time subscription not implemented yet');
  }

  /// Unsubscribe from real-time inventory changes
  static void unsubscribeFromInventoryChanges() {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;

    debugPrint('[InventoryService] 📡 Unsubscribing from inventory changes');
    // Real-time unsubscription not implemented yet
  }
} 
