# Codemagic TestFlight Setup Guide

This guide will help you configure Codemagic to automatically build and deploy your Flutter app to TestFlight.

## Prerequisites

1. **Apple Developer Account** with App Store Connect access
2. **Codemagic Account** (sign up at [codemagic.io](https://codemagic.io))
3. **GitHub/GitLab/Bitbucket repository** with your Flutter project

## Step 1: Configure Codemagic Environment Variables

In your Codemagic project settings, you need to add the following environment variables:

### Required Environment Variables

#### iOS Code Signing
- **iOS_SIGNING_CERTIFICATE**: Your iOS Distribution certificate (P12 file content)
- **IOS_SIGNING_CERTIFICATE_PASSWORD**: Password for the P12 certificate
- **IOS_SIGNING_PROVISIONING_PROFILE**: Your App Store provisioning profile

#### App Store Connect API
- **APP_STORE_CONNECT_PRIVATE_KEY**: Your App Store Connect API private key (P8 file content)
- **APP_STORE_CONNECT_KEY_IDENTIFIER**: Your App Store Connect API key ID
- **APP_STORE_CONNECT_ISSUER_ID**: Your App Store Connect issuer ID

#### App Configuration
- **APP_ID**: Your app's bundle identifier (`com.liglius.lovenest`)
- **APP_NAME**: Your app's display name (`Lovenest Valley`)

### How to Get These Values

#### 1. iOS Code Signing Certificate
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to "Certificates, Identifiers & Profiles"
3. Create or download your iOS Distribution certificate
4. Export as P12 file and upload to Codemagic

#### 2. App Store Connect API Key
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to "Users and Access" → "Keys"
3. Create a new API key with "App Manager" role
4. Download the private key (.p8 file)
5. Note the Key ID and Issuer ID

#### 3. Provisioning Profile
1. In Apple Developer Portal, create an App Store provisioning profile
2. Download and upload to Codemagic

## Step 2: Update codemagic.yaml

The `codemagic.yaml` file has been created with the following features:

### Workflow Configuration
- **Workflow Name**: `ios-testflight`
- **Instance Type**: `mac_mini_m2` (recommended for Flutter builds)
- **Build Duration**: 60 minutes maximum
- **Flutter Version**: Latest stable
- **Xcode Version**: Latest

### Triggering
- Builds trigger on:
  - Push to `main` or `master` branches
  - Push to `release/*` branches
  - Git tags starting with `v*`

### Build Process
1. **Code Signing Setup**: Automatically configures certificates and provisioning profiles
2. **Dependencies**: Installs Flutter packages and CocoaPods
3. **Testing**: Runs Flutter analyze and tests
4. **Build**: Creates iOS IPA file for App Store distribution
5. **Publishing**: Automatically submits to TestFlight

### Artifacts
- IPA file for App Store distribution
- Build logs for debugging

## Step 3: Configure Your App Bundle ID

The `APP_ID` in the `codemagic.yaml` file has been updated with your actual bundle identifier:

```yaml
vars:
  APP_ID: "com.liglius.lovenest" # Your actual bundle ID
```

## Step 4: TestFlight Configuration

The workflow is configured to:
- Submit to TestFlight automatically
- Add to "Internal Testing" and "External Testing" beta groups
- Send email notifications on success/failure

## Step 5: First Build

1. **Commit and Push**: Commit the `codemagic.yaml` file to your repository
2. **Connect Repository**: In Codemagic, add your repository
3. **Configure Environment Variables**: Add all required environment variables
4. **Start Build**: Trigger a build manually or push to trigger automatically

## Troubleshooting

### Common Issues

#### 1. Code Signing Errors
- Ensure your certificate is valid and not expired
- Verify the provisioning profile matches your bundle ID
- Check that the certificate is properly uploaded to Codemagic

#### 2. App Store Connect API Errors
- Verify your API key has the correct permissions
- Ensure the issuer ID and key ID are correct
- Check that the private key is properly formatted

#### 3. Build Failures
- Check the build logs in Codemagic dashboard
- Ensure all dependencies are properly configured
- Verify Flutter and Xcode versions are compatible

### Build Logs
- Access build logs in the Codemagic dashboard
- Check the "Scripts" section for detailed error messages
- Use the "Artifacts" section to download build outputs

## Advanced Configuration

### Custom Build Scripts
You can add custom build steps by modifying the `scripts` section in `codemagic.yaml`:

```yaml
scripts:
  - name: Custom build step
    script: |
      # Your custom commands here
      echo "Running custom build step"
```

### Environment-Specific Builds
You can create multiple workflows for different environments:

```yaml
workflows:
  ios-testflight:
    # TestFlight workflow
  ios-staging:
    # Staging environment workflow
```

### Notification Configuration
Update the email recipients in the `publishing` section:

```yaml
publishing:
  email:
    recipients:
      - your-email@example.com
      - team-member@example.com
```

## Security Best Practices

1. **Never commit sensitive data** to your repository
2. **Use Codemagic environment variables** for all secrets
3. **Rotate certificates and API keys** regularly
4. **Limit API key permissions** to minimum required
5. **Use separate certificates** for different environments

## Support

- **Codemagic Documentation**: [docs.codemagic.io](https://docs.codemagic.io)
- **Apple Developer Documentation**: [developer.apple.com](https://developer.apple.com)
- **Flutter Documentation**: [docs.flutter.dev](https://docs.flutter.dev)

## Next Steps

1. Set up your Codemagic account and connect your repository
2. Configure all required environment variables
3. Test the build process with a manual build
4. Set up automatic builds for your main branches
5. Configure TestFlight beta groups and testers

Your Flutter app will now automatically build and deploy to TestFlight whenever you push changes to your configured branches!
