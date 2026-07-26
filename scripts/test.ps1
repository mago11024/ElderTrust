[CmdletBinding()]
param(
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Resolve-RequiredDirectory {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Name
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Required $Name directory does not exist: $Path"
  }

  return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}

function Resolve-RequiredFile {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Name
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required $Name file does not exist: $Path"
  }

  return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}

function Assert-RequiredCommand {
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )

  if ($null -eq (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found on PATH."
  }
}

function Invoke-CheckedCommand {
  param(
    [Parameter(Mandatory)]
    [string]$StageName,

    [Parameter(Mandatory)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory)]
    [string]$Executable,

    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  Write-Output "RUN: $StageName"
  Push-Location -LiteralPath $WorkingDirectory
  try {
    & $Executable @Arguments
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }

  if ($exitCode -ne 0) {
    throw "Stage '$StageName' failed with exit code $exitCode."
  }
}

$repoRoot = Resolve-RequiredDirectory -Path ([IO.Path]::GetFullPath($RepoRoot)) -Name 'repository root'
$backendPath = Resolve-RequiredDirectory -Path (Join-Path $repoRoot 'backend') -Name 'backend'
$frontendPath = Resolve-RequiredDirectory -Path (Join-Path $repoRoot 'frontend') -Name 'frontend'
$packageJsonPath = Resolve-RequiredFile -Path (Join-Path $frontendPath 'package.json') -Name 'frontend package.json'

Assert-RequiredCommand -Name 'python'
Assert-RequiredCommand -Name 'pnpm'

$repositoryTestsPath = Join-Path $repoRoot 'scripts\tests'
if (Test-Path -LiteralPath $repositoryTestsPath -PathType Container) {
  $repositoryTests = Get-ChildItem -LiteralPath $repositoryTestsPath -File -Filter 'test_*.ps1' | Sort-Object -Property Name
  foreach ($repositoryTest in $repositoryTests) {
    Invoke-CheckedCommand -StageName "repository PowerShell test $($repositoryTest.Name)" -WorkingDirectory $repoRoot -Executable 'powershell.exe' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $repositoryTest.FullName)
  }
}

Invoke-CheckedCommand -StageName 'backend ruff format check' -WorkingDirectory $backendPath -Executable 'python' -Arguments @('-m', 'ruff', 'format', '--check', '.')
Invoke-CheckedCommand -StageName 'backend ruff check' -WorkingDirectory $backendPath -Executable 'python' -Arguments @('-m', 'ruff', 'check', '.')
Invoke-CheckedCommand -StageName 'backend mypy' -WorkingDirectory $backendPath -Executable 'python' -Arguments @('-m', 'mypy')
Invoke-CheckedCommand -StageName 'backend pytest' -WorkingDirectory $backendPath -Executable 'python' -Arguments @('-m', 'pytest')
Invoke-CheckedCommand -StageName 'frontend test' -WorkingDirectory $frontendPath -Executable 'pnpm' -Arguments @('test', '--run')
Invoke-CheckedCommand -StageName 'frontend typecheck' -WorkingDirectory $frontendPath -Executable 'pnpm' -Arguments @('typecheck')

$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
$scriptsProperty = $packageJson.psobject.Properties['scripts']
$e2eProperty = if ($null -eq $scriptsProperty -or $null -eq $scriptsProperty.Value) { $null } else { $scriptsProperty.Value.psobject.Properties['test:e2e'] }
if ($null -ne $e2eProperty) {
  Invoke-CheckedCommand -StageName 'frontend test:e2e' -WorkingDirectory $frontendPath -Executable 'pnpm' -Arguments @('test:e2e')
}
else {
  Write-Output 'SKIP: frontend test:e2e is reserved for T01-13.'
}

Write-Output 'All configured checks passed.'
