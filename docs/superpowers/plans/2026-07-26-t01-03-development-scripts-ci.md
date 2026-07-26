# T01-03 Unified Development Scripts and CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide one PowerShell development launcher and one local/CI quality command for the FastAPI backend, Vue frontend, and MySQL development service.

**Architecture:** Root-level PowerShell scripts resolve paths from their own location and run child commands with explicit working directories. Behavioral contract tests use temporary repository fixtures and PATH command shims, so they can verify ordering and failure propagation without starting real application servers or changing the developer's MySQL container. GitHub Actions installs dependencies and delegates all quality checks to the same local test script.

**Tech Stack:** Windows PowerShell 5.1-compatible scripts, Docker Compose 5.1.4, Python 3.12, PyYAML 6.x, Ruff, mypy, pytest, Node.js 24, pnpm 11.4.0, Vitest, vue-tsc, GitHub Actions.

---

## File Structure

- Create `scripts/dev.ps1`: start MySQL, launch the backend and frontend in one terminal, and clean up only application process trees created by this invocation.
- Create `scripts/test.ps1`: run repository PowerShell tests, backend checks, frontend checks, and the optional `test:e2e` package script.
- Create `scripts/tests/test_t01_03_config.ps1`: verify editor, ignore, and Compose development contracts.
- Create `scripts/tests/test_t01_03_test_entrypoint.ps1`: execute `scripts/test.ps1` against a temporary repository and fake commands.
- Create `scripts/tests/test_t01_03_dev_entrypoint.ps1`: execute `scripts/dev.ps1` against temporary directories and fake commands.
- Create `scripts/tests/test_t01_03_ci.ps1`: parse and verify the CI workflow contract.
- Create `.github/workflows/ci.yml`: install locked toolchain ranges and invoke `scripts/test.ps1`.
- Create `.editorconfig`: define repository text-format rules.
- Modify `.gitignore`: preserve `.worktrees/` and add generated/local artifacts.
- Modify `docker-compose.yml`: add the MySQL startup health probe interval used by `--wait`.
- Modify `backend/pyproject.toml`: declare PyYAML in the shared `dev` dependency set used by local workflow-contract tests and CI.
- Modify `docs/DEVELOPMENT.md`: replace planned commands with the implemented local and CI workflow.
- Modify `docs/CURRENT_STATUS.md`: mark T01-03 `in_progress` at execution start and `completed` only after fresh verification.

### Task 1: Start T01-03 and establish the configuration contract

**Files:**

- Modify: `docs/CURRENT_STATUS.md`
- Create: `scripts/tests/test_t01_03_config.ps1`
- Create: `.editorconfig`
- Modify: `.gitignore`
- Modify: `docker-compose.yml`

- [ ] **Step 1: Move the dynamic pointer to T01-03**

Change only the YAML block in `docs/CURRENT_STATUS.md`:

```yaml
current_milestone: M1
milestone_status: active
current_task: T01-03
status: in_progress
last_completed_task: T01-02
next_task: T01-04
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
```

Keep the existing `last_verification` until T01-03 is accepted.

- [ ] **Step 2: Write the failing configuration contract test**

Create `scripts/tests/test_t01_03_config.ps1` with assertions for:

