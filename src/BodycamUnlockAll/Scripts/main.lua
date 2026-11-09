--[[
    Bodycam Unlock All
    ------------------
    Grants every Steam promo cosmetic in Bodycam by calling the game's own
    SteamCorePro inventory API once, then verifies ownership against the
    DT_NewShopItem data table.

    Runs automatically and exactly once per game session. No keybinds, no
    hooks, no file patching. See README.md for details.

    Author : Bodycam Unlock All contributors
    License: MIT
]]

local MOD = 'BodycamUnlockAll'
local VERSION = '1.0.0'

-- ---------------------------------------------------------------------------
-- Locate this script's folder (used for config, status and log files)
-- ---------------------------------------------------------------------------

local src = debug.getinfo(1, 'S').source
local dir = src:sub(1, 1) == '@' and src:sub(2):match('^(.*[/\\])') or nil
if not dir then
    pcall(print, '[' .. MOD .. '] BLOCKED: could not resolve script directory\n')
    return
end

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

local CONFIG_DEFAULTS = {
    -- Wait this long after the shop table is found before reading inventory.
    -- Steam needs a few seconds to load the player's inventory after startup.
    WARMUP_SECONDS = 15,

    -- Give up waiting for the game / inventory after this many seconds.
    STARTUP_TIMEOUT_SECONDS = 180,

    -- Extra GrantPromoItems attempts after the first one leaves items locked.
    RETRIES = 3,
    RETRY_DELAY_SECONDS = 30,

    -- If GrantPromoItems does not unlock everything, fall back to
    -- AddPromoItems with the game's full item-definition catalog.
    FALLBACK_ADDPROMOS = true,

    -- Always call GrantPromoItems even when everything is already owned.
    -- Useful for testing; leave false for normal use.
    FORCE_GRANT = false,

    -- Write unlock_status.txt / unlock_log.txt next to the scripts.
    WRITE_STATUS = true,

    -- Rows checked per tick during ownership verification.
    VERIFY_CHUNK = 250,

    -- Milliseconds between ticks.
    TICK_MS = 800,
}

local config = {}
for k, v in pairs(CONFIG_DEFAULTS) do config[k] = v end

local config_error = nil
local okcfg, loaded = pcall(dofile, dir .. 'config.lua')
if okcfg and type(loaded) == 'table' then
    for k, default in pairs(CONFIG_DEFAULTS) do
        local v = loaded[k]
        if type(v) == type(default) then config[k] = v end
    end
elseif not okcfg then
    config_error = tostring(loaded)
end

-- Clamp values to sane ranges so a typo cannot freeze the game.
if type(config.WARMUP_SECONDS) ~= 'number' or config.WARMUP_SECONDS < 0 then config.WARMUP_SECONDS = 15 end
if type(config.STARTUP_TIMEOUT_SECONDS) ~= 'number' or config.STARTUP_TIMEOUT_SECONDS < 30 then config.STARTUP_TIMEOUT_SECONDS = 180 end
if type(config.RETRIES) ~= 'number' or config.RETRIES < 0 then config.RETRIES = 3 end
if type(config.RETRY_DELAY_SECONDS) ~= 'number' or config.RETRY_DELAY_SECONDS < 5 then config.RETRY_DELAY_SECONDS = 30 end
if type(config.VERIFY_CHUNK) ~= 'number' or config.VERIFY_CHUNK < 1 then config.VERIFY_CHUNK = 250 end
if config.VERIFY_CHUNK > 1000 then config.VERIFY_CHUNK = 1000 end
if type(config.TICK_MS) ~= 'number' or config.TICK_MS < 100 then config.TICK_MS = 800 end
if config.TICK_MS > 5000 then config.TICK_MS = 5000 end

-- ---------------------------------------------------------------------------
-- Logging + status report
-- ---------------------------------------------------------------------------

local TEMP_DIR = os.getenv('TEMP')
local log_path = nil

