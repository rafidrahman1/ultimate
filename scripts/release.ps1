# Publishes the version in pubspec.yaml as a GitHub Release with the signed APK
# attached, which is what the in-app updater looks for.
#
# Usage:  powershell -File scripts\release.ps1            (or .\scripts\release.ps1)
#         .\scripts\release.ps1 -Notes "Custom release notes"
#
# Bump `version:` in pubspec.yaml and commit it before running.

param([string]$Notes = "")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Run($exe, [string[]]$arguments) {
  & $exe @arguments
  if ($LASTEXITCODE -ne 0) { Fail "'$exe $($arguments -join ' ')' failed (exit $LASTEXITCODE)" }
}

# Locate gh.
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = "C:\Program Files\GitHub CLI\gh.exe" }
if (-not (Test-Path $gh)) { Fail "GitHub CLI not found. Install it: winget install GitHub.cli" }
& $gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Fail "Not logged in to GitHub. Run: gh auth login" }

# Version from pubspec.yaml, e.g. 2.3.0+8 -> tag v2.3.0+8.
$line = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $line) { Fail "No version: line in pubspec.yaml" }
$version = $line.Matches[0].Groups[1].Value
$tag = "v$version"

if (git status --porcelain) { Fail "Working tree has uncommitted changes. Commit or stash them first." }

& $gh release view $tag *> $null
if ($LASTEXITCODE -eq 0) { Fail "Release $tag already exists. Bump the version in pubspec.yaml first." }

Write-Host "Releasing $tag" -ForegroundColor Cyan

# Build first so a failed build leaves no tag behind.
Run flutter @("build", "apk", "--release")
$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) { Fail "APK not found at $apk" }

# Push the commit, then tag it (reuse the tag if it already exists on HEAD).
Run git @("push", "origin", "HEAD")
$existing = git tag --list $tag
if (-not $existing) {
  Run git @("tag", $tag)
} elseif ((git rev-parse "$tag^{commit}") -ne (git rev-parse HEAD)) {
  Fail "Tag $tag already exists but points at a different commit."
}
Run git @("push", "origin", $tag)

$ghArgs = @("release", "create", $tag, $apk, "--title", $tag, "--verify-tag")
if ($Notes) { $ghArgs += @("--notes", $Notes) } else { $ghArgs += "--generate-notes" }
Run $gh $ghArgs

Write-Host "Done: https://github.com/rafidrahman1/ultimate/releases/tag/$([uri]::EscapeDataString($tag))" -ForegroundColor Green
