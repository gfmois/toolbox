$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repo = "gfmois/toolbox"
$AppName = "toolbox"

$Version = "latest"
$InstallDir = ""
$Update = $false
$Uninstall = $false
$Help = $false

$script:VersionProvided = $false
$script:InstallDirProvided = $false

function Show-Usage {
    @"
Install Toolbox from GitHub releases.

Usage:
  install-toolbox.ps1 [-Version <version|latest>] [-InstallDir <dir>] [-Update]
  install-toolbox.ps1 [--version <version|latest>] [--install-dir <dir>] [--update]
  install-toolbox.ps1 [-Uninstall]
  install-toolbox.ps1 [--uninstall]

Examples:
  ./install-toolbox.ps1
  ./install-toolbox.ps1 -Version v1.2.3
  ./install-toolbox.ps1 --version 1.2.3
  ./install-toolbox.ps1 -InstallDir "D:\tools\bin"
  ./install-toolbox.ps1 --install-dir "D:\tools\bin"
  ./install-toolbox.ps1 -Update
  ./install-toolbox.ps1 --update
  ./install-toolbox.ps1 -Uninstall
  ./install-toolbox.ps1 --uninstall
"@
}

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Get-Arch {
    $procArch = $env:PROCESSOR_ARCHITECTURE
    $procArchW6432 = $env:PROCESSOR_ARCHITEW6432

    $arch = if (-not [string]::IsNullOrWhiteSpace($procArchW6432)) {
        $procArchW6432
    } elseif (-not [string]::IsNullOrWhiteSpace($procArch)) {
        $procArch
    } else {
        ""
    }

    switch ($arch.ToUpperInvariant()) {
        "AMD64" { return "amd64" }
        "X86"   { return "amd64" }
        "ARM64" { return "arm64" }
        default { Fail "Unsupported architecture: $arch" }
    }
}

function Resolve-Tag([string]$RequestedVersion) {
    if ($RequestedVersion -eq "latest") {
        $uri = "https://api.github.com/repos/$Repo/releases/latest"
        try {
            $release = Invoke-RestMethod -Uri $uri -Method Get
        }
        catch {
            Fail "Failed to resolve latest release from GitHub: $($_.Exception.Message)"
        }

        if (-not $release -or [string]::IsNullOrWhiteSpace($release.tag_name)) {
            Fail "Failed to resolve latest release tag."
        }

        return [string]$release.tag_name
    }

    if ($RequestedVersion.StartsWith("v")) {
        return $RequestedVersion
    }

    return "v$RequestedVersion"
}

