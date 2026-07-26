[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$workflowPath = Join-Path $repoRoot '.github\workflows\ci.yml'
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
  param(
    [Parameter(Mandatory)]
    [string]$Message
  )

  $failures.Add($Message)
}

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
    Add-Failure -Message "$Message (expected: '$Expected'; actual: '$Actual')"
  }
}

function Get-RequiredProperty {
  param(
    [Parameter(Mandatory)]
    [object]$Object,

    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Context
  )

  if ($null -eq $Object) {
    Add-Failure -Message "$Context should be a mapping before reading '$Name'."
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    Add-Failure -Message "$Context should contain '$Name'."
    return $null
  }

  return $property.Value
}

function Assert-StringArrayEqual {
  param(
    [Parameter(Mandatory)]
    [object]$Actual,

    [Parameter(Mandatory)]
    [string[]]$Expected,

    [Parameter(Mandatory)]
    [string]$Message
  )

  $actualValues = @($Actual | ForEach-Object { [string]$_ })
  if (($actualValues -join "`n") -cne ($Expected -join "`n")) {
    Add-Failure -Message "$Message (expected: '$($Expected -join ', ')'; actual: '$($actualValues -join ', ')')"
  }
}

function Assert-StepAction {
  param(
    [Parameter(Mandatory)]
    [object]$Step,

    [Parameter(Mandatory)]
    [string]$ExpectedUse,

    [Parameter(Mandatory)]
    [string]$Context
  )

  Assert-Equal -Actual ([string](Get-RequiredProperty -Object $Step -Name 'uses' -Context $Context)) -Expected $ExpectedUse -Message "$Context should use the required action"
}

function Test-IsEmptyMapping {
  param(
    [object]$Value
  )

  return $null -ne $Value -and -not ($Value -is [string]) -and @($Value.PSObject.Properties).Count -eq 0
}

