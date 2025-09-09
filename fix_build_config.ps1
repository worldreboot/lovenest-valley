# Fix Build Configuration Script
# This script replaces the current build.gradle.kts with a simple version for testing

Write-Host "Fixing build configuration for testing..." -ForegroundColor Green

# Backup current configuration
$backupPath = "android/app/build.gradle.kts.backup"
$currentPath = "android/app/build.gradle.kts"
$simplePath = "android/app/build.gradle.kts.simple"

if (Test-Path $currentPath) {
    Write-Host "Creating backup of current configuration..." -ForegroundColor Yellow
    Copy-Item $currentPath $backupPath
    Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
}

# Replace with simple configuration
if (Test-Path $simplePath) {
    Write-Host "Applying simple build configuration..." -ForegroundColor Yellow
    Copy-Item $simplePath $currentPath
    Write-Host "✅ Simple configuration applied!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This configuration:" -ForegroundColor Cyan
    Write-Host "• Uses debug signing (no keystore needed)" -ForegroundColor White
    Write-Host "• Disables minification and resource shrinking" -ForegroundColor White
    Write-Host "• Should build without errors" -ForegroundColor White
    Write-Host ""
    Write-Host "Now try running: .\build_closed_testing.ps1" -ForegroundColor Yellow
} else {
    Write-Host "❌ Simple configuration file not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
