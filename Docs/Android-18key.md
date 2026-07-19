# Android 18键方案

本文档描述当前实际运行的 Android 18键方案。历史过程与已放弃方案见 [design-decisions.md](design-decisions.md)。

## 当前版本

| 组件 | 文件 | 版本 |
|------|------|------|
| 输入方案 | `moqi_xh-18key.schema.yaml` | 0.3.0 |
| Trime 主题 | `shouxin_18key.trime.yaml` | 0.2.0 |
| 精确输入 Processor | `lua/sharedkey_shuangpin_precise_input_processor.lua` | v3 |
| 精确输入 Filter | `lua/sharedkey_shuangpin_precise_input_filter.lua` | v10 |

## 设计目标

- 18键共键布局降低手机按键密度。
- 点击共键时模糊匹配两个字母。
- 左右滑动共键时精确输入单个字母。
- 音码使用小鹤双拼，每个音节固定两码。
- 辅助码必须使用 `[` 引导，避免与后续双拼音节产生歧义。

## 键盘布局

```text
Q | WE | RT | Y | U | IO | P
  | A | SD | FG | H | JK | L |
[/' | Z | XC | V | BN | M | BackSpace
```

共键对：`WE RT IO SD FG JK XC BN`。

### 输入记法

本文档用括号表示点击共键，用裸字母表示滑动精确输入：

- `(bn)`：点击 BN，发送小写 `b`，候选允许 `b/n`。
- `b`：在 BN 上滑动精确输入 `b`。
- `(bn)(io)h(xc)`：模糊输入，实际编码为 `bihx`。
- `(bn)(io)hx`：前两码模糊，后两码精确。

## 输入链路

1. 点击共键发送小写字母，由 `speller/algebra` 生成共键模糊拼写。
2. 滑动共键发送大写字母。
3. Processor 把大写转成小写，并在 `precise_input_map` 记录字符位置。
4. Rime 生成模糊候选。
5. Filter 通过 `ReverseLookup` 检查候选的真实音码和辅助码。
6. 精确位置必须完全匹配；点击位置允许共键模糊。

Processor 在最终提交后清空精确位置。部分选词不会提前清空，后续未提交音节仍保持精确约束。

## 辅助码

辅助码格式：

```text
音码[辅助码
```

示例：

| 输入 | 含义 |
|------|------|
| `sy` | 纯双拼 |
| `sy[f` | 一位辅助码 |
| `sy[ff` | 两位辅助码 |

无 `[` 的三字母输入不解释为辅助码。该约束用于避免 `syf` 究竟是辅助码还是下一音节开头的歧义。

形码后继续多音节的智能解析仍存在复杂边界，当前优先级最低；修改前应先补齐明确的输入语法和测试矩阵。

## 精确候选过滤

Filter v10 包含以下规则：

- 解析所有纯双拼音节，而不只检查首音节。
- 按候选自身的 `start/end` 区间匹配输入。
- 只过滤覆盖精确位置或包含 `[` 的候选区间。
- 与后续精确位置无关的前缀候选原样保留。
- 所有相关候选都执行过滤，不再在第 50 个候选后无条件放行。
- 多音字读取全部反查编码，任意读音匹配即可保留。
- 完整句仅有一个精确音节不匹配时，可用该音节的正确单字重组候选。

例如 `bihxga` 中精确位置为 `g` 时，错误的“你好发”会被删除，并可重组“你好尬、你好嘎”等候选。

## 中英文与子键盘

- 中文主键盘 `default`：`ascii_mode: 0`。
- 英文主键盘 `qwerty26`：`ascii_mode: 1`。
- 两个主键盘均为 `lock: true`。
- 数字和编辑键盘通过 `.last_lock` 返回最近的主键盘。
- `reset_ascii_mode: false`，避免切换布局时额外重置中英文状态。

中英文不同步曾偶发出现。当前修复需要长期观察；若再次复现，下一步是移除切键动作中多余的 `Eisu_toggle`，只保留 `select` 和目标键盘的 `ascii_mode`。

## 部署

首次部署：

```powershell
.\Tools\init_deploy_android.bat
```

日常更新：

```powershell
.\Tools\deploy_android.bat
```

快速部署会定向清除以下构建产物：

- `build/moqi_xh-18key.schema.yaml`
- `build/moqi_xh-18key.prism.bin`
- `build/shouxin_18key.trime.yaml`

随后上传核心 schema、主题和 Lua，验证远端文件非空，再触发 Trime 异步部署。脚本不会删除用户词库或其他方案缓存。

拉取手机导出的最新日志：

```powershell
.\Tools\pull_trime_log.bat
```

## 回归测试

### 基础输入

- 点击所有共键，确认左右字母候选都存在。
- 分别滑动共键两侧，确认只保留精确字母候选。
- 混合点击和滑动，确认精确位置不影响其他模糊位置。
- 连续输入四个以上双拼音节，确认没有六码截断。

### 部分选词

- 输入多音节后选择前缀，确认剩余音节仍可产生候选。
- 精确输入后部分选词，确认后续精确位置仍生效。
- 输入 `nihx`，前缀 `ni` 的单字候选应保持完整。

### 多音字

测试非首条反查编码：

| 输入 | 预期候选 |
|------|----------|
| `xk` | 行 |
| `vh` | 长 |
| `vs` | 重 |
| `yt` | 乐 |
| `dw` | 得 |

### 键盘切换

- 中文与英文往返切换。
- 中文/英文分别进入数字键盘再返回。
- 中文/英文分别进入编辑键盘再返回。

## 已知问题

### Trime 展开候选窗口在退格后重新打开

复现：展开候选窗口，部分选择多个字，收起窗口，再连续退格。Rime 在退格时逐段 reopen 已确认 segment；候选刷新后，Trime 3.3.11 可能自动重新挂载展开窗口。

已定位到 Trime 的 `InputBarDelegate.setUnrollWindowToAttach()` 与 `FlexboxUnrolledCandidateWindow` 状态机。`paging_mode: false` 和 `candidate_use_cursor: false` 均无效。主题 YAML 没有关闭当前展开窗口的 action；Lua 接管退格会改变 Rime 标准回退语义，因此不采用高风险 workaround，等待上游修复。

## 相关文件

- `moqi_xh-18key.schema.yaml`
- `shouxin_18key.trime.yaml`
- `lua/sharedkey_shuangpin_precise_input_processor.lua`
- `lua/sharedkey_shuangpin_precise_input_filter.lua`
- `Tools/deploy_android.bat`
- `Tools/init_deploy_android.bat`