```powershell
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Contains {
  param([string]$Actual, [string]$Expected, [string]$Message)
  if (-not $Actual.Contains($Expected)) {
    $failures.Add("$Message (missing: '$Expected')")
  }
}

function Assert-NotContains {
  param([string]$Actual, [string]$Unexpected, [string]$Message)
  if ($Actual.Contains($Unexpected)) {
    $failures.Add("$Message (unexpected: '$Unexpected')")
  }
}

$editorConfigPath = Join-Path $repoRoot '.editorconfig'
$gitignorePath = Join-Path $repoRoot '.gitignore'
$composePath = Join-Path $repoRoot 'docker-compose.yml'

if (-not (Test-Path -LiteralPath $editorConfigPath -PathType Leaf)) {
  $failures.Add('Expected .editorconfig to exist')
} else {
  $editorConfig = [IO.File]::ReadAllText($editorConfigPath)
  Assert-Contains $editorConfig 'charset = utf-8' '.editorconfig should enforce UTF-8'
  Assert-Contains $editorConfig 'end_of_line = lf' '.editorconfig should enforce LF'
  Assert-Contains $editorConfig '[*.py]' '.editorconfig should define Python rules'
  Assert-Contains $editorConfig '[*.{vue,ts,js,json,yml,yaml,ps1}]' '.editorconfig should define app and script rules'
}

$gitignore = [IO.File]::ReadAllText($gitignorePath)
foreach ($entry in @('.worktrees/', '.env', '!.env.example', '__pycache__/', '.venv/', 'node_modules/', 'dist/')) {
  Assert-Contains $gitignore $entry ".gitignore should contain $entry"
}
Assert-NotContains $gitignore 'pnpm-lock.yaml' '.gitignore should retain the frontend lockfile'

$compose = [IO.File]::ReadAllText($composePath)
Assert-Contains $compose 'start_interval: 2s' 'MySQL healthcheck should poll during startup'
Assert-NotContains $compose 'redis:' 'T01-03 should not add Redis'
Assert-NotContains $compose 'minio:' 'T01-03 should not add MinIO'

$composeOutput = & docker compose -f $composePath config 2>&1
if ($LASTEXITCODE -ne 0) {
  $failures.Add("docker compose config failed: $($composeOutput | Out-String)")
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) { Write-Error $failure }
  exit 1
}

Write-Output 'PASS: T01-03 configuration contract is valid.'
```

- [ ] **Step 3: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_config.ps1
```

Expected: exit code 1 with `Expected .editorconfig to exist`.

- [ ] **Step 4: Add the minimal configuration**

Create `.editorconfig`:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space

[*.py]
indent_size = 4

[*.{vue,ts,js,json,yml,yaml,ps1}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false
```

Expand `.gitignore`:

```gitignore
.worktrees/

.env
.env.*
!.env.example

__pycache__/
*.py[cod]
.venv/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage
htmlcov/

node_modules/
dist/
coverage/
.vitest/

.idea/
.vscode/
.DS_Store
Thumbs.db
```

Add this line under the existing MySQL healthcheck `start_period`:

```yaml
      start_interval: 2s
```

- [ ] **Step 5: Run the test and verify GREEN**

Run the test from Step 3.

Expected: `PASS: T01-03 configuration contract is valid.`

- [ ] **Step 6: Commit**

```powershell
git add docs/CURRENT_STATUS.md scripts/tests/test_t01_03_config.ps1 .editorconfig .gitignore docker-compose.yml
git commit -m "chore: establish T01-03 development configuration"
```

### Task 2: Build the unified quality entrypoint

**Files:**

- Create: `scripts/tests/test_t01_03_test_entrypoint.ps1`
- Create: `scripts/test.ps1`

- [ ] **Step 1: Write the failing behavioral test**

Create `scripts/tests/test_t01_03_test_entrypoint.ps1`. The test must:

