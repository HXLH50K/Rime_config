local M = {}
local stores = {}
local day_seconds = 86400

local function check(value, message)
    if not value then
        error("recent_frequency: " .. message)
    end
    return value
end

local function encode(text)
    return (text:gsub(".", function(char)
        return string.format("%02x", string.byte(char))
    end))
end

local function decode(text)
    check(#text > 0 and #text % 2 == 0 and not text:find("[^0-9a-f]"), "invalid history key")
    return (text:gsub("..", function(pair)
        return string.char(tonumber(pair, 16))
    end))
end

local function history_path(store, slot)
    return store.directory .. package.config:sub(1, 1) .. "recent_frequency." .. slot .. ".tsv"
end

local function apply_event(store, key, timestamp, count)
    if count == 0 then
        store.events[key] = nil
    else
        local events = store.events[key] or {}
        local last = events[#events]
        if last and last.time == timestamp then
            last.count = last.count + count
        else
            events[#events + 1] = { time = timestamp, count = count }
        end
        store.events[key] = events
    end
end

local function open_store(directory, now)
    if stores[directory] then
        stores[directory].users = stores[directory].users + 1
        return stores[directory]
    end
    local today = math.floor(now / day_seconds)
    local store = { directory = directory, events = {}, days = {}, users = 1, pruned_day = today }
    -- Four UTC-day slots cover any rolling 72-hour interval without rewriting
    -- live history. Reusing a slot only discards records outside that interval.
    for day = today - 3, today do
        local slot = day % 4
        local path = history_path(store, slot)
        local file, message, code = io.open(path, "r")
        if not file then
            check(code == 2, "cannot read history: " .. tostring(message))
        else
            local header = file:read("*l")
            local saved_day = header and tonumber(header:match("^v1\t(%d+)$"))
            if not saved_day or saved_day % 4 ~= slot then
                file:close()
                error("recent_frequency: invalid history header: " .. path)
            end
            store.days[slot] = saved_day
            if saved_day == day then
                for line in file:lines() do
                    local timestamp, count, key = line:match("^(%d+)\t([01])\t([0-9a-f]+)$")
                    if not timestamp or #key % 2 ~= 0 then
                        file:close()
                        error("recent_frequency: invalid history record: " .. path)
                    end
                    timestamp = tonumber(timestamp)
                    if math.floor(timestamp / day_seconds) ~= day then
                        file:close()
                        error("recent_frequency: history timestamp outside its day: " .. path)
                    end
                    apply_event(store, decode(key), timestamp, tonumber(count))
                end
            end
            check(file:close(), "cannot close history: " .. path)
        end
    end
    stores[directory] = store
    return store
end

local function record(store, key, now, count)
    local day = math.floor(now / day_seconds)
    if day > store.pruned_day then
        for word, events in pairs(store.events) do
            local kept = {}
            for _, event in ipairs(events) do
                if now - event.time < 3 * day_seconds then
                    kept[#kept + 1] = event
                end
            end
            store.events[word] = #kept > 0 and kept or nil
        end
        store.pruned_day = day
    end
    local slot = day % 4
    local path = history_path(store, slot)
    local append = store.days[slot] == day
    check(not store.days[slot] or store.days[slot] <= day, "system clock moved backwards across history slots")
    local file, message = io.open(path, append and "a" or "w")
    check(file, "cannot write history: " .. tostring(message))
    local line = string.format("%d\t%d\t%s\n", now, count, encode(key))
    if not append then
        line = "v1\t" .. day .. "\n" .. line
    end
    local written, write_error = file:write(line)
    local closed, close_error = file:close()
    check(written and closed, "history write failed: " .. tostring(write_error or close_error))
    store.days[slot] = day
    apply_event(store, key, now, count)
end

local function recent_score(env, text, now)
    local key = env.language .. "\t" .. text
    local events = env.store.events[key]
    if not events then
        return 0
    end
    local kept, score = {}, 0
    for _, event in ipairs(events) do
        local age = now - event.time
        if age < env.window then
            kept[#kept + 1] = event
            if age >= 0 then
                score = score + event.count * 2 ^ (-age / env.half_life)
            end
        end
    end
    env.store.events[key] = #kept > 0 and kept or nil
    return score
end

local function phrase_text(candidate, language)
    local phrase = candidate and candidate:get_genuine():to_phrase()
    if phrase and phrase.lang_name == language then
        return phrase.text
    end
end

function M.init(env)
    local config = env.engine.schema.config
    env.native = check(Component.Translator(env.engine, "translator", "script_translator"), "cannot create native translator")
    env.enabled = config:get_bool("recent_frequency/enabled")
    check(env.enabled ~= nil, "missing enabled setting")
    if not env.enabled then return end
    local hours = check(config:get_double("recent_frequency/window_hours"), "missing window_hours")
    local half_life = check(config:get_double("recent_frequency/half_life_hours"), "missing half_life_hours")
    check(hours > 0 and hours <= 72, "window_hours must be in (0, 72]")
    check(half_life > 0 and half_life <= hours, "half_life_hours must be in (0, window_hours]")
    env.window, env.half_life = hours * 3600, half_life * 3600
    env.initial_quality = config:get_double("translator/initial_quality") or 0
    local dictionary = check(config:get_string("translator/dictionary"), "missing translator dictionary")
    env.language = config:get_string("translator/user_dict") or dictionary:match("^[^.]+")
    -- YAML includes run before later patches. Copy the final options instead,
    -- including the platform prism, grammar and user customizations.
    local options = check(config:get_map("translator"), "missing translator options")
    local baseline_options = ConfigMap()
    for _, key in ipairs(options:keys()) do
        baseline_options:set(key, options:get(key))
    end
    baseline_options:set("enable_user_dict", ConfigValue(false).element)
    check(config:set_item("recent_frequency_base", baseline_options.element), "cannot configure baseline translator")
    env.baseline = check(Component.Translator(env.engine, "recent_frequency_base", "script_translator"), "cannot create baseline translator")
    env.store = open_store(rime_api.get_user_data_dir(), os.time())

    env.commit_connection = env.engine.context.commit_notifier:connect(function(ctx)
        local seen, combined = {}, ""
        local function remember(text)
            if text ~= "" and not seen[text] then
                record(env.store, env.language .. "\t" .. text, os.time(), 1)
                seen[text] = true
            end
        end
        for _, segment in ipairs(ctx.composition:toSegmentation():get_segments()) do
            local text = phrase_text(segment:get_selected_candidate(), env.language)
            if text then
                remember(text)
                combined = combined .. text
            else
                remember(combined)
                combined = ""
            end
        end
        remember(combined)
    end)
    env.delete_connection = env.engine.context.delete_notifier:connect(function(ctx)
        local text = phrase_text(ctx:get_selected_candidate(), env.language)
        if text then
            record(env.store, env.language .. "\t" .. text, os.time(), 0)
        end
    end)
end

local function reader(translation)
    if not translation then
        return function() return nil end
    end
    local next_candidate, state = translation:iter()
    return function() return next_candidate(state) end
end

function M.func(input, segment, env)
    local next_native = reader(env.native:query(input, segment))
    if not env.enabled then
        for candidate in next_native do yield(candidate) end
        return
    end
    local next_base = reader(env.baseline:query(input, segment))
    local native, base = next_native(), next_base()
    local now = os.time()
    while native or base do
        local endpoint = math.max(native and native._end or -1, base and base._end or -1)
        local candidates, by_text, priors = {}, {}, {}
        local function add(candidate)
            if not by_text[candidate.text] then
                local item = { candidate = candidate, order = #candidates + 1 }
                candidates[#candidates + 1] = item
                by_text[candidate.text] = item
            end
        end
        while native and native._end == endpoint do
            add(native)
            native = next_native()
        end
        local rank = 0
        while base and base._end == endpoint do
            if not priors[base.text] then
                rank = rank + 1
                priors[base.text] = 1 / rank
            end
            add(base)
            base = next_base()
        end
        for _, item in ipairs(candidates) do
            -- Keep native dictionary order as the prior, but never import the
            -- native user-frequency bonus or its unconditional user-word priority.
            item.prior = priors[item.candidate.text] or 0
            item.score = item.prior + recent_score(env, item.candidate.text, now)
        end
        table.sort(candidates, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            if a.prior ~= b.prior then return a.prior > b.prior end
            return a.order < b.order
        end)
        for _, item in ipairs(candidates) do
            -- Keep this translator in its configured priority band so a burst
            -- of usage cannot overtake explicitly pinned phrases or utilities.
            item.candidate.quality = env.initial_quality + item.score / (1 + item.score)
            yield(item.candidate)
        end
    end
end

function M.fini(env)
    if env.commit_connection then env.commit_connection:disconnect() end
    if env.delete_connection then env.delete_connection:disconnect() end
    if env.store then
        env.store.users = env.store.users - 1
        if env.store.users == 0 then stores[env.store.directory] = nil end
    end
    env.native, env.baseline = nil, nil
end

return M
