# T00-01 Toolchain and Local Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock the supported development toolchain, define safe configuration layers, and provide a verified MySQL 8.4 LTS container for Windows development.

**Architecture:** `.tool-versions` is the authority for developer tool versions, `.env.example` is the committed non-secret configuration contract, and `docker-compose.yml` owns the single local MySQL service. Documentation mirrors those sources, while inline PowerShell assertions and Docker Compose commands provide test-first acceptance without adding files outside T00-01.

**Tech Stack:** Node.js 24 LTS, pnpm 11, Python 3.12, Docker 29, Docker Compose v2+, MySQL 8.4 LTS, PowerShell.

---

## File map

- Create `.tool-versions`: exact developer tool versions.
- Create `.env.example`: safe development defaults and configuration-layer contract.
- Create `docker-compose.yml`: local MySQL service, persistence, and health check.
- Modify `docs/DEVELOPMENT.md`: authoritative environment, commands, and configuration-layer documentation.
- Modify `docs/PRE_DEVELOPMENT_CHECKLIST.md`: evidence-backed completion of T00-01 preparation items.
- Modify `docs/CURRENT_STATUS.md`: dynamic Task state only; this is required governance metadata, not product scope.

### Task 1: Mark T00-01 in progress

**Files:**
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Verify the current pointer before changing it**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\show_current_task.ps1
```

Expected: `Current Task: T00-01` and `Current Status: ready`.

- [ ] **Step 2: Set the dynamic status**

Change only:

```yaml
status: in_progress
```

Keep the milestone, Task ID, next Task, blockers, and verification history unchanged.

- [ ] **Step 3: Re-run the pointer check**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\show_current_task.ps1
```

Expected: `Current Task: T00-01` and `Current Status: in_progress`.

- [ ] **Step 4: Commit the state transition**

```powershell
git add -- docs/CURRENT_STATUS.md
git commit -m "chore: start T00-01"
```

### Task 2: Create the locked toolchain and MySQL configuration

**Files:**
- Create: `.tool-versions`
- Create: `.env.example`
- Create: `docker-compose.yml`

- [ ] **Step 1: Run the failing file-contract assertion**

Run:

```powershell
$required = @('.tool-versions', '.env.example', 'docker-compose.yml')
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missing.Count -eq 0) { throw 'RED setup invalid: target files already exist.' }
throw "RED: missing required T00-01 files: $($missing -join ', ')"
```

Expected: FAIL with `RED: missing required T00-01 files`.

- [ ] **Step 2: Create the minimal version lock**

Create `.tool-versions` with:

```text
nodejs 24.18.0
pnpm 11.4.0
python 3.12.10
docker 29.6.2
docker-compose 5.1.2
```

- [ ] **Step 3: Create the non-secret environment example**

Create `.env.example` with:

```dotenv
# Committed local-development defaults only. Override in an untracked .env.
APP_ENV=development
APP_HOST=127.0.0.1
APP_PORT=8000
FRONTEND_ORIGIN=http://localhost:5173
LOG_LEVEL=INFO

MYSQL_DATABASE=anxin_training
MYSQL_USER=anxin_app
MYSQL_PASSWORD=local-only-change-me
MYSQL_ROOT_PASSWORD=local-root-only-change-me
MYSQL_PORT=3306
DATABASE_URL=mysql+asyncmy://anxin_app:local-only-change-me@localhost:3306/anxin_training
```

- [ ] **Step 4: Create the single-service Compose file**

Create `docker-compose.yml` with:

```yaml
services:
  mysql:
    image: mysql:8.4.10
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE:-anxin_training}
      MYSQL_USER: ${MYSQL_USER:-anxin_app}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-local-only-change-me}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-local-root-only-change-me}
    ports:
      - "${MYSQL_PORT:-3306}:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test:
        - CMD-SHELL
        - mysqladmin ping -h 127.0.0.1 -u root --password="$${MYSQL_ROOT_PASSWORD}" --silent
      interval: 5s
      timeout: 5s
      retries: 20
      start_period: 20s

volumes:
  mysql_data:
```

- [ ] **Step 5: Run focused content assertions**

Run:

