[CmdletBinding()]
param(
  [string]$BuildDirectory = 'build',
  [string]$RuntimeDirectory = '',
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AppArguments = @()
)

$ErrorActionPreference = 'Stop'
$taskProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')
if ([System.IO.Path]::IsPathRooted($BuildDirectory)) {
  $taskBuildRoot = [System.IO.Path]::GetFullPath($BuildDirectory)
} else {
  $taskBuildRoot = [System.IO.Path]::GetFullPath((Join-Path $taskProjectRoot $BuildDirectory))
}
if (-not $taskBuildRoot.StartsWith($taskProjectRoot + [System.IO.Path]::DirectorySeparatorChar,
    [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'BuildDirectory must be a separate directory inside this app.'
}
$taskExecutableDirectory = Join-Path $taskBuildRoot 'bin'
$taskExecutable = Join-Path $taskExecutableDirectory 'RobotLab.exe'
if (-not (Test-Path -LiteralPath $taskExecutable -PathType Leaf)) {
  throw 'RobotLab.exe is missing. Run .\build.ps1 first, or select the correct -BuildDirectory.'
}

if ([string]::IsNullOrWhiteSpace($RuntimeDirectory)) {
  $taskCachePath = Join-Path $taskBuildRoot 'CMakeCache.txt'
  if (Test-Path -LiteralPath $taskCachePath -PathType Leaf) {
    $taskCacheLine = Select-String -LiteralPath $taskCachePath -Pattern '^ROBOTLAB_RUNTIME_DIR:PATH=(.*)$' |
      Select-Object -First 1
    if ($taskCacheLine) { $RuntimeDirectory = $taskCacheLine.Matches[0].Groups[1].Value }
  }
}
$taskPreviousPath = $env:PATH
$taskPushedLocation = $false
try {
  $taskRuntimeDirectories = @($taskExecutableDirectory)
  if (-not [string]::IsNullOrWhiteSpace($RuntimeDirectory)) {
    $taskRuntimeDirectories += (Resolve-Path -LiteralPath $RuntimeDirectory).Path
  }
  $env:PATH = ($taskRuntimeDirectories -join [System.IO.Path]::PathSeparator) +
    [System.IO.Path]::PathSeparator + $taskPreviousPath
  Push-Location -LiteralPath $taskExecutableDirectory
  $taskPushedLocation = $true
  & $taskExecutable @AppArguments
  if ($LASTEXITCODE -ne 0) { throw ('RobotLab exited with code ' + $LASTEXITCODE) }
} finally {
  if ($taskPushedLocation) { Pop-Location }
  $env:PATH = $taskPreviousPath
}
