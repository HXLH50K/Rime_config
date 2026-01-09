# init_deploy_android.bat 脚本内容

以下是根据依赖分析生成的完整部署脚本内容。需要切换到 Code 模式创建实际的 `.bat` 文件。

## 脚本内容

```batch
@echo off
REM ========================================
REM 初次部署 Rime 配置到 Android 设备
REM 基于 moqi_xh-18key.schema.yaml 和 shouxin_18key.trime.yaml 的完整依赖分析
REM 依赖文档: plans/init_deploy_android_dependencies.md
REM ========================================

echo ========================================
echo 开始初次部署 Rime 配置到 Android 设备
echo ========================================
echo.

REM ========================================
REM 阶段1: 基础配置文件
REM ========================================
echo [阶段1/5] 部署基础配置文件...
adb push default.yaml /sdcard/rime2
adb push default.custom.yaml /sdcard/rime2
adb push moqi.yaml /sdcard/rime2
adb push symbols_caps_v.yaml /sdcard/rime2
adb push shouxin_18key.trime.yaml /sdcard/rime2
echo [阶段1/5] 完成
echo.

REM ========================================
REM 阶段2: 词典文件
REM ========================================
echo [阶段2/5] 部署词典文件...

REM 2.1 词库子目录
echo   - 部署墨奇词库 (cn_dicts_moqi/)...
adb shell mkdir -p /sdcard/rime2/cn_dicts_moqi
adb push cn_dicts_moqi/8105.dict.yaml /sdcard/rime2/cn_dicts_moqi
adb push cn_dicts_moqi/41448.dict.yaml /sdcard/rime2/cn_dicts_moqi
adb push cn_dicts_moqi/base.dict.yaml /sdcard/rime2/cn_dicts_moqi
adb push cn_dicts_moqi/ext.dict.yaml /sdcard/rime2/cn_dicts_moqi
adb push cn_dicts_moqi/cell.dict.yaml /sdcard/rime2/cn_dicts_moqi
REM 可选: adb push cn_dicts_moqi/others.dict.yaml /sdcard/rime2/cn_dicts_moqi

echo   - 部署通用词库 (cn_dicts_common/)...
adb shell mkdir -p /sdcard/rime2/cn_dicts_common
adb push cn_dicts_common/user.dict.yaml /sdcard/rime2/cn_dicts_common
adb push cn_dicts_common/changcijian.dict.yaml /sdcard/rime2/cn_dicts_common
adb push cn_dicts_common/changcijian3.dict.yaml /sdcard/rime2/cn_dicts_common

REM 2.2 主词典文件
echo   - 部署主词典文件...
adb push moqi.extended.dict.yaml /sdcard/rime2
adb push moqi_big.extended.dict.yaml /sdcard/rime2

REM 2.3 依赖词典
echo   - 部署依赖词典...
adb push easy_en.dict.yaml /sdcard/rime2
adb push jp_sela.dict.yaml /sdcard/rime2
adb push emoji.dict.yaml /sdcard/rime2
adb push cangjie5.dict.yaml /sdcard/rime2
adb push radical_flypy.dict.yaml /sdcard/rime2
adb push reverse_moqima.dict.yaml /sdcard/rime2

echo [阶段2/5] 完成
echo.

REM ========================================
REM 阶段3: 输入方案
REM ========================================
echo [阶段3/5] 部署输入方案...
REM 清除之前编译的主题文件
adb shell rm -f /sdcard/rime2/build/shouxin_18key.trime.yaml
adb push moqi_xh-18key.schema.yaml /sdcard/rime2
echo [阶段3/5] 完成
echo.

REM ========================================
REM 阶段4: 扩展功能
REM ========================================
echo [阶段4/5] 部署扩展功能...

REM 4.1 Lua脚本 - 核心18键脚本
echo   - 部署Lua脚本 (18键核心)...
adb shell mkdir -p /sdcard/rime2/lua
adb push lua/precise_input_processor.lua /sdcard/rime2/lua
adb push lua/precise_input_filter.lua /sdcard/rime2/lua
adb push lua/sharedkey_shuangpin_auxcode_processor.lua /sdcard/rime2/lua
adb push lua/sharedkey_shuangpin_auxcode_filter.lua /sdcard/rime2/lua

REM 4.2 Lua脚本 - 通用翻译器
echo   - 部署Lua脚本 (通用翻译器)...
adb push lua/date_translator.lua /sdcard/rime2/lua
adb push lua/lunar.lua /sdcard/rime2/lua
adb push lua/unicode.lua /sdcard/rime2/lua
adb push lua/number_translator.lua /sdcard/rime2/lua
adb push lua/calculator.lua /sdcard/rime2/lua

REM 4.3 Lua脚本 - 通用过滤器
echo   - 部署Lua脚本 (通用过滤器)...
adb push lua/pro_comment_format.lua /sdcard/rime2/lua
adb push lua/is_in_user_dict.lua /sdcard/rime2/lua

REM 4.4 Lua依赖库
echo   - 部署Lua依赖库 (sbxlm)...
adb shell mkdir -p /sdcard/rime2/lua/sbxlm
adb push lua/sbxlm/lib.lua /sdcard/rime2/lua/sbxlm

REM 4.5 OpenCC配置文件
echo   - 部署OpenCC配置...
adb shell mkdir -p /sdcard/rime2/opencc
adb push opencc/moqi_chaifen.json /sdcard/rime2/opencc
adb push opencc/moqi_chaifen.txt /sdcard/rime2/opencc
adb push opencc/moqi_chaifen_all.json /sdcard/rime2/opencc
adb push opencc/moqi_chaifen_all.txt /sdcard/rime2/opencc
adb push opencc/chinese_english.json /sdcard/rime2/opencc
adb push opencc/chinese_english.txt /sdcard/rime2/opencc
adb push opencc/emoji.json /sdcard/rime2/opencc
adb push opencc/emoji.txt /sdcard/rime2/opencc
adb push opencc/martian.json /sdcard/rime2/opencc
adb push opencc/martian.txt /sdcard/rime2/opencc

REM 4.6 自定义短语
echo   - 部署自定义短语...
adb shell mkdir -p /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_3_code.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_kf.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_mqzg.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_super_1jian.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_super_2jian.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_super_3jian.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_super_3jian_no_conflict.txt /sdcard/rime2/custom_phrase
adb push custom_phrase/custom_phrase_super_4jian_no_conflict.txt /sdcard/rime2/custom_phrase

echo [阶段4/5] 完成
echo.

REM ========================================
REM 阶段5: 触发重新部署
REM ========================================
echo [阶段5/5] 触发 Trime 重新部署...
adb shell am broadcast -a com.osfans.trime.deploy
echo [阶段5/5] 完成
echo.

echo ========================================
echo 初次部署完成！
echo ========================================
echo.
echo 提示：
echo 1. 字体文件 (*.ttf) 需要单独提供或使用系统默认字体
echo 2. 请在 Trime 中检查部署结果
echo 3. 首次部署可能需要较长时间，请耐心等待
echo 4. 如遇问题，请查看 Trime 日志
echo.

pause
```

