@echo off
chcp 65001 >nul
REM 拉取 Trime 最新日志文件到本地 trime_debug_log 目录
REM 日志文件格式: com.osfans.trime-YYYY-MM-DDTHH_MM_SSZ.txt

setlocal enabledelayedexpansion

REM 创建目标目录（如果不存在）
if not exist "trime_debug_log" mkdir trime_debug_log

REM 获取 /sdcard/Download 下最新的 Trime 日志文件
echo 正在查找最新的 Trime 日志文件...

REM 使用 adb shell 列出匹配的文件并按时间排序，获取最新的一个
for /f "tokens=*" %%a in ('adb shell "ls -t /sdcard/Download/com.osfans.trime-* 2>/dev/null | head -1"') do (
    set "LATEST_FILE=%%a"
)

if not defined LATEST_FILE (
    echo 错误: 未找到 Trime 日志文件
    exit /b 1
)

REM 提取文件名
for %%f in (!LATEST_FILE!) do set "FILENAME=%%~nxf"

echo 找到最新日志: !FILENAME!
echo 正在拉取到 trime_debug_log 目录...

adb pull "!LATEST_FILE!" "trime_debug_log\!FILENAME!"

if %errorlevel% equ 0 (
    echo 成功: 日志已保存到 trime_debug_log\!FILENAME!
) else (
    echo 错误: 拉取文件失败
    exit /b 1
)

endlocal
