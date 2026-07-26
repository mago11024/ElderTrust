[CmdletBinding()]
param(
  [string]$DockerCommand = 'docker',
  [AllowEmptyString()]
  [string]$ComposeJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$editorConfigPath = Join-Path $repoRoot '.editorconfig'
$gitIgnorePath = Join-Path $repoRoot '.gitignore'
$composePath = Join-Path $repoRoot 'docker-compose.yml'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-PathExists {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Message
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $failures.Add("$Message (missing: '$Path')")
  }
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

  if ($Actual -ne $Expected) {
    $failures.Add("$Message (expected: '$Expected'; actual: '$Actual')")
  }
}

function Assert-EditorConfigRoot {
  param(
    [Parameter(Mandatory)]
    [string]$Content
  )

  $preamble = [System.Collections.Generic.List[string]]::new()
  foreach ($line in ($Content -split "`r?`n")) {
    if ($line -match '^\[.*\]$') {
      break
    }
    $preamble.Add($line)
  }

  if (-not ($preamble -match '^\s*root\s*=\s*true\s*$')) {
    $failures.Add('.editorconfig should set root = true before its first section.')
  }
}

function Get-EditorConfigSection {
  param(
    [Parameter(Mandatory)]
    [string]$Content,

    [Parameter(Mandatory)]
    [string]$Header
  )

  $inSection = $false
  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in ($Content -split "`r?`n")) {
    if ($line -eq $Header) {
      $inSection = $true
      continue
    }

    if ($inSection -and $line -match '^\[.*\]$') {
      break
    }

    if ($inSection) {
      $lines.Add($line)
    }
  }

  return ,$lines.ToArray()
}

function Assert-EditorConfigValue {
  param(
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [AllowEmptyString()]
    [string[]]$Section,

    [Parameter(Mandatory)]
    [string]$Header,

    [Parameter(Mandatory)]
    [string]$Key,

    [Parameter(Mandatory)]
    [string]$Value
  )

  if ($Section.Count -eq 0) {
    $failures.Add(".editorconfig should contain section '$Header'")
    return
  }

  $pattern = '^\s*{0}\s*=\s*{1}\s*$' -f [regex]::Escape($Key), [regex]::Escape($Value)
  if (-not ($Section -match $pattern)) {
    $failures.Add(".editorconfig section '$Header' should set $Key = $Value")
  }
}

function Assert-GitIgnoreBehavior {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [bool]$ShouldIgnore
  )

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $null = & git -C $repoRoot check-ignore --no-index --quiet -- $Path 2>&1
    $exitCode = $LASTEXITCODE
    $output = & git -C $repoRoot check-ignore --no-index --verbose -- $Path 2>&1
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  $isIgnored = $exitCode -eq 0
  if ($exitCode -ne 0 -and $exitCode -ne 1) {
    $failures.Add("git check-ignore failed for '$Path' (exit code $exitCode): $($output | Out-String)")
    return
  }

  if ($isIgnored -ne $ShouldIgnore) {
    $expectedState = if ($ShouldIgnore) { 'ignored' } else { 'not ignored' }
    $actualState = if ($isIgnored) { 'ignored' } else { 'not ignored' }
    $failures.Add(".gitignore should leave '$Path' $expectedState (actual: $actualState; diagnostics: $($output | Out-String))")
  }
}

Assert-PathExists -Path $editorConfigPath -Message '.editorconfig should exist'
Assert-PathExists -Path $gitIgnorePath -Message '.gitignore should exist'
Assert-PathExists -Path $composePath -Message 'docker-compose.yml should exist'

if (Test-Path -LiteralPath $editorConfigPath -PathType Leaf) {
  $editorConfig = [IO.File]::ReadAllText($editorConfigPath)
  Assert-EditorConfigRoot -Content $editorConfig
  $globalSection = Get-EditorConfigSection -Content $editorConfig -Header '[*]'
  $pythonSection = Get-EditorConfigSection -Content $editorConfig -Header '[*.py]'
  $appAndScriptSection = Get-EditorConfigSection -Content $editorConfig -Header '[*.{vue,ts,js,json,yml,yaml,ps1}]'
  $markdownSection = Get-EditorConfigSection -Content $editorConfig -Header '[*.md]'

  Assert-EditorConfigValue -Section $globalSection -Header '[*]' -Key 'charset' -Value 'utf-8'
  Assert-EditorConfigValue -Section $globalSection -Header '[*]' -Key 'end_of_line' -Value 'lf'
  Assert-EditorConfigValue -Section $globalSection -Header '[*]' -Key 'insert_final_newline' -Value 'true'
  Assert-EditorConfigValue -Section $globalSection -Header '[*]' -Key 'trim_trailing_whitespace' -Value 'true'
  Assert-EditorConfigValue -Section $globalSection -Header '[*]' -Key 'indent_style' -Value 'space'
  Assert-EditorConfigValue -Section $pythonSection -Header '[*.py]' -Key 'indent_size' -Value '4'
  Assert-EditorConfigValue -Section $appAndScriptSection -Header '[*.{vue,ts,js,json,yml,yaml,ps1}]' -Key 'indent_size' -Value '2'
  Assert-EditorConfigValue -Section $markdownSection -Header '[*.md]' -Key 'trim_trailing_whitespace' -Value 'false'
}

