[CmdletBinding()]
param(
  [ValidateSet('Debug', 'Release', 'RelWithDebInfo', 'MinSizeRel')]
  [string]$Configuration = 'Debug',
  [string]$BuildDirectory = 'build',
  [string]$Generator = 'Ninja',
  [string]$CMakeExe = 'E:\Cmake\bin\cmake.exe',
  [string]$CCompiler = 'E:\mingw64\bin\gcc.exe',
  [string]$CXXCompiler = 'E:\mingw64\bin\g++.exe',
  [string]$MakeProgram = '',
  [string]$RuntimeDirectory = '',
  [ValidateRange(1, 128)]
  [int]$Jobs = 4,
  [switch]$Test
)

$ErrorActionPreference = 'Stop'
$taskProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')

function Resolve-RobotLabTool([string]$Candidate) {
  $taskTool = Get-Command -Name $Candidate -CommandType Application -ErrorAction Stop | Select-Object -First 1
  return [System.IO.Path]::GetFullPath($taskTool.Source)
}

function Invoke-RobotLabTool([string]$Executable, [string[]]$ToolArguments) {
  & $Executable @ToolArguments
  if ($LASTEXITCODE -ne 0) {
    throw ('Command failed with exit code {0}: {1}' -f $LASTEXITCODE, $Executable)
  }
}

if ([System.IO.Path]::IsPathRooted($BuildDirectory)) {
  $taskBuildRoot = [System.IO.Path]::GetFullPath($BuildDirectory)
} else {
  $taskBuildRoot = [System.IO.Path]::GetFullPath((Join-Path $taskProjectRoot $BuildDirectory))
}
if (-not $taskBuildRoot.StartsWith($taskProjectRoot + [System.IO.Path]::DirectorySeparatorChar,
    [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'BuildDirectory must be a separate directory inside this app.'
}

$taskCMake = Resolve-RobotLabTool $CMakeExe
$taskCC = Resolve-RobotLabTool $CCompiler
$taskCXX = Resolve-RobotLabTool $CXXCompiler
if ([string]::IsNullOrWhiteSpace($MakeProgram)) {
  if ($Generator -eq 'Ninja') {
    $MakeProgram = Join-Path ([System.IO.Path]::GetDirectoryName($taskCXX)) 'ninja.exe'
    if (-not (Test-Path -LiteralPath $MakeProgram -PathType Leaf)) { $MakeProgram = 'ninja' }
  } elseif ($Generator -eq 'MinGW Makefiles') {
    $MakeProgram = Join-Path ([System.IO.Path]::GetDirectoryName($taskCXX)) 'mingw32-make.exe'
  }
}
$taskMake = if ([string]::IsNullOrWhiteSpace($MakeProgram)) { '' } else { Resolve-RobotLabTool $MakeProgram }
if ([string]::IsNullOrWhiteSpace($RuntimeDirectory)) {
  $RuntimeDirectory = [System.IO.Path]::GetDirectoryName($taskCXX)
}
$taskRuntime = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
$taskPreviousPath = $env:PATH
try {
  $taskToolDirectories = @(
    [System.IO.Path]::GetDirectoryName($taskCMake)
    [System.IO.Path]::GetDirectoryName($taskCC)
    [System.IO.Path]::GetDirectoryName($taskCXX)
    $taskRuntime
    if ($taskMake) { [System.IO.Path]::GetDirectoryName($taskMake) }
  ) | Select-Object -Unique
  $env:PATH = ($taskToolDirectories -join [System.IO.Path]::PathSeparator) +
    [System.IO.Path]::PathSeparator + $taskPreviousPath

  $taskConfigureArguments = @(
    '-S', $taskProjectRoot, '-B', $taskBuildRoot, '-G', $Generator
    ('-DCMAKE_BUILD_TYPE=' + $Configuration)
    ('-DCMAKE_C_COMPILER:FILEPATH=' + $taskCC)
    ('-DCMAKE_CXX_COMPILER:FILEPATH=' + $taskCXX)
    ('-DROBOTLAB_RUNTIME_DIR:PATH=' + $taskRuntime)
  )
  if ($taskMake) { $taskConfigureArguments += ('-DCMAKE_MAKE_PROGRAM:FILEPATH=' + $taskMake) }
  Invoke-RobotLabTool $taskCMake $taskConfigureArguments
  Invoke-RobotLabTool $taskCMake @('--build', $taskBuildRoot, '--config', $Configuration, '--parallel', "$Jobs")

  if ($Test) {
    $taskCTestCandidate = Join-Path ([System.IO.Path]::GetDirectoryName($taskCMake)) 'ctest.exe'
    if (-not (Test-Path -LiteralPath $taskCTestCandidate -PathType Leaf)) { $taskCTestCandidate = 'ctest' }
    $taskCTest = Resolve-RobotLabTool $taskCTestCandidate
    Invoke-RobotLabTool $taskCTest @('--test-dir', $taskBuildRoot, '--build-config', $Configuration, '--output-on-failure')
  }
  Write-Host ('Built RobotLab: ' + (Join-Path $taskBuildRoot 'bin\RobotLab.exe'))
} finally {
  $env:PATH = $taskPreviousPath
}
