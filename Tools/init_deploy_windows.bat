@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0\.." || (echo [ERROR] Cannot cd to repo root.& exit /b 1)

set "RIME_DIR=%APPDATA%\Rime"
set "SYNC_DIR=%APPDATA%\RimeSync"
set "FAILED=0"

echo ========================================
echo First-time deploy to Windows Weasel
echo Target: "%RIME_DIR%"
echo Existing user databases and unrelated files are preserved.
echo Matching configuration files will be overwritten.
echo ========================================
echo.

echo [1/5] Preparing target directory...
if not exist "%RIME_DIR%\" (
    mkdir "%RIME_DIR%" || (
        echo [ERROR] Cannot create target directory: "%RIME_DIR%"
        goto :fail
    )
)
echo Initializing installation.yaml from the computer name...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0init_installation.ps1" -Platform Windows -RimeDir "%RIME_DIR%" -SyncDir "%SYNC_DIR%"
if errorlevel 1 goto :fail
echo.

echo [2/5] Copying base and Windows config...
call :copy_file "default.windows.yaml" "%RIME_DIR%\default.yaml"
call :copy_file "default.windows.custom.yaml" "%RIME_DIR%\default.custom.yaml"
for %%F in (
    moqi.yaml
    symbols_caps_v.yaml
    moqi_xh-weasel.schema.yaml
    moqi_xh-weasel.custom.yaml
    weasel.custom.yaml
    user.custom.dict.txt
) do call :copy_file "%%F" "%RIME_DIR%\%%F"
echo.

echo [3/5] Copying dictionaries and dependency schemas...
for %%F in (
    moqi.extended.dict.yaml
    moqi_big.extended.dict.yaml
    moqi_big.schema.yaml
    cangjie5.dict.yaml
    cangjie5.schema.yaml
    reverse_moqima.dict.yaml
    reverse_moqima.schema.yaml
    radical_flypy.dict.yaml
    radical_flypy.schema.yaml
    zrlf.dict.yaml
    zrlf.schema.yaml
    emoji.dict.yaml
    emoji.schema.yaml
    easy_en.dict.yaml
    easy_en.schema.yaml
    jp_sela.dict.yaml
    jp_sela.schema.yaml
) do call :copy_file "%%F" "%RIME_DIR%\%%F"
for %%D in (cn_dicts_moqi cn_dicts_common) do call :copy_dir "%%D" "%RIME_DIR%\%%D"
echo   Note: stroke is supplied by the Weasel shared data directory.
echo.

echo [4/5] Copying extensions...
for %%D in (lua opencc custom_phrase) do call :copy_dir "%%D" "%RIME_DIR%\%%D"
echo.

if not "%FAILED%"=="0" (
    echo [ERROR] Copy failed for %FAILED% item^(s^). Redeploy was not started.
    goto :fail
)

echo [5/5] Triggering Weasel redeploy...
set "DEPLOYER="
for %%P in ("%ProgramFiles%\Rime" "%ProgramFiles(x86)%\Rime" "%LOCALAPPDATA%\Programs\Rime") do (
    for /d %%D in ("%%~P\weasel-*") do (
        if exist "%%~D\WeaselDeployer.exe" set "DEPLOYER=%%~D\WeaselDeployer.exe"
    )
)
if not defined DEPLOYER (
    for /f "delims=" %%P in ('where WeaselDeployer.exe 2^>nul') do set "DEPLOYER=%%P"
)
if not defined DEPLOYER (
    echo [WARN] Files copied, but WeaselDeployer.exe was not found.
    echo Please redeploy manually from the Weasel tray icon.
    goto :fail
)

echo   using: "%DEPLOYER%"
start "" "%DEPLOYER%" /deploy
if errorlevel 1 (
    echo [ERROR] Could not start Weasel redeploy.
    goto :fail
)

echo.
echo ========================================
echo Initial files copied and redeploy requested.
echo Weasel deploys asynchronously; check its tray icon or logs.
echo ========================================
popd
endlocal & exit /b 0

:fail
popd
endlocal & exit /b 1

:copy_file
if not exist "%~1" (
    echo [ERROR] Source missing: "%~1"
    set /a FAILED+=1 >nul
    exit /b 1
)
copy /Y "%~1" "%~2" >nul
if errorlevel 1 (
    echo [ERROR] Copy failed: "%~1"
    set /a FAILED+=1 >nul
    exit /b 1
)
echo   ok: "%~1"
exit /b 0

:copy_dir
if not exist "%~1\" (
    echo [ERROR] Source directory missing: "%~1"
    set /a FAILED+=1 >nul
    exit /b 1
)
xcopy "%~1\*" "%~2\" /E /I /Y /Q >nul
if errorlevel 1 (
    echo [ERROR] Directory copy failed: "%~1"
    set /a FAILED+=1 >nul
    exit /b 1
)
echo   ok: "%~1/"
exit /b 0