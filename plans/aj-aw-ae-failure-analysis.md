# aj、aw、ae 失效问题分析报告

## 问题描述
在 `moqi_xh-18key.schema.yaml` 中，`aj`（日语输入）、`aw`（英文单词）、`ae`（Emoji）三个引导前缀全部失效，而在 `moqi_xh-weasel.schema.yaml` 中可以正常使用。

## 根本原因

### 1. **Recognizer 配置缺失**

**18键版本**（`moqi_xh-18key.schema.yaml` 第310-321行）：
```yaml
recognizer:
  patterns:
    punct:            # 禁用 / 开头的符号输入
    reverse_moqima:   # 禁用 amq 墨奇反查
    radical_flypy:    # 禁用 az 部件组字
    reverse_stroke:   # 禁用 ab 笔画反查
    reverse_cj:       # 禁用 arj 仓颉反查
    reverse_zrlf:     # 禁用 alf 自然两分
    add_user_dict:    # 禁用 ac 自造词
    emojis:           # 禁用 ae Emoji
```

**问题分析**：
- 所有 patterns 都是**空值**，意味着这些模式被**禁用**
- `emojis:` 后面没有任何正则表达式，导致 `ae` 前缀无法被识别
- 同样 `aj` 和 `aw` 也完全缺失配置

**工作版本**（`moqi_xh-weasel.schema.yaml`）：
```yaml
__include: moqi.yaml:/guide # 引导前缀配置
```

该配置引入了 `moqi.yaml` 中的完整 recognizer 配置（第321-341行）：
```yaml
recognizer:
  patterns:
    uppercase: "^[A-Z].*$"
    punct: '^/([0-9]|10|[A-z]+)$'
    reverse_moqima: "^amq[A-Za-z]*$"
    radical_flypy: "^az[a-z]*'?$"
    reverse_stroke: "^ab[A-Za-z]*$"
    reverse_cj: "^arj[A-Za-z]*$"
    reverse_zrlf: "^alf[A-Za-z]*$"
    add_user_dict: "^ac[A-Za-z]*$"
    emojis: "^ae[a-z]*'?$"        # ✅ 有效的正则表达式
    easy_en_simp: "^aw[a-z]*"     # ✅ 有效的正则表达式
    jp_sela: "^aj[a-z]*"          # ✅ 有效的正则表达式
    unicode: "^U[a-f0-9]+"
    number: "^R[0-9]+[.]?[0-9]*"
    gregorian_to_lunar: "^N[0-9]{1,8}"
```

### 2. **Segmentors 和 Translators 配置缺失**

**18键版本**的 engine 配置中：
- **缺少** `affix_segmentor@emojis`
- **缺少** `table_translator@emojis`（第70行被注释）
- 虽然有 `affix_segmentor@easy_en_simp` 和 `affix_segmentor@jp_sela`
- 但没有对应的 **tag 配置**（emojis、easy_en_simp、jp_sela）

**工作版本**引入了完整配置：
```yaml
__include: moqi.yaml:/guide # 引导前缀配置
```

包含了所有必需的 tag 配置：
- `emojis:` (第342-348行)
- `easy_en_simp:` (第350-360行)  
- `jp_sela:` (第362-372行)

## 问题总结

### 核心问题
18键版本**故意禁用**了这些功能，原因可能是：
1. 为了简化手机版配置
2. 避免与18键共键布局冲突
3. 减少不必要的功能

### 三个失效的模式

| 前缀 | 功能 | 18键版本状态 | 缺失配置 |
|------|------|--------------|----------|
| `ae` | Emoji | 禁用（空值） | recognizer pattern + segmentor + translator + tag |
| `aw` | 英文单词 | 缺失配置 | recognizer pattern + tag |
| `aj` | 日语 | 缺失配置 | recognizer pattern + tag |

## 修复方案

### 方案一：完全启用（推荐用于需要这些功能的场景）

在 [`moqi_xh-18key.schema.yaml`](moqi_xh-18key.schema.yaml:310) 的 `recognizer` 部分添加：

```yaml
recognizer:
  patterns:
    # 其他已有的禁用项...
    emojis: "^ae[a-z]*'?$"
    easy_en_simp: "^aw[a-z]*"
    jp_sela: "^aj[a-z]*"
```

**同时需要添加对应的 tag 配置**：

```yaml
# 在文件末尾或适当位置添加
emojis:
  tag: emojis
  dictionary: emoji
  enable_completion: true
  prefix: "ae"
  tips: " Emoji"

easy_en_simp:
  tag: easy_en_simp
  dictionary: easy_en
  enable_completion: true
  enable_sentence: false
  prefix: "aw"
  tips: "英文单词（可去元音）"
  spelling_hints: 9
  comment_format:
    - xform/^.+$//

jp_sela:
  tag: jp_sela
  dictionary: jp_sela
  enable_completion: true
  enable_sentence: false
  prefix: "aj"
  tips: "日语"
  spelling_hints: 9
  comment_format:
    - xform/^.+$//
```

**启用 translator**（第70行）：
```yaml
- table_translator@emojis  # 去掉注释
```

**添加 segmentor**（engine/segmentors 部分）：
```yaml
- affix_segmentor@emojis
```

### 方案二：引用共享配置（更简洁）

直接引入 `moqi.yaml` 的配置：

```yaml
# 在 recognizer 之前添加
__include: moqi.yaml:/guide
```

然后删除或注释掉原有的 recognizer 配置块。

### 方案三：保持禁用（如果这是有意为之）

如果18键版本故意禁用这些功能（例如为了避免按键冲突或简化界面），则：
- 保持现状
- 在文档中说明这是设计选择
- 提供用户自定义启用的方法

## 推荐方案

**推荐使用方案一**，原因：
1. 18键版本已经在 engine 中配置了 `easy_en_simp` 和 `jp_sela` 的 segmentor 和 translator
2. 说明开发者**原本打算支持**这些功能
3. 只是 recognizer 配置不完整导致失效
4. 补全配置即可修复，无需大改

## 相关文件位置

- 问题文件：[`moqi_xh-18key.schema.yaml`](moqi_xh-18key.schema.yaml:310-321)
- 参考文件：[`moqi_xh-weasel.schema.yaml`](moqi_xh-weasel.schema.yaml:31)
- 共享配置：[`moqi.yaml`](moqi.yaml:321-372)

## 额外发现

### 18键共键模糊冲突风险

18键版本使用了大量的共键模糊规则（第158-291行），例如：
- JK 共键：`j` 和 `k` 互相模糊
- 这可能导致 `aj` 被误解析为 `ak`

**建议**：
- 在 recognizer patterns 中使用更严格的匹配
- 确保引导前缀在 lua processor 中优先处理
- 测试 `aj`、`aw`、`ae` 是否会被共键规则干扰
