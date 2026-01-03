-- precise_input_filter.lua
-- 精确输入过滤器 v3：使用 ReverseLookup 获取候选的真实拼音
--
-- 使用场景：18键模糊输入时，滑动精确输入的字符应该排除模糊候选
-- 例如：用户滑动输入 E（精确），应该排除 w 的候选
--
-- 工作原理：
-- 1. 从 context.property 读取 precise_input_map（精确输入的位置）
-- 2. 使用 ReverseLookup 对候选文字进行反查，获取真实拼音
-- 3. 逐字比较拼音与用户输入，过滤不匹配的候选
--
-- 参考：lua/cold_word_drop/processor.lua 的 ReverseLookup 用法

-- 18键共键映射：模糊对关系
-- 如果用户精确输入了 e，则候选中如果是 w 就应该被过滤
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

-- 解析精确输入位置记录
local function parse_precise_map(map_str)
    local positions = {}
    if map_str and #map_str > 0 then
        for pos in string.gmatch(map_str, "(%d+)") do
            positions[tonumber(pos)] = true
        end
    end
    return positions
end

-- 检查候选是否匹配用户的精确输入
-- 参数：
--   cand_text: 候选文字（如 "你好"）
--   user_syllables: 用户输入的音节列表（如 {"ni", "hao"}）
--   precise_positions: 精确输入的位置集合（如 {1=true}）
--   reversedb: ReverseLookup 对象
-- 返回：true 表示保留，false 表示过滤
local function matches_precise_input(cand_text, user_syllables, precise_positions, reversedb)
    -- 如果没有精确输入记录，所有候选都通过
    if not precise_positions or not next(precise_positions) then
        return true
    end
    
    -- 拆分候选文字为单个字符
    local chars = split_chars(cand_text)
    
    -- 对每个精确输入位置进行检查
    for pos, _ in pairs(precise_positions) do
        -- 获取用户在这个位置输入的音节
        local user_syllable = user_syllables[pos]
        if not user_syllable then
            goto continue
        end
        
        -- 获取用户输入的首字母
        local user_char = user_syllable:sub(1, 1)
        
        -- 获取对应位置的候选字
        local cand_char = chars[pos]
        if not cand_char then
            goto continue
        end
        
        -- 对候选字进行反查，获取其拼音
        local cand_pinyin = reversedb:lookup(cand_char) or ""
        
        -- 反查结果可能包含多个读音（空格分隔），取第一个
        local cand_first_pinyin = cand_pinyin:match("^([^ ]+)")
        if not cand_first_pinyin then
            goto continue
        end
        
        -- 获取候选拼音的首字母
        local cand_first_char = cand_first_pinyin:sub(1, 1):lower()
        
        -- 检查是否匹配
        if user_char ~= cand_first_char then
            -- 不直接匹配，检查是否是模糊对
            local fuzzy_match = fuzzy_pairs[user_char]
            if fuzzy_match and fuzzy_match == cand_first_char then
                -- 用户精确输入了 e，但候选是 w 的读音，过滤掉
                return false
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
    
    -- 解析用户输入的音节（使用 preedit 或直接分割）
    local preedit = context:get_script_text() or user_input
    local user_syllables = split_syllables(preedit)
    
    -- 如果无法解析音节，使用字符级别解析
    if #user_syllables == 0 then
        for i = 1, #user_input, 2 do
            local syllable = user_input:sub(i, i + 1)
            table.insert(user_syllables, syllable:lower())
        end
    end
    
    -- 过滤候选
    for cand in input:iter() do
        if matches_precise_input(cand.text, user_syllables, precise_positions, reversedb) then
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        -- 被过滤的候选不 yield
    end
end

return filter
