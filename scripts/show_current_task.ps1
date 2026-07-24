[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$StatusPath = 'docs\CURRENT_STATUS.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Stop-WithError {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
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

function Get-StatusValues {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $yamlPattern = '(?ms)^```yaml[ \t]*\r?\n(?<body>.*?)^```[ \t]*$'
    $yamlBlocks = @([regex]::Matches($Content, $yamlPattern))

    if ($yamlBlocks.Count -ne 1) {
        throw "CURRENT_STATUS.md must contain exactly one fenced YAML block; found $($yamlBlocks.Count)."
    }

    $values = @{}
    foreach ($line in ($yamlBlocks[0].Groups['body'].Value -split '\r?\n')) {
        if ($line -match '^[A-Za-z_][A-Za-z0-9_]*\s*:') {
            $separatorIndex = $line.IndexOf(':')
            $key = $line.Substring(0, $separatorIndex).Trim()
            $value = $line.Substring($separatorIndex + 1).Trim()

            if ($values.ContainsKey($key)) {
                throw "CURRENT_STATUS.md contains duplicate key '$key'."
            }

            $values[$key] = $value.Trim("'`"")
        }
    }

    return $values
}

function Get-TaskAcceptance {
    param(
        [Parameter(Mandatory)]
        [string]$TaskBody
    )

    $acceptanceMatch = [regex]::Match(
        $TaskBody,
        '(?ms)^\*\*验收：\*\*\s*(?<acceptance>.*?)(?=\r?\n\r?\n|\z)'
    )

    if (-not $acceptanceMatch.Success) {
        return '未定义'
    }

    return ($acceptanceMatch.Groups['acceptance'].Value -replace '\s+', ' ').Trim()
}

try {
    $resolvedRepoRoot = [IO.Path]::GetFullPath($RepoRoot)
    $resolvedStatusPath = Resolve-RepositoryPath `
        -Root $resolvedRepoRoot `
        -Path $StatusPath `
        -Description 'Status path'

    if (-not (Test-Path -LiteralPath $resolvedStatusPath -PathType Leaf)) {
        throw "Status file not found: $resolvedStatusPath"
    }

    $statusContent = [IO.File]::ReadAllText($resolvedStatusPath)
    $status = Get-StatusValues -Content $statusContent
    $requiredKeys = @('current_milestone', 'current_task', 'status', 'task_catalog')

    foreach ($requiredKey in $requiredKeys) {
        if (-not $status.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($status[$requiredKey])) {
            throw "CURRENT_STATUS.md is missing required key '$requiredKey'."
        }
    }

    $currentTaskId = $status['current_task']
    if ($currentTaskId -notmatch '^T\d{2}-\d{2}$') {
        throw "Invalid current_task '$currentTaskId'; expected TNN-NN."
    }

    $catalogPath = Resolve-RepositoryPath `
        -Root $resolvedRepoRoot `
        -Path $status['task_catalog'] `
        -Description 'Task catalog path'

    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        throw "Task catalog not found: $catalogPath"
    }

    $catalogContent = [IO.File]::ReadAllText($catalogPath)
    $taskPattern = '(?ms)^###\s+(?<id>T\d{2}-\d{2})：(?<title>[^\r\n]+)\r?\n(?<body>.*?)(?=^###\s+T\d{2}-\d{2}：|\z)'
    $taskMatches = @([regex]::Matches($catalogContent, $taskPattern))
    $currentMatches = @($taskMatches | Where-Object { $_.Groups['id'].Value -eq $currentTaskId })

    if ($currentMatches.Count -ne 1) {
        throw "Current Task '$currentTaskId' must appear exactly once in the catalog; found $($currentMatches.Count)."
    }

    $currentTask = $currentMatches[0]
    $currentIndex = [Array]::IndexOf($taskMatches, $currentTask)
    $dependencyLine = [regex]::Match(
        $currentTask.Groups['body'].Value,
        '(?m)^\*\*依赖：\*\*\s*(?<dependencies>[^\r\n]*)'
    )
    $dependencyIds = @(
        if ($dependencyLine.Success) {
            [regex]::Matches($dependencyLine.Groups['dependencies'].Value, 'T\d{2}-\d{2}') |
                ForEach-Object { $_.Value } |
                Select-Object -Unique
        }
    )

    $milestonePrefix = $currentTaskId.Substring(0, 3)
    $milestoneTasks = @(
        for ($index = 0; $index -lt $taskMatches.Count; $index++) {
            $task = $taskMatches[$index]
            if ($task.Groups['id'].Value.StartsWith($milestonePrefix, [StringComparison]::Ordinal)) {
                [pscustomobject]@{
                    Index = $index
                    Match = $task
                }
            }
        }
    )

    if ($milestoneTasks.Count -eq 0) {
        throw "No Tasks found for milestone prefix '$milestonePrefix'."
    }

    $nextGateCandidate = $milestoneTasks |
        Where-Object {
            $_.Index -ge $currentIndex -and
            $_.Match.Groups['title'].Value -match '(?i)Gate'
        } |
        Select-Object -First 1

    if ($null -eq $nextGateCandidate) {
        $nextGateCandidate = $milestoneTasks[-1]
    }

    Write-Output "Current Milestone: $($status['current_milestone'])"
    Write-Output "Current Status: $($status['status'])"
    Write-Output "Current Task: $currentTaskId — $($currentTask.Groups['title'].Value.Trim())"
    Write-Output 'Direct Dependencies:'

    if ($dependencyIds.Count -eq 0) {
        Write-Output '- None'
    }
    else {
        foreach ($dependencyId in $dependencyIds) {
            $dependencyMatches = @(
                $taskMatches |
                    Where-Object { $_.Groups['id'].Value -eq $dependencyId }
            )

            if ($dependencyMatches.Count -ne 1) {
                throw "Dependency '$dependencyId' must appear exactly once; found $($dependencyMatches.Count)."
            }

            $dependency = $dependencyMatches[0]
            $acceptance = Get-TaskAcceptance -TaskBody $dependency.Groups['body'].Value
            Write-Output "- $dependencyId — $($dependency.Groups['title'].Value.Trim())"
            Write-Output "  Acceptance: $acceptance"
        }
    }

    $nextGate = $nextGateCandidate.Match
    Write-Output "Next Gate: $($nextGate.Groups['id'].Value) — $($nextGate.Groups['title'].Value.Trim())"
    Write-Output 'Current Task Content:'
    Write-Output "### $currentTaskId：$($currentTask.Groups['title'].Value.Trim())"
    Write-Output $currentTask.Groups['body'].Value.Trim()
}
catch {
    Stop-WithError -Message $_.Exception.Message
}
