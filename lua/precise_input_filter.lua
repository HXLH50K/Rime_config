-- precise_input_filter.lua
-- 精确输入过滤器 v4：修复混合输入问题
--
-- 使用场景：18键模糊输入时，滑动精确输入的字符应该排除模糊候选
-- 
-- 问题场景：
--   用户在 WE 键上：点击(w) + 滑动(E) = 输入 "we"
--   - 第1个字符是模糊输入，应匹配 w 或 e
--   - 第2个字符是精确输入，应只匹配 e
--   - 候选 "we" 中，第2字符是 e，匹配精确输入 ✓
--   - 候选 "ww" 中，第2字符是 w，不匹配精确输入 ✗
--
-- 核心逻辑：
--   对于每个精确输入位置，候选在该位置的字母必须与用户输入完全匹配
--   对于模糊输入位置，候选可以是该位置的字母或其模糊对
--
-- 参考：lua/cold_word_drop/processor.lua 的 ReverseLookup 用法

-- 18键共键映射：模糊对关系
local fuzzy_pairs = {
    w = "e", e = "w",  -- WE 共键
    r = "t", t = "r",  -- RT 共键
    i = "o", o = "i",  -- IO 共键
    s = "d", d = "s",  -- SD 共键
    f = "g", g = "f",  -- FG 共键
    j = "k", k = "j",  -- JK 共键
    x = "c", c = "x",  -- XC 共键
    b = "n", n = "b",  -- BN 共键
}

-- 将字符串按空格分割为音节列表
local function split_syllables(preedit)
    local syllables = {}
    for syllable in string.gmatch(preedit, "[^ ]+") do
        table.insert(syllables, syllable:lower())
    end
    return syllables
end

-- 将字符串拆分为单个字符
local function split_chars(str)
    local chars = {}
    for _, code in utf8.codes(str) do
        table.insert(chars, utf8.char(code))
    end
    return chars
end

-- 解析精确输入位置记录（字符级别）
local function parse_precise_map(map_str)
    local positions = {}
    if map_str and #map_str > 0 then
        for pos in string.gmatch(map_str, "(%d+)") do
            positions[tonumber(pos)] = true
        end
    end
    return positions
end

-- 检查候选是否匹配用户的输入（考虑精确和模糊）
-- 参数：
--   cand_text: 候选文字（如 "你好"）
--   user_input: 用户输入的原始字符串（如 "niho"）
--   precise_positions: 精确输入的字符位置集合（如 {2=true, 4=true}）
--   reversedb: ReverseLookup 对象
-- 返回：true 表示保留，false 表示过滤
local function matches_input(cand_text, user_input, precise_positions, reversedb)
    -- 如果没有精确输入记录，所有候选都通过
    if not precise_positions or not next(precise_positions) then
        return true
    end
    
    -- 拆分候选文字为单个字符
    local cand_chars = split_chars(cand_text)
    
    -- 对候选的每个字进行反查，获取其拼音
    local cand_pinyins = {}
    for i, char in ipairs(cand_chars) do
        local pinyin = reversedb:lookup(char) or ""
        -- 反查结果可能包含多个读音（空格分隔）
        -- 例如 "ni hao" 或 "ni[jj hao[jw"（带辅助码）
        -- 取第一个读音
        local first_pinyin = pinyin:match("^([^%s%[]+)")
        cand_pinyins[i] = first_pinyin and first_pinyin:lower() or ""
    end
    
    -- 将用户输入拆分为双拼音节（每2个字符一个音节）
    local user_syllables = {}
    for i = 1, #user_input, 2 do
        local syllable = user_input:sub(i, math.min(i + 1, #user_input)):lower()
        table.insert(user_syllables, syllable)
    end
    
    -- 检查每个候选字的拼音是否匹配
    for pos, cand_pinyin in pairs(cand_pinyins) do
        local user_syllable = user_syllables[pos]
        if not user_syllable or #user_syllable < 2 then
            goto continue
        end
        if not cand_pinyin or #cand_pinyin < 2 then
            goto continue
        end
        
        -- 获取用户输入和候选拼音的双拼码
        local user_char1 = user_syllable:sub(1, 1)
        local user_char2 = user_syllable:sub(2, 2)
        local cand_char1 = cand_pinyin:sub(1, 1)
        local cand_char2 = cand_pinyin:sub(2, 2)
        
        -- 计算字符在原始输入中的位置
        local char_pos1 = (pos - 1) * 2 + 1
        local char_pos2 = (pos - 1) * 2 + 2
        
        -- 检查第1个字符
        if precise_positions[char_pos1] then
            -- 精确输入位置：必须完全匹配
            if user_char1 ~= cand_char1 then
                return false  -- 精确输入不匹配，过滤
            end
        else
            -- 模糊输入位置：可以匹配原字符或模糊对
            if user_char1 ~= cand_char1 then
                local fuzzy = fuzzy_pairs[user_char1]
                if not fuzzy or fuzzy ~= cand_char1 then
                    -- 既不是原字符也不是模糊对，但这种情况应该由 speller 处理
                    -- 这里不过滤，让 speller 的结果通过
                end
            end
        end
        
        -- 检查第2个字符
        if precise_positions[char_pos2] then
            -- 精确输入位置：必须完全匹配
            if user_char2 ~= cand_char2 then
                return false  -- 精确输入不匹配，过滤
            end
        else
            -- 模糊输入位置：可以匹配原字符或模糊对
            if user_char2 ~= cand_char2 then
                local fuzzy = fuzzy_pairs[user_char2]
                if not fuzzy or fuzzy ~= cand_char2 then
                    -- 既不是原字符也不是模糊对，但这种情况应该由 speller 处理
                    -- 这里不过滤，让 speller 的结果通过
                end
            end
        end
        
        ::continue::
    end
    
    return true  -- 通过所有检查，保留候选
end

-- 初始化函数：创建 ReverseLookup 对象
local reversedb = nil
local function init(env)
    local config = env.engine.schema.config
    local schema_id = config:get_string("translator/dictionary")
    if not schema_id then
        schema_id = env.engine.schema.schema_id
    end
    ---@diagnostic disable-next-line: undefined-global
    reversedb = ReverseLookup(schema_id)
end

-- 过滤函数
local function filter(input, env)
    -- 延迟初始化 reversedb
    if not reversedb then
        init(env)
    end
    
    local context = env.engine.context
    local user_input = context.input or ""
    
    -- 获取精确输入记录
    local precise_map_str = context:get_property("precise_input_map") or ""
    local precise_positions = parse_precise_map(precise_map_str)
    
    -- 如果没有精确输入记录，直接输出所有候选
    if not next(precise_positions) then
        for cand in input:iter() do
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        return
    end
    
    -- 过滤候选
    for cand in input:iter() do
        if matches_input(cand.text, user_input, precise_positions, reversedb) then
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        -- 被过滤的候选不 yield
    end
end

return filter
