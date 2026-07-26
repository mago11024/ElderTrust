[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$validatorPath = Join-Path $repoRoot 'scripts\validate_task_catalog.ps1'
$catalogPath = Join-Path $repoRoot 'docs\superpowers\plans\2026-07-23-complete-project-task-catalog.md'
$mainPlanPath = Join-Path $repoRoot 'docs\superpowers\plans\2026-07-23-m1-mvp-and-development-sequence.md'
$failures = [System.Collections.Generic.List[string]]::new()
$temporaryFiles = [System.Collections.Generic.List[string]]::new()

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

function Invoke-Validator {
    param(
        [Parameter(Mandatory)]
        [string]$InputCatalogPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $validatorPath `
            -RepoRoot $repoRoot `
            -CatalogPath $InputCatalogPath `
            -MainPlanPath $mainPlanPath `
            -ExpectedTaskCount 66 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return @{
        ExitCode = $exitCode
        Output = ($output | Out-String)
    }
}

function New-MutatedCatalog {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $path = Join-Path $PSScriptRoot ("catalog-{0}.md" -f [Guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
    $temporaryFiles.Add($path)
    return $path
}

function Assert-MutationRejected {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$ExpectedError
    )

    $mutatedPath = New-MutatedCatalog -Content $Content
    $result = Invoke-Validator -InputCatalogPath $mutatedPath
    Assert-Equal -Actual $result.ExitCode -Expected 1 -Message "$Name mutation should be rejected"
    Assert-Contains -Actual $result.Output -Expected $ExpectedError -Message "$Name mutation should explain the violated rule"
}

if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
    throw "Expected validator script does not exist: $validatorPath"
}

try {
    $originalCatalog = [IO.File]::ReadAllText($catalogPath)
    $result = Invoke-Validator -InputCatalogPath $catalogPath
    Assert-Equal -Actual $result.ExitCode -Expected 0 -Message 'The authoritative catalog should pass'
    Assert-Contains -Actual $result.Output -Expected 'Task catalog validation passed' -Message 'The authoritative catalog should report success'
    Assert-Contains -Actual $result.Output -Expected 'Tasks: 66' -Message 'The authoritative catalog should report all Tasks'
    Assert-Contains -Actual $result.Output -Expected 'Migrations: 12' -Message 'The authoritative catalog should report all migrations'

    $duplicateId = [regex]::new('(?m)^### T00-02：').Replace(
        $originalCatalog,
        '### T00-01：',
        1
    )
    Assert-MutationRejected `
        -Name 'Duplicate Task ID' `
        -Content $duplicateId `
        -ExpectedError 'Duplicate task ID: T00-01'

    $unknownDependency = [regex]::new(
        '(?m)^\*\*依赖：\*\* T00-01。$'
    ).Replace(
        $originalCatalog,
        '**依赖：** T99-99。',
        1
    )
    Assert-MutationRejected `
        -Name 'Unknown dependency' `
        -Content $unknownDependency `
        -ExpectedError 'unknown dependency T99-99'

    $duplicateMigration = $originalCatalog.Replace(
        'backend/alembic/versions/0002_audit_logs.py',
        'backend/alembic/versions/0001_audit_logs.py'
    )
    Assert-MutationRejected `
        -Name 'Duplicate migration number' `
        -Content $duplicateMigration `
        -ExpectedError 'Duplicate migration number: 1'

    $missingAcceptance = [regex]::new(
        '(?m)^\*\*验收：\*\*'
    ).Replace(
        $originalCatalog,
        '**验证：**',
        1
    )
    Assert-MutationRejected `
        -Name 'Missing acceptance' `
        -Content $missingAcceptance `
        -ExpectedError 'T00-01 is missing acceptance'

    $duplicateCreatePath = $originalCatalog.Replace(
        '- Create: `.env.example`',
        '- Create: `.tool-versions`'
    )
    Assert-MutationRejected `
        -Name 'Duplicate Create path' `
        -Content $duplicateCreatePath `
        -ExpectedError 'Duplicate Create path: .tool-versions'
}
finally {
    foreach ($temporaryFile in $temporaryFiles) {
        if (Test-Path -LiteralPath $temporaryFile) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}

Write-Output 'PASS: validate_task_catalog.ps1 behavior is valid.'
exit 0
