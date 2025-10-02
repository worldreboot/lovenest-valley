# Superwall Setup Guide for Lovenest Valley

This guide will help you set up Superwall for in-app purchases and paywall management in your Flutter app.

## Prerequisites

1. **Superwall Account** - Create an account at [Superwall Dashboard](https://superwall.com/dashboard)
2. **Google Play Console Account** - For Android in-app purchases
3. **App Store Connect Account** - For iOS in-app purchases

## Step 1: Superwall Dashboard Setup

### 1.1 Create Superwall Account
1. Go to [Superwall Dashboard](https://superwall.com/dashboard)
2. Create a new account and project
3. Add your apps:
   - Android: Package name `com.liglius.lovenest`
   - iOS: Bundle ID (from your iOS project)

### 1.2 Get API Key
1. Go to "Project Settings" → "API Keys"
2. Copy your public API key
3. Replace `SUPERWALL_API_KEY_PLACEHOLDER` in `lib/services/superwall_service.dart`

### 1.3 Configure Products
1. Go to "Products" → "Add Product"
2. Create your subscription products:
   - Product ID: `premium_monthly` (Monthly subscription)
   - Product ID: `premium_yearly` (Yearly subscription)
   - Product ID: `premium_lifetime` (One-time purchase)

### 1.4 Configure Paywalls
1. Go to "Paywalls" → "Create Paywall"
2. Design your paywall UI in the Superwall dashboard
3. Set the placement ID to `premium` (or customize as needed)

## Step 2: Google Play Console Setup (Android)

### 2.1 Create In-App Products
1. Go to "Monetize" → "Products" → "In-app products"
2. Create products matching your Superwall configuration:
   - `premium_monthly` - Monthly subscription
   - `premium_yearly` - Yearly subscription
   - `premium_lifetime` - One-time purchase

### 2.2 Configure Subscription Products
1. Go to "Monetize" → "Products" → "Subscriptions"
2. Create subscription products for monthly and yearly options
3. Set pricing and billing periods

## Step 3: App Store Connect Setup (iOS)

### 3.1 Create In-App Purchases
1. Go to App Store Connect → Your App → Features → In-App Purchases
2. Create products matching your Superwall configuration:
   - `premium_monthly` - Monthly subscription
   - `premium_yearly` - Yearly subscription
   - `premium_lifetime` - One-time purchase

## Step 4: Code Configuration

### 4.1 Update API Key ✅ **COMPLETED**
API key has been configured in `lib/services/superwall_service.dart`:
```dart
static const String _apiKey = 'pk_BdDDDSCh5un6KIdE-18fJ';
```

### 4.2 Enable Paywall
Set `kPaywallEnabled = true` in `lib/config/feature_flags.dart`:
```dart
const bool kPaywallEnabled = true;
```

### 4.3 Customize Placement ID
Update the placement ID in your paywall screens if needed:
```dart
SuperwallPaywallScreen(placement: 'your_custom_placement')
```

## Step 5: Testing

### 5.1 Test Accounts
1. Add test accounts to Google Play Console and App Store Connect
2. These accounts can make test purchases without being charged

### 5.2 Test Purchases
1. Use test accounts to make purchases
2. Verify that:
   - Paywall shows correctly
   - Purchase flow completes
   - Entitlement is granted after purchase
   - App functions correctly with premium access

## Configuration Checklist

- [ ] Superwall API key updated
- [ ] Product IDs match between stores and Superwall
- [ ] Paywall designed in Superwall dashboard
- [ ] Test accounts added to stores
- [ ] Paywall shows subscription options
- [ ] Purchase flow completes
- [ ] Entitlement granted after purchase
- [ ] App functions with premium access

## Common Issues

1. **"Paywall not showing"**: Check Superwall API key and placement ID
2. **"Purchase failed"**: Ensure test account is configured
3. **"Product not found"**: Check product IDs match exactly
4. **"Entitlement not granted"**: Verify Superwall delegate configuration

## Resources

- [Superwall Documentation](https://superwall.com/docs)
- [Superwall Flutter SDK](https://superwall.com/docs/flutter)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
