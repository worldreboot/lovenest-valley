# Testing Superwall Placements

This guide explains how to test the `campaign_trigger` placement and other Superwall placements in your app.

## 🧪 **Testing Methods**

### **Method 1: In-App Test Button**

1. **Launch the app** and navigate to the game screen
2. **Tap the settings button** (⚙️) in the top-left corner
3. **Tap "Test Superwall"** in the settings dialog
4. **Check console logs** for placement trigger confirmation

### **Method 2: Debug Console**

From the Flutter debug console, you can run:

```dart
// Test specific placement
await SuperwallService.testPlacement('campaign_trigger');

// Test all placements
await SuperwallPlacementTester.testAllPlacements();

// Test custom placement
await SuperwallPlacementTester.testCustomPlacement('your_placement_name');
```

### **Method 3: Programmatic Testing**

Add this code anywhere in your app to test:

```dart
import 'package:lovenest_valley/services/superwall_service.dart';

// Test the campaign_trigger placement
SuperwallService.testPlacement('campaign_trigger');
```

## 📊 **Expected Behavior**

### **When Placement is Triggered:**

1. **Console Output**:
   ```
   [SuperwallService] 🧪 Testing placement: campaign_trigger
   [SuperwallService] ✅ Feature executed for placement: campaign_trigger
   ```

2. **UI Feedback**:
   - Orange snackbar appears: "🧪 Triggered campaign_trigger placement! Check console logs."
   - Duration: 3 seconds

3. **Superwall Behavior**:
   - If paywall is configured in dashboard → Shows paywall
   - If no paywall configured → Executes feature immediately
   - If user is entitled → Executes feature immediately

## 🎛️ **Superwall Dashboard Configuration**

To see paywalls when testing, configure in [Superwall Dashboard](https://superwall.com/dashboard):

### **Step 1: Create Campaign**
1. Go to "Campaigns" → "Create Campaign"
2. Name: `Test Campaign`
3. Add placement: `campaign_trigger`

### **Step 2: Configure Paywall**
1. Create or select a paywall
2. Set Feature Gating:
   - **Gated**: Feature only executes if user pays
   - **Non-Gated**: Feature executes regardless of payment

### **Step 3: Set Audience**
1. Configure audience filters (optional)
2. Set presentation percentages
3. Save campaign

## 🔍 **Testing Scenarios**

### **Scenario 1: No Campaign Configured**
- **Expected**: Feature executes immediately
- **Console**: Shows placement trigger + feature execution
- **UI**: Orange snackbar appears

### **Scenario 2: Campaign with Non-Gated Paywall**
- **Expected**: Shows paywall, then executes feature after dismissal
- **Behavior**: User can dismiss paywall and still access feature

### **Scenario 3: Campaign with Gated Paywall**
- **Expected**: Shows paywall, only executes feature if user pays
- **Behavior**: Feature only accessible after successful purchase

### **Scenario 4: Entitled User**
- **Expected**: Feature executes immediately (no paywall)
- **Behavior**: Skips paywall for users with active subscriptions

## 📱 **Testing on Device**

### **Android**
```bash
flutter run --debug
# Then use the in-app test button or debug console
```

### **iOS**
```bash
flutter run --debug
# Then use the in-app test button or debug console
```

## 🐛 **Troubleshooting**

### **Issue: No Console Output**
- **Solution**: Check if Superwall is properly initialized
- **Verify**: API key is set in `lib/services/superwall_service.dart`

### **Issue: Paywall Not Showing**
- **Solution**: Check Superwall dashboard configuration
- **Verify**: Campaign is active and placement is added

### **Issue: Feature Not Executing**
- **Solution**: Check Feature Gating setting in dashboard
- **Verify**: Paywall is set to "Non-Gated" for testing

### **Issue: Multiple Paywalls**
- **Solution**: Check audience filters in dashboard
- **Verify**: Only one campaign is active for the placement

## 📈 **Analytics & Monitoring**

Superwall automatically tracks:
- Placement impressions
- Paywall presentation rates
- Conversion rates
- Feature execution rates

View analytics in the [Superwall Dashboard](https://superwall.com/dashboard) under "Analytics" → "Placements".

## 🔄 **Available Placements**

Current implemented placements:
- `campaign_trigger` - Test placement
- `shop_access` - Shop button access
- `daily_questions_access` - Owl interaction
- `plant_daily_question_seed` - Planting daily question seeds

## 📚 **Related Documentation**

- [Superwall Testing Guide](https://superwall.com/docs/flutter/quickstart/testing)
- [Superwall Campaign Management](https://superwall.com/docs/dashboard/campaigns)
- [Superwall Feature Gating](https://superwall.com/docs/flutter/quickstart/feature-gating)
- [Superwall Analytics](https://superwall.com/docs/dashboard/analytics)
