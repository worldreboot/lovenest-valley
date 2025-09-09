# Build Release Script for Lovenest Valley
# This script builds a release version of the app for Play Store testing

Write-Host "Building Lovenest Valley for Play Store..." -ForegroundColor Green

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build app bundle for Play Store
Write-Host "Building app bundle..." -ForegroundColor Yellow
flutter build appbundle --release

# Check if build was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host "📦 App bundle location: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Upload the AAB file to Google Play Console" -ForegroundColor White
    Write-Host "2. Test in-app purchases with test accounts" -ForegroundColor White
    Write-Host "3. Submit for review when ready" -ForegroundColor White
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Write-Host "Check the error messages above and fix any issues." -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
