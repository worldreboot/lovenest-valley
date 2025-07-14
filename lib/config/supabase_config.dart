import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Replace these with your actual Supabase project URL and anon key
  static const String supabaseUrl = 'https://lxmjpdmqzblpsdhmlfrt.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4bWpwZG1xemJscHNkaG1sZnJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMDg4OTgsImV4cCI6MjA2NTU4NDg5OH0.susz8vV2t70U08PJHArcHz5hR7w8Jc9KU1nw8woH_jo';
  
  // TODO: Remove this when ready for production
  // Mock data for testing without authentication
  static const bool _testingMode = true;
  static const String _mockUserId = '835631ab-1c91-4fb9-81a5-374a5f80acc1';
  static const String _mockPartnerId = '00000000-0000-0000-0000-000000000002';
  static const String _mockCoupleId = '00000000-0000-0000-0000-000000000003';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Set to false in production
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  
  static String? get currentUserId {
    if (_testingMode && currentUser == null) {
      return _mockUserId;
    }
    return currentUser?.id;
  }
  
  // Mock data getters for testing
  static String get mockUserId => _mockUserId;
  static String get mockPartnerId => _mockPartnerId;
  static String get mockCoupleId => _mockCoupleId;
  static bool get isTestingMode => _testingMode;
} 