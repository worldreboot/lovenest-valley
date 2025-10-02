# Lovenest Custom URL Scheme Guide

This guide explains how to use the `lovenest://` custom URL scheme for deep linking into your Lovenest Valley app.

## 🔗 **URL Scheme Overview**

Your app now supports custom URLs with the scheme: `lovenest://`

### **Supported Platforms:**
- ✅ **Android** - Configured in `AndroidManifest.xml`
- ✅ **iOS** - Configured in `Info.plist`
- ✅ **Flutter** - Handled by `app_links` package

## 📱 **Supported Deep Link Formats**

### **Basic URLs:**
```
lovenest://                    # Home page
lovenest:///                   # Home page (alternative)
```

### **Feature-Specific URLs:**
```
lovenest:///game               # Navigate to game
lovenest:///game?farmId=123    # Navigate to specific farm
lovenest:///shop               # Navigate to shop
lovenest:///shop?category=decorations  # Shop with category filter
lovenest:///garden             # Navigate to memory garden
lovenest:///garden?seedId=456  # Garden with specific seed
lovenest:///partner            # Navigate to partner features
lovenest:///partner?action=invite  # Partner invitation flow
```

## 🛠️ **Technical Implementation**

### **Android Configuration:**
```xml
<!-- In android/app/src/main/AndroidManifest.xml -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="lovenest" />
</intent-filter>
```

### **iOS Configuration:**
```xml
<!-- In ios/Runner/Info.plist -->
<dict>
    <key>CFBundleURLName</key>
    <string>lovenest.custom.scheme</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>lovenest</string>
    </array>
</dict>
```

### **Flutter Handling:**
```dart
// DeepLinkService handles all incoming links
DeepLinkService.initialize(); // Called in main.dart
```

## 🧪 **Testing Deep Links**

### **Method 1: In-App Test Button**
1. Go to game screen → Settings (⚙️) → "Test Deep Links"
2. Check console logs for generated URL examples

### **Method 2: ADB Commands (Android)**
```bash
# Test basic deep link
adb shell am start -W -a android.intent.action.VIEW -d "lovenest://" com.liglius.lovenest

# Test game deep link
adb shell am start -W -a android.intent.action.VIEW -d "lovenest:///game?farmId=test123" com.liglius.lovenest

# Test shop deep link
adb shell am start -W -a android.intent.action.VIEW -d "lovenest:///shop?category=decorations" com.liglius.lovenest
```

### **Method 3: iOS Simulator**
```bash
# Test basic deep link
xcrun simctl openurl booted "lovenest://"

# Test game deep link
xcrun simctl openurl booted "lovenest:///game?farmId=test123"

# Test shop deep link
xcrun simctl openurl booted "lovenest:///shop?category=decorations"
```

### **Method 4: Browser/Web Links**
Create HTML files with links:
```html
<a href="lovenest://">Open Lovenest App</a>
<a href="lovenest:///game?farmId=123">Open Game</a>
<a href="lovenest:///shop">Open Shop</a>
```

## 📊 **Expected Behavior**

### **When App is Closed:**
1. **Link clicked** → App launches
2. **Deep link processed** → Navigates to specified screen
3. **Console logs** show link details

### **When App is Running:**
1. **Link clicked** → App comes to foreground
2. **Deep link processed** → Navigates to specified screen
3. **Console logs** show link details

### **Console Output Example:**
```
[DeepLinkService] 🔗 Handling deep link: lovenest:///game?farmId=123
[DeepLinkService] 🎮 Navigating to game
[DeepLinkService] Farm ID: 123
```

## 🎯 **Use Cases**

### **1. Marketing & Sharing**
```
lovenest:///game                    # Share game access
lovenest:///shop?category=decorations  # Share specific shop category
lovenest:///partner?action=invite   # Share partner invitation
```

