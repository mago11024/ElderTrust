[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$entrypointPath = Join-Path $repoRoot 'scripts\dev.ps1'
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryBase ("t01 03 & 安信 {0}" -f [Guid]::NewGuid().ToString('N'))
$failures = [System.Collections.Generic.List[string]]::new()
$testStopwatch = [Diagnostics.Stopwatch]::StartNew()

function Assert-Equal {
  param(
    [Parameter(Mandatory)]
    [object]$Actual,

    [Parameter(Mandatory)]
    [object]$Expected,

    [Parameter(Mandatory)]
    [string]$Message
  )

  if ($Actual -cne $Expected) {
    $failures.Add("$Message (expected: '$Expected'; actual: '$Actual')")
  }
}

function Assert-Contains {
  param(
    [Parameter(Mandatory)]
    [string]$Actual,

    [Parameter(Mandatory)]
    [string]$Expected,

    [Parameter(Mandatory)]
    [string]$Message
  )

  if (-not $Actual.Contains($Expected)) {
    $failures.Add("$Message (missing: '$Expected')")
  }
}

function Assert-True {
  param(
    [Parameter(Mandatory)]
    [bool]$Condition,

    [Parameter(Mandatory)]
    [string]$Message
  )

  if (-not $Condition) {
    $failures.Add($Message)
  }
}

function Test-IsSafeTemporaryFixture {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  $resolvedPath = [IO.Path]::GetFullPath($Path)
  $resolvedBase = [IO.Path]::GetFullPath($temporaryBase)
  $baseWithSeparator = $resolvedBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  return $resolvedPath.StartsWith($baseWithSeparator, [StringComparison]::OrdinalIgnoreCase)
}

function Write-FixtureFile {
  param(
    [Parameter(Mandatory)]
    [string]$RelativePath,

    [Parameter(Mandatory)]
    [string]$Content
  )

  $path = Join-Path $fixtureRoot $RelativePath
  $parent = Split-Path -Parent $path
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
}

function New-Fixture {
  if (Test-Path -LiteralPath $fixtureRoot) {
    if (-not (Test-IsSafeTemporaryFixture -Path $fixtureRoot)) {
      throw "Refusing to remove fixture outside TEMP: $fixtureRoot"
    }
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }

  New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot 'backend'), (Join-Path $fixtureRoot 'frontend'), (Join-Path $fixtureRoot 'shims') | Out-Null
  Write-FixtureFile -RelativePath 'shims\log-command.ps1' -Content @'
param(
  [Parameter(Mandatory, Position = 0)]
  [string]$Name,

  [AllowEmptyString()]
  [string]$CommandLine
)

if ($Name -eq 'pnpm') {
  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    if (Test-Path -LiteralPath $env:BACKEND_READY_PATH -PathType Leaf) {
      break
    }
    Start-Sleep -Milliseconds 50
  }
}

[IO.File]::AppendAllText($env:COMMAND_LOG, ("{0}|{1}|{2}{3}" -f $Name, (Get-Location).Path, $CommandLine, [Environment]::NewLine))

if ($Name -eq 'docker') {
  exit [int]$env:FAKE_DOCKER_EXIT_CODE
}

if ($Name -eq 'python') {
  [IO.File]::WriteAllText($env:BACKEND_READY_PATH, 'ready', [Text.UTF8Encoding]::new($false))
  $child = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -PassThru
  [IO.File]::WriteAllText($env:BACKEND_DESCENDANT_PID_PATH, $child.Id.ToString(), [Text.UTF8Encoding]::new($false))
  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    if (Test-Path -LiteralPath $env:FRONTEND_READY_PATH -PathType Leaf) { break }
    Start-Sleep -Milliseconds 50
  }
  exit 19
}

if ($Name -eq 'pnpm') {
  [IO.File]::WriteAllText($env:FRONTEND_READY_PATH, 'ready', [Text.UTF8Encoding]::new($false))
  $child = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -PassThru
  [IO.File]::WriteAllText($env:DESCENDANT_PID_PATH, $child.Id.ToString(), [Text.UTF8Encoding]::new($false))
  Wait-Process -Id $child.Id
}

exit 0
'@
  $shim = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0log-command.ps1" __NAME__ -CommandLine "%*"
exit /b %ERRORLEVEL%
'@
  Write-FixtureFile -RelativePath 'shims\docker.cmd' -Content $shim.Replace('__NAME__', 'docker')
  Write-FixtureFile -RelativePath 'shims\python.cmd' -Content $shim.Replace('__NAME__', 'python')
  Write-FixtureFile -RelativePath 'shims\pnpm.cmd' -Content $shim.Replace('__NAME__', 'pnpm')
  Write-FixtureFile -RelativePath 'shims\argv-probe.ps1' -Content @'
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CommandArguments
)

