[CmdletBinding()]
param(
    [string]$Version = "latest",
    [string]$InstallDir = "$HOME\.local\bin",
    [switch]$Update,
    [switch]$AddToPath
)

$ErrorActionPreference = "Stop"
$Repo = "gfmois/toolbox"
$ActionWord = "installed"

function Resolve-Tag {
    param([Parameter(Mandatory = $true)][string]$RequestedVersion)

    if ($RequestedVersion -eq "latest") {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
        if (-not $release.tag_name) {
            throw "Failed to resolve latest release tag."
        }
        return [string]$release.tag_name
    }

    if ($RequestedVersion.StartsWith("v")) {
        return $RequestedVersion
    }

    return "v$RequestedVersion"
}

function Resolve-AssetArch {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    switch ($arch) {
        "x64" { return "amd64" }
        "amd64" { return "amd64" }
        "arm64" {
            Write-Warning "No dedicated Windows ARM64 release was found in the published assets. Using amd64."
            return "amd64"
        }
        default { throw "Unsupported architecture: $arch" }
    }
}

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    throw "InstallDir cannot be empty."
}

if ($Update) {
    if ($PSBoundParameters.ContainsKey("Version")) {
        throw "-Update cannot be combined with -Version."
    }

    if ($PSBoundParameters.ContainsKey("InstallDir")) {
        throw "-Update cannot be combined with -InstallDir."
    }

    $installedCommand = Get-Command toolbox -ErrorAction SilentlyContinue
    if (-not $installedCommand) {
        throw "toolbox is not currently installed or not available on PATH."
    }

    $installedPath = $installedCommand.Source
    if ([string]::IsNullOrWhiteSpace($installedPath)) {
        throw "Could not resolve the installed toolbox path."
    }

    $InstallDir = Split-Path -Parent $installedPath
    $Version = "latest"
    $ActionWord = "updated"
    Write-Host "Updating existing toolbox installation in $InstallDir"
}

$tag = Resolve-Tag -RequestedVersion $Version
$versionNoV = $tag.TrimStart("v")
$assetArch = Resolve-AssetArch
$assetName = "toolbox_v${versionNoV}_windows_${assetArch}.zip"
$downloadUrl = "https://github.com/$Repo/releases/download/$tag/$assetName"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("toolbox-install-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $archivePath = Join-Path $tempRoot $assetName
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath

    Expand-Archive -Path $archivePath -DestinationPath $tempRoot -Force

    $binarySource = Join-Path $tempRoot "bin\toolbox.exe"
    if (-not (Test-Path $binarySource)) {
        throw "toolbox.exe was not found inside the downloaded archive."
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $target = Join-Path $InstallDir "toolbox.exe"
    Copy-Item -Path $binarySource -Destination $target -Force

    if ($AddToPath) {
        $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $entries = @()
        if (-not [string]::IsNullOrWhiteSpace($currentUserPath)) {
            $entries = $currentUserPath -split ";"
        }

        if ($entries -notcontains $InstallDir) {
            $newPath = if ([string]::IsNullOrWhiteSpace($currentUserPath)) { $InstallDir } else { "$currentUserPath;$InstallDir" }
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-Host "Added '$InstallDir' to the user PATH."
        }
    }
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

Write-Host "Toolbox $ActionWord at $(Join-Path $InstallDir 'toolbox.exe')"
Write-Host "Run: toolbox --version"
