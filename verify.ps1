# Verify all fixed sessions are valid
# Invalid = has sess_ prefix but content is broken or incomplete:
# - session.json cannot be parsed (corrupted JSON)
# - id field does not match directory name
# - workspacePaths is empty or missing
# - semanticReviewEnabled field is missing (not migrated properly)

Write-Host "=== Verification ===" -ForegroundColor Cyan
Write-Host "Checks: JSON valid, id matches dir, workspacePaths exists, new fields present" -ForegroundColor Gray
Write-Host ""
Write-Host ""
$sessionsRoot = Join-Path $env:USERPROFILE ".kiro\sessions"

$totalValid = 0
$totalInvalid = 0
$issues = @()

$workspaces = Get-ChildItem $sessionsRoot -Directory

foreach ($ws in $workspaces) {
    $dirs = Get-ChildItem $ws.FullName -Directory | Where-Object { $_.Name -like "sess_*" }

    foreach ($d in $dirs) {
        $p = Join-Path $d.FullName "session.json"
        if (-not (Test-Path $p)) { continue }

        try {
            $json = [IO.File]::ReadAllText($p) | ConvertFrom-Json

            $ok = $true
            if ($json.id -ne $d.Name) { $issues += "$($d.Name): id mismatch"; $ok = $false }
            if ($null -eq $json.workspacePaths -or $json.workspacePaths.Count -eq 0) { $issues += "$($d.Name): empty workspacePaths"; $ok = $false }
            if ($null -eq $json.semanticReviewEnabled) { $issues += "$($d.Name): missing semanticReviewEnabled"; $ok = $false }

            if ($ok) { $totalValid++ } else { $totalInvalid++ }
        } catch {
            $issues += "$($d.Name): INVALID JSON - $_"
            $totalInvalid++
        }
    }
}

Write-Host "Valid:   $totalValid" -ForegroundColor Green
Write-Host "Invalid: $totalInvalid" -ForegroundColor $(if ($totalInvalid -gt 0) { "Red" } else { "Green" })

if ($issues.Count -gt 0) {
    Write-Host "`nIssues:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} else {
    Write-Host "`nAll sessions pass validation!" -ForegroundColor Green
}
