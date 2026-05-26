@echo off
REM ========================================
REM Pull the latest Trime debug log from the device.
REM Log files on device: /sdcard/Download/com.osfans.trime-YYYY-MM-DDTHH_MM_SSZ.txt
REM Saved locally under: trime_debug_log\
REM ========================================

setlocal EnableDelayedExpansion

pushd "%~dp0\.." || (echo [ERROR] Cannot cd to repo root.& exit /b 1)

call :check_adb || goto :fail
call :check_device || goto :fail

if not exist "trime_debug_log" mkdir "trime_debug_log"

echo Searching for the latest Trime log on device...
set "LATEST_FILE="
for /f "usebackq tokens=*" %%a in (`adb shell "ls -t /sdcard/Download/com.osfans.trime-* 2>/dev/null | head -1"`) do (
    set "LATEST_FILE=%%a"
)

REM Strip trailing CR that adb shell may emit.
if defined LATEST_FILE set "LATEST_FILE=!LATEST_FILE:`r=!"

if not defined LATEST_FILE (
    echo [ERROR] No Trime log found under /sdcard/Download/.
    goto :fail
)

REM Extract basename.
for %%F in ("!LATEST_FILE!") do set "FILENAME=%%~nxF"

echo Found: !FILENAME!
echo Pulling to trime_debug_log\!FILENAME! ...

adb pull "!LATEST_FILE!" "trime_debug_log\!FILENAME!"
if errorlevel 1 (
    echo [ERROR] adb pull failed.
    goto :fail
)

echo OK: saved to trime_debug_log\!FILENAME!
popd
endlocal & exit /b 0

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
