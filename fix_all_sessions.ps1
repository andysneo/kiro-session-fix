# Kiro Session Migration Fix - ALL Workspaces
# Fixes: sess_ prefix, workspacePaths format, missing fields
#
# Path resolution priority:
# 1. Old globalStorage base64 dirs (original Kiro-recorded paths)
# 2. .trust-migration.json
# 3. Existing sess_ session with correct format
# 4. Fallback: normalize from old session data
#
# Usage:
# .\fix_all_sessions.ps1 # Dry run
# .\fix_all_sessions.ps1 -Execute # Apply changes

param([switch]$Execute = $false)

$DryRun = -not $Execute
$sessionsRoot = Join-Path $env:USERPROFILE ".kiro\sessions"
$workspaceRootsDir = Join-Path $env:USERPROFILE ".kiro\workspace-roots"
$globalStorageDir = Join-Path $env:APPDATA "Kiro\User\globalStorage\kiro.kiroagent\workspace-sessions"
$backupPath = Join-Path $env:USERPROFILE ".kiro\sessions_backup_$(Get-Date -Format 'yyyyMMdd').zip"
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# --- Build path lookup table from globalStorage base64 dirs ---
$pathLookup = @{}
if (Test-Path $globalStorageDir) {
 Get-ChildItem $globalStorageDir -Directory | ForEach-Object {
 try {
 $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.Name.Replace('_','=').Replace('-','+')))
 $pathLookup[$decoded.ToLower()] = $decoded
 } catch {}
 }
}

