[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$entrypointPath = Join-Path $repoRoot 'scripts\test.ps1'
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryBase ("t01-03-test-entrypoint-{0}" -f [Guid]::NewGuid().ToString('N'))
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

  if ($Actual -ne $Expected) {
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
  param(
    [switch]$WithE2E
  )

  if (Test-Path -LiteralPath $fixtureRoot) {
    if (-not (Test-IsSafeTemporaryFixture -Path $fixtureRoot)) {
      throw "Refusing to remove fixture outside TEMP: $fixtureRoot"
    }
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }

  New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot 'backend'), (Join-Path $fixtureRoot 'frontend'), (Join-Path $fixtureRoot 'shims') | Out-Null
  $scripts = if ($WithE2E) { '"scripts":{"test:e2e":"playwright test"}' } else { '"scripts":{}' }
  Write-FixtureFile -RelativePath 'frontend\package.json' -Content ("{{{0}}}" -f $scripts)
  Write-FixtureFile -RelativePath 'shims\log-command.ps1' -Content @'
param(
  [Parameter(Mandatory, Position = 0)]
  [string]$Name,

  [Parameter(Mandatory, Position = 1)]
  [string]$WorkingDirectory,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CommandArguments
)

[IO.File]::AppendAllText($env:COMMAND_LOG, ("{0}|{1}|{2}{3}" -f $Name, $WorkingDirectory, ($CommandArguments -join ' '), [Environment]::NewLine))
if ($Name -eq 'python' -and ($CommandArguments -join ' ') -eq '-m ruff check .' -and $env:FAKE_FAIL_RUFF_CHECK -eq '1') {
  exit 9
}

exit 0
'@
  $shim = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0log-command.ps1" __NAME__ "%CD%" %*
exit /b %ERRORLEVEL%
'@
  Write-FixtureFile -RelativePath 'shims\python.cmd' -Content $shim.Replace('__NAME__', 'python')
  Write-FixtureFile -RelativePath 'shims\pnpm.cmd' -Content $shim.Replace('__NAME__', 'pnpm')
}

function Invoke-Entrypoint {
  param(
    [Parameter(Mandatory)]
    [string]$CommandLogPath
  )

  $env:COMMAND_LOG = $CommandLogPath
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $temporaryBase
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entrypointPath -RepoRoot $fixtureRoot 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
    $ErrorActionPreference = $previousErrorActionPreference
  }

  return @{
    ExitCode = $exitCode
    Output = ($output | Out-String)
    Commands = if (Test-Path -LiteralPath $CommandLogPath) { [IO.File]::ReadAllLines($CommandLogPath) } else { @() }
  }
}

if (-not (Test-Path -LiteralPath $entrypointPath -PathType Leaf)) {
  throw "Expected unified test entrypoint script is missing: $entrypointPath"
}

$originalPath = $env:PATH
$originalCommandLog = $env:COMMAND_LOG
$originalFailRuffCheck = $env:FAKE_FAIL_RUFF_CHECK

try {
  New-Fixture
  $shimPath = Join-Path $fixtureRoot 'shims'
  $env:PATH = "$shimPath;$originalPath"
  $commandLogPath = Join-Path $fixtureRoot 'commands.log'
  $result = Invoke-Entrypoint -CommandLogPath $commandLogPath
  $backendPath = Join-Path $fixtureRoot 'backend'
  $frontendPath = Join-Path $fixtureRoot 'frontend'

  Assert-Equal -Actual $result.ExitCode -Expected 0 -Message 'Configured checks should pass with successful command shims'
  Assert-Equal -Actual ($result.Commands -join "`n") -Expected (@(
      "python|$backendPath|-m ruff format --check .",
      "python|$backendPath|-m ruff check .",
      "python|$backendPath|-m mypy",
      "python|$backendPath|-m pytest",
      "pnpm|$frontendPath|test --run",
      "pnpm|$frontendPath|typecheck"
    ) -join "`n") -Message 'Checks should run in the required order and working directories'
  Assert-Contains -Actual $result.Output -Expected 'SKIP: frontend test:e2e is reserved for T01-13.' -Message 'Absent E2E script should produce the reserved-stage skip message'
  Assert-Contains -Actual $result.Output -Expected 'All configured checks passed.' -Message 'Successful run should report completion'

  New-Fixture
  $env:PATH = "$(Join-Path $fixtureRoot 'shims');$originalPath"
  $env:FAKE_FAIL_RUFF_CHECK = '1'
  $result = Invoke-Entrypoint -CommandLogPath (Join-Path $fixtureRoot 'failed-commands.log')
  Assert-True -Condition ($result.ExitCode -ne 0) -Message 'A failing command should fail the entrypoint'
  Assert-Contains -Actual $result.Output -Expected 'backend ruff check' -Message 'Failure output should identify the failing stage'
  Assert-Contains -Actual $result.Output -Expected 'exit code 9' -Message 'Failure output should include the command exit code'
  Assert-Equal -Actual ($result.Commands -join "`n") -Expected (@(
      "python|$backendPath|-m ruff format --check .",
      "python|$backendPath|-m ruff check ."
    ) -join "`n") -Message 'Entrypoint should stop immediately after the failing backend ruff check'

  Remove-Item Env:FAKE_FAIL_RUFF_CHECK -ErrorAction SilentlyContinue
  New-Fixture -WithE2E
  $env:PATH = "$(Join-Path $fixtureRoot 'shims');$originalPath"
  $result = Invoke-Entrypoint -CommandLogPath (Join-Path $fixtureRoot 'e2e-commands.log')
  Assert-Equal -Actual $result.ExitCode -Expected 0 -Message 'An E2E fixture should pass with successful command shims'
  Assert-True -Condition (@($result.Commands -match '^pnpm\|.*\|test:e2e$').Count -eq 1) -Message 'Exact package test:e2e script should run pnpm test:e2e'
  Assert-True -Condition (-not $result.Output.Contains('SKIP: frontend test:e2e is reserved for T01-13.')) -Message 'Configured E2E stage should not be skipped'
}
finally {
  $env:PATH = $originalPath
  if ($null -eq $originalCommandLog) {
    Remove-Item Env:COMMAND_LOG -ErrorAction SilentlyContinue
  }
  else {
    $env:COMMAND_LOG = $originalCommandLog
  }
  if ($null -eq $originalFailRuffCheck) {
    Remove-Item Env:FAKE_FAIL_RUFF_CHECK -ErrorAction SilentlyContinue
  }
  else {
    $env:FAKE_FAIL_RUFF_CHECK = $originalFailRuffCheck
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

Write-Output 'PASS: unified test entrypoint behavior is valid.'
exit 0
