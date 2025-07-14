import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return; // User cancelled
    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw 'No Access Token found.';
    }
    if (idToken == null) {
      throw 'No ID Token found.';
    }

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
} 