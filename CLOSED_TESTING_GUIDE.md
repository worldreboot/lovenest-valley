# Closed Testing Guide for Lovenest Valley

This guide will help you set up closed testing with subscriptions for your Flutter app.

## Quick Start for Closed Testing

### 1. Build the App
```powershell
.\build_closed_testing.ps1
```

### 2. Google Play Console Setup

#### 2.1 Create App (if not done)
1. Go to [Google Play Console](https://play.google.com/console)
2. Click "Create app"
3. Fill in basic details:
   - App name: "Lovenest Valley"
   - Default language: English
   - App or game: Game
   - Free or paid: Free (with in-app purchases)

#### 2.2 Set Up Internal Testing Track
1. Go to "Testing" → "Internal testing"
2. Click "Create new release"
3. Upload your AAB file (`build/app/outputs/bundle/release/app-release.aab`)
4. Add release notes (e.g., "Initial closed testing release with subscriptions")
5. Save and review release

#### 2.3 Add Testers
1. In Internal testing, click "Testers"
2. Add email addresses of people who should test the app
3. Share the testing link with them

### 3. Configure Subscriptions

#### 3.1 Create Subscription Products
1. Go to "Monetize" → "Products" → "Subscriptions"
2. Click "Create subscription"
3. Create these subscriptions:

**Monthly Premium:**
- Product ID: `premium_monthly`
- Name: "Premium Monthly"
- Description: "Monthly premium access to all features"
- Price: Set your desired price
- Billing period: Monthly

**Yearly Premium:**
- Product ID: `premium_yearly`
- Name: "Premium Yearly"
- Description: "Yearly premium access to all features"
- Price: Set your desired price
- Billing period: Yearly

**Lifetime Premium:**
- Product ID: `premium_lifetime`
- Name: "Premium Lifetime"
- Description: "Lifetime premium access to all features"
- Price: Set your desired price
- Billing period: One-time

#### 3.2 Set Up Test Accounts
1. Go to "Setup" → "License testing"
2. Add test email addresses (these can make test purchases)
3. These accounts won't be charged for purchases

### 4. RevenueCat Setup

#### 4.1 Create RevenueCat Account
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Create account and new project
3. Add Android app with package name: `com.liglus.lovenest`

#### 4.2 Configure Products in RevenueCat
1. Go to "Products" → "Add Product"
2. Create products matching your Play Console setup:
   - `premium_monthly`
   - `premium_yearly`
   - `premium_lifetime`

#### 4.3 Get API Key
1. Go to "Project Settings" → "API Keys"
2. Copy your public API key
3. Update `lib/services/revenuecat_service.dart`:
   ```dart
   static const String _publicApiKey = 'your_actual_api_key_here';
   ```

#### 4.4 Configure Entitlements
1. Go to "Entitlements" → "Add Entitlement"
2. Create entitlement:
   - ID: `premium`
   - Name: "Premium Access"
   - Add your subscription products to this entitlement

### 5. Test the Integration

#### 5.1 Install Test Version
1. Testers will receive an email with the testing link
2. They can install the app from the Play Store (testing version)
3. The app will show as "Internal testing" in the store

#### 5.2 Test Purchases
1. Use test accounts to make purchases
2. Purchases will be processed but not charged
3. Verify that:
   - Paywall shows correctly
   - Purchase flow works
   - Entitlement is granted after purchase
   - Restore purchases works

### 6. Troubleshooting

#### Common Issues:
1. **Purchases not working**: Check RevenueCat API key and product IDs
2. **App not installing**: Ensure testers are added to the internal testing track
3. **Paywall not showing**: Verify `kPaywallEnabled = true` in feature flags

#### Testing Checklist:
- [ ] App installs correctly
- [ ] Paywall appears when expected
- [ ] Subscription products are displayed
- [ ] Purchase flow completes successfully
- [ ] Entitlement is granted after purchase
- [ ] Restore purchases works
- [ ] App functions correctly with premium access

### 7. Next Steps After Testing

1. **Gather Feedback**: Collect feedback from testers
2. **Fix Issues**: Address any problems found during testing
3. **Iterate**: Make improvements and test again
4. **Production**: When ready, move to production release

## Important Notes

- **Test Accounts**: Only use test accounts for purchase testing
- **API Keys**: Keep your RevenueCat API key secure
- **Product IDs**: Ensure product IDs match exactly between Play Console and RevenueCat
- **Testing Period**: Internal testing can run indefinitely while you refine the app

## Support Resources

- [Google Play Console Testing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [RevenueCat Testing Guide](https://docs.revenuecat.com/docs/testing)
- [Flutter Testing](https://docs.flutter.dev/testing)
