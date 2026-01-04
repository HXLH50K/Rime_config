-- precise_input_filter.lua
-- 精确输入过滤器 v6：性能优化版
--
-- 优化点：
-- 1. 添加反查结果缓存，避免重复反查同一个字
-- 2. 只处理前 MAX_CANDIDATES 个候选，后面的直接通过
-- 3. 减少不必要的字符串操作
-- 4. 提前退出：没有精确输入时直接返回

-- 默认的18键共键映射
local default_fuzzy_pairs = {
    w = "e", e = "w",  -- WE 共键
    r = "t", t = "r",  -- RT 共键
    i = "o", o = "i",  -- IO 共键
    s = "d", d = "s",  -- SD 共键
    f = "g", g = "f",  -- FG 共键
    j = "k", k = "j",  -- JK 共键
    x = "c", c = "x",  -- XC 共键
    b = "n", n = "b",  -- BN 共键
}

-- 配置
local MAX_CANDIDATES = 50  -- 只处理前50个候选，提升性能
local fuzzy_pairs = default_fuzzy_pairs
local reversedb = nil
local lookup_cache = {}  -- 反查缓存

-- 从配置文件加载模糊对（简化版）
local function load_fuzzy_pairs(config)
    local pairs_list = config:get_list("precise_input/fuzzy_pairs")
    if pairs_list and pairs_list.size > 0 then
        fuzzy_pairs = {}
        for i = 0, pairs_list.size - 1 do
            local pair_str = pairs_list:get_value_at(i):get_string()
            if pair_str and #pair_str >= 2 then
                local c1, c2 = pair_str:sub(1, 1):lower(), pair_str:sub(2, 2):lower()
                fuzzy_pairs[c1] = c2
                fuzzy_pairs[c2] = c1
            end
        end
    end
end

-- 带缓存的反查（核心性能优化）
local function cached_lookup(char)
    local cached = lookup_cache[char]
    if cached ~= nil then
        return cached
    end
    
    local result = reversedb:lookup(char) or ""
    -- 只取第一个拼音，去掉辅助码
    local first = result:match("^([^%s%[]+)")
    local pinyin = first and first:lower() or ""
    
    lookup_cache[char] = pinyin
    return pinyin
end

-- 解析精确输入位置
local function parse_precise_map(map_str)
    if not map_str or #map_str == 0 then
        return nil
    end
    local positions = {}
    for pos in map_str:gmatch("(%d+)") do
        positions[tonumber(pos)] = true
    end
    return next(positions) and positions or nil
end

-- 简化版 UTF-8 字符遍历
local function each_char(str)
    local i = 1
    return function()
        if i > #str then return nil end
        local b = str:byte(i)
        local len = b < 128 and 1 or b < 224 and 2 or b < 240 and 3 or 4
        local char = str:sub(i, i + len - 1)
        i = i + len
        return char
    end
end

-- 检查候选是否匹配（优化版）
local function matches_input(cand_text, user_input, precise_positions)
    local char_index = 0
    
    for char in each_char(cand_text) do
        char_index = char_index + 1
        local syllable_start = (char_index - 1) * 2 + 1
        local syllable_end = syllable_start + 1
        
        -- 检查这个字的声母/韵母位置是否有精确输入
        local need_check1 = precise_positions[syllable_start]
        local need_check2 = precise_positions[syllable_end]
        
        if not need_check1 and not need_check2 then
            goto next_char
        end
        
        -- 只有需要检查时才反查
        local cand_pinyin = cached_lookup(char)
        if #cand_pinyin < 2 then
            goto next_char
        end
        
        local user_c1 = user_input:sub(syllable_start, syllable_start):lower()
        local user_c2 = user_input:sub(syllable_end, syllable_end):lower()
        local cand_c1 = cand_pinyin:sub(1, 1)
        local cand_c2 = cand_pinyin:sub(2, 2)
        
        -- 检查声母（精确匹配）
        if need_check1 and user_c1 ~= cand_c1 then
            return false
        end
        
        -- 检查韵母（精确匹配）
        if need_check2 and user_c2 ~= cand_c2 then
            return false
        end
        
        ::next_char::
    end
    
    return true
end

-- 初始化
local function init(env)
    local config = env.engine.schema.config
    local dict = config:get_string("translator/dictionary") or env.engine.schema.schema_id
    ---@diagnostic disable-next-line: undefined-global
    reversedb = ReverseLookup(dict)
    load_fuzzy_pairs(config)
end

-- 过滤函数（性能优化版）
local function filter(input, env)
    -- 延迟初始化
    if not reversedb then
        init(env)
    end
    
    local context = env.engine.context
    local precise_map = context:get_property("precise_input_map") or ""
    local precise_positions = parse_precise_map(precise_map)
    
    -- 快速路径：没有精确输入，直接返回所有候选
    if not precise_positions then
        for cand in input:iter() do
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        return
    end
    
    -- 获取用户输入
    local user_input = context.input or ""
    
    -- 清空缓存（每次新输入时）
    lookup_cache = {}
    
    local count = 0
    for cand in input:iter() do
        count = count + 1
        
        -- 超过限制，直接通过（避免处理太多候选）
        if count > MAX_CANDIDATES then
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        elseif matches_input(cand.text, user_input, precise_positions) then
            ---@diagnostic disable-next-line: undefined-global
            yield(cand)
        end
        -- 不匹配的候选不 yield
    end
end

return filter
