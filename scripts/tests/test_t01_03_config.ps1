[CmdletBinding()]
param()

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

function Assert-Matches {
    param(
        [Parameter(Mandatory)]
        [string]$Actual,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Actual -notmatch $Pattern) {
        $failures.Add("$Message (pattern: '$Pattern')")
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

function Assert-NotMatches {
    param(
        [Parameter(Mandatory)]
        [string]$Actual,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Actual -match $Pattern) {
        $failures.Add("$Message (unexpected pattern: '$Pattern')")
    }
}

Assert-PathExists -Path $editorConfigPath -Message '.editorconfig should exist'
Assert-PathExists -Path $gitIgnorePath -Message '.gitignore should exist'
Assert-PathExists -Path $composePath -Message 'docker-compose.yml should exist'

if (Test-Path -LiteralPath $editorConfigPath -PathType Leaf) {
    $editorConfig = [IO.File]::ReadAllText($editorConfigPath)
    Assert-Matches -Actual $editorConfig -Pattern '(?m)^root\s*=\s*true\s*$' -Message '.editorconfig should declare the repository root'
    Assert-Matches -Actual $editorConfig -Pattern '(?m)^charset\s*=\s*utf-8\s*$' -Message '.editorconfig should use UTF-8'
    Assert-Matches -Actual $editorConfig -Pattern '(?m)^end_of_line\s*=\s*lf\s*$' -Message '.editorconfig should use LF endings'
    Assert-Matches -Actual $editorConfig -Pattern '(?ms)^\[\*\.py\].*?^indent_size\s*=\s*4\s*$' -Message '.editorconfig should use four spaces for Python'
    Assert-Matches -Actual $editorConfig -Pattern '(?ms)^\[\*\.\{vue,ts,js,json,yml,yaml,ps1\}\].*?^indent_size\s*=\s*2\s*$' -Message '.editorconfig should use two spaces for app and script files'
}

if (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf) {
    $gitIgnore = [IO.File]::ReadAllText($gitIgnorePath)
    Assert-Contains -Actual $gitIgnore -Expected '.worktrees/' -Message '.gitignore should ignore isolated worktrees'
    Assert-Contains -Actual $gitIgnore -Expected '.env' -Message '.gitignore should ignore environment files'
    Assert-Contains -Actual $gitIgnore -Expected '!.env.example' -Message '.gitignore should retain the environment template'
    Assert-Matches -Actual $gitIgnore -Pattern '(?m)^__pycache__/$' -Message '.gitignore should ignore Python caches'
    Assert-Matches -Actual $gitIgnore -Pattern '(?m)^\.venv/$' -Message '.gitignore should ignore the Python virtual environment'
    Assert-Matches -Actual $gitIgnore -Pattern '(?m)^node_modules/$' -Message '.gitignore should ignore Node dependencies'
    Assert-Matches -Actual $gitIgnore -Pattern '(?m)^dist/$' -Message '.gitignore should ignore build output'
    Assert-NotMatches -Actual $gitIgnore -Pattern '(?m)^pnpm-lock\.yaml$' -Message '.gitignore must not ignore pnpm-lock.yaml'
}

if (Test-Path -LiteralPath $composePath -PathType Leaf) {
    $compose = [IO.File]::ReadAllText($composePath)
    Assert-Matches -Actual $compose -Pattern '(?m)^\s*start_interval:\s*2s\s*$' -Message 'MySQL healthcheck should use a two-second start interval'
    Assert-NotMatches -Actual $compose -Pattern '(?m)^\s{2}(redis|minio):\s*$' -Message 'Compose must not define Redis or MinIO services'

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $composeOutput = & docker compose -f $composePath config 2>&1
        $composeExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($composeExitCode -ne 0) {
        $failures.Add("docker compose config failed (exit code $composeExitCode): $($composeOutput | Out-String)")
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}

Write-Output 'PASS: T01-03 development configuration is valid.'
exit 0
