@echo off
REM 部署 Rime 配置到 Android 设备
REM 主要文件：tongwenfeng-custom.trime.yaml (主题+键盘), moqi_xh.custom.yaml (模糊规则)

adb push trime.custom.yaml /sdcard/rime
adb push moqi_xh.custom.yaml /sdcard/rime
adb push moqi_xh.schema.yaml /sdcard/rime
adb shell rm /sdcard/rime/build/tongwenfeng-custom.trime.yaml
adb push tongwenfeng-custom.trime.yaml /sdcard/rime

adb shell am broadcast -a com.osfans.trime.deploy