local function append_log(line)
    if log_path == nil then log_path = dir .. 'unlock_log.txt' end
    local f = io.open(log_path, 'ab')
    if f == nil and TEMP_DIR ~= nil and TEMP_DIR ~= '' then
        log_path = TEMP_DIR .. '\\BodycamUnlockAll-unlock_log.txt'
        f = io.open(log_path, 'ab')
    end
    if f ~= nil then
        f:write(os.date('%Y-%m-%d %H:%M:%S'), ' ', line, '\r\n')
        f:close()
    end
end

local function log(message)
    local text = tostring(message)
    pcall(print, '[' .. MOD .. '] ' .. text .. '\n')
    append_log(text)
end

local started_at = os.time()
local current_stage = 'STARTING'
local stage_detail = nil
local status_owned = nil
local status_total = nil
local status_missing = nil
local method_used = nil

local function build_status_text()
    local owned_text = 'unknown'
    if status_owned ~= nil and status_total ~= nil then
        owned_text = tostring(status_owned) .. '/' .. tostring(status_total)
    end
    local lines = {
        'Bodycam Unlock All v' .. VERSION,
        'Time: ' .. os.date('%Y-%m-%d %H:%M:%S'),
        'Stage: ' .. current_stage,
        'Owned: ' .. owned_text,
        'Missing: ' .. (status_missing ~= nil and tostring(status_missing) or 'unknown'),
        'Method: ' .. (method_used or 'none'),
        'Elapsed: ' .. tostring(os.time() - started_at) .. 's',
    }
    if stage_detail ~= nil then lines[#lines + 1] = 'Detail: ' .. stage_detail end
    if config_error ~= nil then lines[#lines + 1] = 'Config: ' .. tostring(config_error):sub(1, 300) end
    lines[#lines + 1] = 'Script: ' .. dir
    return table.concat(lines, '\r\n') .. '\r\n'
end

local function write_status()
    if config.WRITE_STATUS ~= true then return end
    local text = build_status_text()
    local candidates = { dir .. 'unlock_status.txt' }
    if TEMP_DIR ~= nil and TEMP_DIR ~= '' then
        candidates[#candidates + 1] = TEMP_DIR .. '\\BodycamUnlockAll-unlock_status.txt'
    end
    for _, path in ipairs(candidates) do
        local f = io.open(path, 'wb')
        if f ~= nil then
            f:write(text)
            f:close()
            return
        end
    end
end

local function set_stage(stage, detail)
    current_stage = stage
    stage_detail = detail
    write_status()
    log('stage=' .. stage .. (detail ~= nil and (' (' .. detail .. ')') or ''))
end

-- ---------------------------------------------------------------------------
-- Generic UE reflection helpers
-- ---------------------------------------------------------------------------

local function get(obj, key)
    if obj == nil then return nil end
    local ok, value = pcall(function() return obj[key] end)
    if ok then return value end
    return nil
end

local function call(obj, key, ...)
    local fn = get(obj, key)
    if fn == nil then return false, 'missing ' .. tostring(key) end
    return pcall(fn, obj, ...)
end

local function obj_name(obj)
    if obj == nil then return 'nil' end
    local ok, name = call(obj, 'GetFullName')
    if ok and name ~= nil then return tostring(name) end
    return '?'
end

local function count_of(arr)
    local ok, n = call(arr, 'GetArrayNum')
    if ok and type(n) == 'number' then return n end
    return 0
end

local function first_of(class_name)
    local ok, list = pcall(FindAllOf, class_name)
    if ok and type(list) == 'table' then
        for _, obj in ipairs(list) do
            if obj ~= nil then return obj end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Game object discovery
-- ---------------------------------------------------------------------------

local gi = nil
local shop_dt = nil
local steampro = nil
local all_rows = nil

local function find_shop_dt()
    local ok, list = pcall(FindAllOf, 'DataTable')
    if ok and type(list) == 'table' then
        local by_struct = nil
        for _, dt in ipairs(list) do
            local okn, full = pcall(function() return dt:GetFullName() end)
            if okn and type(full) == 'string' then
                if full:find('DT_NewShopItem', 1, true) ~= nil then
                    return dt
                end
                if by_struct == nil then
                    local okr, row_struct = pcall(function() return dt:GetRowStruct() end)
                    if okr and row_struct ~= nil then
                        local okrn, rsname = pcall(function() return row_struct:GetFullName() end)
                        if okrn and type(rsname) == 'string' and rsname:find('ShopItemDef', 1, true) ~= nil then
                            by_struct = dt
                        end
                    end
                end
            end
        end
        if by_struct ~= nil then return by_struct end
    end
    -- Last resort: load the known asset path explicitly.
    if type(LoadAsset) == 'function' then
        local okl, dt = pcall(LoadAsset, '/Game/BodycamCore/ItemsDefinition/DT_NewShopItem.DT_NewShopItem')
        if okl and dt ~= nil then return dt end
    end
    return nil
end

local function collect_rows(dt)
    local ok, row_map = pcall(function() return dt:GetRowMap() end)
    if not ok then return nil, 'GetRowMap failed: ' .. tostring(row_map) end
    if type(row_map) ~= 'table' then return nil, 'GetRowMap returned ' .. type(row_map) end
    local rows = {}
    for name, row in pairs(row_map) do
        if row ~= nil then
            rows[#rows + 1] = { name = tostring(name), row = row }
        end
    end
    return rows
end

local function get_steampro()
    if type(StaticFindObject) ~= 'function' then
        return nil, 'StaticFindObject is unavailable in this UE4SS build'
    end
    local ok, obj = pcall(StaticFindObject, '/Script/SteamCorePro.Default__SteamProInventory')
    if not ok or obj == nil then
        return nil, 'SteamProInventory class default object not found'
    end
    local okn, full = pcall(function() return obj:GetFullName() end)
    if not okn or type(full) ~= 'string' or full:find('SteamProInventory', 1, true) == nil then
        return nil, 'SteamProInventory validation failed'
    end
    return obj
end

-- ---------------------------------------------------------------------------
-- Grant / verify operations
-- ---------------------------------------------------------------------------

local function grant_promos()
    if steampro == nil then
        local obj, err = get_steampro()
        if obj == nil then return false, err end
        steampro = obj
    end
    local ok, result = pcall(function() return steampro:GrantPromoItems({}) end)
    if not ok then
        steampro = nil -- re-resolve next attempt
        return false, tostring(result)
    end
    return true, result
end

local function add_promos_fallback()
    if steampro == nil then
        local obj, err = get_steampro()
        if obj == nil then return false, err end
        steampro = obj
    end
    local catalog = get(gi, 'Item with Prices Defs')
    if catalog == nil then return false, 'item price catalog unavailable on game instance' end

    -- Try both plausible signatures (out-param table vs. single array).
    local attempts = {
        function() return steampro:AddPromoItems(catalog, {}) end,
        function() return steampro:AddPromoItems(catalog) end,
    }
    local last_error = nil
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt)
        if ok then return true, result end
        last_error = tostring(result)
    end
    return false, last_error
end

-- Shared state. Declared before the functions that use it.
local state = 'wait_gi'
local loop_handle = nil
local grant_attempts = 0
local retry_at = 0
local fallback_tried = false
local last_error = nil
local warmup_deadline = 0
local verify_state = nil
local finish -- forward declaration, defined below

local function start_verify(tag)
    if all_rows == nil then
        if shop_dt == nil then shop_dt = find_shop_dt() end
        if shop_dt == nil then
            finish('FAILED:no_datatable', 'DT_NewShopItem not found')
            return
        end
        local rows, err = collect_rows(shop_dt)
        if rows == nil then
            finish('FAILED:read_datatable', err)
            return
        end
        all_rows = rows
    end
    if #all_rows == 0 then
        finish('FAILED:empty_datatable', 'DT_NewShopItem has no rows')
        return
    end
    verify_state = {
        tag = tag,
        rows = all_rows,
        idx = 1,
        owned = 0,
        errors = 0,
        missing = {},
    }
    state = 'verify'
    set_stage(tag == 'initial' and 'CHECKING' or 'VERIFYING', string.format('%d shop rows', #all_rows))
end

local function verify_step()
    local st = verify_state
    local last = math.min(st.idx + config.VERIFY_CHUNK - 1, #st.rows)
    for i = st.idx, last do
        local entry = st.rows[i]
        local ok, result = pcall(function() return gi:HasPlayerUnlockedInventoryItem(entry.row) end)
        if ok and result == true then
            st.owned = st.owned + 1
        else
            if #st.missing < 12 then st.missing[#st.missing + 1] = entry.name end
            if not ok then st.errors = st.errors + 1 end
        end
    end
    st.idx = last + 1
    if st.idx > #st.rows then
        verify_state = nil
        return true, st
    end
    return false, st
end

local function missing_sample(st, limit)
    local count = math.min(#st.missing, limit or 5)
    if count == 0 then return '' end
    local names = {}
    for i = 1, count do names[i] = st.missing[i] end
    return table.concat(names, ', ')
end

finish = function(stage, detail)
    state = 'done'
    current_stage = stage
    stage_detail = detail
    if status_owned ~= nil and status_total ~= nil then
        status_missing = status_total - status_owned
    end
    write_status()
    log('RESULT ' .. stage .. (detail ~= nil and (' - ' .. detail) or ''))
    if loop_handle ~= nil and type(CancelDelayedAction) == 'function' then
        pcall(CancelDelayedAction, loop_handle)
    end
end

local function begin_grant()
    grant_attempts = grant_attempts + 1
    state = 'grant'
    set_stage('GRANTING', string.format('GrantPromoItems attempt %d', grant_attempts))
    local ok, result = grant_promos()
    if ok then
        method_used = 'GrantPromoItems'
        last_error = nil
        log('GrantPromoItems call succeeded')
    else
        method_used = 'GrantPromoItems (failed)'
        last_error = tostring(result)
        log('GrantPromoItems failed: ' .. last_error)
    end
    start_verify('after_grant')
end

local function begin_fallback()
    fallback_tried = true
    state = 'fallback'
    set_stage('FALLBACK', 'AddPromoItems with the full catalog')
    local ok, result = add_promos_fallback()
    if ok then
        method_used = 'AddPromoItems'
        last_error = nil
        log('AddPromoItems fallback call succeeded')
    else
        method_used = 'AddPromoItems (failed)'
        last_error = tostring(result)
        log('AddPromoItems fallback failed: ' .. last_error)
    end
    start_verify('fallback')
end

local function on_verify_done(st)
    local total = #st.rows
    status_owned = st.owned
    status_total = total
    status_missing = total - st.owned
    log(string.format('verify[%s] owned=%d/%d errors=%d', st.tag, st.owned, total, st.errors))

    if st.owned == total then
        if st.tag == 'initial' then
            method_used = 'none (already owned)'
            finish('ALREADY_UNLOCKED', 'all shop items were already owned')
        else
            finish('GRANTED', 'unlocked all shop items')
        end
        return
    end

    if st.errors == total then
        if st.tag == 'initial' then
            log('warning: ownership checks failed for every row; attempting a blind grant')
            begin_grant()
        else
            finish('FAILED:verify_unavailable',
                'HasPlayerUnlockedInventoryItem failed for every row; last error: ' .. tostring(last_error))
        end
        return
    end

    if st.tag == 'initial' then
        begin_grant()
        return
    end

    local locked = total - st.owned
    local sample = missing_sample(st)
    local detail = string.format('%d of %d still locked', locked, total)
    if sample ~= '' then detail = detail .. '; first missing: ' .. sample end
    if last_error ~= nil then detail = detail .. '; last error: ' .. last_error end

    if st.tag == 'fallback' then
        finish('FAILED:incomplete', detail)
        return
    end

    if grant_attempts <= config.RETRIES then
        state = 'retry_wait'
        retry_at = os.time() + config.RETRY_DELAY_SECONDS
        set_stage('RETRY_WAIT', string.format('%d/%d locked; retry %d/%d in %ds',
            locked, total, grant_attempts + 1, config.RETRIES + 1, config.RETRY_DELAY_SECONDS))
    elseif config.FALLBACK_ADDPROMOS == true and not fallback_tried then
        begin_fallback()
    else
        finish('FAILED:incomplete', detail)
    end
end

-- ---------------------------------------------------------------------------
-- State machine
-- ---------------------------------------------------------------------------

local function tick()
    if state == 'done' then return end
    local now = os.time()

    if state == 'wait_gi' then
        if gi == nil then gi = first_of('BodycamGI_C') end
        if gi ~= nil then
            log('game instance found: ' .. obj_name(gi))
            set_stage('WAITING_FOR_GAME', 'Game instance found')
            state = 'wait_dt'
        elseif now - started_at >= config.STARTUP_TIMEOUT_SECONDS then
            finish('FAILED:game_not_ready',
                'BodycamGI_C not found after ' .. tostring(config.STARTUP_TIMEOUT_SECONDS) .. 's')
        end
        return
    end

    if state == 'wait_dt' then
        if shop_dt == nil then shop_dt = find_shop_dt() end
        if shop_dt ~= nil then
            local rows, err = collect_rows(shop_dt)
            if rows == nil then
                finish('FAILED:read_datatable', err)
                return
            end
            if #rows > 0 then
                all_rows = rows
                warmup_deadline = now + config.WARMUP_SECONDS
                state = 'warmup'
                set_stage('WARMING_UP', string.format(
                    '%d shop rows found; waiting %ds for Steam inventory',
                    #rows, config.WARMUP_SECONDS))
                return
            end
        end
        if now - started_at >= config.STARTUP_TIMEOUT_SECONDS then
            finish('FAILED:no_datatable',
                'DT_NewShopItem not found after ' .. tostring(config.STARTUP_TIMEOUT_SECONDS) .. 's')
        end
        return
    end

    if state == 'warmup' then
        if now >= warmup_deadline then
            if config.FORCE_GRANT == true then
                begin_grant()
            else
                start_verify('initial')
            end
        end
        return
    end

    if state == 'verify' then
        if verify_state == nil then
            finish('FAILED:internal', 'verification state was lost')
            return
        end
        local done, st = verify_step()
        if done then on_verify_done(st) end
        return
    end

    if state == 'retry_wait' then
        if now >= retry_at then begin_grant() end
        return
    end
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

if type(LoopInGameThreadWithDelay) ~= 'function' then
    current_stage = 'FAILED:no_loop_api'
    stage_detail = 'LoopInGameThreadWithDelay is unavailable in this UE4SS build'
    write_status()
    log(stage_detail)
    return
end

log('v' .. VERSION .. ' starting (dir=' .. dir .. ')')
log(string.format('config: warmup=%ds timeout=%ds retries=%d chunk=%d tick=%dms force_grant=%s',
    config.WARMUP_SECONDS, config.STARTUP_TIMEOUT_SECONDS, config.RETRIES,
    config.VERIFY_CHUNK, config.TICK_MS, tostring(config.FORCE_GRANT)))
if config_error ~= nil then
    log('config.lua could not be loaded, using defaults: ' .. tostring(config_error))
end
set_stage('STARTING', 'waiting for the game world')

loop_handle = LoopInGameThreadWithDelay(config.TICK_MS, function()
    local ok, err = pcall(tick)
    if not ok then
        log('tick error: ' .. tostring(err))
    end
end)
