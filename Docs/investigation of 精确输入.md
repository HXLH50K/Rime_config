# 精确输入 - 纯 Lua 方案分析

## 问题回顾

之前的方案失败原因：
1. **speller/algebra 模糊规则在部署时已生效**：无论 Processor 做什么处理，模糊规则已经在 speller 层面应用
2. **Filter 无法准确获取候选的原始拼音**：`cand.preedit` 可能已经被处理过

## 新方案：移除 speller 模糊规则，使用 Lua Translator

### 核心思路

1. **移除 speller/algebra 的模糊规则**：不在 speller 层面做模糊匹配
2. **使用 Lua Translator 实现动态模糊**：
   - 点击共键（发送小写字母）：查询原字母 + 模糊对的候选
   - 滑动共键（发送大写字母）：只查询精确字母的候选

### 技术实现

#### API 参考（来自 sbxlm/lib.lua 和 sbxlm/hint.lua）

```lua
-- 创建 Memory 对象
local memory = rime.Memory(env.engine, env.engine.schema)

-- 查询词典
memory:dict_lookup(input_code, predictive, limit)
-- input_code: 查询的拼音编码，如 "ni", "hao"
-- predictive: 是否前缀匹配
-- limit: 返回候选数量限制

-- 遍历结果
for entry in memory:iter_dict() do
    -- entry.text: 候选文字
    -- entry.comment: 注释
    -- entry.weight: 权重
end

-- 创建候选
local phrase = rime.Phrase(memory, "table", segment.start, segment._end, entry)
local cand = phrase:toCandidate()
yield(cand)
```

### 方案设计

```
用户按键
    ↓
键盘发送字符
    ├── 小写字母（点击）：Translator 查询 原字母 + 模糊对
    └── 大写字母（滑动）：Processor 转小写 + 标记精确，Translator 只查询精确字母
    ↓
Lua Translator（替代 script_translator）
    ├── 读取输入和精确标记
    ├── 为每个音节确定查询策略
    ├── 调用 Memory:dict_lookup() 查询词典
    └── 合并候选结果
    ↓
返回候选列表
```

### 实现方案

#### 方案 A：完全自定义 Translator（复杂度高）

完全替换 `script_translator`，自己实现：
- 输入切分
- 词典查询
- 模糊匹配
- 候选排序

**问题**：需要重新实现整个拼音输入逻辑，工作量巨大

#### 方案 B：Processor + Filter（当前方案优化）

保持 speller 模糊规则，但在 Filter 层面准确过滤：
- **问题**：Filter 无法获取候选的原始拼音

**优化思路**：使用反查（ReverseLookup）获取候选文字的拼音，然后比较

```lua
local reversedb = ReverseLookup(schema_id)
local cand_pinyin = reversedb:lookup(cand.text)
-- cand_pinyin 返回 "ni hao" 格式的拼音
```

#### 方案 C：双查询合并（推荐）

不修改 speller 模糊规则，而是：
1. Processor 拦截小写字母，发送两个查询（原字母 + 模糊对）
2. 或者在 Filter 层面使用反查验证

**实现细节**：
1. 获取候选的原始拼音（通过 ReverseLookup）
2. 检查每个音节是否与用户输入匹配
3. 如果是精确输入位置，过滤不匹配的候选

### 推荐方案：优化 Filter 使用 ReverseLookup

```lua
-- 在 Filter 中：
local rime = require "sbxlm.lib"
local reversedb = ReverseLookup(schema_id)

local function filter(input, env)
    local context = env.engine.context
    local user_input = context.input
    local precise_map = context:get_property("precise_input_map")
    
    for cand in input:iter() do
        -- 获取候选的真实拼音
        local cand_pinyin = reversedb:lookup(cand.text)
        
        -- 检查是否匹配
        if matches(cand_pinyin, user_input, precise_map) then
            yield(cand)
        end
    end
end
```

### 下一步

1. 修改 Filter 使用 ReverseLookup 获取候选拼音
2. 实现精确匹配逻辑
3. 测试验证
