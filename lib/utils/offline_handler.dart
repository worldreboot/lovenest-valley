import 'package:flutter/material.dart';
import 'package:lovenest_valley/config/supabase_config.dart';

class OfflineHandler {
  /// Wraps a Supabase operation with offline mode handling
  static Future<T?> withOfflineHandling<T>(
    Future<T?> Function() operation, {
    T? offlineFallback,
    String? errorMessage,
  }) async {
    try {
      if (!SupabaseConfig.isOnline) {
        print('[OfflineHandler] ⚠️ Operation skipped - offline mode');
        return offlineFallback;
      }
      
      return await operation();
    } catch (e) {
      if (e.toString().contains('offline mode') || 
          e.toString().contains('not available') ||
          e.toString().contains('Network is unreachable')) {
        print('[OfflineHandler] ⚠️ Network error - returning offline fallback');
        return offlineFallback;
      }
      
      print('[OfflineHandler] ❌ Operation failed: $e');
      if (errorMessage != null) {
        print('[OfflineHandler] Error message: $errorMessage');
      }
      rethrow;
    }
  }
  
  /// Shows offline mode dialog
  static void showOfflineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Internet Connection'),
        content: const Text(
          'This feature requires an internet connection. Please check your connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Checks if we're in offline mode and shows dialog if needed
  static bool checkOfflineMode(BuildContext context, {bool showDialog = true}) {
    if (!SupabaseConfig.isOnline) {
      if (showDialog) {
        showOfflineDialog(context);
      }
      return true;
    }
    return false;
  }
}