$encodedArguments = $CommandArguments | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)) }
[IO.File]::WriteAllLines($env:ARGV_LOG, $encodedArguments, [Text.UTF8Encoding]::new($false))
'@
}

function Invoke-Entrypoint {
  param(
    [Parameter(Mandatory)]
    [string]$CommandLogPath,

    [switch]$ShadowApplications
  )

  $env:COMMAND_LOG = $CommandLogPath
  $env:DESCENDANT_PID_PATH = Join-Path $fixtureRoot 'descendant.pid'
  $env:BACKEND_DESCENDANT_PID_PATH = Join-Path $fixtureRoot 'backend-descendant.pid'
  $env:FRONTEND_READY_PATH = Join-Path $fixtureRoot 'frontend.ready'
  $env:BACKEND_READY_PATH = Join-Path $fixtureRoot 'backend.ready'
  $resultPath = Join-Path $fixtureRoot 'launcher-result.txt'
  Write-FixtureFile -RelativePath 'shims\invoke-launcher.ps1' -Content @'
param(
  [Parameter(Mandatory)]
  [string]$EntrypointPath,

  [Parameter(Mandatory)]
  [string]$RepoRoot,

  [Parameter(Mandatory)]
  [string]$ResultPath
)

function docker { throw 'The docker function should not be selected.' }
function python { throw 'The python function should not be selected.' }
Set-Alias -Name pnpm -Value Write-Output
try {
  & $EntrypointPath -RepoRoot $RepoRoot
  $exitCode = $LASTEXITCODE
  [IO.File]::WriteAllText($ResultPath, '', [Text.UTF8Encoding]::new($false))
}
catch {
  $exitCode = 1
  [IO.File]::WriteAllText($ResultPath, $_.Exception.Message, [Text.UTF8Encoding]::new($false))
}
exit $exitCode
'@
  $wrapperPath = Join-Path $fixtureRoot 'shims\invoke-launcher.ps1'
  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $wrapperPath, '-EntrypointPath', $entrypointPath, '-RepoRoot', $fixtureRoot, '-ResultPath', $resultPath)

  $powershellPath = (Get-Command -Name powershell.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Path
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $powershellPath
  $startInfo.Arguments = (($arguments | ForEach-Object { '"{0}"' -f $_.Replace('"', '\\"') }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $process = [System.Diagnostics.Process]::Start($startInfo)
  $launcherStopwatch = [Diagnostics.Stopwatch]::StartNew()
  $timedOut = -not $process.WaitForExit(8000)
  if ($timedOut) {
    Stop-Process -InputObject $process -Force -ErrorAction SilentlyContinue
    $null = $process.WaitForExit(3000)
  }

  $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
  $launcherStopwatch.Stop()

  return @{
    ExitCode = $exitCode
    Output = if (Test-Path -LiteralPath $resultPath -PathType Leaf) { [IO.File]::ReadAllText($resultPath) } else { '' }
    TimedOut = $timedOut
    ElapsedMilliseconds = $launcherStopwatch.ElapsedMilliseconds
    Commands = if (Test-Path -LiteralPath $CommandLogPath) { [IO.File]::ReadAllLines($CommandLogPath) } else { @() }
  }
}

function Test-ProcessHasExited {
  param(
    [Parameter(Mandatory)]
    [int]$Id
  )

  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    if ($null -eq (Get-Process -Id $Id -ErrorAction SilentlyContinue)) {
      return $true
    }
    Start-Sleep -Milliseconds 100
  }

  return $false
}

function Invoke-WindowsArgumentProbe {
  param(
    [string]$ArgumentLine,

    [Parameter(Mandatory)]
    [string]$CommandLogPath
  )

  . $entrypointPath
  $probePath = Join-Path $fixtureRoot 'shims\argv-probe.ps1'
  $powershellPath = (Get-Command -Name powershell.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Path
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $powershellPath
  $startInfo.Arguments = (Join-WindowsArguments -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $probePath)) + ' ' + $ArgumentLine
  $startInfo.WorkingDirectory = $fixtureRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $process = [System.Diagnostics.Process]::Start($startInfo)
  if (-not $process.WaitForExit(3000)) {
    Stop-Process -InputObject $process -Force -ErrorAction SilentlyContinue
    throw 'Windows argument probe exceeded its three-second deadline.'
  }

  if (Test-Path -LiteralPath $CommandLogPath -PathType Leaf) {
    return [IO.File]::ReadAllLines($CommandLogPath)
  }
  throw "Windows argument probe produced no log (exit code $($process.ExitCode))."
}

if (-not (Test-Path -LiteralPath $entrypointPath -PathType Leaf)) {
  throw "Expected unified development entrypoint script is missing: $entrypointPath"
}

$originalPath = $env:PATH
$originalCommandLog = $env:COMMAND_LOG
$originalDockerExitCode = $env:FAKE_DOCKER_EXIT_CODE
$originalDescendantPidPath = $env:DESCENDANT_PID_PATH
$originalBackendDescendantPidPath = $env:BACKEND_DESCENDANT_PID_PATH
$originalFrontendReadyPath = $env:FRONTEND_READY_PATH
$originalBackendReadyPath = $env:BACKEND_READY_PATH
$originalArgvLog = $env:ARGV_LOG
$sentinelProcess = $null

try {
  $powershellPath = (Get-Command -Name powershell.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Path
  $sentinelStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $sentinelStartInfo.FileName = $powershellPath
  $sentinelStartInfo.Arguments = '-NoProfile -Command "Start-Sleep -Seconds 60"'
  $sentinelStartInfo.UseShellExecute = $false
  $sentinelStartInfo.CreateNoWindow = $true
  $sentinelProcess = [System.Diagnostics.Process]::Start($sentinelStartInfo)

  New-Fixture
  $argumentProbeLogPath = Join-Path $fixtureRoot 'argv.log'
  $env:ARGV_LOG = $argumentProbeLogPath
  . $entrypointPath
  $roundTripLine = @(
      (ConvertTo-WindowsArgument -Argument ''),
      (ConvertTo-WindowsArgument -Argument 'space value'),
      (ConvertTo-WindowsArgument -Argument 'quote"inside'),
      (ConvertTo-WindowsArgument -Argument 'trailing space\'),
      (ConvertTo-WindowsArgument -Argument 'plain')
    ) -join ' '
  $argumentProbeOutput = Invoke-WindowsArgumentProbe -ArgumentLine $roundTripLine -CommandLogPath $argumentProbeLogPath
  Assert-Equal -Actual ($argumentProbeOutput -join "`n") -Expected ((@('', 'space value', 'quote"inside', 'trailing space\', 'plain') | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)) }) -join "`n") -Message 'Windows argument probe should preserve empty, spaced, quoted, trailing-backslash, and plain arguments'

  $env:PATH = "$(Join-Path $fixtureRoot 'shims');$originalPath"
  $env:FAKE_DOCKER_EXIT_CODE = '0'
  $commandLogPath = Join-Path $fixtureRoot 'commands.log'
  $result = Invoke-Entrypoint -CommandLogPath $commandLogPath -ShadowApplications
  $backendPath = Join-Path $fixtureRoot 'backend'
  $frontendPath = Join-Path $fixtureRoot 'frontend'
  Assert-True -Condition (-not ([IO.File]::ReadAllText($entrypointPath).Contains('taskkill'))) -Message 'Launcher must not depend on taskkill PID-tree cleanup'

  Assert-True -Condition ($result.ExitCode -ne 0) -Message 'An application exit should fail the development launcher'
  Assert-True -Condition (-not $result.TimedOut) -Message 'Launcher should clean up and exit before the bounded fixture timeout'
  Assert-True -Condition ($result.ElapsedMilliseconds -lt 8000) -Message 'Launcher should clean up the descendant well before its 30-second natural exit'
  Assert-Contains -Actual $result.Output -Expected 'Unexpected backend process exit' -Message 'Launcher should identify the unexpectedly exited backend'
  Assert-Equal -Actual ($result.Commands -join "`n") -Expected (@(
      "docker|$fixtureRoot|compose up -d --wait mysql",
      "python|$backendPath|-m uvicorn app.main:app --reload",
      "pnpm|$frontendPath|dev"
    ) -join "`n") -Message 'Launcher should invoke Docker and both applications with exact commands and working directories'
  Assert-True -Condition (-not (($result.Commands -join "`n") -match 'docker\|.*\|(.*\bdown\b|.*\bstop\b)')) -Message 'Launcher must not stop or bring down Docker services during cleanup'
  Assert-True -Condition (Test-Path -LiteralPath $env:DESCENDANT_PID_PATH -PathType Leaf) -Message 'Long-running frontend shim should record its descendant PID'
  if (Test-Path -LiteralPath $env:DESCENDANT_PID_PATH -PathType Leaf) {
    $descendantId = [int][IO.File]::ReadAllText($env:DESCENDANT_PID_PATH)
    Assert-True -Condition (Test-ProcessHasExited -Id $descendantId) -Message 'Launcher cleanup should terminate the frontend process tree it created'
  }
  Assert-True -Condition (Test-Path -LiteralPath $env:BACKEND_DESCENDANT_PID_PATH -PathType Leaf) -Message 'Backend shim should record its descendant PID before its root exits'
  if (Test-Path -LiteralPath $env:BACKEND_DESCENDANT_PID_PATH -PathType Leaf) {
    $backendDescendantId = [int][IO.File]::ReadAllText($env:BACKEND_DESCENDANT_PID_PATH)
    Assert-True -Condition (Test-ProcessHasExited -Id $backendDescendantId) -Message 'Launcher cleanup should terminate a backend descendant after its root exits'
  }
  $sentinelProcess.Refresh()
  Assert-True -Condition (-not $sentinelProcess.HasExited) -Message 'Launcher cleanup must not terminate an unrelated sentinel process'

  New-Fixture
  $env:PATH = "$(Join-Path $fixtureRoot 'shims');$originalPath"
  $env:FAKE_DOCKER_EXIT_CODE = '37'
  $result = Invoke-Entrypoint -CommandLogPath (Join-Path $fixtureRoot 'docker-failure.log')
  Assert-True -Condition ($result.ExitCode -ne 0) -Message 'A Docker compose failure should fail the development launcher'
  Assert-True -Condition (-not $result.TimedOut) -Message 'Docker failure should exit before the bounded fixture timeout'
  Assert-Contains -Actual $result.Output -Expected 'Docker compose up failed with exit code 37' -Message 'Docker failure should report its exit code'
  Assert-Equal -Actual ($result.Commands -join "`n") -Expected "docker|$fixtureRoot|compose up -d --wait mysql" -Message 'Docker failure must prevent application startup'
  Assert-True -Condition ($testStopwatch.ElapsedMilliseconds -lt 15000) -Message 'Behavior test must complete within its wall-clock deadline'
}
finally {
  foreach ($pidPath in @($env:DESCENDANT_PID_PATH, $env:BACKEND_DESCENDANT_PID_PATH)) {
    if (Test-Path -LiteralPath $pidPath -PathType Leaf) {
      $fixtureProcess = Get-Process -Id ([int][IO.File]::ReadAllText($pidPath)) -ErrorAction SilentlyContinue
      if ($null -ne $fixtureProcess) {
        Stop-Process -InputObject $fixtureProcess -Force -ErrorAction SilentlyContinue
        $null = $fixtureProcess.WaitForExit(2000)
      }
    }
  }
  if ($null -ne $sentinelProcess) {
    try {
      $sentinelProcess.Refresh()
      if (-not $sentinelProcess.HasExited) {
        Stop-Process -InputObject $sentinelProcess -Force -ErrorAction Stop
      }
    }
    catch {
      Write-Warning "Unable to stop sentinel process: $($_.Exception.Message)"
    }
  }
  $env:PATH = $originalPath
  foreach ($environmentVariable in @(
      @{ Name = 'COMMAND_LOG'; Value = $originalCommandLog },
      @{ Name = 'FAKE_DOCKER_EXIT_CODE'; Value = $originalDockerExitCode },
      @{ Name = 'DESCENDANT_PID_PATH'; Value = $originalDescendantPidPath },
      @{ Name = 'BACKEND_DESCENDANT_PID_PATH'; Value = $originalBackendDescendantPidPath },
      @{ Name = 'FRONTEND_READY_PATH'; Value = $originalFrontendReadyPath },
      @{ Name = 'BACKEND_READY_PATH'; Value = $originalBackendReadyPath },
      @{ Name = 'ARGV_LOG'; Value = $originalArgvLog }
    )) {
    if ($null -eq $environmentVariable.Value) {
      Remove-Item "Env:$($environmentVariable.Name)" -ErrorAction SilentlyContinue
    }
    else {
      Set-Item "Env:$($environmentVariable.Name)" -Value $environmentVariable.Value
    }
  }
  if (Test-Path -LiteralPath $fixtureRoot) {
    if (-not (Test-IsSafeTemporaryFixture -Path $fixtureRoot)) {
      throw "Refusing to remove fixture outside TEMP: $fixtureRoot"
    }
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Error -ErrorAction Continue $failure
  }
  exit 1
}

Write-Output 'PASS: unified development entrypoint behavior is valid.'
exit 0
