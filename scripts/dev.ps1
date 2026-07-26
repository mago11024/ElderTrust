[CmdletBinding()]
param(
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
  if ([string]::IsNullOrWhiteSpace($applicationPath) -or -not [IO.Path]::IsPathRooted($applicationPath)) {
    throw "Required application '$Name' did not resolve to an absolute executable path."
  }

  $extension = [IO.Path]::GetExtension($applicationPath)
  if ($extension -notin @('.exe', '.com', '.cmd', '.bat') -or -not (Test-Path -LiteralPath $applicationPath -PathType Leaf)) {
    throw "Required application '$Name' did not resolve to a supported executable file."
  }

  return (Resolve-Path -LiteralPath $applicationPath -ErrorAction Stop).Path
}

function ConvertTo-WindowsArgument {
  param(
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string]$Argument
  )

  if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
    return $Argument
  }

  $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\\"')
  $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
  return '"{0}"' -f $escaped
}

function Join-WindowsArguments {
  param(
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [string[]]$Arguments
  )

  return (($Arguments | ForEach-Object { ConvertTo-WindowsArgument -Argument $_ }) -join ' ')
}

function Assert-SafeBatchArguments {
  param(
    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  foreach ($argument in $Arguments) {
    if ($argument -notmatch '^[A-Za-z0-9._:-]+$') {
      throw "Batch application argument is not a safe fixed token: $argument"
    }
  }
}

function Start-ManagedApplication {
  param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory)]
    [string]$Executable,

    [Parameter(Mandatory)]
    [string]$CommandHostExecutable,

    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  Write-Host "START: $Name"
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  if ([IO.Path]::GetExtension($Executable) -in @('.cmd', '.bat')) {
    if ($Executable.Contains('"')) {
      throw "Batch application path contains an unsupported quote: $Executable"
    }
    Assert-SafeBatchArguments -Arguments $Arguments
    $batchArguments = $Arguments -join ' '
    $startInfo.FileName = $CommandHostExecutable
    $startInfo.Arguments = '/d /s /c ""{0}" {1}"' -f $Executable, $batchArguments
  }
  else {
    $startInfo.FileName = $Executable
    $startInfo.Arguments = Join-WindowsArguments -Arguments $Arguments
  }
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $false
  return [System.Diagnostics.Process]::Start($startInfo)
}

function Invoke-DockerComposeUp {
  param(
    [Parameter(Mandatory)]
    [string]$DockerExecutable,

    [Parameter(Mandatory)]
    [string]$WorkingDirectory
  )

  $exitCode = $null
  Push-Location -LiteralPath $WorkingDirectory
  try {
    & $DockerExecutable compose up -d --wait mysql
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }

  if ($exitCode -ne 0) {
    throw "Docker compose up failed with exit code $exitCode."
  }
}

function Stop-ManagedApplication {
  param(
    [AllowNull()]
    [System.Diagnostics.Process]$Process,

    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$TaskkillExecutable
  )

  if ($null -eq $Process) {
    return
  }

  try {
    $Process.Refresh()
    if ($Process.HasExited) {
      return
    }
  }
  catch {
    return
  }

  Write-Host "CLEANUP: stopping $Name process tree (PID $($Process.Id))."
  $taskkillExitCode = $null
  try {
    $taskkillStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $taskkillStartInfo.FileName = $TaskkillExecutable
    $taskkillStartInfo.Arguments = "/PID $($Process.Id) /T /F"
    $taskkillStartInfo.UseShellExecute = $false
    $taskkillStartInfo.CreateNoWindow = $true
    $taskkillProcess = [System.Diagnostics.Process]::Start($taskkillStartInfo)
    if ($taskkillProcess.WaitForExit(2000)) {
      $taskkillExitCode = $taskkillProcess.ExitCode
    }
    else {
      Stop-Process -Id $taskkillProcess.Id -Force -ErrorAction SilentlyContinue
    }
  }
  catch {
    $taskkillExitCode = $null
  }

  if ($taskkillExitCode -eq 0) {
    return
  }

  try {
    $Process.Refresh()
    if (-not $Process.HasExited) {
      Stop-Process -Id $Process.Id -Force -ErrorAction Stop
    }
  }
  catch {
    Write-Warning "Unable to stop $Name process (PID $($Process.Id)): $($_.Exception.Message)"
  }
}

function Wait-ForManagedApplications {
  param(
    [Parameter(Mandatory)]
    [System.Diagnostics.Process]$BackendProcess,

    [Parameter(Mandatory)]
    [System.Diagnostics.Process]$FrontendProcess
  )

  while ($true) {
    foreach ($application in @(
        @{ Name = 'backend'; Process = $BackendProcess },
        @{ Name = 'frontend'; Process = $FrontendProcess }
      )) {
      $application.Process.Refresh()
      if ($application.Process.HasExited) {
        throw "Unexpected $($application.Name) process exit (exit code $($application.Process.ExitCode))."
      }
    }
    Start-Sleep -Milliseconds 200
  }
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

$originalLocation = Get-Location
$backendProcess = $null
$frontendProcess = $null
$taskkillExecutable = $null

try {
  $repoRoot = Resolve-RequiredDirectory -Path ([IO.Path]::GetFullPath($RepoRoot)) -Name 'repository root'
  $backendPath = Resolve-RequiredDirectory -Path (Join-Path $repoRoot 'backend') -Name 'backend'
  $frontendPath = Resolve-RequiredDirectory -Path (Join-Path $repoRoot 'frontend') -Name 'frontend'

  $dockerExecutable = Resolve-RequiredApplication -Name 'docker'
  $pythonExecutable = Resolve-RequiredApplication -Name 'python'
  $pnpmExecutable = Resolve-RequiredApplication -Name 'pnpm'
  $taskkillExecutable = Resolve-RequiredApplication -Name 'taskkill.exe'
  $commandHostExecutable = Resolve-RequiredApplication -Name 'cmd.exe'

  Invoke-DockerComposeUp -DockerExecutable $dockerExecutable -WorkingDirectory $repoRoot
  $backendProcess = Start-ManagedApplication -Name 'backend' -WorkingDirectory $backendPath -Executable $pythonExecutable -CommandHostExecutable $commandHostExecutable -Arguments @('-m', 'uvicorn', 'app.main:app', '--reload')
  $frontendProcess = Start-ManagedApplication -Name 'frontend' -WorkingDirectory $frontendPath -Executable $pnpmExecutable -CommandHostExecutable $commandHostExecutable -Arguments @('dev')
  Wait-ForManagedApplications -BackendProcess $backendProcess -FrontendProcess $frontendProcess
}
finally {
  if ($null -ne $taskkillExecutable) {
    Stop-ManagedApplication -Process $frontendProcess -Name 'frontend' -TaskkillExecutable $taskkillExecutable
    Stop-ManagedApplication -Process $backendProcess -Name 'backend' -TaskkillExecutable $taskkillExecutable
  }
  Set-Location -LiteralPath $originalLocation.Path
}
