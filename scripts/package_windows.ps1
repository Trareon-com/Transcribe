# Build and package Trascribe as a .zip for Windows.
#
# Per ADR-12/ADR-8: signing uses a self-signed certificate (free, no CA),
# which still triggers a Windows SmartScreen warning on first run — this
# is documented for users at download time rather than hidden. Signing
# only runs when TRASCRIBE_PFX_PATH + TRASCRIBE_PFX_PASSWORD are set
# (e.g. from a CI secret); without them, this script still produces an
# unsigned build so local packaging works out of the box.
#
# To generate a self-signed cert for local testing:
#   $cert = New-SelfSignedCertificate -Type CodeSigning `
#     -Subject "CN=Trascribe (self-signed)" -CertStoreLocation Cert:\CurrentUser\My
#   $pwd = ConvertTo-SecureString -String "changeit" -Force -AsPlainText
#   Export-PfxCertificate -Cert $cert -FilePath trascribe.pfx -Password $pwd

param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrEmpty($Version)) {
    $pubspec = Get-Content "pubspec.yaml" | Select-String "^version:"
    $Version = ($pubspec -split ":\s*")[1].Split("+")[0]
}

$AppName = "trascribe"
$RustDir = "rust_core"
$BuildDir = "build\windows\x64\runner\Release"
$DistDir = "dist"
$DllName = "rust_core.dll"
$ZipPath = Join-Path $DistDir "$AppName-$Version-windows.zip"

Write-Host "==> Building rust_core (release)"
Push-Location $RustDir
cargo build --release --lib
Pop-Location

$RustDllSource = Join-Path $RustDir "target\release\$DllName"
if (-not (Test-Path $RustDllSource)) {
    Write-Error "rust_core DLL not found at $RustDllSource — cargo build may have failed or changed the output path"
    exit 1
}

Write-Host "==> Building Flutter Windows release"
flutter build windows --release

if (-not (Test-Path $BuildDir)) {
    Write-Error "$BuildDir not found after build"
    exit 1
}

# Explicitly copy the Rust DLL into the Flutter build output. The CMake
# install rules should handle this, but copying here is a belt-and-suspenders
# guarantee that the DLL is present in the packaged zip regardless of which
# CMake generator is in use (Ninja vs MSBuild) or install-step quirks.
$DllDest = Join-Path $BuildDir $DllName
Copy-Item -Path $RustDllSource -Destination $DllDest -Force

if (-not (Test-Path $DllDest)) {
    Write-Error "$DllName not found in build output at $DllDest after copy"
    exit 1
}

# Bundle the tiny model next to the exe — lib/state/models.dart's
# modelPathForId() looks there first so the "bundled, no download needed"
# tiny model actually resolves in a packaged build.
$ModelsDestDir = Join-Path $BuildDir "models"
New-Item -ItemType Directory -Force -Path $ModelsDestDir | Out-Null
Copy-Item -Path "models\ggml-tiny.bin" -Destination $ModelsDestDir -Force

$PfxPath = $env:TRASCRIBE_PFX_PATH
$PfxPassword = $env:TRASCRIBE_PFX_PASSWORD

if ($PfxPath -and $PfxPassword) {
    Write-Host "==> Signing $BuildDir\$AppName.exe"
    & signtool sign /f $PfxPath /p $PfxPassword /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "$BuildDir\$AppName.exe"
    & signtool verify /pa "$BuildDir\$AppName.exe"
} else {
    Write-Host "==> Skipping signing (TRASCRIBE_PFX_PATH/TRASCRIBE_PFX_PASSWORD not set) — unsigned build"
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
if (Test-Path $ZipPath) { Remove-Item $ZipPath }

Write-Host "==> Creating $ZipPath"
Compress-Archive -Path "$BuildDir\*" -DestinationPath $ZipPath

Write-Host "==> Generating checksum"
$hash = Get-FileHash -Path $ZipPath -Algorithm SHA256
"$($hash.Hash.ToLower())  $(Split-Path $ZipPath -Leaf)" | Out-File -Encoding ascii "$ZipPath.sha256"

Write-Host "Done: $ZipPath"
