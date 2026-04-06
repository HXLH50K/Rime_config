# Rime 输入法配置

个人使用的 Rime 配置，基于墨奇音形(Moqi_xh)，包含 Windows 和 Android 两个平台。

## 平台方案

| 平台 | 方案 | 说明 |
|------|------|------|
| Windows | 小狼毫 (Weasel) 26键 | 基于 Moqi_xh 的完整方案，含反查、飞键等 |
| Android | 同文 (Trime) 18键 | 基于 Moqi_xh 的共键双拼方案，仿手心18键布局 |

## 部署

通过 `Tools/` 下的 bat 脚本部署：

- `deploy_windows.bat` — Windows 增量部署
- `deploy_android.bat` — Android 增量部署
- `init_deploy_android.bat` — Android 完整初始化部署
- `sync_to_release.bat` — 同步到发布 repo
- `pull_trime_log.bat` — 拉取 Trime 调试日志

## 目录结构

### 共用基建

| 路径 | 说明 |
|------|------|
| `moqi.yaml` | 主配置 hub（引擎、开关、翻译器、过滤器等） |
| `cn_dicts_moqi/` | 墨奇码表（8105常用字、41448大字集、base、ext等） |
| `cn_dicts_common/` | 通用词库（常词简、用户词库） |
| `custom_phrase/` | 自定义短语（快符、字根、超级简码等） |
| `moqi.extended.dict.yaml` | 主扩展词库 |
| `moqi_big.extended.dict.yaml` | 大字集扩展词库 |
| `opencc/` | 字符转换（拆分显示、emoji、火星文、中英对照） |
| `lua/` | Lua 脚本（翻译器、过滤器、处理器） |
| `symbols_caps_v.yaml` | 符号输入配置 |
| `emoji.*` / `easy_en.*` / `jp_sela.*` | 共用依赖（emoji、英文、日语） |
| `user.custom.dict.txt` | 用户自定义词典 |

### Windows 独有

| 路径 | 说明 |
|------|------|
| `moqi_xh-weasel.schema.yaml` | Windows 26键方案 |
| `moqi_xh-weasel.custom.yaml` | Windows 自定义补丁 |
| `default.windows.yaml` | Windows 默认配置 |
| `default.windows.custom.yaml` | Windows 默认配置补丁 |
| `weasel.custom.yaml` | Weasel 主题配置 |
| `cangjie5.*` / `reverse_moqima.*` / `radical_flypy.*` / `zrlf.*` | 反查依赖 |

### Android 独有

| 路径 | 说明 |
|------|------|
| `moqi_xh-18key.schema.yaml` | Android 18键方案 |
| `shouxin_18key.trime.yaml` | 手心18键键盘主题 |
| `trime.custom.yaml` | Trime 自定义配置 |

### 文档

- `Docs/` — 设计文档与开发参考
- `Docs/archive/` — 已完成/过时的分析文档归档