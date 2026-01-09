@echo off
REM ========================================
REM 快速部署 Rime 18键核心配置到 Android 设备
REM 用途：开发者日常快速更新核心文件
REM 对比 init_deploy_android.bat：仅部署核心文件，速度更快
REM ========================================

REM ========================================
REM 配置变量：目标目录
REM 修改此变量可快速切换部署目标（rime, rime1, rime2, rime3...）
REM ========================================
set RIME_DIR=/sdcard/rime

echo ========================================
echo 快速部署 Rime 18键核心配置
echo 目标目录: %RIME_DIR%
echo ========================================
echo.

REM ========================================
REM 核心配置文件（必需）
REM ========================================
echo [1/4] 部署核心配置文件...
REM default.yaml 和 default.custom.yaml 由 Trime/Weasel 自动生成，无需手动部署
adb push moqi_xh-18key.schema.yaml %RIME_DIR%
echo   完成

echo.
REM ========================================
REM Trime 主题配置（Android专用）
REM ========================================
echo [2/4] 部署 Trime 主题和键盘...
REM 清除编译缓存的主题文件
adb shell "rm -f %RIME_DIR%/build/shouxin_18key.trime.yaml"
adb push shouxin_18key.trime.yaml %RIME_DIR%
echo   完成

echo.
REM ========================================
REM Lua 脚本（18键核心功能）
REM ========================================
echo [3/4] 部署 Lua 脚本...
REM 确保lua目录存在
adb shell "mkdir -p %RIME_DIR%/lua/sbxlm"

REM 精确输入处理（18键共键专用）
adb push lua/sharedkey_shuangpin_precise_input_processor.lua %RIME_DIR%/lua
adb push lua/sharedkey_shuangpin_precise_input_filter.lua %RIME_DIR%/lua

REM Lua依赖库
adb push lua/sbxlm/lib.lua %RIME_DIR%/lua/sbxlm

REM 形码处理（当前有BUG)
REM adb push lua/sharedkey_shuangpin_auxcode_filter.lua %RIME_DIR%/lua
REM adb push lua/sharedkey_shuangpin_auxcode_processor.lua %RIME_DIR%/lua
echo   完成

echo.
REM ========================================
REM 触发 Trime 重新部署
REM ========================================
echo [4/4] 触发 Trime 重新部署...
REM 使用新的 action (Trime v3.2.15+)
adb shell am broadcast -a com.osfans.trime.action.DEPLOY
echo.

echo.
echo ========================================
echo 快速部署完成！
echo ========================================
echo.