@echo off
REM ========================================
REM Sync key files to the trime-sharedkey-shuangpin release repo.
REM Source: this repo (auto-detected from script location).
REM Target: ..\trime-sharedkey-shuangpin (override with DST env var).
REM ========================================

setlocal EnableDelayedExpansion

pushd "%~dp0\.." || (echo [ERROR] Cannot cd to repo root.& exit /b 1)
set "SRC=%CD%"

if not defined DST (
    if exist "%SRC%\..\trime-sharedkey-shuangpin" (
        for %%I in ("%SRC%\..\trime-sharedkey-shuangpin") do set "DST=%%~fI"
    ) else (
        set "DST=C:\Workspace\trime-sharedkey-shuangpin"
    )
)

set "FAILED=0"

echo ========================================
echo Sync to release repo
echo SRC: %SRC%
echo DST: %DST%
echo ========================================
echo.

if not exist "%DST%" (
    echo [ERROR] Target directory does not exist: %DST%
    echo Hint: set DST env var to override, e.g. set DST=D:\path\to\repo
    goto :fail
)

echo [1/8] moqi_xh-18key.schema.yaml
call :copy_file "%SRC%\moqi_xh-18key.schema.yaml" "%DST%\moqi_xh-18key.schema.yaml"

echo [2/8] shouxin_18key.trime.yaml
call :copy_file "%SRC%\shouxin_18key.trime.yaml" "%DST%\shouxin_18key.trime.yaml"

if not exist "%DST%\lua" mkdir "%DST%\lua"
echo [3/8] lua\sharedkey_shuangpin_precise_input_filter.lua
call :copy_file "%SRC%\lua\sharedkey_shuangpin_precise_input_filter.lua" "%DST%\lua\sharedkey_shuangpin_precise_input_filter.lua"

echo [4/8] lua\sharedkey_shuangpin_precise_input_processor.lua
call :copy_file "%SRC%\lua\sharedkey_shuangpin_precise_input_processor.lua" "%DST%\lua\sharedkey_shuangpin_precise_input_processor.lua"

echo [5/8] lua\sharedkey_shuangpin_auxcode_processor.lua
call :copy_file "%SRC%\lua\sharedkey_shuangpin_auxcode_processor.lua" "%DST%\lua\sharedkey_shuangpin_auxcode_processor.lua"

echo [6/8] lua\sharedkey_shuangpin_auxcode_filter.lua
call :copy_file "%SRC%\lua\sharedkey_shuangpin_auxcode_filter.lua" "%DST%\lua\sharedkey_shuangpin_auxcode_filter.lua"

if not exist "%DST%\tools" mkdir "%DST%\tools"
echo [7/8] tools\init_deploy_android.bat
call :copy_file "%SRC%\tools\init_deploy_android.bat" "%DST%\tools\init_deploy_android.bat"

echo [8/8] tools\init_installation.ps1
call :copy_file "%SRC%\tools\init_installation.ps1" "%DST%\tools\init_installation.ps1"

echo.
echo ========================================
if "!FAILED!"=="0" (
    echo Sync finished successfully.
    set "EXITCODE=0"
) else (
    echo Sync finished with !FAILED! failure^(s^).
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
    echo   [ERROR] source missing: %~1
    set /a FAILED+=1
    exit /b 1
)
copy /Y "%~1" "%~2" >nul
if errorlevel 1 (
    echo   [ERROR] copy failed: %~1
    set /a FAILED+=1
) else (
    echo   ok
)
exit /b 0
