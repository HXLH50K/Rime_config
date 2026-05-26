@echo off
REM ========================================
REM Quick deploy Rime 18-key core files to Android device.
REM For day-to-day updates of core files only.
REM See init_deploy_android.bat for full first-time deployment.
REM ========================================

setlocal EnableDelayedExpansion

pushd "%~dp0\.." || (echo [ERROR] Cannot cd to repo root.& exit /b 1)

set "RIME_DIR=/sdcard/rime"

echo ========================================
echo Quick deploy: Rime 18-key core
echo Target: %RIME_DIR%
echo ========================================
echo.

call :check_adb || goto :fail
call :check_device || goto :fail

set "FAILED=0"

echo [1/4] Pushing core schema files...
call :push_file "moqi_xh-18key.schema.yaml" "%RIME_DIR%"

echo.
echo [2/4] Pushing Trime theme...
adb shell "rm -f %RIME_DIR%/build/shouxin_18key.trime.yaml" >nul
call :push_file "shouxin_18key.trime.yaml" "%RIME_DIR%"

echo.
echo [3/4] Pushing Lua scripts...
call :adb_mkdir "%RIME_DIR%/lua/sbxlm"
call :push_file "lua/sharedkey_shuangpin_precise_input_processor.lua" "%RIME_DIR%/lua"
call :push_file "lua/sharedkey_shuangpin_precise_input_filter.lua"    "%RIME_DIR%/lua"
call :push_file "lua/sbxlm/lib.lua"                                   "%RIME_DIR%/lua/sbxlm"

echo.
echo [4/4] Broadcasting Trime deploy intent...
adb shell am broadcast -a com.osfans.trime.action.DEPLOY
if errorlevel 1 (
    echo [WARN] Broadcast command failed.
    set /a FAILED+=1
)

echo.
echo ========================================
if "!FAILED!"=="0" (
    echo Deploy finished successfully.
    set "EXITCODE=0"
) else (
    echo Deploy finished with !FAILED! failure^(s^). Check log above.
    set "EXITCODE=1"
)
echo ========================================
popd
endlocal & exit /b %EXITCODE%

:fail
popd
endlocal & exit /b 1

:check_adb
where adb >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb not found in PATH.
    exit /b 1
)
exit /b 0

:check_device
for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
    if "%%b"=="device" exit /b 0
)
echo [ERROR] No authorized adb device connected.
exit /b 1

:adb_mkdir
adb shell "mkdir -p %~1" >nul
if errorlevel 1 (
    echo [WARN] mkdir failed: %~1
    set /a FAILED+=1
)
exit /b 0

:push_file
if not exist "%~1" (
    echo [ERROR] Source missing: %~1
    set /a FAILED+=1
    exit /b 1
)
adb push "%~1" "%~2"
if errorlevel 1 (
    echo [ERROR] push failed: %~1
    set /a FAILED+=1
)
exit /b 0
