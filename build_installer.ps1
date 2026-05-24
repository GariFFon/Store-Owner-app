#Requires -Version 5.1
<#
.SYNOPSIS
    Build the Exanor Store App Windows installer using Inno Setup.
.DESCRIPTION
    This script compiles the installer.iss script with ISCC.
    Run this after `flutter build windows` to ensure the Release binaries are up to date.
#>

$ErrorActionPreference = "Stop"

$ISCCPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
)

$ISCC = $null
foreach ($path in $ISCCPaths) {
    if (Test-Path $path) {
        $ISCC = $path
        break
    }
}

if (-not $ISCC) {
    Write-Error "ISCC.exe not found. Please install Inno Setup 6 from https://jrsoftware.org/isdl.php"
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$IssPath = Join-Path $ScriptDir "installer.iss"

if (-not (Test-Path $IssPath)) {
    Write-Error "installer.iss not found at $IssPath"
    exit 1
}

# Ensure Release build exists
$ReleaseDir = Join-Path $ScriptDir "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $ReleaseDir "exanor_user_new.exe"))) {
    Write-Warning "Release build not found at $ReleaseDir"
    Write-Warning "Run 'flutter build windows' first."
    exit 1
}

Write-Host "Building installer with Inno Setup..." -ForegroundColor Cyan
& $ISCC $IssPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "Installer built successfully." -ForegroundColor Green
    $OutputDir = Join-Path $ScriptDir "installer_output"
    Get-ChildItem $OutputDir -Filter "*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object {
        Write-Host "Output: $($_.FullName)" -ForegroundColor Green
    }
} else {
    Write-Error "Installer build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
