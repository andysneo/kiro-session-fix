@echo off
cls
echo.
echo ===================================================
echo Kiro Session Migration Fix Tool
echo ===================================================
echo.
echo After updating Kiro to v1.0.0, old sessions become
echo invisible due to a migration naming issue.
echo This tool renames them to the new sess_ format.
echo.
echo Data: %USERPROFILE%\.kiro\sessions\
echo.
echo ---------------------------------------------------
echo.
echo [0] Dry Run - Preview changes without modifying
echo [1] Backup - Create zip backup before fixing
powershell -Command "Write-Host '[2] Fix - Apply session fix' -ForegroundColor Yellow"
echo [3] Verify - Check sessions after fix
echo [4] Exit
echo.
set /p CHOICE=" Select (0-4): "
if "%CHOICE%"=="0" goto DODRYRUN
if "%CHOICE%"=="1" goto DOBACKUP
if "%CHOICE%"=="2" goto DOCONFIRM
if "%CHOICE%"=="3" goto DOVERIFY
if "%CHOICE%"=="4" goto DOQUIT
echo Invalid choice.
pause
goto DOQUIT

:DODRYRUN
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0fix_all_sessions.ps1"
echo.
pause
goto DOQUIT

:DOBACKUP
echo.
echo Creating backup...
echo.
powershell -Command "Compress-Archive -Path '%USERPROFILE%\.kiro\sessions' -DestinationPath '%USERPROFILE%\.kiro\sessions_backup.zip' -Force"
echo.
echo Done. Saved to: %USERPROFILE%\.kiro\sessions_backup.zip
echo.
pause
goto DOQUIT

:DOCONFIRM
echo.
echo This will:
echo 1. Rename dirs: uuid to sess_uuid
echo 2. Update session.json (id, workspacePaths, new fields)
echo 3. NOT modify messages.jsonl
echo.
set /p CONFIRM=" Proceed? (Y/N): "
if /i "%CONFIRM%"=="Y" (
 echo.
 powershell -ExecutionPolicy Bypass -File "%~dp0fix_all_sessions.ps1" -Execute
) else (
 echo.
 echo Cancelled.
)
echo.
pause
goto DOQUIT

:DOVERIFY
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0verify.ps1"
echo.
pause
goto DOQUIT

:DOQUIT
