param(
    [ValidateSet("all","windows","web","android","linux")]
    [string]$Target = "all",
    [switch]$Package
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Project = Join-Path $Root "Godot"
$BuildRoot = Join-Path $Root "Builds"

function Resolve-FirstExisting([string[]]$Candidates) {
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

$Godot = Resolve-FirstExisting @(
    $env:GODOT_BIN,
    "E:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe",
    (Get-Command godot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Get-Command godot4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
)
if (-not $Godot) { throw "Godot 4.7.2+ executable not found. Set GODOT_BIN." }

$AndroidSdk = Resolve-FirstExisting @(
    $env:ANDROID_SDK_ROOT,
    $env:ANDROID_HOME,
    "E:\Tools\AndroidSdk",
    "$env:LOCALAPPDATA\Android\Sdk"
)
$JavaHome = Resolve-FirstExisting @(
    $env:JAVA_HOME,
    "F:\Rev-Eng\Scoop\apps\temurin25-jdk\current"
)

if ($AndroidSdk) {
    $env:ANDROID_HOME = $AndroidSdk
    $env:ANDROID_SDK_ROOT = $AndroidSdk
    $env:PATH = "$AndroidSdk\platform-tools;$env:PATH"
}
if ($JavaHome) {
    $env:JAVA_HOME = $JavaHome
    $env:PATH = "$JavaHome\bin;$env:PATH"
}

function Export-Preset([string]$Preset,[string]$Path,[bool]$Debug=$false) {
    $dir = Split-Path $Path -Parent
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $mode = if ($Debug) { "--export-debug" } else { "--export-release" }
    Write-Host "Exporting $Preset ($mode) -> $Path"
    & $Godot --headless --path $Project $mode $Preset $Path
    if ($LASTEXITCODE -ne 0) { throw "$Preset export failed with exit $LASTEXITCODE" }
}

if ($Target -in @("all","windows")) { Export-Preset "Windows" "$BuildRoot\Windows\Parallax.exe" }
if ($Target -in @("all","web")) { Export-Preset "Web" "$BuildRoot\Web\index.html" }
if ($Target -in @("all","linux")) { Export-Preset "Linux-SteamDeck" "$BuildRoot\Linux\Parallax.x86_64" }
if ($Target -in @("all","android")) {
    if (-not $AndroidSdk) { throw "Android SDK not found. Set ANDROID_SDK_ROOT." }
    if (-not $JavaHome) { throw "JAVA_HOME not found." }
    # Debug signing uses the standard local Android debug keystore and avoids
    # checking a private release-signing key into the reconstruction project.
    Export-Preset "Android" "$BuildRoot\Android\Parallax.apk" $true
}

if ($Package -and $Target -eq "all") {
    $Release = Join-Path $BuildRoot "Release"
    Remove-Item $Release -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $Release | Out-Null

    Compress-Archive -Path "$BuildRoot\Windows\Parallax.exe" -DestinationPath "$Release\Parallax-Windows-x64.zip" -CompressionLevel Optimal
    Compress-Archive -Path "$BuildRoot\Web\*" -DestinationPath "$Release\Parallax-Web.zip" -CompressionLevel Optimal
    Copy-Item "$BuildRoot\Android\Parallax.apk" "$Release\Parallax-Android-arm64.apk"

    # Preserve the Linux executable bit inside the Steam Deck/Linux archive.
    $linuxDir = "/mnt/" + $BuildRoot.Substring(0,1).ToLower() + $BuildRoot.Substring(2).Replace("\","/") + "/Linux"
    $linuxSrc = "$linuxDir/Parallax.x86_64"
    $releaseWsl = "/mnt/" + $Release.Substring(0,1).ToLower() + $Release.Substring(2).Replace("\","/")
    & wsl.exe -d Ubuntu -- bash -lc "chmod +x '$linuxSrc' && tar -C '$linuxDir' -czf '$releaseWsl/Parallax-Linux-SteamDeck-x86_64.tar.gz' Parallax.x86_64"
    if ($LASTEXITCODE -ne 0) { throw "Linux/Steam Deck packaging failed" }

    $files = Get-ChildItem $Release -File | Sort-Object Name
    $lines = foreach ($file in $files) {
        $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($file.Name)"
    }
    [IO.File]::WriteAllLines("$Release\SHA256SUMS.txt", $lines, [Text.UTF8Encoding]::new($false))
}

Write-Host "Build complete."
Get-ChildItem $BuildRoot -Recurse -File |
    Where-Object { $_.FullName -notlike "*.idsig" } |
    Select-Object FullName,Length
