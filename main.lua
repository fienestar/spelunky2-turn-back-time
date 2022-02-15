meta.name = 'Turn Back Time'
meta.version = '0.0.5'
meta.description = 'Pay money and go back to the past'
meta.author = 'fienestar'

local status = {}
local restart = false

local vars = {
    state = {'seed', 'level_count', 'time_total', 'shoppie_aggro', 'shoppie_aggro_next', 'merchant_aggro', 'kali_favor', 'kali_status', 'kali_altars_destroyed', 'level_flags', 'quest_flags', 'journal_flags', 'presence_flags', 'special_visibility_flags', 'kills_npc', 'damage_taken', 'time_last_level', 'saved_dogs', 'saved_cats', 'saved_hamsters', 'money_last_levels', 'money_shop_total', 'correct_ushabti'},
    quests = {'yang_state', 'jungle_susters_flags', 'van_horsing_state', 'sparrow_state', 'madame_tusk_state', 'beg_state'},
    inventory = {'health', 'bombs', 'ropes', 'held_item', 'held_item_metadata', 'kapala_blood_amount', 'poison_tick_timer', 'cursed', 'elixir_buff', 'mount_type', 'mount_metadata', 'kills_level', 'kills_total', 'collected_money_total'}
}

local names = {}
for i,v in pairs(ENT_TYPE) do
    names[v] = i
end

local function save(from, arr)
    for i,v in ipairs(arr) do
        status[v] = from[v]
    end
end

local function load(to, arr)
    for i,v in ipairs(arr) do
        if status[v] ~= nil then
            to[v] = status[v]
        end
    end
end

local function clear()
    status = {}
    status.back = -1
    status.power = {}
    status.rng = {}
end

death_count = 0
end_hashes = {
    0x3877db27, -- 온갖 어려움에도 불구하고, 나는 티아마트를 물리치고 지상으로 탈출했어.
    0x6990f16a, -- 놀랍게도 나는 훈둔을 물리치고 지상으로 탈출했어.
    0x5961bce3, -- 나는 기술과 지식, 용맹 덕분에 우주의 일원이 될 수 있었어.
    0x551be6e9, -- 나는 결국 레벨 %d-%d (%ls)에서 사망했어.
    0xe46f0a0c, -- 나는 결국 레벨 %d-%d에서 사망했어.
}

end_strings = {}

is_ko = false

set_callback(function()
    is_ko = #get_string(hash_to_stringid(end_hashes[1])) == 99
    for idx=1,5 do
        end_strings[idx] = get_string(hash_to_stringid(end_hashes[idx]))
    end
end, ON.LOAD)


local function update_death_count(new_death_count)
    death_count = new_death_count

    text = ''
    if death_count > 0 then
        if is_ko then
            text = "나는 시간을 " .. tostring(death_count) .. "번 되돌렸어.\n"
        elseif death_count > 1 then
            text = "I turned back time " .. tostring(death_count) .. " times.\n"
        else
            text = "I turned back time.\n"
        end
    end

    for idx=1,5 do
        change_string(hash_to_stringid(end_hashes[idx]), text .. end_strings[idx])
    end
end

local function get_cost()
    return math.floor(5000 * 1.25^(death_count + state.world - 1))
end

local function is_restart_possible()
    return state.items.player_inventory[1].collected_money_total + status.money_shop_total >= get_cost()
end

local function is_restart_needed()
    return is_restart_possible()
        and not entity_has_item_type(players[1].uid, ENT_TYPE.ITEM_POWERUP_ANKH)
end

local function restart_level()
    restart = true
    update_death_count(death_count + 1)
    state.screen_next = SCREEN.LEVEL
    state.screen_last = SCREEN.TRANSITION
    state.world_next = state.world
    state.level_next = state.level
    state.theme_next = state.theme
    state.quest_flags = 1
    state.loading = 2
end

local function request_restart_level()
    if is_restart_needed() then
        status.collected_money_total = status.collected_money_total - get_cost()
        restart_level()
    end
end

set_callback(function()
    if state.items.player_inventory[1].health < 1 then
        state.items.player_inventory[1].health = 4
    end

    if restart then
        if status.rng then
            for i,v in ipairs(status.rng) do
                prng:set_pair(i, v.a, v.b)
            end
        end
        load(state, vars.state)
        load(state.quests, vars.quests)
        load(state.items.player_inventory[1], vars.inventory)
    else
        if state.time_total == 0 then
            update_death_count(0)
        end

        if not status.rng then
            status.rng = {}
        end
        for i=1,20 do
            local a,b = prng:get_pair(i)
            status.rng[i] = { a=a, b=b }
        end
        save(state, vars.state)
        save(state.quests, vars.quests)
        save(state.items.player_inventory[1], vars.inventory)
    end
end, ON.PRE_LEVEL_GENERATION)

set_callback(function()
    local ent = players[1]
    if restart then
        if status.power then
            for i,v in ipairs(status.power) do
                local m = string.find(names[v], 'PACK')
                if not m and not ent:has_powerup(v) then
                    ent:give_powerup(v)
                end
            end
        end
        if status.back and status.back ~= -1 and ent:worn_backitem() == -1 then
            pick_up(ent.uid, spawn(status.back, 0, 0, LAYER.PLAYER, 0, 0))
        end
    else
        status.back = -1
        local backitem = worn_backitem(players[1].uid)
        if backitem ~= -1 then
            status.back = get_entity(backitem).type.id
        end

        status.power = {}
        for i,v in ipairs(players[1]:get_powerups()) do
            status.power[i] = v
        end
    end

    set_on_kill(ent.uid, request_restart_level)
    set_on_destroy(ent.uid, request_restart_level)

    restart = false
end, ON.LEVEL)

set_callback(function()
    if state.theme == 17 or state.theme == 0 then return end
    local tile = get_grid_entity_at(6, 121, LAYER.FRONT)
    if tile then
        tile_entity = get_entity(tile)
        if tile_entity then
            tile_entity:destroy()
        end
    end
end, ON.TRANSITION)

set_callback(function(draw_ctx)
    if state.theme == 17 or state.theme == 0 then return end
    if state.time_level < 15 then return end
    cost_color = rgba(171, 26, 45, 255)
    if is_restart_possible() then
        cost_color = rgba(10, 149, 255, 255)
    end

    font_size = math.floor(70.0 / 3840.0 * get_window_size())
    draw_ctx:draw_text(-0.67, 0.95, font_size, "Cost: " .. tostring(get_cost()), cost_color)
    draw_ctx:draw_text(-0.67, 0.9, font_size, "Death: " .. tostring(death_count), rgba(171, 26, 45, 255))
end, ON.GUIFRAME)

set_callback(function()
    update_death_count(0)
end, ON.DEATH)