```powershell
$expected = [ordered]@{
  nodejs = '24.18.0'
  pnpm = '11.4.0'
  python = '3.12.10'
  docker = '29.6.2'
  'docker-compose' = '5.1.2'
}
$actual = @{}
Get-Content -LiteralPath '.tool-versions' | ForEach-Object {
  $name, $version = $_ -split '\s+', 2
  $actual[$name] = $version
}
foreach ($entry in $expected.GetEnumerator()) {
  if ($actual[$entry.Key] -ne $entry.Value) {
    throw "Version mismatch for $($entry.Key): expected $($entry.Value), got $($actual[$entry.Key])"
  }
}
$envText = Get-Content -Raw -LiteralPath '.env.example'
if ($envText -match '(?im)^(REDIS|MINIO|STORAGE|ASR|LLM|TTS)') {
  throw 'T00-01 must not define later-service variables.'
}
$composeText = Get-Content -Raw -LiteralPath 'docker-compose.yml'
if ($composeText -notmatch 'mysql:8\.4\.10' -or $composeText -notmatch 'mysqladmin ping') {
  throw 'Compose must lock MySQL 8.4.10 and define its health check.'
}
```

Expected: exit code 0 with no output.

- [ ] **Step 6: Validate the Compose model**

Run:

```powershell
docker compose config
docker compose config --services
```

Expected: both commands exit 0; the second prints only `mysql`.

- [ ] **Step 7: Commit the configuration**

```powershell
git add -- .tool-versions .env.example docker-compose.yml
git commit -m "build: lock T00-01 local toolchain"
```

### Task 3: Synchronize development documentation

**Files:**
- Modify: `docs/DEVELOPMENT.md`
- Modify: `docs/PRE_DEVELOPMENT_CHECKLIST.md`

- [ ] **Step 1: Run the failing documentation assertion**

Run:

```powershell
$development = Get-Content -Raw -LiteralPath 'docs/DEVELOPMENT.md'
$required = @('24.18.0', '11.4.0', '3.12.10', '29.6.2', '5.1.2', '8.4.10')
$missing = @($required | Where-Object { $development -notmatch [regex]::Escape($_) })
if ($missing.Count -gt 0) { throw "RED: DEVELOPMENT.md is missing locked versions: $($missing -join ', ')" }
throw 'RED setup invalid: documentation already contains every locked version.'
```

Expected: FAIL listing the locked versions missing from `docs/DEVELOPMENT.md`.

- [ ] **Step 2: Replace the planned environment table**

In `docs/DEVELOPMENT.md`, rename `## 4. 计划开发环境` to `## 4. 开发环境`, replace the tool table with the six exact versions from `.tool-versions` plus MySQL `8.4.10`, and state:

```markdown
`.tool-versions` 是 Node.js、pnpm、Python、Docker 和 Docker Compose 精确版本的权威来源；`docker-compose.yml` 锁定 MySQL 镜像版本。版本变化必须同时更新锁定文件、本节和相关验收。

Windows 11 是当前主要开发与容器验收环境。仓库脚本优先提供 PowerShell 入口；跨平台脚本不得依赖 PowerShell 独有行为，若暂时只能在 Windows 运行必须在命令旁明确标注。
```

Keep the existing statement that M1 only introduces MySQL.

- [ ] **Step 3: Replace the environment-variable section with explicit layers**

In `docs/DEVELOPMENT.md`, make the committed variable example match `.env.example`, then add:

```markdown
配置按以下四层管理：

1. `.env.example`：提交到仓库，只包含安全的本地默认值和明显占位值。
2. 本地 `.env`：开发者私有，不提交，用于覆盖端口和本地开发凭据。
3. 测试配置：由测试进程或 CI 注入，使用隔离数据库和独立凭据。
4. 部署密钥：由部署平台密钥存储注入，不进入仓库、镜像或前端构建产物。

Redis、MinIO、存储和 AI 供应商变量在相应 Task 首次需要时加入，不在 T00-01 提前建立契约。
```

Retain the rule prohibiting real secrets from commits, logs, and frontend responses.

- [ ] **Step 4: Update only evidence-backed checklist items**

In `docs/PRE_DEVELOPMENT_CHECKLIST.md`, mark the tool-version, primary-environment, and configuration-layer items complete. Rewrite the primary-environment item to state that Windows 11 and PowerShell are the current primary environment. Leave the MySQL-container item unchecked until Task 4 succeeds.

- [ ] **Step 5: Run documentation consistency assertions**

Run:

```powershell
$versions = Get-Content -LiteralPath '.tool-versions'
$development = Get-Content -Raw -LiteralPath 'docs/DEVELOPMENT.md'
foreach ($line in $versions) {
  $name, $version = $line -split '\s+', 2
  if ($development -notmatch [regex]::Escape($version)) {
    throw "DEVELOPMENT.md does not match .tool-versions for $name $version"
  }
}
if ($development -notmatch 'MySQL \| 8\.4\.10' -or $development -notmatch '配置按以下四层管理') {
  throw 'Development documentation is missing the MySQL lock or configuration layers.'
}
```

