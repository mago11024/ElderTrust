[CmdletBinding()]
param(
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($null -eq ('LauncherJob.OwnedJob' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace LauncherJob {
  public sealed class OwnedJob : IDisposable {
    const uint CREATE_SUSPENDED = 0x00000004;
    const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
    IntPtr job;
    bool closed;

    [StructLayout(LayoutKind.Sequential)] struct STARTUPINFO { public uint cb; public string lpReserved; public string lpDesktop; public string lpTitle; public uint dwX; public uint dwY; public uint dwXSize; public uint dwYSize; public uint dwXCountChars; public uint dwYCountChars; public uint dwFillAttribute; public uint dwFlags; public short wShowWindow; public short cbReserved2; public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError; }
    [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public uint dwProcessId; public uint dwThreadId; }
    [StructLayout(LayoutKind.Sequential)] struct BASIC_LIMIT_INFORMATION { public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags; public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit; public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass; }
    [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong ReadOperationCount; public ulong WriteOperationCount; public ulong OtherOperationCount; public ulong ReadTransferCount; public ulong WriteTransferCount; public ulong OtherTransferCount; }
    [StructLayout(LayoutKind.Sequential)] struct EXTENDED_LIMIT_INFORMATION { public BASIC_LIMIT_INFORMATION BasicLimitInformation; public IO_COUNTERS IoInfo; public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit; public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed; }
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length);
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool CreateProcess(string app, StringBuilder commandLine, IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles, uint flags, IntPtr environment, string currentDirectory, ref STARTUPINFO startupInfo, out PROCESS_INFORMATION processInfo);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateProcess(IntPtr process, uint exitCode);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr handle);

    public OwnedJob() {
      job = CreateJobObject(IntPtr.Zero, null);
      if (job == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateJobObject failed.");
      var info = new EXTENDED_LIMIT_INFORMATION(); info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
      IntPtr buffer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(EXTENDED_LIMIT_INFORMATION)));
      try { Marshal.StructureToPtr(info, buffer, false); if (!SetInformationJobObject(job, 9, buffer, (uint)Marshal.SizeOf(typeof(EXTENDED_LIMIT_INFORMATION)))) throw new Win32Exception(Marshal.GetLastWin32Error(), "SetInformationJobObject failed."); }
      catch { Close(); throw; } finally { Marshal.FreeHGlobal(buffer); }
    }
    public Process Start(string application, string commandLine, string currentDirectory) {
      var si = new STARTUPINFO(); si.cb = (uint)Marshal.SizeOf(typeof(STARTUPINFO)); PROCESS_INFORMATION pi;
      if (!CreateProcess(application, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero, true, CREATE_SUSPENDED, IntPtr.Zero, currentDirectory, ref si, out pi)) throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateProcess failed.");
      try { if (!AssignProcessToJobObject(job, pi.hProcess)) throw new Win32Exception(Marshal.GetLastWin32Error(), "AssignProcessToJobObject failed."); if (ResumeThread(pi.hThread) == UInt32.MaxValue) throw new Win32Exception(Marshal.GetLastWin32Error(), "ResumeThread failed."); return Process.GetProcessById((int)pi.dwProcessId); }
      catch { TerminateProcess(pi.hProcess, 1); throw; }
      finally { CloseHandle(pi.hThread); CloseHandle(pi.hProcess); }
    }
    public void Close() { if (closed) return; closed = true; if (job != IntPtr.Zero) { var handle = job; job = IntPtr.Zero; if (!CloseHandle(handle)) throw new Win32Exception(Marshal.GetLastWin32Error(), "CloseHandle(job) failed."); } }
    public void Dispose() { Close(); GC.SuppressFinalize(this); }
  }
}
'@
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

  $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
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
    [LauncherJob.OwnedJob]$Job,

    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  Write-Host "START: $Name"
  $application = $Executable
  $argumentsLine = $null
  if ([IO.Path]::GetExtension($Executable) -in @('.cmd', '.bat')) {
    if ($Executable.Contains('"')) {
      throw "Batch application path contains an unsupported quote: $Executable"
    }
    Assert-SafeBatchArguments -Arguments $Arguments
    $batchArguments = $Arguments -join ' '
    $application = $CommandHostExecutable
    $argumentsLine = '/d /s /c ""{0}" {1}"' -f $Executable, $batchArguments
  }
  else {
    $argumentsLine = Join-WindowsArguments -Arguments $Arguments
  }
  $commandLine = (ConvertTo-WindowsArgument -Argument $application) + ' ' + $argumentsLine
  return $Job.Start($application, $commandLine, $WorkingDirectory)
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

