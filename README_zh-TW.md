# Kiro 對話歷史修復工具

| [English](README.md) | 繁體中文 |

從 **Kiro v0.12.318** 更新至 **v1.0.0** 後，舊的對話 session 在面板中消失不見。

## 受影響的版本

| | 更新前（正常） | 更新後（異常） |
|--|--------------|--------------|
| **Kiro 版本** | 0.12.318 | 1.0.0 |
| **VSCode 版本** | 1.107.1 | 1.107.1 |
| **Commit** | c8b7de5 | 0974fb9 |
| **日期** | 2026-06-09 | 2026-06-17 |

v1.0.0 更新引入 **Agent Focus**，同時重構了 session 儲存結構。遷移未能：
1. 在 session 目錄名稱加上必要的 `sess_` 前綴
2. 將 `workspacePaths` 從舊格式（`e:/dev/web/estate`）轉為新格式（`e:\Dev\Web\Estate`）

## 根本原因

| 項目 | 舊格式 | 新格式（必要） |
|------|--------|---------------|
| 目錄名稱 | `a5d9f774-...` | `sess_a5d9f774-...` |
| `session.json` id | `a5d9f774-...` | `sess_a5d9f774-...` |
| `workspacePaths` | `e:/dev/web/estate` | `e:\Dev\Web\Estate` |
| 新欄位 | 不存在 | `semanticReviewEnabled`, `ftaEnabled`, `effortLevel` |

## 檔案說明

| 檔案 | 用途 |
|------|------|
| `run.bat` | 選單啟動器（雙擊執行） |
| `fix_all_sessions.ps1` | 主修復腳本 |
| `verify.ps1` | 修復後驗證 |
| `backup.bat` | 獨立備份（選單內也有） |

## 使用方式

> **免安裝**：放哪裡都能跑，路徑自動解析。

雙擊 `run.bat` 開啟選單：

```
[0] Dry Run - 預覽變更（不修改）
[1] Backup - 建立 zip 備份
[2] Fix - 執行修復
[3] Verify - 驗證修復結果
[4] Exit
```

建議流程：`Backup` -> `Dry Run` -> `Fix` -> `Verify` -> 重新載入 Kiro

## 修復內容

對所有 workspace 的 session：

1. **重命名**目錄：`<uuid>` → `sess_<uuid>`
2. **修正 `workspacePaths`**：`e:/dev/web/estate` → `e:\Dev\Web\Estate`
3. **更新 `session.json`**：加 `sess_` 前綴、補新欄位
4. **不會**修改 `messages.jsonl`（對話資料不動）

### 路徑解析優先順序

```
1. globalStorage base64 目錄（Kiro 原始記錄，最可靠）
2. .trust-migration.json
3. 已存在的 sess_ session（含反斜線格式）
4. Fallback：正規化舊資料的正斜線
```

## 安全性

- 選單式操作，修復前需確認
- 內建 Dry Run 預覽
- 可重複執行（冪等）
- `messages.jsonl` 永遠不會被修改

## 使用方式

> **免安裝**：放哪裡都能跑，路徑自動解析。

雙擊 `run.bat` 開啟選單：

```
[0] Dry Run - 預覽變更（不修改）
[1] Backup - 建立 zip 備份
[2] Fix - 執行修復
[3] Verify - 驗證修復結果
[4] Exit
```

建議流程：`Backup` -> `Dry Run` -> `Fix` -> `Verify` -> 重新載入 Kiro

## 修復內容

對所有 workspace 的 session：

1. **重命名**目錄：`<uuid>` → `sess_<uuid>`
2. **修正 `workspacePaths`**：`e:/dev/web/estate` → `e:\Dev\Web\Estate`
3. **更新 `session.json`**：加 `sess_` 前綴、補新欄位
4. **不會**修改 `messages.jsonl`（對話資料不動）

### 路徑解析優先順序

```
1. globalStorage base64 目錄（Kiro 原始記錄，最可靠）
2. .trust-migration.json
3. 已存在的 sess_ session（含反斜線格式）
4. Fallback：正規化舊資料的正斜線
```

## 安全性

- 選單式操作，修復前需確認
- 內建 Dry Run 預覽
- 可重複執行（冪等）
- `messages.jsonl` 永遠不會被修改