```powershell
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$scriptPath = Join-Path $repoRoot 'scripts\test.ps1'
$fixtureRoot = Join-Path $env:TEMP ("anxin-test-entry-{0}" -f [Guid]::NewGuid().ToString('N'))
$shimRoot = Join-Path $fixtureRoot 'shims'
$logPath = Join-Path $fixtureRoot 'commands.log'
$oldPath = $env:PATH

try {
  New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'backend'), (Join-Path $fixtureRoot 'frontend'), $shimRoot | Out-Null
  [IO.File]::WriteAllText(
    (Join-Path $fixtureRoot 'frontend\package.json'),
    '{"private":true,"scripts":{"test":"vitest","typecheck":"vue-tsc"}}',
    [Text.UTF8Encoding]::new($false)
  )

  $shim = @'
@echo off
echo %~n0^|%CD%^|%*>>"%FAKE_COMMAND_LOG%"
if not "%FAKE_FAIL_MATCH%"=="" echo %*|findstr /C:"%FAKE_FAIL_MATCH%" >nul && exit /b 9
exit /b 0
'@
  [IO.File]::WriteAllText((Join-Path $shimRoot 'python.cmd'), $shim)
  [IO.File]::WriteAllText((Join-Path $shimRoot 'pnpm.cmd'), $shim)

  $env:PATH = "$shimRoot;$oldPath"
  $env:FAKE_COMMAND_LOG = $logPath
  $env:FAKE_FAIL_MATCH = ''

  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RepoRoot $fixtureRoot 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Expected success, got: $($output | Out-String)" }
  $log = [IO.File]::ReadAllText($logPath)
  foreach ($expected in @('-m ruff format --check .', '-m ruff check .', '-m mypy', '-m pytest', 'test --run', 'typecheck')) {
    if (-not $log.Contains($expected)) { throw "Missing command: $expected" }
  }
  if (-not (($output | Out-String).Contains('SKIP: frontend test:e2e is reserved for T01-13.'))) {
    throw 'Missing explicit E2E skip message'
  }

  [IO.File]::WriteAllText($logPath, '')
  $env:FAKE_FAIL_MATCH = 'ruff check'
  $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RepoRoot $fixtureRoot 2>&1
  if ($LASTEXITCODE -eq 0) { throw 'Expected a failed backend check to propagate' }
  $failedLog = [IO.File]::ReadAllText($logPath)
  if ($failedLog.Contains('typecheck')) { throw 'Checks should stop after failure' }
}
finally {
  $env:PATH = $oldPath
  Remove-Item Env:FAKE_COMMAND_LOG, Env:FAKE_FAIL_MATCH -ErrorAction SilentlyContinue
  $resolvedTemp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
  $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
  if (-not $resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove fixture outside TEMP: $resolvedFixture"
  }
  if (Test-Path -LiteralPath $resolvedFixture) {
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
  }
}

Write-Output 'PASS: scripts/test.ps1 behavior is valid.'
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_test_entrypoint.ps1
```

Expected: exit code 1 because `scripts/test.ps1` does not exist.

- [ ] **Step 3: Implement `scripts/test.ps1`**

The implementation must expose an optional, validated `RepoRoot` for fixtures while defaulting to the script directory:

```powershell
[CmdletBinding()]
param(
  [string]$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$backendRoot = Join-Path $RepoRoot 'backend'
$frontendRoot = Join-Path $RepoRoot 'frontend'

function Invoke-CheckedCommand {
  param(
    [string]$Name,
    [string]$WorkingDirectory,
    [string]$FilePath,
    [string[]]$Arguments
  )

  Write-Output "==> $Name"
  Push-Location $WorkingDirectory
  try {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$Name failed with exit code $LASTEXITCODE."
    }
  }
  finally {
    Pop-Location
  }
}

foreach ($command in @('python', 'pnpm')) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Required command is unavailable: $command"
  }
}

$repositoryTests = Join-Path $RepoRoot 'scripts\tests'
if (Test-Path -LiteralPath $repositoryTests -PathType Container) {
  foreach ($test in Get-ChildItem -LiteralPath $repositoryTests -Filter 'test_*.ps1' | Sort-Object Name) {
    Invoke-CheckedCommand "PowerShell test: $($test.Name)" $RepoRoot 'powershell' @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $test.FullName
    )
  }
}

Invoke-CheckedCommand 'Backend format' $backendRoot 'python' @('-m', 'ruff', 'format', '--check', '.')
Invoke-CheckedCommand 'Backend lint' $backendRoot 'python' @('-m', 'ruff', 'check', '.')
Invoke-CheckedCommand 'Backend types' $backendRoot 'python' @('-m', 'mypy')
Invoke-CheckedCommand 'Backend tests' $backendRoot 'python' @('-m', 'pytest')
Invoke-CheckedCommand 'Frontend tests' $frontendRoot 'pnpm' @('test', '--run')
Invoke-CheckedCommand 'Frontend types' $frontendRoot 'pnpm' @('typecheck')

$package = Get-Content -LiteralPath (Join-Path $frontendRoot 'package.json') -Raw | ConvertFrom-Json
$hasEndToEnd = $null -ne $package.scripts.PSObject.Properties['test:e2e']
if ($hasEndToEnd) {
  Invoke-CheckedCommand 'Frontend end-to-end' $frontendRoot 'pnpm' @('test:e2e')
} else {
  Write-Output 'SKIP: frontend test:e2e is reserved for T01-13.'
}

Write-Output 'All configured checks passed.'
```