if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
  Add-Failure -Message "Required CI workflow is missing: $workflowPath"
}
else {
  $python = Get-Command -Name 'python' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $python) {
    Add-Failure -Message 'Python executable was not found; cannot parse the CI workflow with PyYAML.'
  }
  else {
    $pythonPath = if ([string]::IsNullOrWhiteSpace($python.Path)) { $python.Source } else { $python.Path }
    $parser = @'
import json
import sys

try:
    import yaml
except ImportError as error:
    raise SystemExit('PyYAML is required to parse ci.yml: {}'.format(error))

try:
    with open(sys.argv[1], encoding='utf-8') as workflow_file:
        document = yaml.load(workflow_file, Loader=yaml.BaseLoader)
except Exception as error:
    raise SystemExit('Unable to parse ci.yml as YAML: {}'.format(error))

if not isinstance(document, dict):
    raise SystemExit('ci.yml must parse to a mapping')

print(json.dumps(document))
'@
    $parseOutput = @()
    $parseExitCode = $null
    try {
      $previousErrorActionPreference = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      $parseOutput = & $pythonPath -c $parser $workflowPath 2>&1
      $parseExitCode = $LASTEXITCODE
    }
    finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($parseExitCode -ne 0) {
      Add-Failure -Message "Python/PyYAML could not parse ci.yml (exit code $parseExitCode): $($parseOutput | Out-String)"
    }
    else {
      try {
        $workflow = ($parseOutput | Out-String | ConvertFrom-Json -ErrorAction Stop)
      }
      catch {
        Add-Failure -Message "Python/PyYAML did not return a valid parsed workflow model: $($_.Exception.Message)"
        $workflow = $null
      }

      if ($null -ne $workflow) {
        Assert-Equal -Actual ([string](Get-RequiredProperty -Object $workflow -Name 'name' -Context 'Workflow')) -Expected 'CI' -Message 'Workflow name'

        $triggers = Get-RequiredProperty -Object $workflow -Name 'on' -Context 'Workflow'
        if ($null -ne $triggers) {
          $triggerNames = @($triggers.PSObject.Properties | ForEach-Object { $_.Name })
          if ($triggerNames.Count -ne 2 -or -not ($triggerNames -ccontains 'pull_request') -or -not ($triggerNames -ccontains 'push')) {
            Add-Failure -Message "Workflow triggers should contain exactly the case-sensitive keys pull_request and push (actual: '$($triggerNames -join ', ')')."
          }
        }
        $pullRequest = Get-RequiredProperty -Object $triggers -Name 'pull_request' -Context 'Workflow triggers'
        if ($null -ne $pullRequest -and -not [string]::IsNullOrEmpty([string]$pullRequest) -and -not (Test-IsEmptyMapping -Value $pullRequest)) {
          Add-Failure -Message 'pull_request should run for all pull requests without restrictions.'
        }
        $push = Get-RequiredProperty -Object $triggers -Name 'push' -Context 'Workflow triggers'
        $pushBranches = Get-RequiredProperty -Object $push -Name 'branches' -Context 'push trigger'
        Assert-StringArrayEqual -Actual $pushBranches -Expected @('main') -Message 'push trigger branches'

        $permissions = Get-RequiredProperty -Object $workflow -Name 'permissions' -Context 'Workflow'
        Assert-Equal -Actual ([string](Get-RequiredProperty -Object $permissions -Name 'contents' -Context 'permissions')) -Expected 'read' -Message 'permissions.contents'
        if ($null -ne $permissions -and @($permissions.PSObject.Properties).Count -ne 1) {
          Add-Failure -Message 'permissions should grant only contents: read.'
        }

        $concurrency = Get-RequiredProperty -Object $workflow -Name 'concurrency' -Context 'Workflow'
        Assert-Equal -Actual ([string](Get-RequiredProperty -Object $concurrency -Name 'group' -Context 'concurrency')) -Expected '${{ github.workflow }}-${{ github.ref }}' -Message 'concurrency.group'
        Assert-Equal -Actual ([string](Get-RequiredProperty -Object $concurrency -Name 'cancel-in-progress' -Context 'concurrency')) -Expected 'true' -Message 'concurrency.cancel-in-progress'

        $jobs = Get-RequiredProperty -Object $workflow -Name 'jobs' -Context 'Workflow'
        if ($null -ne $jobs -and @($jobs.PSObject.Properties).Count -ne 1) {
          Add-Failure -Message 'Workflow should define exactly one quality job.'
        }
        $quality = Get-RequiredProperty -Object $jobs -Name 'quality' -Context 'Workflow jobs'
        Assert-Equal -Actual ([string](Get-RequiredProperty -Object $quality -Name 'runs-on' -Context 'quality job')) -Expected 'windows-latest' -Message 'quality job runner'
        Assert-Equal -Actual ([string](Get-RequiredProperty -Object $quality -Name 'timeout-minutes' -Context 'quality job')) -Expected '20' -Message 'quality job timeout'

        $servicesProperty = $quality.PSObject.Properties['services']
        if ($null -ne $servicesProperty -and $null -ne $servicesProperty.Value) {
          foreach ($service in $servicesProperty.Value.PSObject.Properties) {
            if ($service.Name -match '(?i)^(mysql|redis|minio)$') {
              Add-Failure -Message "quality job must not start the prohibited service '$($service.Name)'."
            }
          }
        }

        $steps = @(Get-RequiredProperty -Object $quality -Name 'steps' -Context 'quality job')
        if ($steps.Count -ne 7) {
          Add-Failure -Message "quality job should contain exactly seven ordered steps (actual: $($steps.Count))."
        }
        else {
          Assert-StepAction -Step $steps[0] -ExpectedUse 'actions/checkout@v6' -Context 'Step 1'
          Assert-StepAction -Step $steps[1] -ExpectedUse 'actions/setup-python@v6' -Context 'Step 2'
          $pythonWith = Get-RequiredProperty -Object $steps[1] -Name 'with' -Context 'Step 2'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $pythonWith -Name 'python-version' -Context 'Step 2 with')) -Expected '3.12' -Message 'Step 2 Python version'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $pythonWith -Name 'cache' -Context 'Step 2 with')) -Expected 'pip' -Message 'Step 2 cache'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $pythonWith -Name 'cache-dependency-path' -Context 'Step 2 with')) -Expected 'backend/pyproject.toml' -Message 'Step 2 cache dependency path'

          Assert-StepAction -Step $steps[2] -ExpectedUse 'pnpm/action-setup@v6' -Context 'Step 3'
          $pnpmWith = Get-RequiredProperty -Object $steps[2] -Name 'with' -Context 'Step 3'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $pnpmWith -Name 'version' -Context 'Step 3 with')) -Expected '11.4.0' -Message 'Step 3 pnpm version'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $pnpmWith -Name 'run_install' -Context 'Step 3 with')) -Expected 'false' -Message 'Step 3 automatic install setting'

          Assert-StepAction -Step $steps[3] -ExpectedUse 'actions/setup-node@v6' -Context 'Step 4'
          $nodeWith = Get-RequiredProperty -Object $steps[3] -Name 'with' -Context 'Step 4'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $nodeWith -Name 'node-version' -Context 'Step 4 with')) -Expected '24' -Message 'Step 4 Node version'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $nodeWith -Name 'cache' -Context 'Step 4 with')) -Expected 'pnpm' -Message 'Step 4 cache'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $nodeWith -Name 'cache-dependency-path' -Context 'Step 4 with')) -Expected 'frontend/pnpm-lock.yaml' -Message 'Step 4 cache dependency path'

          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $steps[4] -Name 'run' -Context 'Step 5')) -Expected 'python -m pip install -e "backend[dev]" "PyYAML>=6,<7"' -Message 'Step 5 backend dependency installation'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $steps[5] -Name 'run' -Context 'Step 6')) -Expected 'pnpm install --frozen-lockfile' -Message 'Step 6 frontend dependency installation'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $steps[5] -Name 'working-directory' -Context 'Step 6')) -Expected 'frontend' -Message 'Step 6 working directory'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $steps[6] -Name 'run' -Context 'Step 7')) -Expected 'powershell -ExecutionPolicy Bypass -File scripts/test.ps1' -Message 'Step 7 repository checks command'
          Assert-Equal -Actual ([string](Get-RequiredProperty -Object $steps[6] -Name 'shell' -Context 'Step 7')) -Expected 'powershell' -Message 'Step 7 shell'
        }

        foreach ($step in $steps) {
          $runProperty = $step.PSObject.Properties['run']
          if ($null -ne $runProperty -and [string]$runProperty.Value -match '(?i)\b(ruff|mypy|pytest|vitest|typecheck|test:e2e|mysql|redis|minio)\b') {
            $run = [string]$runProperty.Value
            Add-Failure -Message "CI should delegate checks to scripts/test.ps1 and must not duplicate check commands or start services (found: '$run')."
          }
        }
      }
    }
  }
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Error -ErrorAction Continue $failure
  }
  exit 1
}

Write-Output 'PASS: CI workflow contract is valid.'
exit 0
