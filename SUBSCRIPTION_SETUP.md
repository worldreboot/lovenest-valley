# Subscription Setup Quick Reference

## Product IDs to Configure

### In Google Play Console:
1. **Monthly Subscription**
   - Product ID: `premium_monthly`
   - Type: Subscription
   - Billing: Monthly

2. **Yearly Subscription**
   - Product ID: `premium_yearly`
   - Type: Subscription
   - Billing: Yearly

3. **Lifetime Purchase**
   - Product ID: `premium_lifetime`
   - Type: One-time purchase

### In RevenueCat:
1. **Entitlement**
   - ID: `premium`
   - Name: "Premium Access"

2. **Products** (same IDs as Play Console)
   - `premium_monthly`
   - `premium_yearly`
   - `premium_lifetime`

## Configuration Steps

### 1. Google Play Console
```
Monetize → Products → Subscriptions → Create subscription
```

### 2. RevenueCat Dashboard
```
Products → Add Product → [Enter product IDs]
Entitlements → Add Entitlement → [Link products to entitlement]
```

### 3. Update Code
```dart
// In lib/services/revenuecat_service.dart
static const String _publicApiKey = 'your_revenuecat_api_key';
static const String _entitlementId = 'premium';
```

## Testing Checklist

- [ ] RevenueCat API key updated
- [ ] Product IDs match between Play Console and RevenueCat
- [ ] Entitlement configured in RevenueCat
- [ ] Test accounts added to Play Console
- [ ] Paywall shows subscription options
- [ ] Purchase flow completes
- [ ] Entitlement granted after purchase
- [ ] Restore purchases works

## Common Issues

1. **"Product not found"**: Check product IDs match exactly
2. **"API key invalid"**: Verify RevenueCat API key
3. **"Purchase failed"**: Ensure test account is configured
4. **"Paywall not showing"**: Check `kPaywallEnabled = true`