Before finalizing, prevent recursion: when `scripts/test.ps1` discovers `test_t01_03_test_entrypoint.ps1`, the nested invocation uses a fixture `RepoRoot` without `scripts/tests`, so it terminates normally.

- [ ] **Step 4: Run behavior and real checks**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_test_entrypoint.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1
```

Expected: both exit 0; the real run ends with `All configured checks passed.`

- [ ] **Step 5: Commit**

```powershell
git add scripts/test.ps1 scripts/tests/test_t01_03_test_entrypoint.ps1
git commit -m "feat: add unified quality entrypoint"
```

### Task 3: Build the same-terminal development launcher

**Files:**

- Create: `scripts/tests/test_t01_03_dev_entrypoint.ps1`
- Create: `scripts/dev.ps1`

- [ ] **Step 1: Write the failing launcher test**

Create `scripts/tests/test_t01_03_dev_entrypoint.ps1`. Use a temporary repository with empty `backend` and `frontend` directories and `docker.cmd`, `python.cmd`, and `pnpm.cmd` shims. Each shim appends `name|working-directory|arguments` to `FAKE_COMMAND_LOG`; Docker exits 0 and both application shims exit immediately.

The assertions must be:

```powershell
$output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RepoRoot $fixtureRoot 2>&1
if ($LASTEXITCODE -eq 0) {
  throw 'An application process exiting immediately should fail the launcher.'
}

$commands = Get-Content -LiteralPath $logPath
if (-not $commands[0].Contains('docker|') -or -not $commands[0].Contains('compose up -d --wait mysql')) {
  throw 'MySQL should be started and awaited before application processes.'
}
if (-not (($commands | Out-String).Contains('python|') -and ($commands | Out-String).Contains('-m uvicorn app.main:app --reload'))) {
  throw 'The backend command was not started.'
}
if (-not (($commands | Out-String).Contains('pnpm|') -and ($commands | Out-String).Contains('dev'))) {
  throw 'The frontend command was not started.'
}
```

Always restore PATH/environment and recursively remove only the validated temporary fixture in `finally`.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_dev_entrypoint.ps1
```

Expected: exit code 1 because `scripts/dev.ps1` does not exist.

- [ ] **Step 3: Implement the launcher**

Create `scripts/dev.ps1` with these focused helpers:

```powershell
[CmdletBinding()]
param(
  [string]$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

function Resolve-RequiredCommand {
  param([string]$Name)
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -eq $command) { throw "Required command is unavailable: $Name" }
  return $command.Source
}

function Start-ApplicationProcess {
  param([string]$CommandPath, [string[]]$Arguments, [string]$WorkingDirectory)

  if ([IO.Path]::GetExtension($CommandPath) -in @('.cmd', '.bat')) {
    $quotedCommand = '"{0}" {1}' -f $CommandPath, ($Arguments -join ' ')
    return Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/s', '/c', "`"$quotedCommand`"") `
      -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru
  }

  return Start-Process -FilePath $CommandPath -ArgumentList $Arguments `
    -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru
}

function Stop-ApplicationProcessTree {
  param([Diagnostics.Process]$Process)
  if ($null -eq $Process -or $Process.HasExited) { return }
  & taskkill.exe /PID $Process.Id /T /F *> $null
  if ($LASTEXITCODE -ne 0 -and -not $Process.HasExited) {
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
  }
}
```

The main flow must resolve all commands before side effects, run Compose from the repository root, then start and monitor both children:

