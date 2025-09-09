# Build Closed Testing Script for Lovenest Valley
# This script builds a release version for closed testing with subscriptions

Write-Host "Building Lovenest Valley for Closed Testing..." -ForegroundColor Green

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build app bundle for closed testing
Write-Host "Building app bundle for closed testing..." -ForegroundColor Yellow
flutter build appbundle --release

# Check if build was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host "📦 App bundle location: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🎯 Closed Testing Setup:" -ForegroundColor Yellow
    Write-Host "1. Upload AAB to Google Play Console → Testing → Internal Testing" -ForegroundColor White
    Write-Host "2. Add testers - your email + others" -ForegroundColor White
    Write-Host "3. Configure subscriptions in Play Console" -ForegroundColor White
    Write-Host "4. Set up RevenueCat products" -ForegroundColor White
    Write-Host "5. Test purchases with test accounts" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "• Complete RevenueCat setup (see guide)" -ForegroundColor White
    Write-Host "• Configure subscriptions in Play Console" -ForegroundColor White
    Write-Host "• Add test accounts for purchase testing" -ForegroundColor White
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Write-Host "Check the error messages above and fix any issues." -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
