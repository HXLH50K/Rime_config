@echo off
REM 部署 Rime 配置到 Android 设备
REM 主要文件：shouxin_18key.trime.yaml (主题+键盘), moqi_xh-trime.custom.yaml (模糊规则)
REM Lua 文件：精确输入处理器和过滤器（依赖 sbxlm.lib）

adb push default.yaml /sdcard/rime
adb push default.custom.yaml /sdcard/rime
REM 配置文件
adb push trime.custom.yaml /sdcard/rime
@REM adb push moqi_xh-trime.custom.yaml /sdcard/rime
@REM adb push moqi_xh-trime.schema.yaml /sdcard/rime
adb push moqi_xh-18key.schema.yaml /sdcard/rime
adb shell rm /sdcard/rime/build/shouxin_18key.trime.yaml
adb push shouxin_18key.trime.yaml /sdcard/rime

REM Lua 脚本：精确输入处理
adb push lua/precise_input_processor.lua /sdcard/rime/lua
adb push lua/precise_input_filter.lua /sdcard/rime/lua

REM Lua 脚本: 形码处理
adb push lua/sharedkey_shuangpin_auxcode_filter.lua /sdcard/rime/lua
adb push lua/sharedkey_shuangpin_auxcode_processor.lua /sdcard/rime/lua

REM Lua 依赖库：sbxlm（精确输入处理器依赖）
adb shell mkdir -p /sdcard/rime/lua/sbxlm
adb push lua/sbxlm/lib.lua /sdcard/rime/lua/sbxlm

adb shell am broadcast -a com.osfans.trime.deploy
