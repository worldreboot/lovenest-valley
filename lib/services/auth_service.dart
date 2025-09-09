import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static Future<void> signInWithGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
    );
  }

  static Future<void> signInWithGoogleNative() async {
    /// TODO: update the Web client ID with your own.
    /// Web Client ID that you registered with Google Cloud.
    const webClientId = '1021335959685-i7mcdsisng25g8ghsan6msa6kkahnfn4.apps.googleusercontent.com';

    /// TODO: update the iOS client ID with your own.
    /// iOS Client ID that you registered with Google Cloud.
    const iosClientId = 'my-ios.apps.googleusercontent.com';

    try {
      debugPrint('[AuthService] 🔐 Starting Google sign-in process...');
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      
      // Force account picker every time
      debugPrint('[AuthService] 🔄 Signing out from Google to force account picker...');
      await googleSignIn.signOut();
      
      debugPrint('[AuthService] 📱 Requesting Google sign-in...');
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('[AuthService] ❌ User cancelled Google sign-in');
        return; // User cancelled
      }
      
      debugPrint('[AuthService] ✅ Google user obtained: ${googleUser.email}');
      
      debugPrint('[AuthService] 🔑 Getting Google authentication tokens...');
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw Exception('No Access Token found from Google.');
      }
      if (idToken == null) {
        throw Exception('No ID Token found from Google.');
      }

      debugPrint('[AuthService] ✅ Google tokens obtained successfully');
      debugPrint('[AuthService] 🔐 Signing in to Supabase with Google tokens...');

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      debugPrint('[AuthService] ✅ Successfully signed in to Supabase with Google');
      
      // Verify the session was established
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        debugPrint('[AuthService] ✅ Session verified - User ID: ${currentUser.id}');
      } else {
        debugPrint('[AuthService] ⚠️ Session verification failed - no current user');
      }
      
    } catch (e) {
      debugPrint('[AuthService] ❌ Google sign-in failed: $e');
      rethrow; // Re-throw to let the calling code handle the error
    }
  }

  static Future<void> signInWithApple() async {
    try {
      debugPrint('[AuthService] 🍎 Starting Apple sign-in process...');

      // Request Apple ID credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint('[AuthService] ✅ Apple credentials obtained');

      // Extract the identity token
      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        throw Exception('No identity token found from Apple sign-in');
      }

      debugPrint('[AuthService] 🔑 Got identity token from Apple');

      // Sign in to Supabase with the Apple identity token
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
      );

      debugPrint('[AuthService] ✅ Successfully signed in to Supabase with Apple');

      // Verify the session was established
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        debugPrint('[AuthService] ✅ Session verified - User ID: ${currentUser.id}');
      } else {
        debugPrint('[AuthService] ⚠️ Session verification failed - no current user');
      }

    } catch (e) {
      debugPrint('[AuthService] ❌ Apple sign-in failed: $e');
      rethrow; // Re-throw to let the calling code handle the error
    }
  }

  static Future<void> signOut() async {
    try {
      debugPrint('[AuthService] 🚪 Signing out from Supabase...');
      await Supabase.instance.client.auth.signOut();
      debugPrint('[AuthService] ✅ Successfully signed out from Supabase');
      
      // Also sign out from Google
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        debugPrint('[AuthService] ✅ Successfully signed out from Google');
      } catch (e) {
        debugPrint('[AuthService] ⚠️ Error signing out from Google: $e');
      }

      // Note: Apple Sign-In doesn't require explicit sign out as it doesn't maintain a persistent session
      // The Supabase session cleanup is sufficient
    } catch (e) {
      debugPrint('[AuthService] ❌ Error signing out: $e');
      rethrow;
    }
  }
} 