Expected: exit code 0 with no output.

- [ ] **Step 6: Commit the documentation**

```powershell
git add -- docs/DEVELOPMENT.md docs/PRE_DEVELOPMENT_CHECKLIST.md
git commit -m "docs: document T00-01 environment baseline"
```

### Task 4: Validate MySQL on the Windows development device

**Files:**
- Modify: `docs/PRE_DEVELOPMENT_CHECKLIST.md`

- [ ] **Step 1: Verify the installed host tools**

Run:

```powershell
node --version
pnpm --version
python --version
docker --version
docker compose version
```

Expected: supported commands are callable. Any mismatch from `.tool-versions` is reported as a host prerequisite; `docker compose` must be available before continuing.

- [ ] **Step 2: Start only MySQL**

Run:

```powershell
docker compose up -d mysql
```

Expected: image pull/start succeeds and no service other than `mysql` is created.

- [ ] **Step 3: Wait for the health check**

Run:

```powershell
$deadline = (Get-Date).AddMinutes(3)
do {
  $health = docker inspect --format '{{.State.Health.Status}}' (docker compose ps -q mysql)
  if ($health -eq 'healthy') { break }
  if ($health -eq 'unhealthy') { throw 'MySQL health check reported unhealthy.' }
  Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deadline)
if ($health -ne 'healthy') { throw "Timed out waiting for MySQL; last status: $health" }
$rootPassword = if ($env:MYSQL_ROOT_PASSWORD) { $env:MYSQL_ROOT_PASSWORD } else { 'local-root-only-change-me' }
docker compose exec -T mysql mysqladmin ping -h 127.0.0.1 -u root --password="$rootPassword"
```

Expected: health becomes `healthy` and `mysqladmin` reports `mysqld is alive`.

- [ ] **Step 4: Stop containers without deleting data**

Run:

```powershell
docker compose down
```

Expected: containers and the project network are removed; the named `mysql_data` volume is retained.

- [ ] **Step 5: Record the Windows evidence**

Only after Steps 1-4 pass, mark the MySQL-container item complete in `docs/PRE_DEVELOPMENT_CHECKLIST.md` and append the verification date `2026-07-24` plus the commands `docker compose up -d mysql`, health inspection, `mysqladmin ping`, and `docker compose down`.

- [ ] **Step 6: Commit the verified checklist**

```powershell
git add -- docs/PRE_DEVELOPMENT_CHECKLIST.md
git commit -m "test: verify T00-01 MySQL container"
```

### Task 5: Run final acceptance and complete T00-01

**Files:**
- Modify: `docs/CURRENT_STATUS.md`

- [ ] **Step 1: Run the complete file and scope assertion**

Run:

```powershell
$required = @('.tool-versions', '.env.example', 'docker-compose.yml')
foreach ($path in $required) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing $path" }
}
$services = @(docker compose config --services)
if ($LASTEXITCODE -ne 0 -or $services.Count -ne 1 -or $services[0] -ne 'mysql') {
  throw "Expected only the mysql service; got: $($services -join ', ')"
}
$envText = Get-Content -Raw -LiteralPath '.env.example'
if ($envText -match '(?im)^(REDIS|MINIO|STORAGE|ASR|LLM|TTS)') {
  throw 'Out-of-scope environment variables found.'
}
```

Expected: exit code 0 with no output.

- [ ] **Step 2: Run Task and governance acceptance**

Run:

```powershell
docker compose config
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_task_catalog.ps1
```

Expected: both commands exit 0.

- [ ] **Step 3: Inspect the complete Task diff**

Run:

```powershell
git status --short
git diff --check
git log -5 --oneline
```

Expected: no unrelated changes, no whitespace errors, and the T00-01 commits are present.

- [ ] **Step 4: Set T00-01 completed**

In `docs/CURRENT_STATUS.md`, change only the dynamic fields:

```yaml
status: completed
last_completed_task: T00-01
last_verification:
  command: docker compose config + MySQL health check + scripts/validate_task_catalog.ps1
  result: passed
  verified_at: 2026-07-24
updated_at: 2026-07-24
```

Do not switch `current_task` to T00-02 in this Task.

- [ ] **Step 5: Verify and commit completion**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\show_current_task.ps1
git add -- docs/CURRENT_STATUS.md
git commit -m "chore: complete T00-01"
```

Expected: current Task remains T00-01 with status `completed`, followed by a successful commit.
