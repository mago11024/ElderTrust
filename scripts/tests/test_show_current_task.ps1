[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$scriptPath = Join-Path $repoRoot 'scripts\show_current_task.ps1'
$statusPath = Join-Path $repoRoot 'docs\CURRENT_STATUS.md'
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

function Assert-NotContains {
    param(
        [Parameter(Mandatory)]
        [string]$Actual,

        [Parameter(Mandatory)]
        [string]$Unexpected,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Actual.Contains($Unexpected)) {
        $failures.Add("$Message (unexpected: '$Unexpected')")
    }
}

function Invoke-Extractor {
    param(
        [Parameter(Mandatory)]
        [string]$InputStatusPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
            -RepoRoot $repoRoot `
            -StatusPath $InputStatusPath 2>&1
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

function New-TemporaryStatus {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $path = Join-Path $PSScriptRoot ("status-{0}.md" -f [Guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
    return $path
}

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Expected extractor script does not exist: $scriptPath"
}

$originalStatus = [IO.File]::ReadAllText($statusPath)
$currentTaskMatch = [regex]::Match(
    $originalStatus,
    '(?m)^current_task:\s*(?<id>T\d{2}-\d{2})\s*$'
)
if (-not $currentTaskMatch.Success) {
    throw 'Current status does not contain a valid current_task.'
}
$currentTaskId = $currentTaskMatch.Groups['id'].Value

$result = Invoke-Extractor -InputStatusPath $statusPath
Assert-Equal -Actual $result.ExitCode -Expected 0 -Message 'Default status should be extracted successfully'
Assert-Contains -Actual $result.Output -Expected "Current Task: $currentTaskId" -Message 'Output should identify the current Task'
Assert-Contains -Actual $result.Output -Expected 'Next Gate:' -Message 'Output should identify the next Gate'
$unrelatedTaskId = if ($currentTaskId -eq 'T07-06') { 'T00-01' } else { 'T07-06' }
Assert-NotContains -Actual $result.Output -Unexpected "### $unrelatedTaskId" -Message 'Output should not include unrelated Task bodies'

$temporaryFiles = [System.Collections.Generic.List[string]]::new()

try {
    foreach ($fixture in @(
        @{ TaskId = 'T00-01'; Milestone = 'M0' },
        @{ TaskId = 'T00-02'; Milestone = 'M0' },
        @{ TaskId = 'T07-06'; Milestone = 'M7' }
    )) {
        $fixtureStatus = [regex]::Replace(
            $originalStatus,
            '(?m)^current_task:\s*T\d{2}-\d{2}\s*$',
            "current_task: $($fixture.TaskId)",
            1
        )
        $fixtureStatus = [regex]::Replace(
            $fixtureStatus,
            '(?m)^current_milestone:\s*M\d+\s*$',
            "current_milestone: $($fixture.Milestone)",
            1
        )
        $fixturePath = New-TemporaryStatus -Content $fixtureStatus
        $temporaryFiles.Add($fixturePath)
        $result = Invoke-Extractor -InputStatusPath $fixturePath
        Assert-Equal -Actual $result.ExitCode -Expected 0 -Message "$($fixture.TaskId) fixture should be extracted successfully"
        Assert-Contains -Actual $result.Output -Expected "Current Task: $($fixture.TaskId)" -Message "$($fixture.TaskId) fixture should identify its current Task"
        $fixtureUnrelatedTaskId = if ($fixture.TaskId -eq 'T07-06') { 'T00-01' } else { 'T07-06' }
        Assert-NotContains -Actual $result.Output -Unexpected "### $fixtureUnrelatedTaskId" -Message "$($fixture.TaskId) fixture should not include unrelated Task bodies"
    }

    $missingPath = Join-Path $PSScriptRoot ("missing-{0}.md" -f [Guid]::NewGuid().ToString('N'))
    $result = Invoke-Extractor -InputStatusPath $missingPath
    Assert-Equal -Actual $result.ExitCode -Expected 1 -Message 'A missing status file should fail'
    Assert-Contains -Actual $result.Output -Expected 'ERROR:' -Message 'A missing status file should report a controlled error'

    $invalidTaskStatus = [regex]::Replace(
        $originalStatus,
        '(?m)^current_task:\s*T\d{2}-\d{2}\s*$',
        'current_task: T99-99',
        1
    )
    $invalidTaskPath = New-TemporaryStatus -Content $invalidTaskStatus
    $temporaryFiles.Add($invalidTaskPath)
    $result = Invoke-Extractor -InputStatusPath $invalidTaskPath
    Assert-Equal -Actual $result.ExitCode -Expected 1 -Message 'An unknown current Task should fail'
    Assert-Contains -Actual $result.Output -Expected 'ERROR:' -Message 'An unknown current Task should report a controlled error'

    $duplicateYamlBlock = @'
```yaml
current_task: T00-01
```
'@
    $duplicateYamlStatus = "$originalStatus`r`n$duplicateYamlBlock"
    $duplicateYamlPath = New-TemporaryStatus -Content $duplicateYamlStatus
    $temporaryFiles.Add($duplicateYamlPath)
    $result = Invoke-Extractor -InputStatusPath $duplicateYamlPath
    Assert-Equal -Actual $result.ExitCode -Expected 1 -Message 'Multiple YAML status blocks should fail'
    Assert-Contains -Actual $result.Output -Expected 'ERROR:' -Message 'Multiple YAML status blocks should report a controlled error'

    $escapingCatalogStatus = $originalStatus.Replace(
        'task_catalog: docs/superpowers/plans/2026-07-23-complete-project-task-catalog.md',
        'task_catalog: ../outside.md'
    )
    $escapingCatalogPath = New-TemporaryStatus -Content $escapingCatalogStatus
    $temporaryFiles.Add($escapingCatalogPath)
    $result = Invoke-Extractor -InputStatusPath $escapingCatalogPath
    Assert-Equal -Actual $result.ExitCode -Expected 1 -Message 'A catalog path outside the repository should fail'
    Assert-Contains -Actual $result.Output -Expected 'ERROR:' -Message 'A catalog path outside the repository should report a controlled error'
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

Write-Output 'PASS: show_current_task.ps1 behavior is valid.'
exit 0
