# Google Sign-In Configuration Update Guide

Since we changed the package name to `com.liglus.lovenest`, you need to update your Google Sign-In configuration.

## Step 1: Update Firebase Console

### 1.1 Go to Firebase Console
1. Visit [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`tunetown-59caf`)

### 1.2 Update Authentication Settings
1. Go to "Authentication" → "Sign-in method"
2. Click on "Google" provider
3. Make sure it's enabled
4. Add your new package name to the authorized domains if needed

### 1.3 Update OAuth Client Configuration
1. Go to "Project Settings" → "General"
2. Scroll down to "Your apps" section
3. Find your Android app with package name `com.liglus.lovenest`
4. Click on the app to view details
5. Note the OAuth 2.0 Client ID (you'll need this)

## Step 2: Update Google Cloud Console (if needed)

### 2.1 Go to Google Cloud Console
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project

### 2.2 Update OAuth Consent Screen
1. Go to "APIs & Services" → "OAuth consent screen"
2. Add your new package name to authorized domains if needed

### 2.3 Update OAuth 2.0 Client IDs
1. Go to "APIs & Services" → "Credentials"
2. Find the OAuth 2.0 Client ID for your Android app
3. Update the package name to `com.liglus.lovenest`
4. Add the SHA-1 fingerprint for your release keystore

## Step 3: Get SHA-1 Fingerprint for Release Keystore

Run this command to get your release keystore's SHA-1 fingerprint:

```powershell
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload -storepass lovenest123
```

Look for the "SHA1" fingerprint in the output.

## Step 4: Update Google Cloud Console with SHA-1

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to "APIs & Services" → "Credentials"
3. Find your Android OAuth 2.0 Client ID
4. Add the SHA-1 fingerprint from your release keystore
5. Save the changes

## Step 5: Test Google Sign-In

After updating the configuration:

1. Build and install your app
2. Test Google Sign-In functionality
3. Verify that users can sign in successfully

## Troubleshooting

### Common Issues:
1. **"Sign in failed"**: Check that the package name matches exactly
2. **"OAuth client not found"**: Verify the SHA-1 fingerprint is correct
3. **"Invalid package name"**: Ensure the package name is registered in Firebase

### Verification Steps:
- [ ] Package name is `com.liglus.lovenest` in Firebase
- [ ] SHA-1 fingerprint is added to Google Cloud Console
- [ ] Google Sign-In provider is enabled in Firebase
- [ ] OAuth consent screen is configured

## Quick Commands

```powershell
# Get SHA-1 fingerprint
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload -storepass lovenest123

# Build and test
.\build_closed_testing.ps1
```

## Important Notes

- **Development vs Production**: You may need different OAuth client IDs for debug and release builds
- **SHA-1 Fingerprints**: Both debug and release keystores need their SHA-1 fingerprints registered
- **Package Name**: Must match exactly between your app and Firebase configuration
