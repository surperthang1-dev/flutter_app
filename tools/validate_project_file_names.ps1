$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$blockedNames = @(
  'test',
  'new',
  'final',
  'fix',
  'v2',
  'copy',
  'demo',
  'temp',
  'main2'
)

$ignoredDirectories = @(
  '.dart_tool',
  '.git',
  '.idea',
  'build',
  'windows',
  'linux',
  'macos',
  'android',
  'ios'
)

$violations = New-Object System.Collections.Generic.List[string]

Get-ChildItem -Path $projectRoot -Recurse -File | ForEach-Object {
  $relativePath = Resolve-Path -Path $_.FullName -Relative
  $relativePath = $relativePath.TrimStart('.', '\', '/')
  $segments = $relativePath -split '[\\/]'

  foreach ($ignoredDirectory in $ignoredDirectories) {
    if ($segments -contains $ignoredDirectory) {
      return
    }
  }

  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
  $extension = $_.Extension.ToLowerInvariant()
  $normalizedBaseName = $baseName.ToLowerInvariant()

  if ($blockedNames -contains $normalizedBaseName) {
    $violations.Add("$relativePath uses vague filename '$baseName'.")
  }

  if ($normalizedBaseName -match '(^|[-_])(new|final|fix|v2|copy|demo|temp|main2)([-_]|$)') {
    $violations.Add("$relativePath contains temporary filename token '$baseName'.")
  }

  if ($extension -eq '.dart' -and $baseName -cnotmatch '^[a-z][a-z0-9_]*$') {
    $violations.Add("$relativePath should use Dart snake_case naming.")
  }
}

if ($violations.Count -gt 0) {
  Write-Host 'File naming validation failed:' -ForegroundColor Red
  $violations | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'File naming validation passed.' -ForegroundColor Green
