@echo off
REM ========================================
REM Deploy Rime config to Windows Weasel (Xiaolangmao).
REM Pushes moqi_xh-weasel.schema.yaml and friends to %APPDATA%\Rime.
REM ========================================

setlocal EnableDelayedExpansion

pushd "%~dp0\.." || (echo [ERROR] Cannot cd to repo root.& exit /b 1)

set "RIME_DIR=%APPDATA%\Rime"
set "FAILED=0"

echo ========================================
echo Deploy to Weasel
echo Target: %RIME_DIR%
echo ========================================
echo.

if not exist "%RIME_DIR%" (
    echo [INFO] Target directory missing, creating: %RIME_DIR%
    mkdir "%RIME_DIR%" || (
        echo [ERROR] Failed to create %RIME_DIR%
        goto :fail
    )
)

echo [1/3] Copying schema and custom files...
call :copy_file "moqi_xh-weasel.schema.yaml"    "%RIME_DIR%\moqi_xh-weasel.schema.yaml"
call :copy_file "moqi_xh-weasel.custom.yaml"    "%RIME_DIR%\moqi_xh-weasel.custom.yaml"
call :copy_file "default.windows.custom.yaml"   "%RIME_DIR%\default.custom.yaml"
echo.

echo [2/3] Copying lua scripts...
if not exist "%RIME_DIR%\lua" mkdir "%RIME_DIR%\lua"
call :copy_file "lua\kp_num_processor.lua" "%RIME_DIR%\lua\kp_num_processor.lua"
echo.

echo [3/3] Triggering Weasel redeploy...
set "DEPLOYER="
for %%P in (
    "%ProgramFiles%\Rime\weasel-0.17.4\WeaselDeployer.exe"
    "%ProgramFiles(x86)%\Rime\weasel-0.17.4\WeaselDeployer.exe"
    "%ProgramFiles%\Rime\weasel-0.16.0\WeaselDeployer.exe"
) do (
    if exist "%%~P" set "DEPLOYER=%%~P"
)
if not defined DEPLOYER (
    REM Fallback: scan for any installed version.
    for /f "delims=" %%P in ('dir /b /s "%ProgramFiles%\Rime\WeaselDeployer.exe" 2^>nul') do set "DEPLOYER=%%P"
)
if not defined DEPLOYER (
    echo [WARN] WeaselDeployer.exe not found. Please redeploy manually from the tray icon.
    set /a FAILED+=1
) else (
    echo   using: !DEPLOYER!
    start "" "!DEPLOYER!" /deploy
)

echo.
echo ========================================
if "!FAILED!"=="0" (
    echo Deploy finished successfully.
    set "EXITCODE=0"
) else (
    echo Deploy finished with !FAILED! warning^(s^).
    set "EXITCODE=1"
)
echo ========================================
popd
endlocal & exit /b %EXITCODE%

:fail
popd
endlocal & exit /b 1

:copy_file
if not exist "%~1" (
    echo [ERROR] Source missing: %~1
    set /a FAILED+=1
    exit /b 1
)
copy /Y "%~1" "%~2" >nul
if errorlevel 1 (
    echo [ERROR] copy failed: %~1
    set /a FAILED+=1
) else (
    echo   ok: %~1
)
exit /b 0
