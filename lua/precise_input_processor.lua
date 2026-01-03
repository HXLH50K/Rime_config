-- precise_input_processor.lua
-- 精确输入处理器：拦截大写字母，记录精确输入序列，转换为小写发送给 speller
-- 
-- 使用场景：18键模糊输入时，滑动发送大写字母作为"精确输入标记"
-- 点击发送小写字母（触发模糊匹配），滑动发送大写字母（精确匹配）
--
-- 工作原理：
-- 1. 拦截大写字母输入（A-Z）
-- 2. 将大写字母位置记录到 precise_input_map（用于 filter 过滤）
-- 3. 转换为小写字母发送给引擎
--
-- 配合 precise_input_filter.lua 使用
-- 参考：lua/sbxlm/upper_case.lua

local rime = require "sbxlm.lib"

local function processor(key, env)
    -- 只处理按键按下事件，忽略释放、Alt、Ctrl、Caps
    if key:release() or key:alt() or key:ctrl() or key:caps() then
        return rime.process_results.kNoop
    end
    
    local keycode = key.keycode
    local context = env.engine.context
    
    -- 检查是否是大写字母 (A=65, Z=90)
    if keycode >= 65 and keycode <= 90 then
        -- 转换为小写字母
        local char = utf8.char(keycode + 32)
        
        -- 获取当前输入长度（新字母将添加到这个位置）
        local pos = #context.input + 1
        
        -- 获取或初始化精确输入记录
        local precise_map = context:get_property("precise_input_map") or ""
        
        -- 记录这个位置是精确输入
        -- 格式: "1,3,5" 表示第1、3、5个字符是精确输入
        if #precise_map > 0 then
            precise_map = precise_map .. "," .. tostring(pos)
        else
            precise_map = tostring(pos)
        end
        context:set_property("precise_input_map", precise_map)
        
        -- 追加小写字母到输入
        context:push_input(char)
        
        return rime.process_results.kAccepted
    end
    
    -- 检查是否是退格键 (BackSpace = 0xff08 = 65288)
    if keycode == 65288 or keycode == 0xff08 then
        -- 需要更新精确输入记录
        local precise_map = context:get_property("precise_input_map") or ""
        if #precise_map > 0 and #context.input > 0 then
            -- 解析当前记录
            local positions = {}
            for p in string.gmatch(precise_map, "(%d+)") do
                local pos_num = tonumber(p)
                if pos_num < #context.input then
                    -- 保留比当前输入长度小的位置
                    table.insert(positions, pos_num)
                end
            end
            -- 重建记录
            context:set_property("precise_input_map", table.concat(positions, ","))
        end
        -- 让其他 processor 处理退格
        return rime.process_results.kNoop
    end
    
    -- 检查是否是 Escape (0xff1b = 65307)
    if keycode == 65307 or keycode == 0xff1b then
        -- 清空精确输入记录
        context:set_property("precise_input_map", "")
        return rime.process_results.kNoop
    end
    
    -- 其他按键不处理
    return rime.process_results.kNoop
end

return processor
