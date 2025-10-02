# Configuration Update Checklist

Since we changed the package name to `com.liglus.lovenest`, here's everything you need to update:

## ✅ **Your Release Keystore SHA-1 Fingerprint**
```
SHA1: F4:B3:D5:E0:A4:B3:E4:0C:05:7B:CF:A5:46:B7:D2:8E:BE:16:64:D3
```

## 🔧 **Required Updates**

### 1. **Firebase Configuration** ⚠️ **REQUIRED**
- [ ] Go to [Firebase Console](https://console.firebase.google.com/)
- [ ] Add new Android app with package name: `com.liglus.lovenest`
- [ ] Download new `google-services.json`
- [ ] Replace existing file at `android/app/google-services.json`

### 2. **Google Sign-In Configuration** ⚠️ **REQUIRED**
- [ ] Go to [Google Cloud Console](https://console.cloud.google.com/)
- [ ] Navigate to "APIs & Services" → "Credentials"
- [ ] Find your Android OAuth 2.0 Client ID
- [ ] Add SHA-1 fingerprint: `F4:B3:D5:E0:A4:B3:E4:0C:05:7B:CF:A5:46:B7:D2:8E:BE:16:64:D3`
- [ ] Update package name to `com.liglus.lovenest`

### 3. **Google Play Console** ⚠️ **REQUIRED**
- [ ] Create app with package name: `com.liglus.lovenest`
- [ ] Configure subscription products
- [ ] Add test accounts for purchase testing

### 4. **Superwall Configuration** ⚠️ **REQUIRED**
- [x] Create account at [Superwall Dashboard](https://superwall.com/dashboard)
- [ ] Add Android app with package name: `com.liglus.lovenest`
- [ ] Configure products: `premium_monthly`, `premium_yearly`, `premium_lifetime`
- [ ] Design paywall in Superwall dashboard with placement: `premium`
- [x] Get API key and update `lib/services/superwall_service.dart`

## 🚀 **After Updates - Build and Test**

### 1. **Clean and Rebuild**
```powershell
flutter clean
flutter pub get
.\build_closed_testing.ps1
```

### 2. **Test Functionality**
- [ ] App builds successfully
- [ ] Google Sign-In works
- [ ] Firebase services work (notifications, etc.)
- [ ] Paywall shows correctly
- [ ] Purchase flow works (with test accounts)

## 📋 **Quick Reference**

### **Package Name**: `com.liglus.lovenest`
### **SHA-1 Fingerprint**: `F4:B3:D5:E0:A4:B3:E4:0C:05:7B:CF:A5:46:B7:D2:8E:BE:16:64:D3`
### **Keystore Password**: `lovenest123`
### **Key Alias**: `upload`

## 🔗 **Useful Links**

- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Google Play Console](https://play.google.com/console)
- [Superwall Dashboard](https://superwall.com/dashboard)

## ⚠️ **Important Notes**

1. **Keep your keystore secure** - you'll need it for all future app updates
2. **Test thoroughly** - especially Google Sign-In and purchases
3. **Use test accounts** - for Play Console purchase testing
4. **Backup configurations** - save your API keys and settings

## 🎯 **Priority Order**

1. **Firebase** (required for app to work)
2. **Google Sign-In** (required for authentication)
3. **Play Console** (required for testing)
4. **Superwall** (required for subscriptions)

Complete these in order and your app will be ready for closed testing! 🚀
