# Kiro Session Migration Fix

| English | [繁體中文](README_zh-TW.md) |

After updating Kiro IDE from **v0.12.318** to **v1.0.0**, old chat sessions become invisible in the session panel.

## Affected Version

| | Before (Working) | After (Broken) |
|--|-----------------|----------------|
| **Kiro Version** | 0.12.318 | 1.0.0 |
| **VSCode Version** | 1.107.1 | 1.107.1 |
| **Commit** | c8b7de5 | 0974fb9 |
| **Date** | 2026-06-09 | 2026-06-17 |

The v1.0.0 update introduced **Agent Focus** and restructured internal session storage. The migration fails to:
1. Add the required `sess_` prefix to session directory names
2. Convert `workspacePaths` from old format (`e:/dev/web/estate`) to new format (`e:\Dev\Web\Estate`)

## Root Cause

| Aspect | Old Format | New Format (Required) |
|--------|-----------|----------------------|
| Directory name | `a5d9f774-...` | `sess_a5d9f774-...` |
| `session.json` id | `a5d9f774-...` | `sess_a5d9f774-...` |
| `workspacePaths` | `e:/dev/web/estate` | `e:\Dev\Web\Estate` |
| New fields | Not present | `semanticReviewEnabled`, `ftaEnabled`, `effortLevel` |

## Files

| File | Purpose |
|------|---------|
| `run.bat` | Menu launcher (double-click) |
| `fix_all_sessions.ps1` | Main fix script |
| `verify.ps1` | Verify sessions after fix |
| `backup.bat` | Standalone backup (also in menu) |

## Usage

> **Portable**: Place anywhere and run. Paths resolve automatically.

Double-click `run.bat` to open the menu:

```
[0] Dry Run - Preview changes without modifying
[1] Backup - Create zip backup before fixing
[2] Fix - Apply session fix
[3] Verify - Check sessions after fix
[4] Exit
```

Recommended flow: `Backup` -> `Dry Run` -> `Fix` -> `Verify` -> Reload Kiro Window

## What It Does

For each session across all workspaces:

1. **Rename** directory from `<uuid>` to `sess_<uuid>`
2. **Fix `workspacePaths`** using correct paths from old globalStorage records
3. **Update `session.json`**: add `sess_` prefix to id, add missing fields
4. Does **NOT** modify `messages.jsonl` (conversation data untouched)

### Path Resolution Priority

```
1. globalStorage base64 dirs (Kiro original recorded paths - most reliable)
2. .trust-migration.json
3. Existing sess_ session with backslash format
4. Fallback: normalize forward slashes from old data
```

## Safety

- Menu-driven with confirmation before any changes
- Dry-run preview included
- Idempotent (safe to run multiple times)
- `messages.jsonl` is never modified

## Usage

> **Portable**: Place anywhere and run. Paths resolve automatically.

Double-click `run.bat` to open the menu:

```
[0] Dry Run - Preview changes without modifying
[1] Backup - Create zip backup before fixing
[2] Fix - Apply session fix
[3] Verify - Check sessions after fix
[4] Exit
```

Recommended flow: `Backup` -> `Dry Run` -> `Fix` -> `Verify` -> Reload Kiro Window

## What It Does

For each session across all workspaces:

1. **Rename** directory from `<uuid>` to `sess_<uuid>`
2. **Fix `workspacePaths`** from `e:/dev/web/estate` to `e:\Dev\Web\Estate`
3. **Update `session.json`**: add `sess_` prefix to id, add missing fields
4. Does **NOT** modify `messages.jsonl` (conversation data untouched)

### Path Resolution Priority

```
1. globalStorage base64 dirs (Kiro original recorded paths - most reliable)
2. .trust-migration.json
3. Existing sess_ session with correct backslash format
4. Fallback: normalize forward slashes from old data
```

## Safety

- Menu-driven with confirmation before any changes
- Dry-run preview included
- Idempotent (safe to run multiple times)
- `messages.jsonl` is never modified