```powershell
$docker = Resolve-RequiredCommand 'docker'
$python = Resolve-RequiredCommand 'python'
$pnpm = Resolve-RequiredCommand 'pnpm'
$backend = $null
$frontend = $null

Push-Location $RepoRoot
try {
  & $docker compose up -d --wait mysql
  if ($LASTEXITCODE -ne 0) {
    throw "MySQL startup failed with exit code $LASTEXITCODE."
  }

  $backend = Start-ApplicationProcess $python @('-m', 'uvicorn', 'app.main:app', '--reload') (Join-Path $RepoRoot 'backend')
  $frontend = Start-ApplicationProcess $pnpm @('dev') (Join-Path $RepoRoot 'frontend')

  while (-not $backend.HasExited -and -not $frontend.HasExited) {
    Start-Sleep -Milliseconds 200
    $backend.Refresh()
    $frontend.Refresh()
  }

  $exitedName = if ($backend.HasExited) { 'Backend' } else { 'Frontend' }
  throw "$exitedName process exited unexpectedly."
}
finally {
  Stop-ApplicationProcessTree $backend
  Stop-ApplicationProcessTree $frontend
  Pop-Location
}
```

- [ ] **Step 4: Run launcher and regression tests**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_dev_entrypoint.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1
```

Expected: launcher contract test passes; unified checks pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/dev.ps1 scripts/tests/test_t01_03_dev_entrypoint.ps1
git commit -m "feat: add unified development launcher"
```

### Task 4: Add CI that delegates to the local quality command

**Files:**

- Create: `scripts/tests/test_t01_03_ci.ps1`
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the failing CI contract test**

Create `scripts/tests/test_t01_03_ci.ps1`. It must fail if the file is absent, parse the workflow with the available Python YAML parser, and assert:

```powershell
$workflowPath = Join-Path $repoRoot '.github\workflows\ci.yml'
if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
  throw "Expected CI workflow does not exist: $workflowPath"
}

python -c "from pathlib import Path; import yaml; data=yaml.safe_load(Path(r'$workflowPath').read_text(encoding='utf-8')); assert isinstance(data, dict)"
if ($LASTEXITCODE -ne 0) { throw 'CI workflow YAML is not parseable.' }

$workflow = [IO.File]::ReadAllText($workflowPath)
foreach ($expected in @(
  'windows-latest',
  'python-version: "3.12"',
  'node-version: "24"',
  'actions/checkout@v6',
  'actions/setup-python@v6',
  'actions/setup-node@v6',
  'pnpm/action-setup@v6',
  'version: 11.4.0',
  'pnpm install --frozen-lockfile',
  'powershell -ExecutionPolicy Bypass -File scripts/test.ps1'
)) {
  if (-not $workflow.Contains($expected)) { throw "CI workflow is missing: $expected" }
}

foreach ($duplicatedCheck in @('ruff check', 'python -m mypy', 'pnpm test --run', 'pnpm typecheck')) {
  if ($workflow.Contains($duplicatedCheck)) {
    throw "CI should delegate checks instead of duplicating: $duplicatedCheck"
  }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_ci.ps1
```

Expected: exit code 1 with `Expected CI workflow does not exist`.

- [ ] **Step 3: Create the workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    runs-on: windows-latest
    timeout-minutes: 20
    steps:
      - name: Check out repository
        uses: actions/checkout@v6

      - name: Set up Python
        uses: actions/setup-python@v6
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: backend/pyproject.toml

      - name: Set up pnpm
        uses: pnpm/action-setup@v6
        with:
          version: 11.4.0
          run_install: false

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: "24"
          cache: pnpm
          cache-dependency-path: frontend/pnpm-lock.yaml

      - name: Install backend dependencies
        working-directory: backend
        run: python -m pip install -e ".[dev]"

      - name: Install frontend dependencies
        working-directory: frontend
        run: pnpm install --frozen-lockfile

      - name: Run repository checks
        shell: powershell
        run: powershell -ExecutionPolicy Bypass -File scripts/test.ps1