## 脚本特点

### 1. 分阶段部署
- **阶段1**: 基础配置文件（5个文件）
- **阶段2**: 词典文件（主词典、子词典、依赖词典）
- **阶段3**: 输入方案（主方案文件）
- **阶段4**: 扩展功能（Lua脚本、OpenCC、自定义短语）
- **阶段5**: 触发Trime重新部署

### 2. 目录自动创建
使用 `adb shell mkdir -p` 命令确保目标目录存在

### 3. 清理旧文件
在部署方案前清除编译缓存：
```batch
adb shell rm -f /sdcard/rime2/build/shouxin_18key.trime.yaml
```

### 4. 完整依赖覆盖
包含所有必需的依赖文件：
- 6个主词典文件
- 8个词库子文件
- 13个Lua脚本文件
- 10个OpenCC配置文件
- 9个自定义短语文件

### 5. 可选依赖标注
使用注释标记可选文件，如：
```batch
REM 可选: adb push cn_dicts_moqi/others.dict.yaml /sdcard/rime2/cn_dicts_moqi
```

## 使用方法

1. 确保 Android 设备已通过 USB 连接并开启 USB 调试
2. 确认 ADB 已安装并在系统 PATH 中
3. 在项目根目录运行：
   ```cmd
   init_deploy_android.bat
   ```
4. 等待部署完成后，在 Trime 中点击"部署"

## 与 deploy_android.bat 的区别

| 特性 | deploy_android.bat | init_deploy_android.bat |
|------|-------------------|------------------------|
| 用途 | 日常更新部署 | 初次完整部署 |
| 文件数量 | 约10个核心文件 | 约60+个完整依赖 |
| 词典部署 | 不包含 | 包含所有词库子文件 |
| OpenCC | 不包含 | 包含完整配置 |
| 自定义短语 | 不包含 | 包含所有短语文件 |
| 部署时间 | 快速（几秒） | 较长（1-2分钟） |

## 后续优化建议

1. **添加错误检查**：检测 ADB 连接状态
2. **文件存在性验证**：部署前检查文件是否存在
3. **进度显示**：显示详细的文件传输进度
4. **可选组件选择**：允许用户选择是否部署大字集等可选组件
5. **备份功能**：部署前备份现有配置

## 下一步

需要切换到 **Code 模式** 来创建实际的 `init_deploy_android.bat` 文件。
