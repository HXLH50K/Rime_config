-- kp_num_processor.lua
local function processor(key_event, env)
    local key_code = key_event:repr() -- 获取按键名称
    -- 定义数字键盘数字键的映射
    local numpad_keys = {
        ["KP_0"] = "0",
        ["KP_1"] = "1",
        ["KP_2"] = "2",
        ["KP_3"] = "3",
        ["KP_4"] = "4",
        ["KP_5"] = "5",
        ["KP_6"] = "6",
        ["KP_7"] = "7",
        ["KP_8"] = "8",
        ["KP_9"] = "9"
    }
 
    -- 检查是否是数字键盘数字键
    if numpad_keys[key_code] then
        local context = env.engine.context -- 获取输入上下文
        local input_text = context.input -- 获取当前输入的原始码
        if input_text and input_text ~= "" then
            -- 如果有输入的原始码，拼接原始码和数字并提交
            env.engine:commit_text(input_text .. numpad_keys[key_code])
            context:clear() -- 清空输入缓冲区
        else
            -- 如果没有原始码，只提交数字
            env.engine:commit_text(numpad_keys[key_code])
        end
        return 1 -- 表示按键已处理
    end
 
    return 2 -- 未处理，交给其他处理器
end
 
return processor
