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
- `init_deploy_windows.bat` — Windows 完整初始化部署到 `%APPDATA%\Rime`，覆盖同名配置，保留用户数据库；需已安装小狼毫（提供 `stroke` 依赖）
- `deploy_android.bat` — Android 增量部署
- `init_deploy_android.bat` — Android 完整初始化部署
- `sync_to_release.bat` — 同步到发布 repo
- `pull_trime_log.bat` — 拉取 Trime 调试日志

两个初始化脚本都会调用 `Tools/init_installation.ps1`，自动创建或补齐目标目录的 `installation.yaml`，包含 `distribution_code_name`、`distribution_name`、`distribution_version`、`install_time`、`rime_version`、`name`、`installation_id` 和 `sync_dir`：

- Windows：使用目标计算机名填写 `name` 和 `installation_id`；发行版名称为“小狼毫”，代号为 `Weasel`。
- Android：依次读取 `secure/system/global` 的 `bluetooth_name`，再尝试 `system/device_name` 和 `persist.sys.device_name`，填写 `name` 和 `installation_id`；发行版名称为 `Trime`，代号为 `trime`。候选值若与 `ro.product.model` 或 `ro.product.*marketname` 的产品名称相同则跳过；不使用 `global/device_name` 作为名称来源。输出选中字段的来源，读取不到区别于型号的自定义名称时停止部署，避免将默认产品名写入同步标识。
- 同步目录在各自 BAT 顶部的 `SYNC_DIR` 变量中修改：Windows 默认 `%APPDATA%\RimeSync`，Android 默认 `/sdcard/com.hxlh/Rime`。必须填写目标平台的绝对路径。初始化时该值会覆盖已有 `sync_dir`；不会迁移旧同步目录或其中的数据。
- 保留已有非空的发行版信息、版本、安装时间及其他字段；缺失的安装时间使用当前时间。缺失版本的默认值为 Windows `0.17.4` / librime `1.13.1`、Android `v3.3.8-0-gf3f5c923` / librime `1.15.0`，不是自动探测结果，可通过辅助脚本的 `-DistributionVersion` 和 `-RimeVersion` 参数修改补缺值。
- 单独调用辅助脚本且未传 `-SyncDir` 时，保留已有非空的同步路径；缺失时使用上述平台默认值。设备改名会更新 `name` 和 `installation_id`，但不会自动迁移旧设备同步子目录。

可用 `powershell.exe -NoProfile -File Tools/init_installation.ps1 -Platform Android -SyncDir "/sdcard/com.hxlh/Rime" -WhatIf` 只读检查名称和写入目标；Windows 使用 `-Platform Windows` 及本机同步路径。隔离测试：`powershell.exe -NoProfile -File Tools/tests/init_installation.tests.ps1`。

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

- [`Docs/Android-18key.md`](Docs/Android-18key.md) — Android 18键当前设计、输入规则、测试与已知问题
- [`Docs/Trime-reference.md`](Docs/Trime-reference.md) — Trime 键盘配置与部署参考
- [`Docs/design-decisions.md`](Docs/design-decisions.md) — 已采用和放弃方案的决策摘要