# 共键双拼辅助码 Bug 分析报告

**日期**: 2026-01-08  
**问题**: 输入超过2个字母只能解析一个字

---

## 问题根因

### 设计意图 vs 实际行为

根据 [设计文档](plans/sharedkey-shuangpin-auxcode-design.md)，三码模式的解析规则是：

```
syfui → [sy+f] [ui]    三码+纯音码（两个字）
```

但实际上 `parse_without_bracket()` 函数的行为是：

```
syfui → [sy+f] [ui]    ❌ 实际没问题
wiaib → [wi+a] [ib]    ❌ 问题在这里！
```

### Bug 位置

[`lua/sharedkey_shuangpin_auxcode_filter.lua`](lua/sharedkey_shuangpin_auxcode_filter.lua:86-128) 的 `parse_without_bracket()` 函数：

```lua
-- 第108-121行
if i <= len then
    local third = input:sub(i, i)
    if third:match("[a-z]") then
        -- 后面还有字符，判断这是辅助码还是新音码
        if i + 1 <= len then
            -- 后面还有2位以上，这个是辅助码
            segment.shape = third
            i = i + 1
        elseif i == len then
            -- 这是最后一位，作为辅助码
            segment.shape = third
            i = i + 1
        end
    end
end
```

### 问题分析

输入 `wiaib`（5个字母）：

| 步骤 | 变量值 | 操作 |
|------|--------|------|
| 1 | i=1, len=5 | 读取 `wi` 作为音码，i=3 |
| 2 | i=3, i+1=4 <= 5 | 第3位 `a` 是辅助码，i=4 |
| 3 | i=4, len=5 | 读取 `ib` 作为音码，i=6 |
| 结果 | | `[{wi,a}, {ib,}]` - 两个 segment |

**问题**：第二个 segment `{pinyin="ib"}` 不是有效的双拼编码！

- `ib` 不是任何汉字的双拼
- 用户实际想输入的可能是：`wi+a` + `ib` 两个字，或者 `wiai` + `b` 等组合

### 根本设计缺陷

三码模式的 `2+1` 循环解析存在歧义：

| 输入 | 解析方式1 | 解析方式2 | 解析方式3 |
|------|-----------|-----------|-----------|
| `wiaib` | `[wi+a][ib]` | `[wi+a][i...]`+`b` | `[wi][aib...]` |

**无法确定用户意图**，因为：
1. 第3位可能是辅助码，也可能是下一个字的声母
2. 没有分隔符，无法区分

---

## 解决方案

### 方案 A：禁用三码模式（临时方案，已实施）

删除 processor 和 filter，使用 custom.yaml 覆盖。

**优点**：简单可靠  
**缺点**：失去三码输入功能

### 方案 B：只对首字启用三码（推荐）

修改解析逻辑：
- 只有第一个字支持三码（无引导符辅助码）
- 后续字必须用引导符 `[` 来添加辅助码

```lua
-- 修改后的解析逻辑
local function parse_without_bracket(input)
    local segments = {}
    local i = 1
    local len = #input
    local is_first = true  -- 是否是第一个 segment
    
    while i <= len do
        local segment = { pinyin = "", shape = "" }
        
        -- 读取2位音码
        if i + 1 <= len then
            segment.pinyin = input:sub(i, i + 1)
            i = i + 2
        else
            segment.pinyin = input:sub(i)
            segment.incomplete = true
            i = len + 1
            table.insert(segments, segment)
            break
        end
        
        -- 只有第一个字才检查第3位辅助码
        if is_first and i <= len then
            local third = input:sub(i, i)
            if third:match("[a-z]") then
                segment.shape = third
                i = i + 1
            end
            is_first = false
        end
        
        table.insert(segments, segment)
    end
    
    return segments
end
```

**效果**：
- `wia` → `[wi+a]` ✅ 首字三码
- `wiaib` → `[wi+a][ib]` → ❌ 第二字 `ib` 不是有效双拼
- `wiab` → `[wi+a][b...]` → ⚠️ 第二字不完整

### 方案 C：智能分词（复杂）

根据双拼有效性来判断分词：

```lua
-- 检查是否是有效的双拼
local function is_valid_shuangpin(code)
    local valid_initials = "bpmfdtnlgkhjqxzcsryw"
    local valid_finals = "aoeiu"  -- 简化
    if #code ~= 2 then return false end
    local initial = code:sub(1, 1)
    -- ... 复杂的验证逻辑
end

-- 智能分词：回溯找最优解析
local function parse_smart(input)
    -- 尝试不同的分词方案
    -- 选择产生最多有效双拼的方案
end
```

**优点**：更智能  
**缺点**：复杂、性能开销大

### 方案 D：强制引导符（最简单）

完全禁用三码模式，所有辅助码都必须用 `[` 引导：

```yaml
# schema 配置
sharedkey_shuangpin_auxcode:
  three_code_enabled: false  # 禁用三码
```

**效果**：
- `wia` → `[wi][a...]` 纯音码，第二字不完整
- `wi[a` → `[wi+a]` 需要引导符
- `wi[aui` → `[wi+a][ui]` 正确

---

## 推荐方案

**方案 D（强制引导符）** + **精确输入结合**

理由：
1. 避免歧义，用户意图明确
2. 实现简单，不易出错
3. 可以通过精确输入（大写字母）来区分共键

修改 `parse_without_bracket()` 为只解析纯双拼（每2位一组），不处理辅助码。辅助码完全由 `[` 引导的模式处理。

---

## 下一步行动

1. 确认采用哪个方案
2. 修改 Lua 脚本
3. 更新 schema 配置
4. 测试验证

