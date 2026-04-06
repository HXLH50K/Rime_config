# TODO: 特殊字符模糊映射方案

## 目标

解决18键共键输入中popup精确输入被模糊处理的问题。

## 方案概述

使用特殊字符（Unicode或ASCII）作为共键模糊输入的标记，与普通字母区分：
- 特殊字符（如 ω 或 ~）= 模糊输入
- 普通字母（小写）= 精确输入（从popup选择）
- 大写字母 = 精确输入（滑动输入）

## 核心思想

```
点击WE键 → 发送特殊字符 → Speller展开为w和e → 模糊匹配
Popup选w → 发送小写w → 精确匹配w
Popup选W → 发送大写W → 精确匹配w（大写标记）
```

## 技术方案

### 方案A：Unicode字符（理想但可能不可行）

**字符映射表：**
| 共键 | Unicode字符 | 码点 | 形似原因 |
|------|-------------|------|----------|
| WE | ω (omega) | U+03C9 | 形似w |
| RT | ρ (rho) | U+03C1 | 形似r |
| IO | ο (omicron) | U+03BF | 形似o |
| SD | δ (delta) | U+03B4 | 形似d |
| FG | φ (phi) | U+03C6 | 形似f |
| JK | κ (kappa) | U+03BA | 形似k |
| XC | ξ (xi) | U+03BE | 形似x |
| BN | η (eta) | U+03B7 | 形似n |

**实现：**
```yaml
# shouxin_18key.trime.yaml
key_WE:
  send: "ω"

# moqi_xh-18key.schema.yaml
alphabet: "...ω"
algebra:
  - derive/^ω/w/
  - derive/^ω/e/
  - derive/([a-z])ω/$1w/
  - derive/([a-z])ω/$1e/
```

**问题：**
- ❌ Trime可能不支持发送Unicode字符
- ❌ 显示依赖字体支持
- ❌ 输入框显示不直观

### 方案B：ASCII特殊字符（可行但占用符号）

**字符映射表：**
| 共键 | ASCII字符 | 备选 |
|------|-----------|------|
| WE | ~ | ` |
| RT | ` | @ |
| IO | @ | # |
| SD | # | $ |
| FG | $ | % |
| JK | % | & |
| XC | & | * |
| BN | * | = |

**实现：**
```yaml
# shouxin_18key.trime.yaml
key_WE:
  send: "~"

# moqi_xh-18key.schema.yaml
alphabet: "...~"
algebra:
  - derive/^~/w/
  - derive/^~/e/
  - derive/([a-z])~/$1w/
  - derive/([a-z])~/$1e/
```

**优点：**
- ✅ 100%兼容ASCII
- ✅ 单字符编码
- ✅ 无字体依赖

**缺点：**
- ⚠️ 特殊字符可能与其他功能冲突
- ⚠️ 显示不直观（~不如ω）
- ⚠️ 需要检查每个字符是否已被占用

### 方案C：双字符组合（最可靠但效率低）

**字符映射表：**
| 共键 | 组合字符 | 说明 |
|------|----------|------|
| WE | 0w | 0+字母表示模糊 |
| RT | 0r | |
| IO | 0i | |
| SD | 0s | |
| FG | 0f | |
| JK | 0j | |
| XC | 0x | |
| BN | 0b | |

**实现：**
```yaml
# shouxin_18key.trime.yaml
key_WE:
  send: "0w"

# moqi_xh-18key.schema.yaml
algebra:
  - derive/^0w/w/
  - derive/^0w/e/
  - derive/([a-z])0w/$1w/
  - derive/([a-z])0w/$1e/
```

**优点：**
- ✅ 完全可靠
- ✅ 无冲突风险

**缺点：**
- ❌ 占用2个字符位置
- ❌ 降低输入效率

## 测试结果

### 已测试方案

| 方案 | 字符 | 结果 | 问题 |
|------|------|------|------|
| Unicode | ω | ❌ 失败 | 无法解析出候选 |
| ASCII | ~ | ⚠️ 未测试 | 用户放弃 |

### 失败原因分析

**ω字符失败的可能原因：**
1. Trime的 `send` 不支持UTF-8字符
2. Trime在发送前过滤非ASCII字符
3. Rime的alphabet不能正确处理UTF-8
4. 正则表达式不支持Unicode字符类

**需要深入调查：**
- [ ] Trime源代码中send的实现
- [ ] 使用commit代替send是否可行
- [ ] Rime对Unicode的正式支持文档
- [ ] 其他输入方案是否有Unicode使用案例

## 待验证事项

### Trime层面
- [ ] `send` vs `commit` vs `label` 对Unicode的支持
- [ ] Trime是否有配置项启用Unicode支持
- [ ] 查看Trime日志确认发送的字符
- [ ] 在非Rime环境测试Trime是否能发送Unicode

### Rime层面
- [ ] alphabet是否支持UTF-8字符
- [ ] initials是否支持UTF-8字符
- [ ] derive正则是否支持Unicode字符类
- [ ] 使用librime调试工具测试Unicode输入

### 显示层面
- [ ] 添加preedit_format转换显示
- [ ] 测试不同Android版本的字体支持
- [ ] 优化输入框显示体验

## 参考资料

### 分析文档
- `plans/special-character-fuzzy-mapping.md` - 完整技术分析
- `plans/shared-key-combination-key-analysis.md` - 方案对比
- `plans/omega-troubleshooting.md` - 故障排查

### 相关配置
- `shouxin_18key.trime.yaml:950` - 键盘配置
- `moqi_xh-18key.schema.yaml:122` - Schema配置
- `lua/sharedkey_shuangpin_precise_input_processor.lua` - 精确输入处理器
