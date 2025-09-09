# Create Keystore Script for Lovenest Valley
# This script generates a keystore file for signing your app

Write-Host "Creating keystore for Lovenest Valley..." -ForegroundColor Green

# Set keystore path
$keystorePath = "android/app/upload-keystore.jks"

# Check if keystore already exists
if (Test-Path $keystorePath) {
    Write-Host "⚠️  Keystore already exists at: $keystorePath" -ForegroundColor Yellow
    $response = Read-Host "Do you want to overwrite it? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Keystore creation cancelled." -ForegroundColor Red
        exit
    }
}

Write-Host "Generating keystore..." -ForegroundColor Yellow

# Generate keystore using keytool
try {
    keytool -genkey -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass "your-store-password" -keypass "your-key-password" -dname "CN=Lovenest Valley, OU=Development, O=Your Company, L=Your City, S=Your State, C=US"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Keystore created successfully!" -ForegroundColor Green
        Write-Host "📁 Location: $keystorePath" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "🔑 Keystore Details:" -ForegroundColor Yellow
        Write-Host "   Alias: upload" -ForegroundColor White
        Write-Host "   Store Password: your-store-password" -ForegroundColor White
        Write-Host "   Key Password: your-key-password" -ForegroundColor White
        Write-Host ""
        Write-Host "⚠️  IMPORTANT: Change these passwords in production!" -ForegroundColor Red
        Write-Host "⚠️  Keep this keystore file secure - you'll need it for app updates!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Update passwords in android/app/build.gradle.kts" -ForegroundColor White
        Write-Host "2. Run .\build_closed_testing.ps1 to build your app" -ForegroundColor White
    } else {
        Write-Host "❌ Failed to create keystore!" -ForegroundColor Red
        Write-Host "Make sure you have Java installed and keytool is in your PATH." -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error creating keystore: $_" -ForegroundColor Red
    Write-Host "Make sure you have Java installed and keytool is in your PATH." -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
