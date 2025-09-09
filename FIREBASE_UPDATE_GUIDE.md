# Firebase Configuration Update Guide

Since we changed the package name from `com.example.lovenest` to `com.liglus.lovenest`, you need to update your Firebase configuration.

## Option 1: Add New Package to Existing Firebase Project (Recommended)

### 1. Go to Firebase Console
1. Visit [Firebase Console](https://console.firebase.google.com/)
2. Select your existing project (`tunetown-59caf`)

### 2. Add Android App
1. Click on the Android icon (🤖) to add an Android app
2. Enter the new package name: `com.liglus.lovenest`
3. Enter app nickname: "Lovenest Valley"
4. Click "Register app"

### 3. Download New google-services.json
1. Download the new `google-services.json` file
2. Replace the existing file at `android/app/google-services.json`

### 4. Keep Both Configurations
- Your existing `com.example.lovenest` configuration will still work for development
- The new `com.lovenest.valley` configuration will work for Play Store

## Option 2: Create New Firebase Project

If you prefer a fresh start:

### 1. Create New Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Name it "Lovenest Valley" or similar

### 2. Add Android App
1. Add Android app with package name: `com.liglus.lovenest`
2. Download the new `google-services.json`

### 3. Update Supabase Configuration
You'll also need to update your Supabase configuration if you want to use the new Firebase project.

## Quick Commands

After updating the google-services.json file:

```powershell
# Clean and rebuild
flutter clean
flutter pub get
.\build_closed_testing.ps1
```

## Package Name Summary

- **Old**: `com.example.lovenest` (for development)
- **New**: `com.liglus.lovenest` (for Play Store)
- **Firebase**: Can support both simultaneously
