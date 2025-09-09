# Play Store Deployment Guide for Lovenest Valley

This guide will help you deploy your Flutter app to the Google Play Store with in-app purchases enabled.

## Prerequisites

1. **Google Play Console Account** - You need a developer account ($25 one-time fee)
2. **RevenueCat Account** - For managing in-app purchases
3. **App Signing Key** - For signing your release APK/AAB

## Step 1: RevenueCat Setup

### 1.1 Create RevenueCat Account
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Create a new account and project
3. Add your Android app with the package name: `com.liglus.lovenest`

### 1.2 Configure Products
1. In RevenueCat dashboard, go to "Products" → "Add Product"
2. Create your in-app purchase products:
   - Product ID: `premium_monthly` (Monthly subscription)
   - Product ID: `premium_yearly` (Yearly subscription)
   - Product ID: `premium_lifetime` (One-time purchase)

### 1.3 Get API Key
1. Go to "Project Settings" → "API Keys"
2. Copy your public API key
3. Replace `REVENUECAT_PUBLIC_API_KEY_PLACEHOLDER` in `lib/services/revenuecat_service.dart`

## Step 2: Google Play Console Setup

### 2.1 Create App
1. Go to [Google Play Console](https://play.google.com/console)
2. Click "Create app"
3. Fill in app details:
   - App name: "Lovenest Valley"
   - Default language: English
   - App or game: Game
   - Free or paid: Free (with in-app purchases)

### 2.2 Configure In-App Purchases
1. Go to "Monetize" → "Products" → "In-app products"
2. Create products matching your RevenueCat configuration:
   - `premium_monthly` - Monthly subscription
   - `premium_yearly` - Yearly subscription
   - `premium_lifetime` - One-time purchase

### 2.3 App Content Rating
1. Complete the content rating questionnaire
2. Your game should likely be rated "Everyone" or "Everyone 10+"

## Step 3: App Signing Setup

### 3.1 Generate Keystore
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 3.2 Update Build Configuration
1. Copy the generated keystore to `android/app/upload-keystore.jks`
2. Update `android/app/build.gradle.kts` with your actual keystore details:
   ```kotlin
   keyAlias = "upload"
   keyPassword = "your-actual-key-password"
   storePassword = "your-actual-store-password"
   ```

## Step 4: Build Release Version

### 4.1 Application ID
The application ID is set to `com.liglus.lovenest` for Play Store deployment.

### 4.2 Build App Bundle
```bash
flutter build appbundle --release
```

The AAB file will be created at: `build/app/outputs/bundle/release/app-release.aab`

## Step 5: Upload to Play Store

### 5.1 Create Release
1. In Play Console, go to "Release" → "Production"
2. Click "Create new release"
3. Upload your AAB file
4. Add release notes

### 5.2 Complete Store Listing
1. **App details**: Description, screenshots, feature graphic
2. **Privacy policy**: Required for apps with in-app purchases
3. **Content rating**: Complete the questionnaire
4. **Target audience**: Set appropriate age range
5. **App access**: Set to "All users" for public release

### 5.3 Pricing & Distribution
1. Set app as "Free"
2. Select countries for distribution
3. Enable in-app purchases

## Step 6: Testing In-App Purchases

### 6.1 Internal Testing
1. Create an internal testing track
2. Add testers (your email)
3. Test purchases with test accounts

### 6.2 Test Accounts
1. In Play Console, go to "Setup" → "License testing"
2. Add test email addresses
3. These accounts can make test purchases without being charged

## Step 7: Production Release

### 7.1 Final Review
1. Ensure all store listing information is complete
2. Test the app thoroughly
3. Verify in-app purchases work correctly

### 7.2 Submit for Review
1. Submit the production release
2. Google will review your app (typically 1-7 days)
3. You'll receive email notifications about the review status

## Important Notes

### Security
- Keep your keystore file secure - losing it means you can't update your app
- Store keystore passwords securely
- Never commit keystore files to version control

### RevenueCat Integration
- Ensure your RevenueCat API key is correct
- Test purchases in sandbox mode first
- Monitor purchase events in RevenueCat dashboard

### Compliance
- Ensure your app complies with Google Play policies
- Include privacy policy if you collect user data
- Follow in-app purchase guidelines

## Troubleshooting

### Common Issues
1. **Build fails**: Check keystore configuration
2. **Purchases not working**: Verify RevenueCat API key and product IDs
3. **App rejected**: Review Google Play policies and fix issues

### Support Resources
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)

## Next Steps After Release

1. Monitor app performance and crash reports
2. Track in-app purchase metrics in RevenueCat
3. Gather user feedback and plan updates
4. Consider implementing analytics for better insights