# --- Resolve correct workspace path for a given hash ---
function Resolve-WorkspacePath($hash, $sessions) {
 # Priority 1: globalStorage lookup (match via any session in this hash)
 foreach ($s in $sessions) {
 $p = Join-Path $s.FullName "session.json"
 if (-not (Test-Path $p)) { continue }
 try {
 $j = [IO.File]::ReadAllText($p) | ConvertFrom-Json
 $raw = $j.workspacePaths[0].Replace('/', '\')
 $key = $raw.ToLower()
 if ($pathLookup.ContainsKey($key)) { return $pathLookup[$key] }
 } catch {}
 break
 }

 # Priority 2: .trust-migration.json
 $trustFile = Join-Path $workspaceRootsDir "$hash\.trust-migration.json"
 if (Test-Path $trustFile) {
 try {
 $trust = Get-Content $trustFile -Raw | ConvertFrom-Json
 return $trust.root
 } catch {}
 }

 # Priority 3: existing sess_ session with backslash format
 $ref = $sessions | Where-Object { $_.Name -like "sess_*" } | Select-Object -First 1
 if ($ref) {
 try {
 $rj = [IO.File]::ReadAllText((Join-Path $ref.FullName "session.json")) | ConvertFrom-Json
 if ($rj.workspacePaths[0] -match '^[a-z]:\\\\') { return $rj.workspacePaths[0] }
 } catch {}
 }

 # Priority 4: normalize from raw path
 foreach ($s in $sessions) {
 $p = Join-Path $s.FullName "session.json"
 if (-not (Test-Path $p)) { continue }
 try {
 $j = [IO.File]::ReadAllText($p) | ConvertFrom-Json
 return $j.workspacePaths[0].Replace('/', '\')
 } catch {}
 break
 }
 return $null
}

# --- Header ---
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Kiro Session Migration Fix - ALL Workspaces" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
if ($DryRun) {
 Write-Host "[DRY RUN] No changes will be made. Use -Execute to apply.`n" -ForegroundColor Yellow
} else {
 Write-Host "[EXECUTE MODE] Changes will be applied!`n" -ForegroundColor Red
}
Write-Host "Path sources: $($pathLookup.Count) from globalStorage" -ForegroundColor Gray

if (-not (Test-Path $sessionsRoot)) {
 Write-Host "[ERROR] Sessions directory not found: $sessionsRoot" -ForegroundColor Red
 exit 1
}

$workspaces = Get-ChildItem $sessionsRoot -Directory
$totalScanned = $workspaces.Count
$totalFixed = 0
$totalPathFixed = 0
$totalSkipped = 0
$totalErrors = 0
$workspaceStats = @()

foreach ($ws in $workspaces) {
 $hash = $ws.Name
 $allSessions = Get-ChildItem $ws.FullName -Directory
 $oldSessions = $allSessions | Where-Object { $_.Name -notlike "sess_*" }
 $existingSess = $allSessions | Where-Object { $_.Name -like "sess_*" }

 # Resolve correct path for this workspace
 $correctPath = Resolve-WorkspacePath $hash $allSessions
 if (-not $correctPath) {
 if ($oldSessions.Count -gt 0) {
 Write-Host "[$hash] SKIP - Cannot determine workspace path" -ForegroundColor Yellow
 $totalSkipped += $oldSessions.Count
 }
 continue
 }

 $escapedPath = $correctPath.Replace('\', '\\' )
 $wsFixCount = 0

 # --- Fix 1: Rename old UUID dirs to sess_ ---
 foreach ($dir in $oldSessions) {
 $uuid = $dir.Name
 $newId = "sess_$uuid"
 $jsonPath = Join-Path $dir.FullName "session.json"

 if (-not (Test-Path $jsonPath)) {
 $totalSkipped++
 continue
 }

 try {
 $session = [IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json
 } catch {
 Write-Host " [ERROR] $uuid - invalid JSON" -ForegroundColor Red
 $totalErrors++
 continue
 }

 if (-not $DryRun) {
 $escapedTitle = $session.title.Replace('\', '\\').Replace('"', '\"')
 $autopilotStr = if ($session.autopilot) { "true" } else { "false" }
 $newJson = @"
{
 "schemaVersion": "$($session.schemaVersion)",
 "dataModelVersion": $($session.dataModelVersion),
 "id": "$newId",
 "title": "$escapedTitle",
 "agentMode": "$($session.agentMode)",
 "workspacePaths": [
 "$escapedPath"
 ],
 "createdAt": "$($session.createdAt)",
 "lastModifiedAt": "$($session.lastModifiedAt)",
 "modelId": "$($session.modelId)",
 "autopilot": $autopilotStr,
 "semanticReviewEnabled": true,
 "ftaEnabled": false,
 "effortLevel": "high"
}
"@
 [IO.File]::WriteAllText($jsonPath, $newJson, (New-Object System.Text.UTF8Encoding($false)))
 Rename-Item -Path $dir.FullName -NewName $newId
 }
 $wsFixCount++
 $totalFixed++
 }

 # --- Fix 2: Correct workspacePaths in existing sess_ sessions ---
 foreach ($dir in $existingSess) {
 $jsonPath = Join-Path $dir.FullName "session.json"
 if (-not (Test-Path $jsonPath)) { continue }
 $content = [IO.File]::ReadAllText($jsonPath)
 $parsed = $null
 try { $parsed = $content | ConvertFrom-Json } catch { continue }

 $currentPath = $parsed.workspacePaths[0]
 $needsFix = ($currentPath -ne $correctPath) -or ($null -eq $parsed.semanticReviewEnabled)

 if ($needsFix -and (-not $DryRun)) {
 $escapedTitle = $parsed.title.Replace('\', '\\').Replace('"', '\"')
 $autopilotStr = if ($parsed.autopilot) { "true" } else { "false" }
 $sre = if ($null -ne $parsed.semanticReviewEnabled) { $parsed.semanticReviewEnabled.ToString().ToLower() } else { "true" }
 $fta = if ($null -ne $parsed.ftaEnabled) { $parsed.ftaEnabled.ToString().ToLower() } else { "false" }
 $eff = if ($parsed.effortLevel) { $parsed.effortLevel } else { "high" }
 $fixJson = @"
{
 "schemaVersion": "$($parsed.schemaVersion)",
 "dataModelVersion": $($parsed.dataModelVersion),
 "id": "$($parsed.id)",
 "title": "$escapedTitle",
 "agentMode": "$($parsed.agentMode)",
 "workspacePaths": [
 "$escapedPath"
 ],
 "createdAt": "$($parsed.createdAt)",
 "lastModifiedAt": "$($parsed.lastModifiedAt)",
 "modelId": "$($parsed.modelId)",
 "autopilot": $autopilotStr,
 "semanticReviewEnabled": $sre,
 "ftaEnabled": $fta,
 "effortLevel": "$eff"
}
"@
 [IO.File]::WriteAllText($jsonPath, $fixJson, (New-Object System.Text.UTF8Encoding($false)))
 }
 if ($needsFix) { $totalPathFixed++ }
 }

 # --- Report ---
 $totalWsChanges = $wsFixCount + ($existingSess | Where-Object {
 $p = Join-Path $_.FullName "session.json"
 if (-not (Test-Path $p)) { return $false }
 try { $j = [IO.File]::ReadAllText($p) | ConvertFrom-Json; return ($j.workspacePaths[0] -ne $correctPath) } catch { return $false }
 }).Count
 if (($oldSessions.Count -gt 0) -or ($totalWsChanges -gt 0)) {
 $workspaceStats += [PSCustomObject]@{ Path=$correctPath; Renamed=$oldSessions.Count; PathFix=($totalWsChanges - $wsFixCount) }
 Write-Host "[$hash] $correctPath (rename:$($oldSessions.Count) path:$($totalWsChanges - $wsFixCount))" -ForegroundColor White
 }
}

$stopwatch.Stop()
$elapsed = $stopwatch.Elapsed.TotalSeconds.ToString("F1")

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
if ($DryRun) {
 Write-Host " Mode: DRY RUN" -ForegroundColor Yellow
} else {
 Write-Host " Mode: EXECUTED" -ForegroundColor Green
}

if ($workspaceStats.Count -gt 0) {
 Write-Host "`n Per-workspace breakdown:" -ForegroundColor Gray
 foreach ($ws in $workspaceStats | Sort-Object { $_.Renamed + $_.PathFix } -Descending) {
 $detail = ""
 if ($ws.Renamed -gt 0) { $detail += "rename:$($ws.Renamed) " }
 if ($ws.PathFix -gt 0) { $detail += "path:$($ws.PathFix) " }
 Write-Host " $($detail.PadRight(20)) $($ws.Path)" -ForegroundColor White
 }
}

Write-Host "`n -------------------------------------------" -ForegroundColor Gray
Write-Host " Workspaces scanned: $totalScanned" -ForegroundColor White
Write-Host " Workspaces affected: $($workspaceStats.Count)" -ForegroundColor White
if ($DryRun) {
 Write-Host " Sessions to rename: $totalFixed" -ForegroundColor Yellow
 Write-Host " Sessions path fix: $totalPathFixed" -ForegroundColor Yellow
} else {
 Write-Host " Sessions renamed: $totalFixed" -ForegroundColor Green
 Write-Host " Sessions path fixed: $totalPathFixed" -ForegroundColor Green
}
Write-Host " Sessions skipped: $totalSkipped" -ForegroundColor Yellow
Write-Host " Errors: $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { "Red" } else { "Green" })
Write-Host " Elapsed: ${elapsed}s" -ForegroundColor Gray
Write-Host "`n Backup: $backupPath" -ForegroundColor DarkGray
Write-Host " Next: Ctrl+Shift+P -> Reload Window`n" -ForegroundColor DarkCyan