if (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf) {
  foreach ($expectation in @(
      @{ Path = '.env'; ShouldIgnore = $true },
      @{ Path = '.env.example'; ShouldIgnore = $false },
      @{ Path = 'frontend/pnpm-lock.yaml'; ShouldIgnore = $false },
      @{ Path = '.worktrees/example'; ShouldIgnore = $true },
      @{ Path = 'backend/__pycache__/example.pyc'; ShouldIgnore = $true },
      @{ Path = 'backend/.venv/example'; ShouldIgnore = $true },
      @{ Path = 'frontend/node_modules/example'; ShouldIgnore = $true },
      @{ Path = 'frontend/dist/example'; ShouldIgnore = $true },
      @{ Path = 'backend/.coverage'; ShouldIgnore = $true },
      @{ Path = 'frontend/coverage/lcov.info'; ShouldIgnore = $true }
    )) {
    Assert-GitIgnoreBehavior -Path $expectation.Path -ShouldIgnore $expectation.ShouldIgnore
  }
}

if (Test-Path -LiteralPath $composePath -PathType Leaf) {
  $docker = Get-Command -Name $DockerCommand -ErrorAction SilentlyContinue
  if ($null -eq $docker) {
    $failures.Add("Docker command '$DockerCommand' was not found; install Docker Desktop or make docker available on PATH.")
  }
  else {
    $composeOutput = @()
    $composeExitCode = $null
    if ($PSBoundParameters.ContainsKey('ComposeJson')) {
      $composeOutput = $ComposeJson
      $composeExitCode = 0
    }
    else {
      $previousErrorActionPreference = $ErrorActionPreference
      try {
        $ErrorActionPreference = 'Continue'
        $composeOutput = & $DockerCommand compose -f $composePath config --format json 2>&1
        $composeExitCode = $LASTEXITCODE
      }
      finally {
        $ErrorActionPreference = $previousErrorActionPreference
      }
    }

    if ($composeExitCode -ne 0) {
      $failures.Add("docker compose config failed (exit code $composeExitCode): $($composeOutput | Out-String)")
    }
    else {
      try {
        $composeConfig = ($composeOutput | Out-String | ConvertFrom-Json -ErrorAction Stop)
      }
      catch {
        $failures.Add("docker compose config did not produce valid JSON: $($_.Exception.Message)")
        $composeConfig = $null
      }

      if ($null -ne $composeConfig) {
        $servicesProperty = $composeConfig.psobject.Properties['services']
        if ($null -eq $servicesProperty -or $null -eq $servicesProperty.Value) {
          $failures.Add('Normalized Compose configuration should define services.')
        }
        else {
          $services = $servicesProperty.Value
          $serviceNames = @($services.psobject.Properties | ForEach-Object { $_.Name })
          Assert-Equal -Actual ($serviceNames -join ',') -Expected 'mysql' -Message 'Normalized Compose services should contain only mysql'

          $mysqlProperty = $services.psobject.Properties['mysql']
          if ($null -eq $mysqlProperty -or $null -eq $mysqlProperty.Value) {
            $failures.Add('Normalized Compose configuration should define the mysql service.')
          }
          else {
            $mysql = $mysqlProperty.Value
            $healthcheckProperty = $mysql.psobject.Properties['healthcheck']
            if ($null -eq $healthcheckProperty -or $null -eq $healthcheckProperty.Value) {
              $failures.Add('Normalized MySQL Compose configuration should define a healthcheck.')
            }
            else {
              $healthcheck = $healthcheckProperty.Value
              $startIntervalProperty = $healthcheck.psobject.Properties['start_interval']
              if ($null -eq $startIntervalProperty) {
                $failures.Add('Normalized MySQL healthcheck should define start_interval.')
              }
              else {
                Assert-Equal -Actual $startIntervalProperty.Value -Expected '2s' -Message 'MySQL healthcheck start_interval should be two seconds'
              }
            }
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

Write-Output 'PASS: T01-03 development configuration is valid.'
exit 0
