local processor = {}

function processor.fini(env)
    if env.connection then
        env.connection:disconnect()
        env.connection = nil
    end
end

function processor.func(key_event, env)
    if key_event:release() or key_event:shift() or key_event:ctrl()
        or key_event:alt() or key_event:super() then
        return 2
    end

    -- 使用独立键码，不受 Caps Lock 等状态对 repr() 的影响。
    local digit = key_event.keycode - 0xffb0 -- XK_KP_0
    if digit < 0 or digit > 9 then
        return 2
    end

    local context = env.engine.context
    if not context:is_composing() then
        env.engine:commit_text(tostring(digit))
        return 1
    end

    if not context:get_option("ascii_mode") then
        processor.fini(env)
        -- 与 inline_ascii 相同：本次组合结束后恢复中文，不永久切换输入模式。
        env.connection = context.update_notifier:connect(function(ctx)
            if not ctx:is_composing() then
                processor.fini(env)
                ctx:set_option("ascii_mode", false)
            end
        end)
        context:set_option("ascii_mode", true)
    end
    context:push_input(tostring(digit))
    return 1
end

return processor
