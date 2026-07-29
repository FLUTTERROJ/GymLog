# Generates the platform folders (android/ ios/ web/) that Flutter needs,
# WITHOUT touching lib/ or pubspec.yaml.
#
# `flutter create .` run directly in this folder would overwrite the hand-written
# pubspec.yaml and lib/main.dart with its templates, so instead we scaffold into
# a throwaway directory and copy only the platform folders across.
#
#   pwsh -File tool/bootstrap.ps1

$ErrorActionPreference = 'Stop'

$project = Split-Path -Parent $PSScriptRoot
$scaffold = Join-Path ([System.IO.Path]::GetTempPath()) "gymlog_scaffold_$(Get-Random)"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter was not found on PATH. Install it from https://docs.flutter.dev/get-started/install/windows first.'
}

Write-Host "Scaffolding platform folders in $scaffold ..." -ForegroundColor Cyan
flutter create --project-name gymlog --org io.supabase --platforms=android,ios,web $scaffold | Out-Null

foreach ($folder in @('android', 'ios', 'web')) {
    $source = Join-Path $scaffold $folder
    $target = Join-Path $project $folder

    if (Test-Path $target) {
        Write-Host "  $folder/ already exists - leaving it alone" -ForegroundColor DarkGray
        continue
    }

    Copy-Item -Path $source -Destination $target -Recurse
    Write-Host "  added $folder/" -ForegroundColor Green
}

$metadata = Join-Path $project '.metadata'
if (-not (Test-Path $metadata)) {
    Copy-Item -Path (Join-Path $scaffold '.metadata') -Destination $metadata
}

Remove-Item -Path $scaffold -Recurse -Force

Write-Host "`nFetching packages ..." -ForegroundColor Cyan
Push-Location $project
try {
    flutter pub get
}
finally {
    Pop-Location
}

Write-Host "`nDone. Next: add the deep-link entries described in frontend/README.md," -ForegroundColor Cyan
Write-Host "then run with --dart-define-from-file=env.json" -ForegroundColor Cyan
