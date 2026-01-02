@echo off
REM 部署 Rime 配置到 Android 设备
REM 主要文件：shouxin_18key.trime.yaml (主题+键盘), moqi_xh-trime.custom.yaml (模糊规则)

adb push trime.custom.yaml /sdcard/rime
adb push moqi_xh-trime.custom.yaml /sdcard/rime
adb push moqi_xh-trime.schema.yaml /sdcard/rime
adb shell rm /sdcard/rime/build/shouxin_18key.trime.yaml
adb push shouxin_18key.trime.yaml /sdcard/rime

adb shell am broadcast -a com.osfans.trime.deploy
