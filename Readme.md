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

## Windows 小键盘输入

仅作用于 `moqi_xh-weasel` 方案，不改变 Android 18键方案：

- 主键盘数字仍用于选词。
- Num Lock 开启时，已有组合输入后按小键盘数字，进入本次组合的临时原样输入。例如 `c` + 小键盘 `8` 显示 `c8`，不选汉字、不立即上屏；后续字母及两组数字键均继续输入验证码。
- 主键盘 Enter 和小键盘 Enter 均将组合内容原样上屏；上屏、Esc 取消或退格清空后恢复中文。支持在组合区移动光标、插入数字和退格编辑。
- 没有组合输入时，小键盘数字直接输入，小键盘 Enter 交给应用处理。已处于英文模式时不强制切回中文；修饰键组合及 Num Lock 关闭后的导航键维持原有处理。

Weasel 0.17.4 已区分 `KP_0`～`KP_9` 和 `KP_Enter`（[上游键码转换](https://github.com/rime/weasel/blob/0.17.4/WeaselTSF/KeyEvent.cpp)），因此无需修改小狼毫本体。默认配置把小键盘数字映射成主键盘数字；[Lua 处理器](lua/kp_num_processor.lua) 在该映射之前拦截，并借用 Rime 的临时 ASCII 组合机制避免中文候选。[Windows 补丁](moqi_xh-weasel.custom.yaml) 将 `KP_Enter` 绑定为 `Return`，复用原有回车行为。

运行 [Windows 增量部署脚本](Tools/deploy_windows.bat) 即可复制上述两项修改并请求重新部署；无需完整初始化或清理用户词库。

回归测试：安装 Python、PyYAML 和小狼毫后，运行 `python .\Tools\tests\keypad.tests.py`。默认加载 `C:\Program Files\Rime\weasel-0.17.4\rime.dll`，其他安装位置可通过 PowerShell 的 `$env:WEASEL_DIR` 指定。测试使用临时用户目录、实际 Windows 处理器和按键绑定，以及九候选小词典，验证缓冲内容、实际提交文本、主键盘选词、回车、编辑与模式恢复，不修改日常输入法配置或用户词库；不覆盖完整词库或物理键盘事件采集。

## 两端共用的短期调频

Windows 与 Android 的主中文翻译器使用 [recent_frequency.lua](lua/recent_frequency.lua)，保留原生词典查询、造句和用户造词，额外按真实时间重排候选：

- **最长 72 小时滑动窗口、12 小时半衰期**。每次实际使用的加权在 12 小时后减半；达到 72 小时即归零，不需要继续输入其他词来推进衰减，也不是每天清零。
- 短时间反复输入“池泛”可以提升它；停用后逐渐恢复“吃饭”等系统常用候选。单次使用通常比三天更早回落，具体取决于系统排序及其他词的近期使用。
- 过期的是近期加权，不是词条。历史用户词和新造词均保留；旧用户词没有真实使用日期，启用时不把累计次数转换为近期使用。
- 相同覆盖区间内，基础分为 `1 / 系统候选名次`，仅用户词的基础分为 `0`；近期分为窗口内各次使用的 `2^(-经过小时数 / 半衰期)` 之和。系统候选来自关闭用户词典的并行原生查询，避免原生用户词优先规则覆盖时间衰减。
- 保留候选覆盖区间、原生候选对象、Android 精确输入/辅助码过滤，以及专用翻译器和固定短语的优先级。不只是把带 `*` 的候选移到后面，也不会截断候选列表。

在 [moqi.yaml](moqi.yaml) 中统一调整两端：

```yaml
recent_frequency:
  recent_frequency:
    enabled: true
    window_hours: 72
    half_life_hours: 12
```

如需更快恢复，可改成 `window_hours: 24`、`half_life_hours: 4`。支持 `0 < half_life_hours <= window_hours <= 72`，单位为小时；`enabled: false` 恢复原生调频且不再记录新统计。Windows 也可在自定义补丁中单独覆盖 `recent_frequency/window_hours` 等路径。

统计保存在各设备 Rime 用户目录的四个 `recent_frequency.0.tsv`～`recent_frequency.3.tsv` 轮转文件中，记录词条与时间，不与原生用户词典混写。候选浏览、原样回车和验证码不计入词频。文件按 UTC 日期复用，最多保留四个日期槽；长期停用时旧文件仍可能存在，但窗口外记录不参与排序。读取损坏或读写失败会在 Rime 日志中明确报错，不静默重置历史。

**近期统计目前按设备独立计算，不参与 Rime 用户词典同步**；两端共享的是调频规则。无需清空、转换或重新导入已有用户词库。运行对应的 [Windows](Tools/deploy_windows.bat) / [Android](Tools/deploy_android.bat) 增量部署即可更新，完整初始化及发布同步脚本也已包含相关文件。

验证命令：安装 Python、PyYAML、lupa 和小狼毫后运行 `python .\Tools\tests\recent_frequency.tests.py`。测试使用可控时钟，覆盖严格窗口边界、半衰回落、新词保留、重启、24 小时窗口、两端完整配置编译、Android 精确输入、损坏/不可写历史和大候选列表。Windows 小键盘测试仍为 `python .\Tools\tests\keypad.tests.py`。均通过小狼毫的 librime 在隔离目录执行；Android 配置兼容性测试不等于手机端实测，也不替代完整词库和语言模型的效果评估。

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