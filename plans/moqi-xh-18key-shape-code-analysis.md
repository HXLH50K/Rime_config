# 墨奇18键形码输入问题分析报告

## 问题描述

在没有输入引导符 `[` 的情况下，三码形码仍然能够被触发。例如：输入 `uio` 会被解析成"时"字。

## 根本原因分析

### 1. 发现的问题源头

通过分析配置文件和词典，发现了问题的根本原因：

#### **custom_phrase/custom_phrase_3_code.txt 中存在无引导符的三码条目**

在 [`custom_phrase/custom_phrase_3_code.txt`](custom_phrase/custom_phrase_3_code.txt:6) 文件的第6行发现：

```
时	uio
```

这个条目直接将 `uio` 映射到"时"字，**没有使用 `[` 引导符**。

#### **词典配置在 schema 中被加载**

在 [`moqi_xh-18key.schema.yaml`](moqi_xh-18key.schema.yaml:290-296) 中：

```yaml
custom_phrase_3_code:
  dictionary: ""
  user_dict: custom_phrase/custom_phrase_3_code
  db_class: stabledb
  enable_sentence: false
  enable_completion: false
  initial_quality: 1
```

这个翻译器在 [`engine/translators`](moqi_xh-18key.schema.yaml:83) 中被引用：

```yaml
translators:
  # 码表翻译器
  - table_translator@custom_phrase_3_code
```

### 2. 设计意图 vs 实际行为

#### 设计意图（从注释推断）
- 形码应该使用 `[` 作为引导符（如注释所述："点击[进入形码"）
- Speller 的 algebra 规则设计用于处理带 `[` 的编码

#### 实际行为
- `custom_phrase_3_code.txt` 中的条目**绕过了** speller 的 algebra 规则
- 这些条目直接映射三字母编码到汉字，无需引导符
- 导致与设计意图不符的行为

### 3. Speller Algebra 规则分析

在 [`moqi_xh-18key.schema.yaml`](moqi_xh-18key.schema.yaml:131-136) 的 algebra 规则中：

```yaml
algebra:
  # ========== 辅助码处理规则 ==========
  # 必须使用 [ 引导符才能输入形码，禁用直接输入形码
  - derive|^(.+)[[](\w)(\w)$|$1|              # 纯双拼
  - derive|^(.+)[[](\w)(\w)$|$1[$2|           # 双拼+[+1位辅助码
  - derive|^(.+)[[](\w)(\w)$|$1[$2$3|         # 双拼+[+2位辅助码
```

