# 共键双拼辅助码方案设计

**版本**: v1.0  
**日期**: 2026-01-08  
**英文名**: sharedkey_shuangpin_auxcode

---

## 核心设计

### 输入模式

| 模式 | 格式 | 示例 | 说明 |
|------|------|------|------|
| 纯音码 | 2位一组 | `sy` | 高频词，候选20-50个 |
| 三码 | 音码2+辅助码1 | `syf` | 无需引导符，候选5-15个 |
| 四码 | 音码2+[+辅助码2 | `sy[ff` | 需引导符，候选1-5个 |
| 手动分词 | [+辅助码+' | `sy[z'xi` | 用户主动分词为两个字 |

### 关键规则

1. **无引导符**：按 `2+1` 循环解析（音码2+辅助码1）
2. **有引导符**：`[` 后贪心匹配2位辅助码
3. **共键模糊**：音码和辅助码都支持共键模糊匹配

---

## 解析示例

```
输入示例：
sy       → [sy]           纯音码
syf      → [sy+f]         三码
sy[f     → [sy+f]         引导符+1位辅助码（等待更多输入）
sy[ff    → [sy+ff]        引导符+2位辅助码
sy[z'xi  → [sy+z] [xi]    手动分词
syfui    → [sy+f] [ui]    三码+纯音码
sy[ffui  → [sy+ff] [ui]   四码+纯音码
```

---

## 共键模糊支持

18键共键对：WE, RT, IO, SD, FG, JK, XC, BN

- 音码部分：应用共键模糊
- 辅助码部分：应用共键模糊
- 精确输入：大写字母跳过模糊

---

## Schema 配置要点

### Speller Algebra

```yaml
# 纯双拼
- derive|^(.+)[[](\w)(\w)$|$1|

# 三码无引导符（音码2+辅助码1）
- derive|^(..)[[](.)(\w)$|$1$2|

# 引导符+辅助码（支持1-2位）
- derive|^(.+)[[](\w)(\w)$|$1[$2|      # 1位
- derive|^(.+)[[](\w)(\w)$|$1[$2$3|    # 2位

# 共键模糊规则（音码+辅助码）
...
```

### Engine 配置

```yaml
engine:
  processors:
    - lua_processor@*sharedkey_shuangpin_auxcode_processor
  filters:
    - lua_filter@*sharedkey_shuangpin_auxcode_filter
```

---

## 实现文件

| 文件 | 说明 |
|------|------|
| `lua/sharedkey_shuangpin_auxcode_processor.lua` | 处理器：解析输入结构 |
| `lua/sharedkey_shuangpin_auxcode_filter.lua` | 过滤器：根据辅助码过滤候选 |
| `moqi_xh-18key.schema.yaml` | Schema配置 |

---

## 设计优势

1. **日常高效**：常用字用纯音码或三码（无需引导符）
2. **精确可控**：冷门字用四码（引导符+2位辅助码）
3. **灵活分词**：用户可主动用分词符控制解析
4. **共键友好**：完全兼容共键模糊输入

---

## 相关文档

- [`plans/18key-shape-code-scheme-comparison.md`](18key-shape-code-scheme-comparison.md) - 多方案对比分析
- [`plans/moqi-xh-18key-shape-code-analysis.md`](moqi-xh-18key-shape-code-analysis.md) - 形码输入问题分析