```

- [ ] **Step 4: Verify CI and all configured checks**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_ci.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1
```

Expected: both pass.

- [ ] **Step 5: Commit**

```powershell
git add .github/workflows/ci.yml scripts/tests/test_t01_03_ci.ps1
git commit -m "ci: reuse unified repository checks"
```

### Task 5: Document the implemented workflow

**Files:**

- Modify: `docs/DEVELOPMENT.md`

- [ ] **Step 1: Write a failing documentation assertion**

Extend `scripts/tests/test_t01_03_config.ps1` to read `docs/DEVELOPMENT.md` and require these exact command fragments:

```powershell
$development = [IO.File]::ReadAllText((Join-Path $repoRoot 'docs\DEVELOPMENT.md'))
foreach ($expected in @(
  'powershell -ExecutionPolicy Bypass -File scripts\dev.ps1',
  'powershell -ExecutionPolicy Bypass -File scripts\test.ps1',
  'docker compose stop mysql',
  'test:e2e',
  'Ctrl+C'
)) {
  Assert-Contains $development $expected "Development documentation should contain $expected"
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_config.ps1
```

Expected: exit code 1 because the unified script commands are not documented.

- [ ] **Step 3: Replace the planned command block**

Update the command contract in `docs/DEVELOPMENT.md` with:

```powershell
# First-time backend dependencies
cd backend
python -m pip install -e ".[dev]"
cd ..

# First-time frontend dependencies
cd frontend
pnpm install --frozen-lockfile
cd ..

# Start MySQL, backend, and frontend in one terminal
powershell -ExecutionPolicy Bypass -File scripts\dev.ps1

# Run PowerShell, backend, frontend, and configured end-to-end checks
powershell -ExecutionPolicy Bypass -File scripts\test.ps1

# Stop MySQL when it is no longer needed
docker compose stop mysql
```

Document that Ctrl+C cleans up only the two application process trees, MySQL remains running, missing `test:e2e` is reported as the expected T01-13 reservation, and CI invokes the same test script.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_t01_03_config.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1
```

Expected: both pass.

Commit:

```powershell
git add docs/DEVELOPMENT.md scripts/tests/test_t01_03_config.ps1
git commit -m "docs: document unified development workflow"
```

### Task 6: Complete acceptance and advance the task pointer

**Files:**

- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Run the full T01-03 acceptance**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1
docker compose config
python scripts/check_traceability.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate_task_catalog.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_show_current_task.ps1
git diff --check
```

Expected:

- every command exits 0;
- unified checks end with `All configured checks passed.`;
- Compose reports only the MySQL service and `mysql_data` volume;
- traceability reports zero unassigned P0/P1 requirements;
- task catalog reports 66 Tasks and 12 migrations;
- no whitespace errors are reported.

- [ ] **Step 2: Record the optional interactive smoke procedure**

Do not start long-running services in unattended verification. Confirm that `docs/DEVELOPMENT.md` gives the bounded manual procedure: run `scripts/dev.ps1`, check `/health` and the Vite root, press Ctrl+C, and verify MySQL remains running. The automated launcher contract test is the acceptance evidence for process ordering and cleanup.

- [ ] **Step 3: Update the completion state**

After all acceptance evidence is fresh, update the YAML block:

```yaml
current_task: T01-03
status: completed
last_completed_task: T01-03
next_task: T01-04
blockers: []
active_regression: null
suspended_task: null
gate_reverification_required: false
last_verification:
  command: scripts/test.ps1 + Docker Compose config + CI YAML parse + traceability/governance/task catalog
  result: passed
  verified_at: 2026-07-26
updated_at: 2026-07-26
```

- [ ] **Step 4: Re-run governance checks after the state update**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test_show_current_task.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate_task_catalog.ps1
git status --short
```

Expected: both tests pass; only intended T01-03 files are modified or staged, and the generated `scripts/tests/__pycache__/` is ignored and not staged.

- [ ] **Step 5: Commit completion**

```powershell
git add docs/CURRENT_STATUS.md
git commit -m "chore: complete T01-03"
```
