# Flutter Installation Script for Windows
# Run this in PowerShell as Administrator

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Flutter Installation Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator. PATH changes will be for current user only." -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Check if Flutter already exists
$flutterPath = "C:\src\flutter"
if (Test-Path $flutterPath) {
    Write-Host "[!] Flutter directory already exists at $flutterPath" -ForegroundColor Yellow
    $response = Read-Host "Do you want to delete and reinstall? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host "[*] Removing existing Flutter installation..." -ForegroundColor Yellow
        Remove-Item -Path $flutterPath -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[*] Keeping existing installation. Skipping download." -ForegroundColor Green
        $skipDownload = $true
    }
}

# Step 2: Download Flutter
if (-not $skipDownload) {
    Write-Host "[*] Creating directory C:\src..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path "C:\src" | Out-Null

    Write-Host "[*] Downloading Flutter SDK..." -ForegroundColor Cyan
    Write-Host "    This may take 5-10 minutes depending on your internet speed..." -ForegroundColor Gray

    $flutterZip = "C:\src\flutter_windows_stable.zip"
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.6-stable.zip"

    try {
        Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZip -UseBasicParsing
        Write-Host "[✓] Download complete!" -ForegroundColor Green
    } catch {
        Write-Host "[✗] Download failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual download:" -ForegroundColor Yellow
        Write-Host "1. Go to: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
        Write-Host "2. Download the Flutter SDK ZIP" -ForegroundColor Yellow
        Write-Host "3. Extract to C:\src\flutter" -ForegroundColor Yellow
        Write-Host "4. Run this script again" -ForegroundColor Yellow
        exit 1
    }

    # Step 3: Extract Flutter
    Write-Host "[*] Extracting Flutter SDK..." -ForegroundColor Cyan
    Write-Host "    This may take 2-3 minutes..." -ForegroundColor Gray

    try {
        Expand-Archive -Path $flutterZip -DestinationPath "C:\src" -Force
        Write-Host "[✓] Extraction complete!" -ForegroundColor Green

        # Clean up
        Remove-Item -Path $flutterZip -Force
    } catch {
        Write-Host "[✗] Extraction failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 4: Add to PATH
$flutterBin = "C:\src\flutter\bin"
Write-Host "[*] Adding Flutter to PATH..." -ForegroundColor Cyan

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$flutterBin*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$currentPath;$flutterBin",
        "User"
    )
    Write-Host "[✓] Flutter added to PATH!" -ForegroundColor Green
    $env:Path += ";$flutterBin"
} else {
    Write-Host "[✓] Flutter already in PATH!" -ForegroundColor Green
}

# Step 5: Run Flutter Doctor
Write-Host ""
Write-Host "[*] Running Flutter Doctor..." -ForegroundColor Cyan
Write-Host ""

& "$flutterBin\flutter.bat" doctor

# Step 6: Final Instructions
Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. RESTART your terminal/PowerShell/VS Code" -ForegroundColor Yellow
Write-Host "2. Run: flutter doctor" -ForegroundColor White
Write-Host "3. Navigate to your project:" -ForegroundColor White
Write-Host "   cd C:\Users\yhpark\Desktop\BB\simple_bible" -ForegroundColor Gray
Write-Host "4. Run: flutter pub get" -ForegroundColor White
Write-Host "5. Run: flutter run -d chrome" -ForegroundColor White
Write-Host ""
Write-Host "To accept Android licenses:" -ForegroundColor Cyan
Write-Host "   flutter doctor --android-licenses" -ForegroundColor White
Write-Host ""