function Confirm-ManagedApplicationsStopped {
  param(
    [AllowEmptyCollection()]
    [System.Diagnostics.Process[]]$Processes
  )
  foreach ($process in $Processes) {
    if ($null -ne $process -and -not $process.WaitForExit(5000)) {
      return "Job close did not terminate managed process PID $($process.Id) within five seconds."
    }
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

if ($MyInvocation.InvocationName -eq '.') {
  return
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

$originalLocation = Get-Location
$backendProcess = $null
$frontendProcess = $null
$ownedJob = $null
$launcherFailure = $null
$cleanupFailures = [System.Collections.Generic.List[string]]::new()

try {
  $repoRoot = Resolve-RequiredDirectory -Path ([IO.Path]::GetFullPath($RepoRoot)) -Name 'repository root'
  $backendPath = Resolve-RequiredDirectory -Path (Join-Path $repoRoot 'backend') -Name 'backend'
  $frontendPath = Resolve-RequiredDirectory -Path (Join-Path $repoRoot 'frontend') -Name 'frontend'

  $dockerExecutable = Resolve-RequiredApplication -Name 'docker'
  $pythonExecutable = Resolve-RequiredApplication -Name 'python'
  $pnpmExecutable = Resolve-RequiredApplication -Name 'pnpm'
  $commandHostExecutable = Resolve-RequiredApplication -Name 'cmd.exe'

  Invoke-DockerComposeUp -DockerExecutable $dockerExecutable -WorkingDirectory $repoRoot
  $ownedJob = [LauncherJob.OwnedJob]::new()
  $backendProcess = Start-ManagedApplication -Name 'backend' -WorkingDirectory $backendPath -Executable $pythonExecutable -CommandHostExecutable $commandHostExecutable -Job $ownedJob -Arguments @('-m', 'uvicorn', 'app.main:app', '--reload')
  $frontendProcess = Start-ManagedApplication -Name 'frontend' -WorkingDirectory $frontendPath -Executable $pnpmExecutable -CommandHostExecutable $commandHostExecutable -Job $ownedJob -Arguments @('dev')
  Wait-ForManagedApplications -BackendProcess $backendProcess -FrontendProcess $frontendProcess
}
catch {
  $launcherFailure = $_
}
finally {
  if ($null -ne $ownedJob) {
    try {
      $ownedJob.Dispose()
      $cleanupResult = Confirm-ManagedApplicationsStopped -Processes @($frontendProcess, $backendProcess)
      if ($null -ne $cleanupResult) {
        $cleanupFailures.Add($cleanupResult)
      }
    }
    catch {
      $cleanupFailures.Add("Job cleanup failed: $($_.Exception.Message)")
    }
  }
  Set-Location -LiteralPath $originalLocation.Path
}

if ($null -ne $launcherFailure) {
  if ($cleanupFailures.Count -gt 0) {
    throw "$($launcherFailure.Exception.Message) Cleanup failures: $($cleanupFailures -join ' ')"
  }
  throw $launcherFailure
}

if ($cleanupFailures.Count -gt 0) {
  throw "Cleanup failures: $($cleanupFailures -join ' ')"
}
