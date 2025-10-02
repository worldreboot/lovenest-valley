# Superwall Feature Gating Implementation

This document outlines the feature gating implementation using Superwall's `registerPlacement` functionality, following the [official Superwall feature gating guide](https://superwall.com/docs/flutter/quickstart/feature-gating).

## 🎯 **Implemented Feature Gates**

### 1. **Shop Access** (`shop_access`)
- **Location**: Game screen shop button (🛍️)
- **File**: `lib/screens/game_screen.dart` (lines 1520-1538)
- **Feature**: Access to the shop screen for purchasing items
- **Gating Logic**: The shop navigation is wrapped in `SuperwallService.registerPlacement('shop_access', feature: () { ... })`

### 2. **Daily Questions Access** (`daily_questions_access`)
- **Location**: Owl interaction in game
- **File**: `lib/screens/game_screen.dart` (lines 1283-1375)
- **Feature**: Access to daily question prompts and seed collection
- **Gating Logic**: Owl tap handler wraps the daily question modal in feature gating

### 3. **Plant Daily Question Seeds** (`plant_daily_question_seed`)
- **Location**: Planting daily question seeds
- **File**: `lib/screens/game_screen.dart` (lines 1071-1260)
- **Feature**: Ability to plant daily question seeds in the farm
- **Gating Logic**: Planting logic for daily question seeds is feature-gated

## 🔧 **How Feature Gating Works**

### **With Superwall (Current Implementation)**
```dart
// Example: Shop access
SuperwallService.registerPlacement(
  'shop_access',
  feature: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShopScreen(
          inventoryManager: inventoryManager,
          onItemPurchased: () {
            setState(() {});
          },
        ),
      ),
    );
  },
);
```

### **Without Superwall (Previous Approach)**
```dart
// Old approach - manual subscription checking
if (user.hasActiveSubscription) {
  Navigator.of(context).push(/* shop screen */);
} else {
  showPaywall();
}
```

## 📊 **Benefits of Feature Gating**

1. **Remote Control**: Enable/disable paywalls for any feature without app updates
2. **A/B Testing**: Test different paywall strategies for different features
3. **Gradual Rollout**: Gradually introduce paywalls to different user segments
4. **Flexible Campaigns**: Create different paywall campaigns for different placements
5. **Real-time Changes**: Modify paywall behavior instantly from Superwall dashboard

## 🎛️ **Superwall Dashboard Configuration**

To configure these feature gates in your Superwall dashboard:

### **Step 1: Create Campaigns**
1. Go to [Superwall Dashboard](https://superwall.com/dashboard)
2. Navigate to "Campaigns" → "Create Campaign"
3. Create campaigns for each placement:
   - `shop_access`
   - `daily_questions_access` 
   - `plant_daily_question_seed`

### **Step 2: Configure Placements**
For each campaign:
1. Add the placement name (e.g., `shop_access`)
2. Set audience filters (optional)
3. Configure paywall presentation rules

### **Step 3: Set Feature Gating**
For each paywall:
1. Go to "General" → "Feature Gating"
2. Choose:
   - **Gated**: Feature only executes if user pays
   - **Non-Gated**: Feature executes regardless of payment

### **Step 4: Test Placements**
Use Superwall's debug tools to test different scenarios:
- Users with active subscriptions
- Users without subscriptions
- Different audience segments

## 🔄 **Placement Lifecycle**

1. **App Launch**: SDK retrieves campaign settings from dashboard
2. **Placement Called**: When user taps a feature (e.g., shop button)
3. **Audience Evaluation**: SDK evaluates user against campaign audiences
4. **Paywall Decision**: Shows paywall if user enters experiment
5. **Feature Execution**: After paywall closes, executes feature based on gating setting

## 📱 **Testing Feature Gates**

### **Enable Debug Mode**
```dart
// In your Superwall configuration
Superwall.shared.options.logging.level = .debug;
```

### **Test Different Scenarios**
1. **Entitled Users**: Should access features immediately
2. **Non-Entitled Users**: Should see paywall (if configured)
3. **Non-Gated Paywalls**: Should access features after dismissing paywall

## 🚀 **Adding More Feature Gates**

To add feature gating to new features:

1. **Identify the feature access point**
2. **Wrap the feature logic in `registerPlacement`**:
   ```dart
   SuperwallService.registerPlacement(
     'your_placement_name',
     feature: () {
       // Your feature logic here
     },
   );
   ```
3. **Configure the placement in Superwall dashboard**
4. **Test the implementation**

## 📈 **Analytics & Optimization**

Superwall automatically tracks:
- Placement impressions
- Paywall presentation rates
- Conversion rates per placement
- Feature usage after paywall dismissal

Use this data to optimize:
- Paywall timing and frequency
- Feature gating strategies
- Audience targeting
- Paywall design and messaging

## 🔐 **Security Considerations**

- Feature gates are evaluated **on-device** for performance
- Paywall logic is controlled from **Superwall dashboard**
- No sensitive business logic is exposed in the app
- Users cannot bypass paywalls by modifying app code

## 📚 **Related Documentation**

- [Superwall Feature Gating Guide](https://superwall.com/docs/flutter/quickstart/feature-gating)
- [Superwall Campaign Management](https://superwall.com/docs/dashboard/campaigns)
- [Superwall Analytics](https://superwall.com/docs/dashboard/analytics)
- [Superwall Testing Guide](https://superwall.com/docs/flutter/quickstart/testing)
