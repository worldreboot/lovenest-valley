import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseConfig {
  // Replace these with your actual Supabase project URL and anon key
  static const String supabaseUrl = 'https://lxmjpdmqzblpsdhmlfrt.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4bWpwZG1xemJscHNkaG1sZnJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMDg4OTgsImV4cCI6MjA2NTU4NDg5OH0.susz8vV2t70U08PJHArcHz5hR7w8Jc9KU1nw8woH_jo';
  
  // TODO: Remove this when ready for production
  // Mock data for testing without authentication
  static const bool _testingMode = false;
  static const String _mockUserId = '835631ab-1c91-4fb9-81a5-374a5f80acc1';
  static const String _mockPartnerId = '00000000-0000-0000-0000-000000000002';
  static const String _mockCoupleId = '00000000-0000-0000-0000-000000000003';
  
  // Track connection status
  static bool _isOnline = true;
  static bool get isOnline => _isOnline;
  static bool _isInitialized = false;
  static bool _needsReauth = false;
  static bool get needsReauth => _needsReauth;
  
  static Future<void> initialize() async {
    try {
      // Test network connectivity before initializing Supabase
      await _testConnectivity();
      
      if (_isOnline) {
        try {
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseAnonKey,
            debug: true, // Set to false in production
          );
          _isInitialized = true;
          print('[SupabaseConfig] ✅ Supabase initialized successfully');
          
          // Check if there's an existing session
          try {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              print('[SupabaseConfig] ✅ Found existing session for user: ${user.id}');
              // Don't clear the session automatically - let the auth flow handle it
              _needsReauth = false;
            } else {
              print('[SupabaseConfig] ℹ️ No existing session found');
              _needsReauth = false;
            }
          } catch (e) {
            print('[SupabaseConfig] ⚠️ Error checking session: $e');
            _needsReauth = true;
          }
        } catch (e) {
          print('[SupabaseConfig] ❌ Supabase initialization failed: $e');
          
          // Check if this is a network-related error
          if (_isNetworkAuthError(e)) {
            print('[SupabaseConfig] 🔄 Network error during initialization - requiring re-auth');
            _needsReauth = true;
          }
          
          _isOnline = false;
          _isInitialized = true;
        }
      } else {
        print('[SupabaseConfig] ⚠️ Offline mode - Supabase initialization skipped');
        // Initialize with mock data for offline mode
        _isInitialized = true;
      }
    } catch (e) {
      print('[SupabaseConfig] ❌ Initialization error: $e');
      _isOnline = false;
      _isInitialized = true;
      // Continue in offline mode
    }
  }
  
  static bool _isNetworkAuthError(dynamic error) {
    final errorString = error.toString();
    return errorString.contains('AuthRetryableFetchException') ||
           errorString.contains('Network is unreachable') ||
           errorString.contains('Connection failed') ||
           errorString.contains('SocketException') ||
           errorString.contains('ClientException');
  }
  
  static Future<void> _testConnectivity() async {
    try {
      // Test basic internet connectivity
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _isOnline = true;
        print('[SupabaseConfig] ✅ Network connectivity confirmed');
      } else {
        _isOnline = false;
        print('[SupabaseConfig] ⚠️ No network connectivity detected');
      }
    } catch (e) {
      _isOnline = false;
      print('[SupabaseConfig] ⚠️ Network connectivity test failed: $e');
    }
  }
  
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('SupabaseConfig not initialized. Call SupabaseConfig.initialize() first.');
    }
    
    if (!_isOnline) {
      throw StateError('Supabase client not available in offline mode');
    }
    
    try {
      return Supabase.instance.client;
    } catch (e) {
      print('[SupabaseConfig] ⚠️ Error getting Supabase client: $e');
      throw StateError('Supabase client not available: $e');
    }
  }
  
  static User? get currentUser {
    if (!_isOnline || _needsReauth) {
      return null;
    }
    
    try {
      return client.auth.currentUser;
    } catch (e) {
      print('[SupabaseConfig] ⚠️ Error getting current user: $e');
      return null;
    }
  }
  
  // Method to validate if the current user exists in the backend
  static Future<bool> validateCurrentUser() async {
    if (!_isOnline) {
      return false;
    }
    
    try {
      final user = currentUser;
      if (user == null) {
        print('[SupabaseConfig] ❌ No current user to validate');
        return false;
      }
      
      // Check if user exists in the profiles table
      final profile = await client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      
      if (profile == null) {
        print('[SupabaseConfig] ❌ User ${user.id} not found in backend - clearing session and onboarding flag');
        // User doesn't exist in backend, clear the session
        await client.auth.signOut();
        _needsReauth = true;
        
        // Also clear the onboarding flag so user sees onboarding again
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('has_seen_onboarding');
          print('[SupabaseConfig] ✅ Onboarding flag cleared');
        } catch (e) {
          print('[SupabaseConfig] ⚠️ Error clearing onboarding flag: $e');
        }
        
        return false;
      }
      
      print('[SupabaseConfig] ✅ User ${user.id} validated in backend');
      return true;
    } catch (e) {
      print('[SupabaseConfig] ❌ Error validating user: $e');
      // On error, assume user is invalid and clear session
      try {
        await client.auth.signOut();
        _needsReauth = true;
        
        // Also clear the onboarding flag on error
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('has_seen_onboarding');
          print('[SupabaseConfig] ✅ Onboarding flag cleared due to validation error');
        } catch (e) {
          print('[SupabaseConfig] ⚠️ Error clearing onboarding flag: $e');
        }
      } catch (signOutError) {
        print('[SupabaseConfig] ❌ Error signing out after validation failure: $signOutError');
      }
      return false;
    }
  }
  
  static String? get currentUserId {
    if (_testingMode && currentUser == null) {
      return _mockUserId;
    }
    return currentUser?.id;
  }
  
  // Method to force refresh authentication state
  static Future<User?> refreshAuthState() async {
    if (!_isOnline) {
      return null;
    }
    
    try {
      // Force a refresh of the session
      final session = client.auth.currentSession;
      final user = session?.user;
      
      if (user != null) {
        print('[SupabaseConfig] ✅ Auth state refreshed - User: ${user.id}');
        _needsReauth = false;
      } else {
        print('[SupabaseConfig] ℹ️ Auth state refreshed - No user found');
        _needsReauth = false;
      }
      
      return user;
    } catch (e) {
      print('[SupabaseConfig] ❌ Error refreshing auth state: $e');
      _needsReauth = true;
      return null;
    }
  }
  
  // Mock data getters for testing
  static String get mockUserId => _mockUserId;
  static String get mockPartnerId => _mockPartnerId;
  static String get mockCoupleId => _mockCoupleId;
  static bool get isTestingMode => _testingMode;
  
  // Method to retry connection
  static Future<bool> retryConnection() async {
    await _testConnectivity();
    if (_isOnline) {
      try {
        // Check if Supabase is already initialized
        if (_isInitialized) {
          // Test the existing connection by making a simple request
          try {
            final client = Supabase.instance.client;
            // Try to access the auth state to test connectivity
            final currentUser = client.auth.currentUser;
            print('[SupabaseConfig] ✅ Existing connection is working');
            _needsReauth = false; // Reset re-auth flag on successful connection
            return true;
          } catch (e) {
            print('[SupabaseConfig] ⚠️ Existing connection failed, but Supabase is initialized: $e');
            // If the existing connection fails, we need to handle this differently
            // For now, just return false and let the user try signing in again
            return false;
          }
        } else {
          // Supabase is not initialized, so we can initialize it
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseAnonKey,
            debug: true,
          );
          _isInitialized = true;
          _needsReauth = false; // Reset re-auth flag on successful connection
          print('[SupabaseConfig] ✅ Connection restored');
          return true;
        }
      } catch (e) {
        print('[SupabaseConfig] ❌ Reconnection failed: $e');
        return false;
      }
    }
    return false;
  }
  
  // Safe client access method for offline-aware code
  static SupabaseClient? get clientOrNull {
    if (!_isInitialized || !_isOnline) {
      return null;
    }
    
    try {
      return Supabase.instance.client;
    } catch (e) {
      return null;
    }
  }
  
  // Method to clear re-auth flag after successful sign-in
  static void clearReauthFlag() {
    _needsReauth = false;
  }
  
  
  // Enhanced authentication validation method
  static Future<bool> isAuthenticated() async {
    if (!_isOnline || _needsReauth) {
      return false;
    }
    
    try {
      final user = currentUser;
      if (user == null) {
        return false;
      }
      
      // Check if session is still valid
      final session = client.auth.currentSession;
      if (session == null || session.isExpired) {
        print('[SupabaseConfig] ⚠️ Session expired or invalid');
        _needsReauth = true;
        return false;
      }
      
      return true;
    } catch (e) {
      print('[SupabaseConfig] ⚠️ Error checking authentication: $e');
      _needsReauth = true;
      return false;
    }
  }
  
  // Safe database operation wrapper
  static Future<T> safeDbOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? fallbackValue,
  }) async {
    try {
      // Check authentication first
      if (!await isAuthenticated()) {
        throw Exception('User not authenticated for ${operationName ?? 'database operation'}');
      }
      
      return await operation();
    } catch (e) {
      if (e.toString().contains('PostgrestException') && 
          e.toString().contains('Not authenticated')) {
        print('[SupabaseConfig] ❌ Authentication error in ${operationName ?? 'database operation'}: $e');
        _needsReauth = true;
        throw Exception('Authentication required. Please sign in again.');
      }
      
      // Re-throw other errors
      rethrow;
    }
  }
  
  
  // Check if user is authenticated and throw if not
  static void requireAuthentication({String? operation}) {
    if (!_isOnline) {
      throw Exception('App is offline. Cannot perform ${operation ?? 'operation'}.');
    }
    
    if (_needsReauth) {
      throw Exception('Authentication required. Please sign in again.');
    }
    
    final user = currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please sign in to ${operation ?? 'perform this action'}.');
    }
  }
  
  // Method to clear all local authentication data
  static Future<void> clearAllAuthData() async {
    try {
      if (_isInitialized && _isOnline) {
        // Sign out from Supabase to clear the session
        await client.auth.signOut();
        print('[SupabaseConfig] ✅ Local auth session cleared');
      }
      
      // Clear the re-auth flag
      _needsReauth = false;
      
      // Clear any cached user data
      _isInitialized = false;
      _isOnline = true;
      
      // Re-initialize to get a fresh state
      await initialize();
      
      print('[SupabaseConfig] ✅ All authentication data cleared and re-initialized');
    } catch (e) {
      print('[SupabaseConfig] ❌ Error clearing auth data: $e');
    }
  }
  
  // Method to clear all local storage data
  static Future<void> clearAllLocalData() async {
    try {
      // Clear auth data first
      await clearAllAuthData();
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('[SupabaseConfig] ✅ All SharedPreferences cleared');
      
      print('[SupabaseConfig] ✅ All local data cleared');
    } catch (e) {
      print('[SupabaseConfig] ❌ Error clearing local data: $e');
    }
  }
} 