### **2. Push Notifications**
```
lovenest:///game?farmId=user123     # Direct to user's farm
lovenest:///garden?seedId=seed456   # Direct to specific memory
lovenest:///partner                 # Direct to partner features
```

### **3. Web Integration**
```
lovenest:///game                    # From website "Play Now" button
lovenest:///shop                    # From website "Shop" button
lovenest:///partner?action=invite   # From website "Invite Partner" button
```

### **4. Cross-Platform Sharing**
```
lovenest:///game?farmId=shared123   # Share farm between users
lovenest:///garden?seedId=shared456 # Share specific memory
```

## 🔧 **Customization**

### **Adding New Routes:**
1. **Update `DeepLinkService.dart`**:
   ```dart
   case '/newfeature':
       _handleNewFeatureLink(queryParams);
       break;
   ```

2. **Implement handler**:
   ```dart
   static void _handleNewFeatureLink(Map<String, String> params) {
       // Add navigation logic
   }
   ```

3. **Generate URLs**:
   ```dart
   DeepLinkService.generateLink(
       path: '/newfeature',
       queryParams: {'param': 'value'},
   );
   ```

### **Adding Query Parameters:**
```dart
// Example: lovenest:///game?farmId=123&mode=creative
final farmId = params['farmId'];
final mode = params['mode'];
```

## 🚨 **Security Considerations**

### **Input Validation:**
- ✅ **Validate all query parameters** before processing
- ✅ **Sanitize user input** to prevent injection attacks
- ✅ **Check user permissions** before navigation

### **Example Validation:**
```dart
static void _handleGameLink(Map<String, String> params) {
    final farmId = params['farmId'];
    
    // Validate farm ID
    if (farmId == null || farmId.isEmpty) {
        debugPrint('[DeepLinkService] ❌ Invalid farm ID');
        return;
    }
    
    // Check if user has access to this farm
    if (!_userHasAccessToFarm(farmId)) {
        debugPrint('[DeepLinkService] ❌ User does not have access to farm: $farmId');
        return;
    }
    
    // Proceed with navigation
    _navigateToGame(farmId);
}
```

## 📈 **Analytics & Tracking**

### **Track Deep Link Usage:**
```dart
static void _handleDeepLink(Uri uri) {
    // Log deep link for analytics
    Analytics.track('deep_link_opened', {
        'scheme': uri.scheme,
        'path': uri.path,
        'query_params': uri.queryParameters,
    });
    
    // Process the link
    _processDeepLink(uri);
}
```

## 🐛 **Troubleshooting**

### **Issue: Deep Links Not Working**
**Solutions:**
1. **Check configuration** - Verify AndroidManifest.xml and Info.plist
2. **Restart app** - Deep links are registered on app launch
3. **Check console logs** - Look for DeepLinkService initialization
4. **Test with ADB/xcrun** - Use command line tools to test

### **Issue: App Opens But Doesn't Navigate**
**Solutions:**
1. **Check console logs** - Look for deep link processing messages
2. **Verify URL format** - Ensure proper lovenest:// scheme
3. **Check navigation logic** - Verify route handlers are implemented
4. **Test with debug button** - Use in-app test functionality

### **Issue: Links Work on One Platform Only**
**Solutions:**
1. **Check platform configuration** - Verify both Android and iOS configs
2. **Test on both platforms** - Use appropriate testing tools
3. **Check app_links package** - Ensure it's properly configured

## 📚 **Related Documentation**

- [Flutter Deep Linking](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [App Links Package](https://pub.dev/packages/app_links)
- [Android App Links](https://developer.android.com/training/app-links)
- [iOS Universal Links](https://developer.apple.com/ios/universal-links/)

## 💡 **Pro Tips**

1. **Test on real devices** - Simulator behavior may differ
2. **Use console logs** - Monitor DeepLinkService for debugging
3. **Validate all inputs** - Never trust URL parameters blindly
4. **Handle edge cases** - What happens with malformed URLs?
5. **Consider fallbacks** - What if the target screen doesn't exist?
