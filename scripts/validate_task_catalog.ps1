[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$CatalogPath = 'docs\superpowers\plans\2026-07-23-complete-project-task-catalog.md',
    [string]$MainPlanPath = 'docs\superpowers\plans\2026-07-23-m1-mvp-and-development-sequence.md',
    [int]$ExpectedTaskCount = 66
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Add-ValidationError {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $errors.Add($Message)
}

function Resolve-RepositoryPath {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $candidate = if ([IO.Path]::IsPathRooted($Path)) {
        [IO.Path]::GetFullPath($Path)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path $resolvedRoot $Path))
    }
    $rootPrefix = $resolvedRoot + [IO.Path]::DirectorySeparatorChar

    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description must remain inside the repository: $Path"
    }

    return $candidate
}

try {
    $resolvedRepoRoot = [IO.Path]::GetFullPath($RepoRoot)
    $resolvedCatalogPath = Resolve-RepositoryPath `
        -Root $resolvedRepoRoot `
        -Path $CatalogPath `
        -Description 'Catalog path'
    $resolvedMainPlanPath = Resolve-RepositoryPath `
        -Root $resolvedRepoRoot `
        -Path $MainPlanPath `
        -Description 'Main plan path'

    if (-not (Test-Path -LiteralPath $resolvedCatalogPath -PathType Leaf)) {
        throw "Catalog not found: $resolvedCatalogPath"
    }
    if (-not (Test-Path -LiteralPath $resolvedMainPlanPath -PathType Leaf)) {
        throw "Main plan not found: $resolvedMainPlanPath"
    }

    $catalog = [IO.File]::ReadAllText($resolvedCatalogPath)
    $mainPlan = [IO.File]::ReadAllText($resolvedMainPlanPath)
    $taskPattern = '(?ms)^###\s+(?<id>T\d{2}-\d{2})：(?<title>[^\r\n]+)\r?\n(?<body>.*?)(?=^###\s+T\d{2}-\d{2}：|\z)'
    $taskMatches = @([regex]::Matches($catalog, $taskPattern))

    if ($taskMatches.Count -ne $ExpectedTaskCount) {
        Add-ValidationError "Expected $ExpectedTaskCount tasks, found $($taskMatches.Count)"
    }

    $taskIds = @($taskMatches | ForEach-Object { $_.Groups['id'].Value })
    foreach ($duplicate in @($taskIds | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-ValidationError "Duplicate task ID: $($duplicate.Name)"
    }

    $taskOrder = @{}
    for ($index = 0; $index -lt $taskMatches.Count; $index++) {
        $taskId = $taskMatches[$index].Groups['id'].Value
        if (-not $taskOrder.ContainsKey($taskId)) {
            $taskOrder[$taskId] = $index
        }
    }

    for ($index = 0; $index -lt $taskMatches.Count; $index++) {
        $taskId = $taskMatches[$index].Groups['id'].Value
        $body = $taskMatches[$index].Groups['body'].Value

        if ($body -notmatch '(?m)^\*\*Files:\*\*[ \t]*$') {
            Add-ValidationError "$taskId is missing Files"
        }
        if ([regex]::Matches($body, '(?m)^- \[ \]').Count -lt 3) {
            Add-ValidationError "$taskId has fewer than three checklist steps"
        }
        if ($body -notmatch '(?m)^\*\*验收：\*\*') {
            Add-ValidationError "$taskId is missing acceptance"
        }
        if ($body -notmatch '(?m)^\*\*不包含：\*\*') {
            Add-ValidationError "$taskId is missing exclusions"
        }

        $dependencyLine = [regex]::Match(
            $body,
            '(?m)^\*\*依赖：\*\*\s*(?<value>[^\r\n]*)'
        )
        if ($dependencyLine.Success) {
            foreach ($dependencyMatch in [regex]::Matches(
                $dependencyLine.Groups['value'].Value,
                'T\d{2}-\d{2}'
            )) {
                $dependencyId = $dependencyMatch.Value
                if (-not $taskOrder.ContainsKey($dependencyId)) {
                    Add-ValidationError "$taskId has unknown dependency $dependencyId"
                }
                elseif ($taskOrder[$dependencyId] -ge $index) {
                    Add-ValidationError "$taskId depends on non-prior task $dependencyId"
                }
            }
        }
    }

    $createPaths = @(
        [regex]::Matches($catalog, '(?m)^- Create: `(?<path>[^`]+)`') |
            ForEach-Object { $_.Groups['path'].Value }
    )
    foreach ($duplicate in @($createPaths | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-ValidationError "Duplicate Create path: $($duplicate.Name)"
    }

    $migrationNumbers = @(
        [regex]::Matches(
            $catalog,
            'backend/alembic/versions/(?<number>\d{4})_[^`]+'
        ) |
            ForEach-Object { [int]$_.Groups['number'].Value }
    )
    foreach ($duplicate in @($migrationNumbers | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-ValidationError "Duplicate migration number: $($duplicate.Name)"
    }
    if ($migrationNumbers.Count -gt 0) {
        $sortedMigrations = @($migrationNumbers | Sort-Object)
        $expectedMigrations = @(1..$sortedMigrations[-1])
        if (@(Compare-Object $expectedMigrations $sortedMigrations).Count -gt 0) {
            Add-ValidationError 'Migration numbers are not continuous'
        }
    }

    $summary = [regex]::Match(
        $catalog,
        '共 (?<total>\d+) 个 Task：M0 (?<m0>\d+) 个、M1 (?<m1>\d+) 个、M2 (?<m2>\d+) 个、M3 (?<m3>\d+) 个、M4 (?<m4>\d+) 个、M5 (?<m5>\d+) 个、M6 (?<m6>\d+) 个、M7 (?<m7>\d+) 个'
    )
    if (-not $summary.Success) {
        Add-ValidationError 'Task count summary is missing'
    }
    else {
        if ([int]$summary.Groups['total'].Value -ne $taskMatches.Count) {
            Add-ValidationError 'Task count summary total does not match'
        }

        for ($milestone = 0; $milestone -le 7; $milestone++) {
            $prefix = 'T{0:D2}' -f $milestone
            $actualCount = @(
                $taskIds |
                    Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }
            ).Count
            $declaredCount = [int]$summary.Groups["m$milestone"].Value

            if ($actualCount -ne $declaredCount) {
                Add-ValidationError "M$milestone count mismatch: declared $declaredCount, actual $actualCount"
            }
        }
    }

    $requiredFamilies = @(
        'FR-AUTH-001..008',
        'FR-LEARN-001..005',
        'FR-TRAIN-001..009',
        'FR-ASSESS-001..008',
        'FR-FAMILY-001..007',
        'FR-SAFETY-001..004',
        'FR-CONTENT-001..008',
        'FR-SCENE-001..004',
        'FR-FALLBACK-001..005',
        'NFR-USE-*',
        'NFR-PERF-*',
        'NFR-SEC-*',
        'NFR-MAINT-*'
    )
    foreach ($family in $requiredFamilies) {
        if (-not $catalog.Contains($family)) {
            Add-ValidationError "Missing requirement family: $family"
        }
    }

    if (-not $mainPlan.Contains('2026-07-23-complete-project-task-catalog.md')) {
        Add-ValidationError 'Main plan does not link to task catalog'
    }

    $placeholderPatterns = @(
        ('T' + 'BD'),
        ('T' + 'ODO'),
        ('implement' + ' later'),
        ('fill in' + ' details')
    )
    foreach ($placeholder in $placeholderPatterns) {
        if ($catalog -match [regex]::Escape($placeholder)) {
            Add-ValidationError "Placeholder found: $placeholder"
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($validationError in $errors) {
            [Console]::Error.WriteLine("ERROR: $validationError")
        }
        exit 1
    }

    Write-Output 'Task catalog validation passed'
    Write-Output "Tasks: $($taskMatches.Count)"
    Write-Output "Migrations: $($migrationNumbers.Count)"
    exit 0
}
catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}