这些规则**仅处理来自主词典的条目**（如 `cn_dicts_moqi/8105.dict.yaml` 中的 `时	ui[oc`），将其转换为：
- `ui` （纯双拼）
- `ui[o` （双拼+[+1位辅助码）
- `ui[oc` （双拼+[+2位辅助码）

但是，**custom_phrase 作为独立的 table_translator，不经过 speller 的 algebra 处理**。

## 问题影响

### 冲突示例

1. **主词典条目**：`时	ui[oc` （需要引导符）
2. **Custom phrase 条目**：`时	uio` （无需引导符）

当用户输入 `uio` 时：
- 本应触发18键共键模糊（`i` ↔ `o`），匹配到其他字词
- 但 `custom_phrase_3_code` 直接匹配 `uio` → "时"
- 绕过了引导符设计

### 与18键共键模糊的冲突

18键共键对包括 `io` 共键，在 [`speller/algebra`](moqi_xh-18key.schema.yaml:158-160) 中定义：

```yaml
# IO 共键
- derive/^i([a-z])/o$1/
- derive/^o([a-z])/i$1/
```

这意味着 `uio` 可能是：
- `uoo`（时）的模糊输入
- `uii`（式）的模糊输入
- 或其他组合

但 custom_phrase 的直接匹配会干扰这种设计。

## 解决方案（仅修改 Schema）

由于只能修改 [`moqi_xh-18key.schema.yaml`](moqi_xh-18key.schema.yaml)，以下是可行的 schema 级别解决方案：

### 方案1：完全禁用 custom_phrase_3_code 翻译器（最简单）

**操作**：从 [`engine/translators`](moqi_xh-18key.schema.yaml:83) 中移除或注释掉 `table_translator@custom_phrase_3_code`

```yaml
translators:
  # lua翻译器
  - lua_translator@*date_translator
  - lua_translator@*lunar
  - lua_translator@*unicode
  - lua_translator@*number_translator
  - lua_translator@*calculator
  - punct_translator
  # 码表翻译器
  # - table_translator@custom_phrase_3_code  # 已禁用：与引导符设计冲突
  - table_translator@custom_phrase_kf
  - table_translator@custom_phrase_mqzg
  - table_translator@big_char_set
  - table_translator@easy_en_simp
  - table_translator@jp_sela
  # 脚本翻译器
  - script_translator
  - script_translator@user_dict_set
```

**同时删除或注释配置块**：

```yaml
# 3码出简让全（已禁用）
# custom_phrase_3_code:
#   dictionary: ""
#   user_dict: custom_phrase/custom_phrase_3_code
#   db_class: stabledb
#   enable_sentence: false
#   enable_completion: false
#   initial_quality: 1
```

**优点**：
- 立即解决问题
- 简单直接，无副作用
- 防止未来类似问题

**缺点**：
- 失去 custom_phrase_3_code 提供的所有三码简化输入
- 用户需要使用完整的引导符输入

### 方案2：大幅降低 custom_phrase_3_code 的优先级

**操作**：修改 [`custom_phrase_3_code`](moqi_xh-18key.schema.yaml:290-296) 的 `initial_quality` 为负值

```yaml
custom_phrase_3_code:
  dictionary: ""
  user_dict: custom_phrase/custom_phrase_3_code
  db_class: stabledb
  enable_sentence: false
  enable_completion: false
  initial_quality: -10  # 改为负值，降低优先级
```

**优点**：
- 保留功能，但降低干扰
- 主词典和其他翻译器的结果优先显示
- 用户仍可在候选列表后面找到三码条目

**缺点**：
- 不能完全解决问题，只是降低影响
- 仍然违反"必须使用引导符"的设计原则
- `uio` 仍会出现"时"，只是排在后面

### 方案3：调整翻译器顺序

**操作**：将 `table_translator@custom_phrase_3_code` 移到翻译器列表末尾

```yaml
translators:
  # lua翻译器
  - lua_translator@*date_translator
  - lua_translator@*lunar
  - lua_translator@*unicode
  - lua_translator@*number_translator
  - lua_translator@*calculator
  - punct_translator
  # 码表翻译器
  - table_translator@custom_phrase_kf
  - table_translator@custom_phrase_mqzg
  - table_translator@big_char_set
  - table_translator@easy_en_simp
  - table_translator@jp_sela
  # 脚本翻译器
  - script_translator
  - script_translator@user_dict_set
  # 三码简化（低优先级）
  - table_translator@custom_phrase_3_code
```

**优点**：
- 其他翻译器优先处理
- 减少干扰

**缺点**：
- 效果有限，仍会出现在候选中
- 不能根本解决设计冲突

### 方案4：使用 Lua 过滤器过滤掉三字母无引导符的结果（高级）

**操作**：创建一个 Lua 过滤器，过滤掉来自 `custom_phrase_3_code` 的三字母无引导符匹配

在 schema 中添加：

```yaml
engine:
  filters:
    # ... 其他过滤器 ...
    - lua_filter@*filter_3code_without_prefix  # 过滤无引导符的三码
    - uniquifier
```

**需要创建对应的 Lua 脚本**（但这超出了"仅修改 schema"的范围）

**优点**：
- 可以精确控制过滤逻辑
- 保留其他 custom_phrase_3_code 功能

**缺点**：
- 需要编写 Lua 代码
- 复杂度高
- 超出仅修改 schema 的限制

## 推荐方案（仅限 Schema 修改）

### 首选：方案1（完全禁用 custom_phrase_3_code）

这是在"仅修改 schema"限制下最彻底、最符合设计意图的解决方案：

1. **立即生效**：注释掉翻译器后，`uio` 不再匹配"时"
2. **符合设计**：强制使用引导符 `[` 输入形码
3. **无副作用**：不会引入新的问题或复杂性

### 备选：方案2（降低优先级）

如果需要保留 custom_phrase_3_code 的部分功能：

1. **设置 `initial_quality: -10`**
2. **将翻译器移到列表末尾**
3. **结合两种方法降低影响**

## 实施步骤

### 方案1的实施步骤

1. 在 [`moqi_xh-18key.schema.yaml`](moqi_xh-18key.schema.yaml:83) 中注释翻译器引用
2. 在 [`moqi_xh-18key.schema.yaml`](moqi_xh-18key.schema.yaml:290-296) 中注释配置块
3. 重新部署 Rime 配置
4. 测试验证：
   - 输入 `uio` 不再直接出现"时"
   - 输入 `ui[o` 或完整编码能正确工作
   - 18键共键模糊功能正常

### 方案2的实施步骤

1. 修改 `initial_quality: -10`
2. 调整翻译器顺序
3. 重新部署
4. 测试验证候选顺序

## 设计建议

如果未来可以修改 custom_phrase 文件，建议：

1. **统一编码格式**：所有形码使用 `[` 引导符
2. **清晰分离**：
   - 音码（双拼）条目 → 其他 custom_phrase 文件
   - 形码条目 → 必须使用引导符格式
3. **文档化**：明确说明编码规则和引导符使用

## 附录：配置位置参考

| 配置项 | 文件 | 行号 |
|--------|------|------|
| 形码引导符说明 | moqi_xh-18key.schema.yaml | 5, 17 |
| Speller alphabet | moqi_xh-18key.schema.yaml | 127 |
| Algebra 规则 | moqi_xh-18key.schema.yaml | 131-256 |
| Custom phrase 配置 | moqi_xh-18key.schema.yaml | 290-296 |
| Translators 引用 | moqi_xh-18key.schema.yaml | 83 |
| 问题条目示例 | custom_phrase/custom_phrase_3_code.txt | 6 |
| 主词典示例 | cn_dicts_moqi/8105.dict.yaml | 5624 |

## 结论

在"仅修改 schema"的约束下，**推荐完全禁用 `custom_phrase_3_code` 翻译器**（方案1），这是最符合设计意图且无副作用的解决方案。这将确保所有形码输入必须使用引导符 `[`，与设计文档描述一致，并避免与18键共键模糊功能冲突。
