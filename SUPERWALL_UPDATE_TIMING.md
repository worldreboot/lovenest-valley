# Superwall Update Timing & Refresh Guide

Understanding when and how Superwall updates propagate to your app, and how to force immediate updates.

## ⏱️ **Typical Update Timing**

### **Immediate Updates (0-30 seconds)**
- ✅ **Campaign changes** (enable/disable, audience filters)
- ✅ **Paywall design changes** (text, colors, layout, images)
- ✅ **Feature gating settings** (Gated vs Non-Gated)
- ✅ **Placement configuration**
- ✅ **A/B test percentages**

### **Quick Updates (1-5 minutes)**
- ⚡ **Product configuration changes** (pricing, descriptions, features)
- ⚡ **New product additions**
- ⚡ **Subscription status changes**
- ⚡ **User attribute updates**

### **Delayed Updates (5-30 minutes)**
- ⏳ **Initial product setup** from scratch
- ⏳ **Cross-platform sync** (iOS ↔ Android)
- ⏳ **App Store Connect/Google Play Console propagation**
- ⏳ **Network/CDN propagation delays**

## 🔄 **Update Process Flow**

```
Superwall Dashboard → CDN → App SDK → Local Cache → Paywall Display
     ↓                ↓         ↓          ↓            ↓
   Immediate      1-5 min    Next app   Cached     User sees
   changes         delay      launch     locally    updated UI
```

## 🚀 **How to Force Immediate Updates**

### **Method 1: In-App Refresh Button**
1. Go to game screen → Settings (⚙️) → "Refresh Superwall"
2. This forces a fresh fetch from Superwall servers
3. Updates should be visible immediately

### **Method 2: Debug Console**
```dart
await SuperwallService.forceRefresh();
```

### **Method 3: App Restart**
- Force close and restart the app
- Superwall fetches fresh data on app launch

### **Method 4: Clear App Data** (Android)
```bash
adb shell pm clear com.liglius.lovenest
```

## 📱 **Testing Update Timing**

### **Quick Test:**
1. **Make change** in Superwall dashboard
2. **Note the time** you made the change
3. **Use refresh button** in app settings
4. **Test placement** to see if changes are visible

### **Expected Results:**
- **Campaign changes**: Should be immediate after refresh
- **Paywall design**: Should be immediate after refresh
- **Product changes**: May take 1-5 minutes even after refresh

## 🎛️ **Factors Affecting Update Speed**

### **Fast Updates:**
- ✅ Strong internet connection
- ✅ App is in foreground
- ✅ Using refresh button
- ✅ Simple configuration changes

### **Slower Updates:**
- ⏳ Poor network connection
- ⏳ App in background
- ⏳ Complex product configurations
- ⏳ Cross-platform sync needed
- ⏳ App Store/Google Play integration

## 🔍 **Troubleshooting Update Issues**

### **Issue: Changes Not Visible After 30 Minutes**
**Solutions:**
1. **Check dashboard**: Ensure campaign is active and saved
2. **Force refresh**: Use in-app refresh button
3. **Restart app**: Close and reopen completely
4. **Check network**: Ensure stable internet connection
5. **Verify placement**: Make sure placement name matches exactly

### **Issue: Paywall Shows Old Products**
**Solutions:**
1. **Product sync delay**: Wait 5-10 minutes for cross-platform sync
2. **App Store delay**: Google Play/App Store may need time to propagate
3. **Force refresh**: Use refresh button
4. **Check product IDs**: Ensure product IDs match exactly in dashboard

### **Issue: Feature Gating Not Working**
**Solutions:**
1. **Immediate check**: Feature gating should update in seconds
2. **Verify setting**: Check Gated vs Non-Gated in dashboard
3. **Test placement**: Use test button to verify behavior
4. **Clear cache**: Restart app or use refresh button

## 📊 **Monitoring Update Status**

### **Console Logs to Watch:**
```
[SuperwallService] 🔄 Forcing refresh of Superwall data...
[SuperwallService] ✅ Superwall data refreshed successfully
[SuperwallService] 🧪 Testing placement: campaign_trigger
[SuperwallService] ✅ Feature executed for placement: campaign_trigger
```

### **UI Indicators:**
- **Blue snackbar**: "🔄 Superwall data refreshed! Latest changes should now be visible."
- **Orange snackbar**: "🧪 Triggered campaign_trigger placement! Check console logs."

## 🎯 **Best Practices for Testing**

### **During Development:**
1. **Use refresh button** frequently when testing
2. **Make small changes** and test incrementally
3. **Test on both platforms** (iOS/Android)
4. **Check console logs** for confirmation

### **Before Production:**
1. **Test all placements** thoroughly
2. **Verify product configurations** are synced
3. **Test with different user states** (entitled/non-entitled)
4. **Allow extra time** for final updates to propagate

## 📈 **Optimizing Update Speed**

### **Dashboard Configuration:**
- ✅ **Save changes immediately** after making them
- ✅ **Test campaigns** before enabling them
- ✅ **Use consistent naming** for placements and products
- ✅ **Verify product IDs** match app store exactly

### **App Configuration:**
- ✅ **Initialize Superwall early** in app lifecycle
- ✅ **Use refresh button** during testing
- ✅ **Handle network errors** gracefully
- ✅ **Provide user feedback** during refresh operations

## 🔗 **Related Resources**

- [Superwall Dashboard](https://superwall.com/dashboard)
- [Superwall Testing Guide](https://superwall.com/docs/flutter/quickstart/testing)
- [Superwall Troubleshooting](https://superwall.com/docs/flutter/troubleshooting)
- [Superwall Analytics](https://superwall.com/docs/dashboard/analytics)

## 💡 **Pro Tips**

1. **Always use the refresh button** when testing changes
2. **Wait 5-10 minutes** for product changes to fully sync
3. **Test on real devices** for most accurate timing
4. **Check Superwall dashboard analytics** to verify placement triggers
5. **Use consistent product IDs** across all platforms