function Find-InstalledToolbox {
    $candidates = New-Object System.Collections.Generic.List[string]

    try {
        $cmd = Get-Command toolbox -ErrorAction SilentlyContinue
        if ($cmd) {
            if ($cmd.Path)   { $candidates.Add($cmd.Path) }
            if ($cmd.Source) { $candidates.Add($cmd.Source) }
        }
    }
    catch {
    }

    $whereExe = Get-Command where.exe -ErrorAction SilentlyContinue
    if ($whereExe) {
        try {
            $whereResults = & where.exe toolbox 2>$null
            foreach ($result in $whereResults) {
                if (-not [string]::IsNullOrWhiteSpace($result)) {
                    $candidates.Add($result.Trim())
                }
            }
        }
        catch {
        }
    }

    $userLocalBin = Join-Path $HOME ".local\bin\toolbox.exe"
    $userBin = Join-Path $HOME "bin\toolbox.exe"

    $candidates.Add($userLocalBin)
    $candidates.Add($userBin)

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Test-VersionValue([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Fail "Version cannot be empty."
    }

    if ($Value -match '^-{1,2}(update|uninstall|help|version|install-dir)$') {
        Fail "Invalid version value '$Value'. Use a real version like '1.2.3', 'v1.2.3' or 'latest'."
    }
}

function Parse-Arguments {
    param([string[]]$Arguments)

    $i = 0
    while ($i -lt $Arguments.Count) {
        $arg = $Arguments[$i]

        switch -Regex ($arg) {
            '^(-h|--help)$' {
                $script:Help = $true
                $i++
                continue
            }

            '^(-Update|--update|-update)$' {
                $script:Update = $true
                $i++
                continue
            }

            '^(-Uninstall|--uninstall|-uninstall)$' {
                $script:Uninstall = $true
                $i++
                continue
            }

            '^(-Version|--version|-version)$' {
                if ($i + 1 -ge $Arguments.Count) {
                    Fail "Missing value for $arg."
                }

                $script:Version = $Arguments[$i + 1]
                $script:VersionProvided = $true
                $i += 2
                continue
            }

            '^(-InstallDir|--install-dir|-install-dir)$' {
                if ($i + 1 -ge $Arguments.Count) {
                    Fail "Missing value for $arg."
                }

                $script:InstallDir = $Arguments[$i + 1]
                $script:InstallDirProvided = $true
                $i += 2
                continue
            }

            '^(-Version|--version|-version)=(.+)$' {
                $script:Version = $Matches[2]
                $script:VersionProvided = $true
                $i++
                continue
            }

            '^(-InstallDir|--install-dir|-install-dir)=(.+)$' {
                $script:InstallDir = $Matches[2]
                $script:InstallDirProvided = $true
                $i++
                continue
            }

            default {
                Fail "Unknown argument: $arg"
            }
        }
    }
}

Parse-Arguments -Arguments $args

if ($Help) {
    Show-Usage
    exit 0
}

if ($Update -and $Uninstall) {
    Fail "-Update/--update cannot be combined with -Uninstall/--uninstall."
}

if ($Uninstall) {
    if ($VersionProvided) {
        Fail "-Uninstall/--uninstall cannot be combined with -Version/--version."
    }

    if ($InstallDirProvided) {
        Fail "-Uninstall/--uninstall cannot be combined with -InstallDir/--install-dir."
    }

    $installedBinary = Find-InstalledToolbox
    if (-not $installedBinary) {
        Fail "toolbox is not installed or could not be located."
    }

    Write-Host "Uninstalling toolbox from $installedBinary"

    try {
        Remove-Item -LiteralPath $installedBinary -Force
    }
    catch {
        Fail "Failed to remove toolbox binary: $($_.Exception.Message)"
    }

    $resolvedInstallDir = Split-Path -Parent $installedBinary

    try {
        $remaining = @(Get-ChildItem -LiteralPath $resolvedInstallDir -Force -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) {
            Remove-Item -LiteralPath $resolvedInstallDir -Force -ErrorAction SilentlyContinue
            Write-Host "Removed empty directory $resolvedInstallDir"
        }
    }
    catch {
    }

    Write-Host "Toolbox uninstalled successfully"
    exit 0
}

Test-VersionValue $Version

if ($Update) {
    if ($VersionProvided) {
        Fail "-Update/--update cannot be combined with -Version/--version."
    }

    if ($InstallDirProvided) {
        Fail "-Update/--update cannot be combined with -InstallDir/--install-dir."
    }

    $installedBinary = Find-InstalledToolbox
    if (-not $installedBinary) {
        Fail "toolbox is not currently installed or could not be located."
    }

    $InstallDir = Split-Path -Parent $installedBinary
    $Version = "latest"
    $Action = "updated"

    Write-Host "Updating existing toolbox installation in $InstallDir"
}
else {
    if ([string]::IsNullOrWhiteSpace($InstallDir)) {
        $InstallDir = Join-Path $HOME ".local\bin"
    }
    $Action = "installed"
}

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    Fail "Install directory cannot be empty."
}

$os = "windows"
$arch = Get-Arch
$tag = Resolve-Tag $Version
$versionNoV = $tag.TrimStart("v")
$assetName = "${AppName}_v${versionNoV}_${os}_${arch}.zip"
$downloadUrl = "https://github.com/$Repo/releases/download/$tag/$assetName"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("toolbox-install-" + [guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $tempRoot -Force

try {
    $archivePath = Join-Path $tempRoot $assetName

    Write-Host "Downloading $downloadUrl"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath
    }
    catch {
        Fail "Failed to download asset '$assetName' from release '$tag'. $($_.Exception.Message)"
    }

    Write-Host "Extracting archive"
    Expand-Archive -LiteralPath $archivePath -DestinationPath $tempRoot -Force

    $binarySource = Join-Path $tempRoot "bin\toolbox.exe"
    if (-not (Test-Path -LiteralPath $binarySource -PathType Leaf)) {
        Fail "toolbox.exe not found in downloaded archive."
    }

    $null = New-Item -ItemType Directory -Path $InstallDir -Force

    $targetPath = Join-Path $InstallDir "toolbox.exe"
    Copy-Item -LiteralPath $binarySource -Destination $targetPath -Force

    Write-Host "Toolbox $Action at $targetPath"
    Write-Host "Run: toolbox --version"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}