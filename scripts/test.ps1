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

function Resolve-RequiredApplication {
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )

  $application = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $application) {
    throw "Required application '$Name' was not found on PATH."
  }

  $applicationPath = if ([string]::IsNullOrWhiteSpace($application.Path)) { $application.Source } else { $application.Path }
  if ([string]::IsNullOrWhiteSpace($applicationPath) -or -not (Test-Path -LiteralPath $applicationPath -PathType Leaf)) {
    throw "Required application '$Name' did not resolve to an executable file."
  }

  return (Resolve-Path -LiteralPath $applicationPath -ErrorAction Stop).Path
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
  $exitCode = $null
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

$pythonExecutable = Resolve-RequiredApplication -Name 'python'
$pnpmExecutable = Resolve-RequiredApplication -Name 'pnpm'
$powershellExecutable = Resolve-RequiredApplication -Name 'powershell.exe'

$repositoryTestsPath = Join-Path $repoRoot 'scripts\tests'
if (Test-Path -LiteralPath $repositoryTestsPath -PathType Container) {
  $repositoryTests = Get-ChildItem -LiteralPath $repositoryTestsPath -File -Filter 'test_*.ps1' | Sort-Object -Property Name
  foreach ($repositoryTest in $repositoryTests) {
    Invoke-CheckedCommand -StageName "repository PowerShell test $($repositoryTest.Name)" -WorkingDirectory $repoRoot -Executable $powershellExecutable -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $repositoryTest.FullName)
  }
}

Invoke-CheckedCommand -StageName 'backend ruff format check' -WorkingDirectory $backendPath -Executable $pythonExecutable -Arguments @('-m', 'ruff', 'format', '--check', '.')
Invoke-CheckedCommand -StageName 'backend ruff check' -WorkingDirectory $backendPath -Executable $pythonExecutable -Arguments @('-m', 'ruff', 'check', '.')
Invoke-CheckedCommand -StageName 'backend mypy' -WorkingDirectory $backendPath -Executable $pythonExecutable -Arguments @('-m', 'mypy')
Invoke-CheckedCommand -StageName 'backend pytest' -WorkingDirectory $backendPath -Executable $pythonExecutable -Arguments @('-m', 'pytest')
Invoke-CheckedCommand -StageName 'frontend test' -WorkingDirectory $frontendPath -Executable $pnpmExecutable -Arguments @('test', '--run')
Invoke-CheckedCommand -StageName 'frontend typecheck' -WorkingDirectory $frontendPath -Executable $pnpmExecutable -Arguments @('typecheck')

$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
$scriptsProperty = $packageJson.psobject.Properties['scripts']
$e2eProperty = $null
if ($null -ne $scriptsProperty -and $null -ne $scriptsProperty.Value) {
  foreach ($property in $scriptsProperty.Value.psobject.Properties) {
    if ($property.Name -ceq 'test:e2e') {
      $e2eProperty = $property
      break
    }
  }
}
if ($null -ne $e2eProperty) {
  Invoke-CheckedCommand -StageName 'frontend test:e2e' -WorkingDirectory $frontendPath -Executable $pnpmExecutable -Arguments @('test:e2e')
}
else {
  Write-Output 'SKIP: frontend test:e2e is reserved for T01-13.'
}

Write-Output 'All configured checks passed.'
