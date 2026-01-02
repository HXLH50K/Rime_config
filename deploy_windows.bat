@echo off
chcp 65001 >nul
REM 部署 Rime 配置到 Windows 小狼毫
REM 主要文件：moqi_xh-weasel.schema.yaml, moqi_xh-weasel.custom.yaml

set RIME_DIR=%APPDATA%\Rime

echo 正在复制 moqi_xh-weasel 相关文件到 %RIME_DIR%...

REM 复制 schema 和 custom 文件
copy /Y moqi_xh-weasel.schema.yaml "%RIME_DIR%\"
copy /Y moqi_xh-weasel.custom.yaml "%RIME_DIR%\"

@REM REM 复制 moqi.yaml 共享配置
@REM copy /Y moqi.yaml "%RIME_DIR%\"

@REM REM 复制 default.custom.yaml 方案列表
@REM copy /Y default.custom.yaml "%RIME_DIR%\"

@REM REM 复制词典文件
@REM copy /Y moqi.extended.dict.yaml "%RIME_DIR%\"

@REM REM 复制符号配置
@REM copy /Y symbols_caps_v.yaml "%RIME_DIR%\"

echo 文件复制完成！

echo 正在触发小狼毫重新部署...
REM 调用小狼毫部署程序
start "" "%ProgramFiles%\Rime\weasel-0.17.4\WeaselDeployer.exe" /deploy

echo 部署命令已发送！
