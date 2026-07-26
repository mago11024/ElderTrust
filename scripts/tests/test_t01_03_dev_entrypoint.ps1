[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$entrypointPath = Join-Path $repoRoot 'scripts\dev.ps1'
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryBase ("t01-03-dev-entrypoint-临时-{0}" -f [Guid]::NewGuid().ToString('N'))
$failures = [System.Collections.Generic.List[string]]::new()

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
  Start-Sleep -Seconds 1
  exit 19
}

if ($Name -eq 'pnpm') {
  $child = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 10') -PassThru
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
}

function Invoke-Entrypoint {
  param(
    [Parameter(Mandatory)]
    [string]$CommandLogPath,

    [switch]$ShadowApplications
  )

  $env:COMMAND_LOG = $CommandLogPath
  $env:DESCENDANT_PID_PATH = Join-Path $fixtureRoot 'descendant.pid'
  $env:BACKEND_READY_PATH = Join-Path $fixtureRoot 'backend.ready'
  if ($ShadowApplications) {
    $wrapperPath = Join-Path $fixtureRoot 'shims\invoke-with-shadows.ps1'
    Write-FixtureFile -RelativePath 'shims\invoke-with-shadows.ps1' -Content @'
param(
  [Parameter(Mandatory)]
  [string]$EntrypointPath,

  [Parameter(Mandatory)]
  [string]$RepoRoot
)

function docker { throw 'The docker function should not be selected.' }
function python { throw 'The python function should not be selected.' }
Set-Alias -Name pnpm -Value Write-Output
& $EntrypointPath -RepoRoot $RepoRoot
exit $LASTEXITCODE
'@
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $wrapperPath, '-EntrypointPath', $entrypointPath, '-RepoRoot', $fixtureRoot)
  }
  else {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entrypointPath, '-RepoRoot', $fixtureRoot)
  }

  $powershellPath = (Get-Command -Name powershell.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Path
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $powershellPath
  $startInfo.Arguments = (($arguments | ForEach-Object { '"{0}"' -f $_.Replace('"', '\\"') }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($startInfo)
  $timedOut = -not $process.WaitForExit(15000)
  if ($timedOut) {
    & taskkill.exe /PID $process.Id /T /F | Out-Null
    $null = $process.WaitForExit(3000)
  }

  $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
  $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }

  return @{
    ExitCode = $exitCode
    Output = ($output | Out-String)
    TimedOut = $timedOut
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

if (-not (Test-Path -LiteralPath $entrypointPath -PathType Leaf)) {
  throw "Expected unified development entrypoint script is missing: $entrypointPath"
}

$originalPath = $env:PATH
$originalCommandLog = $env:COMMAND_LOG
$originalDockerExitCode = $env:FAKE_DOCKER_EXIT_CODE
$originalDescendantPidPath = $env:DESCENDANT_PID_PATH
$originalBackendReadyPath = $env:BACKEND_READY_PATH

try {
  New-Fixture
  $env:PATH = "$(Join-Path $fixtureRoot 'shims');$originalPath"
  $env:FAKE_DOCKER_EXIT_CODE = '0'
  $commandLogPath = Join-Path $fixtureRoot 'commands.log'
  $result = Invoke-Entrypoint -CommandLogPath $commandLogPath -ShadowApplications
  $backendPath = Join-Path $fixtureRoot 'backend'
  $frontendPath = Join-Path $fixtureRoot 'frontend'

  Assert-True -Condition ($result.ExitCode -ne 0) -Message 'An application exit should fail the development launcher'
  Assert-True -Condition (-not $result.TimedOut) -Message 'Launcher should clean up and exit before the bounded fixture timeout'
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

  New-Fixture
  $env:PATH = "$(Join-Path $fixtureRoot 'shims');$originalPath"
  $env:FAKE_DOCKER_EXIT_CODE = '37'
  $result = Invoke-Entrypoint -CommandLogPath (Join-Path $fixtureRoot 'docker-failure.log')
  Assert-True -Condition ($result.ExitCode -ne 0) -Message 'A Docker compose failure should fail the development launcher'
  Assert-True -Condition (-not $result.TimedOut) -Message 'Docker failure should exit before the bounded fixture timeout'
  Assert-Contains -Actual $result.Output -Expected 'Docker compose up failed with exit code 37' -Message 'Docker failure should report its exit code'
  Assert-Equal -Actual ($result.Commands -join "`n") -Expected "docker|$fixtureRoot|compose up -d --wait mysql" -Message 'Docker failure must prevent application startup'
}
finally {
  $env:PATH = $originalPath
  foreach ($environmentVariable in @(
      @{ Name = 'COMMAND_LOG'; Value = $originalCommandLog },
      @{ Name = 'FAKE_DOCKER_EXIT_CODE'; Value = $originalDockerExitCode },
      @{ Name = 'DESCENDANT_PID_PATH'; Value = $originalDescendantPidPath },
      @{ Name = 'BACKEND_READY_PATH'; Value = $originalBackendReadyPath }
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
