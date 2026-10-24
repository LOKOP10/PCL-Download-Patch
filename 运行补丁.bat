@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch_dl.ps1"
) else (
    echo [info] target: %~1
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch_dl.ps1" -Source "%~1"
)
echo.
pause
endlocal
