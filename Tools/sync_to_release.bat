@echo off
chcp 65001 >nul
REM Sync key files to trime-sharedkey-shuangpin release directory
REM Source: C:\Workspace\Rime_config
REM Target: C:\Workspace\trime-sharedkey-shuangpin

setlocal EnableDelayedExpansion

set "SRC=C:\Workspace\Rime_config"
set "DST=C:\Workspace\trime-sharedkey-shuangpin"

echo ========================================
echo 同步关键文件到发布目录
echo 源目录: %SRC%
echo 目标目录: %DST%
echo ========================================
echo.

REM 检查目标目录是否存在
if not exist "%DST%" (
    echo 错误: 目标目录不存在 - %DST%
    exit /b 1
)

REM 同步根目录文件
echo [1/5] 同步 moqi_xh-18key.schema.yaml ...
copy /Y "%SRC%\moqi_xh-18key.schema.yaml" "%DST%\moqi_xh-18key.schema.yaml"
if errorlevel 1 (
    echo 错误: 复制 moqi_xh-18key.schema.yaml 失败
) else (
    echo 成功: moqi_xh-18key.schema.yaml
)

echo [2/5] 同步 shouxin_18key.trime.yaml ...
copy /Y "%SRC%\shouxin_18key.trime.yaml" "%DST%\shouxin_18key.trime.yaml"
if errorlevel 1 (
    echo 错误: 复制 shouxin_18key.trime.yaml 失败
) else (
    echo 成功: shouxin_18key.trime.yaml
)

REM 确保 lua 目录存在
if not exist "%DST%\lua" mkdir "%DST%\lua"

echo [3/5] 同步 lua/sharedkey_shuangpin_precise_input_filter.lua ...
copy /Y "%SRC%\lua\sharedkey_shuangpin_precise_input_filter.lua" "%DST%\lua\sharedkey_shuangpin_precise_input_filter.lua"
if errorlevel 1 (
    echo 错误: 复制 sharedkey_shuangpin_precise_input_filter.lua 失败
) else (
    echo 成功: sharedkey_shuangpin_precise_input_filter.lua
)

echo [4/5] 同步 lua/sharedkey_shuangpin_precise_input_processor.lua ...
copy /Y "%SRC%\lua\sharedkey_shuangpin_precise_input_processor.lua" "%DST%\lua\sharedkey_shuangpin_precise_input_processor.lua"
if errorlevel 1 (
    echo 错误: 复制 sharedkey_shuangpin_precise_input_processor.lua 失败
) else (
    echo 成功: sharedkey_shuangpin_precise_input_processor.lua
)

REM 确保 Tools 目录存在
if not exist "%DST%\Tools" mkdir "%DST%\Tools"

echo [5/5] 同步 Tools/init_deploy_android.bat ...
copy /Y "%SRC%\Tools\init_deploy_android.bat" "%DST%\Tools\init_deploy_android.bat"
if errorlevel 1 (
    echo 错误: 复制 init_deploy_android.bat 失败
) else (
    echo 成功: init_deploy_android.bat
)

echo.
echo ========================================
echo 同步完成!
echo ========================================

endlocal
